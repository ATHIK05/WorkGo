const express = require("express");
const crypto = require("crypto");
const router = express.Router();

/**
 * POST /api/verification/aadhaar-qr
 *
 * Receives on-device verified Aadhaar QR fields (hashed — raw data never leaves device).
 * Stores demographic hashes + district for cross-reference.
 * Updates trustScore and triggers auto-approve if eligible.
 *
 * Body: {
 *   workerId: string,
 *   nameHash: string,      // SHA-256 of name
 *   dobHash: string,       // SHA-256 of DOB
 *   gender: string,        // "M" | "F" | "T"
 *   district: string,      // e.g. "Thanjavur, TN"
 *   signatureValid: bool,  // UIDAI RSA verified on-device
 *   photoBase64: string?,  // Aadhaar photo (v2 QR only) — admin view only
 * }
 */
router.post("/aadhaar-qr", async (req, res) => {
  try {
    const {
      workerId,
      nameHash,
      dobHash,
      gender,
      district,
      signatureValid,
      photoBase64,
    } = req.body;

    if (!workerId || !nameHash || !signatureValid) {
      return res.status(400).json({
        error: "workerId, nameHash, and signatureValid are required",
      });
    }

    if (!signatureValid) {
      return res.status(400).json({
        error: "UIDAI signature verification failed. QR may be tampered.",
      });
    }

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentData = workerDoc.exists ? workerDoc.data() : {};
    const currentStage = currentData.verificationStage || "aadhaarOfflineEkyc";

    const now = new Date().toISOString();

    // Compute a reference ID from the name hash for audit linkage
    const referenceId = crypto
      .createHash("sha256")
      .update(`${workerId}:${nameHash}:${now}`)
      .digest("hex")
      .substring(0, 16)
      .toUpperCase();

    const updatePayload = {
      verificationStage: "selfieCapture",
      "verificationDetails.aadhaarQrVerified": true,
      "verificationDetails.aadhaarQrMethod": "qr_scan",
      "verificationDetails.aadhaarNameHash": nameHash,
      "verificationDetails.aadhaarDobHash": dobHash,
      "verificationDetails.aadhaarGender": gender || "",
      "verificationDetails.aadhaarDistrict": district || "",
      "verificationDetails.aadhaarSignatureValid": true,
      "verificationDetails.aadhaarReferenceId": referenceId,
      "verificationDetails.aadhaarVerifiedAt": now,
      // photoBase64 stored only if provided (v2 QR) — admin-only field
      ...(photoBase64 ? { "verificationDetails.aadhaarPhotoBase64": photoBase64 } : {}),
    };

    await workerRef.set(updatePayload, { merge: true });

    // Recalculate trust score
    await _recalcTrustScore(req.db, workerId);

    // Audit log
    await req.db.collection("verification_audit_logs").add({
      workerId,
      fromStage: currentStage,
      toStage: "selfieCapture",
      action: "AADHAAR_QR_VERIFIED",
      actorId: req.user ? req.user.uid : workerId,
      actorRole: "worker",
      reason: `Aadhaar Secure QR scanned and UIDAI RSA-SHA256 signature verified on-device. District: ${district}`,
      metadata: {
        signatureValid: true,
        district,
        gender,
        referenceId,
        hasPhoto: !!photoBase64,
      },
      timestamp: now,
    });

    res.json({
      success: true,
      referenceId,
      nextStage: "selfieCapture",
      message: "Aadhaar identity verified",
    });
  } catch (e) {
    console.error("verification/aadhaar-qr error:", e);
    res.status(500).json({ error: "Aadhaar QR verification failed", detail: e.message });
  }
});

/**
 * POST /api/verification/eshram
 *
 * Links e-Shram UAN to the worker profile.
 * Cross-references name against Aadhaar name hash.
 */
router.post("/eshram", async (req, res) => {
  try {
    const { workerId, uan, trade, district, nameFromEshram } = req.body;

    if (!workerId || !uan) {
      return res.status(400).json({ error: "workerId and uan are required" });
    }

    // Validate UAN format (12 digits)
    const cleanUan = uan.replace(/\D/g, "");
    if (cleanUan.length !== 12) {
      return res.status(400).json({ error: "UAN must be 12 digits" });
    }

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentData = workerDoc.exists ? workerDoc.data() : {};
    const currentStage = currentData.verificationStage || "pccUpload";

    // Cross-reference: fuzzy match e-Shram name against Aadhaar name hash
    let eshramNameMatch = false;
    if (nameFromEshram && currentData.verificationDetails?.aadhaarNameHash) {
      // Compare the SHA-256 of the eshram name (normalized) to stored Aadhaar name hash
      const eshramNameHash = crypto
        .createHash("sha256")
        .update(nameFromEshram.trim().toLowerCase())
        .digest("hex");
      eshramNameMatch =
        eshramNameHash === currentData.verificationDetails.aadhaarNameHash;
    }

    const now = new Date().toISOString();

    await workerRef.set(
      {
        "verificationDetails.eshramUan": cleanUan,
        "verificationDetails.eshramTrade": trade || "",
        "verificationDetails.eshramDistrict": district || "",
        "verificationDetails.eshramNameMatch": eshramNameMatch,
        "verificationDetails.eshramVerifiedAt": now,
      },
      { merge: true }
    );

    // Recalculate trust score
    const newScore = await _recalcTrustScore(req.db, workerId);

    await req.db.collection("verification_audit_logs").add({
      workerId,
      fromStage: currentStage,
      toStage: currentStage,
      action: "ESHRAM_UAN_LINKED",
      actorId: req.user ? req.user.uid : workerId,
      actorRole: "worker",
      reason: `e-Shram UAN linked: ${cleanUan}. Trade: ${trade}. Name match: ${eshramNameMatch}`,
      metadata: { uan: cleanUan, trade, district, eshramNameMatch },
      timestamp: now,
    });

    res.json({
      success: true,
      uan: cleanUan,
      eshramNameMatch,
      trustScore: newScore,
      message: "e-Shram UAN linked",
    });
  } catch (e) {
    console.error("verification/eshram error:", e);
    res.status(500).json({ error: "Failed to link e-Shram", detail: e.message });
  }
});

/**
 * POST /api/verification/recalc-trust
 *
 * Admin or system trigger to recompute trustScore for a worker.
 */
router.post("/recalc-trust", async (req, res) => {
  try {
    const { workerId } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId required" });
    const score = await _recalcTrustScore(req.db, workerId);
    res.json({ success: true, trustScore: score });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/**
 * Recalculates trustScore (0–5) from Firestore worker doc and updates it.
 * Also triggers auto-live if score reaches 5 with all automated signals passing.
 *
 * Signal mapping:
 *  1. Phone OTP          — isPhoneVerified == true (from users collection)
 *  2. Aadhaar            — aadhaarQrVerified OR aadhaarVerifiedAt present
 *  3. Biometric Liveness — livenessPassedAt present
 *  4. e-Shram            — eshramUan present
 *  5. PCC                — pccDocumentId present AND pccReviewedAt present
 */
async function _recalcTrustScore(db, workerId) {
  const workerDoc = await db.collection("workers").doc(workerId).get();
  if (!workerDoc.exists) return 0;

  const d = workerDoc.data();
  const vd = d.verificationDetails || {};

  let score = 0;
  const signals = {};

  // Signal 1: Phone
  const userDoc = await db.collection("users").doc(d.userId || workerId).get();
  const phoneVerified =
    userDoc.exists &&
    (userDoc.data().phoneVerified === true ||
      userDoc.data().isPhoneVerified === true);
  if (phoneVerified) { score++; signals.phone = true; }

  // Signal 2: Aadhaar (QR primary OR XML fallback)
  const aadhaarDone =
    vd.aadhaarQrVerified === true || !!vd.aadhaarVerifiedAt;
  if (aadhaarDone) { score++; signals.aadhaar = true; }

  // Signal 3: Biometric liveness
  if (vd.livenessPassedAt) { score++; signals.liveness = true; }

  // Signal 4: e-Shram
  if (vd.eshramUan) { score++; signals.eshram = true; }

  // Signal 5: PCC reviewed
  if (vd.pccDocumentId && vd.pccReviewedAt) { score++; signals.pcc = true; }

  // Determine status
  let visibilityStatus = d.visibilityStatus || "pending";
  let verificationStatus = d.verificationStatus || "pending";
  let autoApproved = false;

  if (score >= 5 && !d.flaggedForReview) {
    // Auto-approve: all signals pass, no admin flags
    visibilityStatus = "public";
    verificationStatus = "approved";
    verificationStage = "approved";
    autoApproved = true;
  } else if (score >= 3 && verificationStatus === "approved") {
    // Already manually approved — keep public
    visibilityStatus = "public";
  }

  await db.collection("workers").doc(workerId).set(
    {
      trustScore: score,
      trustSignals: signals,
      ...(autoApproved
        ? {
            visibilityStatus: "public",
            verificationStatus: "approved",
            verificationStage: "approved",
            autoApprovedAt: new Date().toISOString(),
          }
        : {}),
    },
    { merge: true }
  );

  // Push notification on auto-approve
  if (autoApproved) {
    try {
      const token = d.fcmToken;
      if (token) {
        await db.collection("notifications").add({
          userId: d.userId || workerId,
          title: "You are live on WorkGo",
          body: "All 5 verification signals complete. Customers nearby can now find you.",
          type: "trust_live",
          read: false,
          createdAt: new Date().toISOString(),
        });
      }
    } catch (_) {}
  }

  return score;
}

module.exports = router;
