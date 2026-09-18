"use strict";

/**
 * WorkGo IVR Voice Routes — POST /api/ivr/voice/*
 *
 * These routes are called by Asterisk via the curl System() command in extensions.conf.
 * They are intentionally NOT protected by Firebase auth tokens because Asterisk
 * cannot attach Bearer tokens. Instead they are protected by:
 *   1. Binding to localhost only on Render / production (Asterisk runs on same host)
 *   2. A shared ASTERISK_WEBHOOK_SECRET header checked on every request
 *
 * Endpoints:
 *   POST /api/ivr/voice/inbound          — Called when ANY call arrives on gateway SIM
 *   POST /api/ivr/voice/toggle-status    — Worker pressed 1 (online) or 2 (offline)
 *   POST /api/ivr/voice/claim-booking    — Worker pressed 1 during a booking alert call
 *   POST /api/ivr/voice/peer-kyc/submit  — Smartphone artisan submits Peer KYC (4 stages)
 *   POST /api/ivr/voice/peer-kyc/accept  — Artisan accepts the KYC bounty task
 */

const express = require("express");
const router = express.Router();
const crypto = require("crypto");

const { generateBookingAlertAudio } = require("../services/bhashini_voice_service");
const { triggerOtpFlashCall, abortCallBookingTaken } = require("../services/voice_call_engine");
const { NotificationEngine } = require("../services/notification_engine");

// Peer KYC bounty amount
const PEER_KYC_BOUNTY = 150;

// ── Shared Webhook Secret Guard ───────────────────────────────────────────────
// Asterisk passes this as a query param: /api/ivr/voice/inbound?secret=XXXX
function validateAsteriskSecret(req, res) {
  const secret = process.env.ASTERISK_WEBHOOK_SECRET;
  if (!secret) return true; // not configured → skip check in dev
  const provided = req.query.secret || req.headers["x-asterisk-secret"];
  if (provided !== secret) {
    res.status(403).json({ error: "Unauthorized IVR call" });
    return false;
  }
  return true;
}

// ── Helper: Get or create a pending dial worker doc ───────────────────────────
async function getOrCreateDialWorker(db, callerPhone) {
  const normalized = callerPhone.startsWith("+") ? callerPhone : `+${callerPhone}`;
  const snap = await db
    .collection("workers")
    .where("phoneForCalling", "==", normalized)
    .limit(1)
    .get();
  if (!snap.empty) {
    return { doc: snap.docs[0], isNew: false };
  }
  // Create a new stub profile — will be enriched during onboarding Q&A
  const ref = db.collection("workers").doc();
  await ref.set({
    phoneForCalling: normalized,
    isDialWorker: true,
    dialLanguage: "hi",
    verificationStatus: "pending",
    verificationStage: "signup",
    visibilityStatus: "hidden",
    availabilityStatus: "offline",
    callIvrStatus: "onboarding",
    walletBalance: 0,
    totalEarnings: 0,
    completedJobsCount: 0,
    avgRating: 5.0,
    skills: [],
    preferredAreas: [],
    createdAt: new Date().toISOString(),
  });
  const newDoc = await ref.get();
  return { doc: newDoc, isNew: true };
}

// ── 1. POST /api/ivr/voice/inbound ───────────────────────────────────────────
/**
 * Called by Asterisk immediately when a call arrives on +91 90802 62334.
 * The system determines what this caller needs:
 *   - New caller (no profile) → initiate Bhashini onboarding Q&A
 *   - Pending KYC caller      → inform still pending
 *   - Verified offline worker → play Online/Offline toggle menu
 *   - Verified online worker  → play Online/Offline toggle menu
 *
 * Response JSON tells Asterisk which dialplan context/extension to jump to.
 */
router.all("/inbound", async (req, res) => {
  if (!validateAsteriskSecret(req, res)) return;

  let caller = req.body?.caller || req.query?.caller;
  if (!caller && typeof req.body === "string") {
    try {
      caller = JSON.parse(req.body)?.caller;
    } catch (_) {
      caller = req.body.trim();
    }
  }
  if (!caller) return res.status(400).json({ error: "caller required" });

  console.log("\n========================================================");
  console.log(`[IVR Gateway] 📞 LIVE INCOMING CALL FROM: ${caller}`);
  console.log("========================================================\n");

  try {
    const db = req.db;
    const { doc, isNew } = await getOrCreateDialWorker(db, caller);
    const worker = doc.data();

    const isTextFormat = req.query.format === "text" || 
      req.body?.format === "text" || 
      (typeof req.body === "string" && req.body.includes("format=text"));

    let respPayload;
    if (isNew || (worker.verificationStatus === "pending" && worker.verificationStage === "signup")) {
      // New registration call — Asterisk will play welcome + ask name/trade/pincode
      await doc.ref.update({ callIvrStatus: "onboarding" });
      respPayload = {
        action: "onboarding",
        workerId: doc.id,
        language: worker.dialLanguage || "hi",
      };
    } else if (worker.verificationStatus === "pending") {
      // Profile exists but still awaiting Peer KYC
      respPayload = {
        action: "pending_kyc",
        workerId: doc.id,
        language: worker.dialLanguage || "hi",
      };
    } else {
      // Verified worker — show Online/Offline toggle menu
      respPayload = {
        action: "toggle_menu",
        workerId: doc.id,
        workerName: worker.name || "",
        currentStatus: worker.availabilityStatus || "offline",
        language: worker.dialLanguage || "hi",
      };
    }

    if (isTextFormat) {
      return res.type("text/plain").send(
        `ACTION=${respPayload.action}|LANG=${respPayload.language}|STATUS=${respPayload.currentStatus || "offline"}|NAME=${respPayload.workerName || ""}`
      );
    }
    return res.json(respPayload);
  } catch (err) {
    console.error("[IVR] /inbound error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── 2. POST /api/ivr/voice/onboarding ────────────────────────────────────────
/**
 * Called after Asterisk collects name (via Bhashini ASR), trade & description (via ASR),
 * and location / pincode. Stores the data and triggers Peer KYC dispatch + Admin KYC entry.
 */
router.post("/onboarding", async (req, res) => {
  if (!validateAsteriskSecret(req, res)) return;

  const {
    caller,
    name,
    trade: rawTrade,
    tradeDtmf,
    tradeText,
    tradeDescription,
    locationText,
    pincode,
    language = "en",
  } = req.body;
  if (!caller) return res.status(400).json({ error: "caller required" });

  const tradeMap = {
    "1": "plumbing", "2": "electrical", "3": "carpentry",
    "4": "painting", "5": "cleaning",
  };
  const trade = rawTrade || tradeMap[tradeDtmf] || tradeText?.toLowerCase() || "general";

  try {
    const db = req.db;
    const { doc } = await getOrCreateDialWorker(db, caller);

    const areas = [];
    if (pincode) areas.push(pincode);
    if (locationText) areas.push(locationText);

    const existing = doc.data();
    const isAlreadyApproved =
      existing?.verificationStatus === "approved" ||
      existing?.verificationStage === "approved";

    await doc.ref.update({
      name: name || existing?.name || "Dial Artisan",
      skills: [trade],
      tradeDescription: tradeDescription || existing?.tradeDescription || "",
      locationText: locationText || existing?.locationText || "",
      preferredAreas: areas.length > 0 ? areas : (existing?.preferredAreas || []),
      dialLanguage: language,
      verificationStage: isAlreadyApproved ? "approved" : "pending_peer_kyc",
      verificationStatus: isAlreadyApproved ? "approved" : "pending",
      visibilityStatus: isAlreadyApproved ? "public" : (existing?.visibilityStatus || "hidden"),
      callIvrStatus: "idle",
      updatedAt: new Date().toISOString(),
    });

    // 1. Log to Admin KYC Queue for admin dashboard visibility
    const adminQueueRef = db.collection("admin_kyc_queue").doc(doc.id);
    await adminQueueRef.set({
      workerId: doc.id,
      phone: caller,
      name: name || "Dial Artisan",
      trade,
      tradeDescription: tradeDescription || "",
      locationText: locationText || "",
      pincode: pincode || "",
      language,
      status: "pending_verification",
      source: "IVR_VOICE_ONBOARDING",
      createdAt: new Date().toISOString(),
    }, { merge: true });

    // 2. Dispatch Peer KYC notification to nearby smartphone artisans (Karya Mitra)
    await dispatchPeerKycToNearbyArtisans(db, req.messaging, doc.id, {
      name: name || "Dial Artisan",
      trade,
      tradeDescription: tradeDescription || "",
      locationText: locationText || "",
      pincode,
      phone: caller,
    });

    console.log(`[IVR Onboarding] Stored worker ${doc.id} (${name}, ${trade}, ${locationText || pincode}). Admin & Artisans notified.`);
    return res.json({ action: "registration_done", workerId: doc.id });
  } catch (err) {
    console.error("[IVR] /onboarding error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── 3. POST /api/ivr/voice/toggle-status ─────────────────────────────────────
/**
 * Called when a verified dial worker presses 1 (online) or 2 (offline)
 * during the toggle menu IVR call.
 */
router.post("/toggle-status", async (req, res) => {
  if (!validateAsteriskSecret(req, res)) return;

  const { caller, status } = req.body;
  if (!caller || !status) {
    return res.status(400).json({ error: "caller and status required" });
  }
  if (!["online", "offline"].includes(status)) {
    return res.status(400).json({ error: "status must be 'online' or 'offline'" });
  }

  try {
    const db = req.db;
    const snap = await db
      .collection("workers")
      .where("phoneForCalling", "==", caller.startsWith("+") ? caller : `+${caller}`)
      .limit(1)
      .get();

    if (snap.empty) {
      return res.status(404).json({ error: "Worker not found. Please register first." });
    }

    const workerDoc = snap.docs[0];
    const worker = workerDoc.data();

    if (worker.verificationStatus !== "approved" && worker.verificationStage !== "approved") {
      return res.json({
        action: "not_verified",
        message: "Your account is pending verification. A Karya Mitra will contact you soon.",
        language: worker.dialLanguage || "hi",
      });
    }

    await workerDoc.ref.update({
      availabilityStatus: status,
      isCheckedIn: status === "online",
      callIvrStatus: "idle",
      ...(status === "online"
        ? { lastOnlineAt: new Date().toISOString() }
        : { lastOfflineAt: new Date().toISOString() }),
    });

    console.log(`[IVR] Worker ${workerDoc.id} is now ${status}`);
    return res.json({
      action: "status_updated",
      status,
      workerName: worker.name || "",
      language: worker.dialLanguage || "hi",
    });
  } catch (err) {
    console.error("[IVR] /toggle-status error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── 4. POST /api/ivr/voice/claim-booking ─────────────────────────────────────
/**
 * Called when a dial worker presses 1 during an outbound booking alert robocall.
 * Uses a Firestore transaction to atomically claim the booking — prevents race conditions.
 */
router.post("/claim-booking", async (req, res) => {
  if (!validateAsteriskSecret(req, res)) return;

  const { caller, bookingId } = req.body;
  if (!caller || !bookingId) {
    return res.status(400).json({ error: "caller and bookingId required" });
  }

  const db = req.db;

  try {
    // Find worker by phone
    const workerSnap = await db
      .collection("workers")
      .where("phoneForCalling", "==", caller.startsWith("+") ? caller : `+${caller}`)
      .limit(1)
      .get();

    if (workerSnap.empty) {
      return res.status(404).json({ error: "Worker not found" });
    }

    const workerDoc = workerSnap.docs[0];
    const bookingRef = db.collection("bookings").doc(bookingId);

    // Atomic transaction — only ONE worker can claim
    const claimed = await db.runTransaction(async (txn) => {
      const bookingDoc = await txn.get(bookingRef);
      if (!bookingDoc.exists) return false;
      const booking = bookingDoc.data();

      // Only claim if still in broadcast/pending state
      if (booking.status !== "pending" && booking.status !== "broadcast") {
        return false; // Already claimed by someone else
      }

      const workerData = workerDoc.data();
      txn.update(bookingRef, {
        status: "accepted",
        workerId: workerDoc.id,
        acceptedWorkerName: workerData.name || "Dial Worker",
        workerPhone: workerData.phoneForCalling,
        isAssignedToDialWorker: true,
        dialCallStatus: "accepted",
        dialWorkerPhone: workerData.phoneForCalling,
        acceptedAt: new Date().toISOString(),
      });

      txn.update(workerDoc.ref, {
        availabilityStatus: "busy",
        callIvrStatus: "booking_accepted",
      });

      return true;
    });

    if (!claimed) {
      // Booking already taken — the call will play the "taken" audio
      return res.json({
        action: "already_taken",
        language: workerSnap.docs[0].data().dialLanguage || "hi",
      });
    }

    // Abort any other active alert calls for this booking
    await abortCallBookingTaken(bookingId, workerSnap.docs[0].data().dialLanguage || "hi");

    // Notify customer app that booking is accepted
    const bookingDoc = await bookingRef.get();
    const booking = bookingDoc.data();
    if (booking.customerId && req.messaging) {
      const engine = new NotificationEngine(db, req.messaging);
      await engine.sendToUser(booking.customerId, "BOOKING_ACCEPTED", {
        workerName: workerSnap.docs[0].data().name || "Dial Artisan",
        category: booking.serviceType || "Service",
        startOtp: booking.startOtp || "----",
      });
    }

    console.log(`[IVR] Booking ${bookingId} claimed by dial worker ${workerDoc.id}`);
    return res.json({
      action: "booking_claimed",
      bookingId,
      customerAddress: booking?.customerAddressText || "",
      customerPhone: booking?.customerPhone || "",
      language: workerSnap.docs[0].data().dialLanguage || "hi",
    });
  } catch (err) {
    console.error("[IVR] /claim-booking error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── 5. POST /api/ivr/voice/peer-kyc/accept ───────────────────────────────────
/**
 * Called when a smartphone artisan taps "Accept KYC Task" in workgo_karya app.
 * Generates handshake OTP, triggers flash-call to dial worker's phone, returns OTP.
 */
router.post("/peer-kyc/accept", async (req, res) => {
  const { mitraWorkerId, dialWorkerPhone, language = "hi" } = req.body;
  if (!mitraWorkerId || !dialWorkerPhone) {
    return res.status(400).json({ error: "mitraWorkerId and dialWorkerPhone required" });
  }

  const otpCode = String(Math.floor(1000 + Math.random() * 9000));
  const db = req.db;

  try {
    // Store the OTP against the dial worker for later validation
    const snap = await db
      .collection("workers")
      .where("phoneForCalling", "==", dialWorkerPhone)
      .limit(1)
      .get();

    if (snap.empty) return res.status(404).json({ error: "Dial worker not found" });

    await snap.docs[0].ref.update({
      peerKycOtp: otpCode,
      peerKycMitraId: mitraWorkerId,
      peerKycOtpGeneratedAt: new Date().toISOString(),
    });

    // Trigger flash-call to dial worker with the OTP spoken aloud
    await triggerOtpFlashCall(dialWorkerPhone, otpCode, language);

    return res.json({ otpCode, message: "OTP flash-call triggered to dial worker." });
  } catch (err) {
    console.error("[IVR] /peer-kyc/accept error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── 6. POST /api/ivr/voice/peer-kyc/submit ───────────────────────────────────
/**
 * Called when smartphone artisan submits all 4 verification pipeline stages.
 * Validates handshake OTP, promotes dial worker, credits ₹150 to mitra wallet.
 *
 * Body: {
 *   mitraWorkerId: string,
 *   dialWorkerPhone: string,
 *   enteredOtp: string,
 *   photoBase64: string,         // Stage 1: face photo
 *   toolsChecklist: string[],    // Stage 2: trade tool verification
 *   documentPhotoBase64: string, // Stage 3: Aadhaar / e-Shram photo
 * }
 */
router.post("/peer-kyc/submit", async (req, res) => {
  const {
    mitraWorkerId,
    dialWorkerPhone,
    enteredOtp,
    photoBase64,
    toolsChecklist,
    documentPhotoBase64,
  } = req.body;

  if (!mitraWorkerId || !dialWorkerPhone || !enteredOtp) {
    return res.status(400).json({ error: "mitraWorkerId, dialWorkerPhone, enteredOtp required" });
  }

  const db = req.db;

  try {
    // Find dial worker
    const dialSnap = await db
      .collection("workers")
      .where("phoneForCalling", "==", dialWorkerPhone)
      .limit(1)
      .get();

    if (dialSnap.empty) return res.status(404).json({ error: "Dial worker not found" });

    const dialDoc = dialSnap.docs[0];
    const dialWorker = dialDoc.data();

    // Validate OTP
    if (dialWorker.peerKycOtp !== enteredOtp) {
      return res.status(400).json({ error: "Incorrect OTP. Verification failed." });
    }

    // Check OTP freshness (10-minute window)
    const generatedAt = new Date(dialWorker.peerKycOtpGeneratedAt);
    if (Date.now() - generatedAt.getTime() > 10 * 60 * 1000) {
      return res.status(400).json({ error: "OTP expired. Please restart verification." });
    }

    // Validate 4-stage completeness
    const missingStages = [];
    if (!photoBase64) missingStages.push("Face Photo (Stage 1)");
    if (!toolsChecklist || toolsChecklist.length === 0) missingStages.push("Tools Inspection (Stage 2)");
    if (!documentPhotoBase64) missingStages.push("Identity Document (Stage 3)");
    // Stage 4 (OTP) already validated above

    if (missingStages.length > 0) {
      return res.status(400).json({
        error: `Incomplete verification. Missing: ${missingStages.join(", ")}`,
      });
    }

    // Find mitra artisan
    const mitraDoc = await db.collection("workers").doc(mitraWorkerId).get();
    if (!mitraDoc.exists) return res.status(404).json({ error: "Mitra artisan not found" });

    const mitra = mitraDoc.data();

    // Atomic batch: Promote dial worker + Credit ₹150 to mitra + Create audit log + Wallet txn
    const batch = db.batch();

    // 1. Promote dial worker to verified
    batch.update(dialDoc.ref, {
      verificationStatus: "approved",
      verificationStage: "approved",
      visibilityStatus: "public",
      peerKycMitraId: mitraWorkerId,
      peerKycCompletedAt: new Date().toISOString(),
      peerKycOtp: null, // Clear OTP after use
      "verificationDetails.selfieBase64": photoBase64,
      "verificationDetails.toolsChecklist": toolsChecklist,
      "verificationDetails.documentPhotoBase64": documentPhotoBase64,
    });

    // 2. Credit ₹150 to mitra's wallet
    const newBalance = (mitra.walletBalance || 0) + PEER_KYC_BOUNTY;
    batch.update(mitraDoc.ref, {
      walletBalance: newBalance,
      referralCount: (mitra.referralCount || 0) + 1,
      referralEarnings: (mitra.referralEarnings || 0) + PEER_KYC_BOUNTY,
    });

    // 3. Create wallet transaction record
    const txnRef = db.collection("wallet_transactions").doc();
    batch.set(txnRef, {
      workerId: mitraWorkerId,
      type: "PEER_KYC_BOUNTY",
      amount: PEER_KYC_BOUNTY,
      description: `Peer KYC bounty for verifying ${dialWorker.name || dialWorkerPhone}`,
      referenceId: dialDoc.id,
      createdAt: new Date().toISOString(),
    });

    // 4. Create audit log
    const auditRef = db.collection("verification_audit_logs").doc();
    batch.set(auditRef, {
      workerId: dialDoc.id,
      fromStage: "signup",
      toStage: "approved",
      action: "PEER_KYC_COMPLETED",
      actorId: mitraWorkerId,
      actorRole: "smartphone_artisan",
      metadata: {
        bountyPaid: PEER_KYC_BOUNTY,
        toolsChecklist,
        dialWorkerPhone,
      },
      timestamp: new Date().toISOString(),
    });

    await batch.commit();

    console.log(
      `[IVR] Peer KYC complete: dial worker ${dialDoc.id} verified by mitra ${mitraWorkerId}. ₹${PEER_KYC_BOUNTY} credited.`
    );

    // Send FCM to mitra: bounty credited
    if (req.messaging && mitra.userId) {
      const engine = new NotificationEngine(db, req.messaging);
      await engine.sendToUser(mitra.userId, "PEER_KYC_BOUNTY_CREDITED", {
        amount: String(PEER_KYC_BOUNTY),
        workerName: dialWorker.name || "Dial Worker",
      }).catch(() => {}); // Non-fatal
    }

    return res.json({
      success: true,
      message: `Peer KYC complete. ₹${PEER_KYC_BOUNTY} credited to ${mitra.name || "your"} wallet.`,
      newMitraBalance: newBalance,
      dialWorkerStatus: "approved",
    });
  } catch (err) {
    console.error("[IVR] /peer-kyc/submit error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Helper: Dispatch Peer KYC to nearby smartphone artisans ──────────────────
async function dispatchPeerKycToNearbyArtisans(db, messaging, dialWorkerId, dialWorkerInfo) {
  try {
    const artisanSnap = await db
      .collection("workers")
      .where("isDialWorker", "==", false)
      .where("availabilityStatus", "==", "online")
      .where("verificationStatus", "==", "approved")
      .limit(10)
      .get();

    if (artisanSnap.empty) {
      console.warn("[IVR] No online artisans available for Peer KYC dispatch.");
      return;
    }

    const engine = new NotificationEngine(db, messaging);
    const notifications = artisanSnap.docs.map((d) =>
      engine.sendToUser(d.data().userId || d.id, "PEER_KYC_BOUNTY_ALERT", {
        workerName: dialWorkerInfo.name || "Dial Worker",
        trade: dialWorkerInfo.trade || "General",
        amount: String(PEER_KYC_BOUNTY),
        dialWorkerId,
        dialWorkerPhone: dialWorkerInfo.phone,
      })
    );
    await Promise.allSettled(notifications);
    console.log(
      `[IVR] Peer KYC dispatched to ${artisanSnap.docs.length} artisan(s) for dial worker ${dialWorkerId}`
    );
  } catch (err) {
    console.error("[IVR] dispatchPeerKycToNearbyArtisans error:", err.message);
  }
}

module.exports = router;
