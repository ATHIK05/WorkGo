const express = require("express");
const router = express.Router();
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");
const { sendOtp, verifyOtp, sanitizePhoneNumber } = require("../services/sms_service");

// Specific rate limit: max 5 OTP requests per 10 minutes per IP
const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  message: { error: "Too many OTP requests. Please wait a few minutes before trying again." },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * Middleware: Verify Firebase ID token if present, but optional for initial login
 */
const optionalVerifyToken = async (req, _res, next) => {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith("Bearer ")) {
    try {
      const token = auth.split(" ")[1];
      req.user = await admin.auth().verifyIdToken(token);
    } catch (_) {
      // Continue without user
    }
  }
  next();
};

/**
 * Middleware: Strictly require Firebase ID token
 */
const requireToken = async (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or invalid Authorization header" });
  }
  try {
    const token = auth.split(" ")[1];
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token", detail: e.message });
  }
};

/**
 * POST /api/auth/send-otp
 * Dispatches 2Factor SMS OTP to a 10-digit Indian phone number.
 */
router.post("/send-otp", otpLimiter, async (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    return res.status(400).json({ error: "Phone number is required" });
  }

  const cleanPhone = sanitizePhoneNumber(phone);
  if (!cleanPhone || cleanPhone.length !== 10) {
    return res.status(400).json({ error: "Valid 10-digit mobile number required" });
  }

  const result = await sendOtp(req.db, cleanPhone);
  if (!result.success) {
    return res.status(500).json({ error: result.error || "Failed to send OTP" });
  }

  return res.json({
    success: true,
    sessionId: result.sessionId,
    phone: cleanPhone,
  });
});

/**
 * POST /api/auth/verify-and-link-phone
 * Verifies OTP and binds the phone to the logged-in user's UID (preventing duplicate accounts).
 */
router.post("/verify-and-link-phone", requireToken, async (req, res) => {
  const { sessionId, otpCode, phone, role } = req.body;
  const uid = req.user.uid;

  if (!sessionId || !otpCode || !phone) {
    return res.status(400).json({ error: "Missing sessionId, otpCode, or phone" });
  }

  const cleanPhone = sanitizePhoneNumber(phone);
  if (!cleanPhone || cleanPhone.length !== 10) {
    return res.status(400).json({ error: "Invalid 10-digit phone number" });
  }

  // 1. Verify OTP with 2Factor
  const verifyResult = await verifyOtp(req.db, sessionId, otpCode);
  if (!verifyResult.success) {
    return res.status(400).json({ error: verifyResult.error || "Invalid OTP" });
  }

  const formattedPhone = `+91${cleanPhone}`;
  const collectionName = role === "worker" ? "workers" : "users";

  try {
    // 2. Check if phone is already linked to another UID
    const existingCheck = await req.db
      .collection(collectionName)
      .where("phoneNumber", "==", formattedPhone)
      .limit(1)
      .get();

    if (!existingCheck.empty && existingCheck.docs[0].id !== uid) {
      return res.status(409).json({
        error: "This phone number is already linked to another WorkGo account.",
      });
    }

    // 3. Update Firestore user document
    const updateData = {
      phoneNumber: formattedPhone,
      phoneVerified: true,
      phoneVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await req.db.collection(collectionName).doc(uid).set(updateData, { merge: true });

    // Also update customer collection if worker has dual entry
    if (role === "worker") {
      await req.db.collection("users").doc(uid).set(updateData, { merge: true }).catch(() => {});
    }

    // 4. Safely update Firebase Auth phoneNumber
    try {
      await admin.auth().updateUser(uid, {
        phoneNumber: formattedPhone,
      });
    } catch (authErr) {
      console.warn("[AuthOtp] Firebase Auth updateUser phoneNumber notice:", authErr.message);
    }

    return res.json({
      success: true,
      message: "Phone number verified and linked successfully",
      phoneNumber: formattedPhone,
    });
  } catch (err) {
    console.error("[AuthOtp] Error linking phone:", err);
    return res.status(500).json({ error: "Internal server error while linking phone" });
  }
});

/**
 * POST /api/auth/verify-otp-login
 * Direct Phone OTP login (generates Firebase customToken).
 */
router.post("/verify-otp-login", async (req, res) => {
  const { sessionId, otpCode, phone, role } = req.body;

  if (!sessionId || !otpCode || !phone) {
    return res.status(400).json({ error: "Missing sessionId, otpCode, or phone" });
  }

  const cleanPhone = sanitizePhoneNumber(phone);
  if (!cleanPhone || cleanPhone.length !== 10) {
    return res.status(400).json({ error: "Invalid 10-digit phone number" });
  }

  // 1. Verify OTP with 2Factor
  const verifyResult = await verifyOtp(req.db, sessionId, otpCode);
  if (!verifyResult.success) {
    return res.status(400).json({ error: verifyResult.error || "Invalid OTP" });
  }

  const formattedPhone = `+91${cleanPhone}`;
  const targetRole = role === "worker" ? "worker" : "customer";
  const collectionName = targetRole === "worker" ? "workers" : "users";

  try {
    // 2. Check for role conflict
    if (targetRole === "customer") {
      const workerSnap = await req.db
        .collection("workers")
        .where("phoneNumber", "==", formattedPhone)
        .limit(1)
        .get();
      if (!workerSnap.empty) {
        return res.status(403).json({
          success: false,
          error: "This account is registered as a Karya Member. Please use a different account.",
        });
      }
      const userSnap = await req.db
        .collection("users")
        .where("phoneNumber", "==", formattedPhone)
        .limit(1)
        .get();
      if (!userSnap.empty && userSnap.docs[0].data().role === "worker") {
        return res.status(403).json({
          success: false,
          error: "This account is registered as a Karya Member. Please use a different account.",
        });
      }
    } else if (targetRole === "worker") {
      const userSnap = await req.db
        .collection("users")
        .where("phoneNumber", "==", formattedPhone)
        .limit(1)
        .get();
      if (!userSnap.empty && userSnap.docs[0].data().role === "customer") {
        return res.status(403).json({
          success: false,
          error: "This account is registered as a Customer. Please use a different account.",
        });
      }
    }

    let targetUid;
    let isNewUser = false;

    // Check if user exists by phone in Firestore
    const snapshot = await req.db
      .collection(collectionName)
      .where("phoneNumber", "==", formattedPhone)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      targetUid = snapshot.docs[0].id;
    } else {
      // Check if user exists in Firebase Auth by phone
      try {
        const authUser = await admin.auth().getUserByPhoneNumber(formattedPhone);
        targetUid = authUser.uid;
      } catch (_) {
        // Create new user in Firebase Auth
        const newAuthUser = await admin.auth().createUser({
          phoneNumber: formattedPhone,
          displayName: role === "worker" ? "Worker" : "Customer",
        });
        targetUid = newAuthUser.uid;
        isNewUser = true;

        // Initialize Firestore doc
        await req.db.collection(collectionName).doc(targetUid).set({
          uid: targetUid,
          phoneNumber: formattedPhone,
          phoneVerified: true,
          role: role || "customer",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    // Generate Firebase custom token for client sign-in
    const customToken = await admin.auth().createCustomToken(targetUid, {
      role: role || "customer",
    });

    return res.json({
      success: true,
      customToken,
      uid: targetUid,
      isNewUser,
    });
  } catch (err) {
    console.error("[AuthOtp] Error in verify-otp-login:", err);
    return res.status(500).json({ error: "Failed to authenticate with phone OTP" });
  }
});

module.exports = router;
