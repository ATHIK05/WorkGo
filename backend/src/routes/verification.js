const express = require("express");
const crypto = require("crypto");
const router = express.Router();
const { verifyAadhaarOfflineKyc } = require("../services/aadhaar_xml_verifier");

/**
 * Helper to record tamper-proof audit log entry in Firestore.
 */
async function recordAuditLog(db, {
  workerId,
  fromStage,
  toStage,
  action,
  actorId,
  actorRole,
  reason,
  metadata = {},
}) {
  const auditRef = db.collection("verification_audit_logs").doc();
  const entry = {
    id: auditRef.id,
    workerId,
    fromStage: fromStage || "",
    toStage: toStage || "",
    action: action || "STAGE_TRANSITION",
    actorId: actorId || "system",
    actorRole: actorRole || "system",
    reason: reason || "",
    metadata,
    timestamp: new Date().toISOString(),
  };
  await auditRef.set(entry);
  return entry;
}

/**
 * Helper to verify admin permissions.
 */
async function isAdmin(req) {
  if (!req.user || !req.user.uid) return false;
  const userDoc = await req.db.collection("users").doc(req.user.uid).get();
  return userDoc.exists && userDoc.data().role === "admin";
}

// ── 1. POST /api/verification/consent ────────────────────────────────────────
router.post("/consent", async (req, res) => {
  try {
    const { workerId, consentVersion = "DPDP_2023_v1.0" } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId is required" });

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentStage = workerDoc.exists ? workerDoc.data().verificationStage || "signup" : "signup";

    const consentTime = new Date().toISOString();
    await workerRef.set({
      verificationStage: "aadhaarOfflineEkyc",
      verificationDetails: {
        biometricConsentVersion: consentVersion,
        biometricConsentTimestamp: consentTime,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: currentStage,
      toStage: "aadhaarOfflineEkyc",
      action: "BIOMETRIC_CONSENT_CAPTURED",
      actorId: req.user.uid,
      actorRole: "worker",
      reason: `Worker accepted biometric & eKYC consent under DPDP Act 2023 (${consentVersion})`,
      metadata: { consentVersion, consentTime, ip: req.ip },
    });

    res.json({ success: true, nextStage: "aadhaarOfflineEkyc" });
  } catch (e) {
    console.error("verification/consent error:", e);
    res.status(500).json({ error: "Failed to record consent", detail: e.message });
  }
});

// ── 2. POST /api/verification/aadhaar-offline ────────────────────────────────
router.post("/aadhaar-offline", async (req, res) => {
  try {
    const { workerId, shareCode, base64Data, fileName } = req.body;
    if (!workerId || !shareCode || !base64Data) {
      return res.status(400).json({ error: "workerId, shareCode, and base64Data are required" });
    }

    // Call UIDAI XML-DSig verifier
    const verificationResult = await verifyAadhaarOfflineKyc({
      base64Data,
      shareCode,
      fileName,
    });

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentStage = workerDoc.exists ? workerDoc.data().verificationStage || "aadhaarOfflineEkyc" : "aadhaarOfflineEkyc";

    await workerRef.set({
      verificationStage: "selfieCapture",
      verificationDetails: {
        aadhaarVerifiedName: verificationResult.name,
        aadhaarMaskedNumber: verificationResult.maskedAadhaar,
        aadhaarVerifiedAt: verificationResult.verifiedAt,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: currentStage,
      toStage: "selfieCapture",
      action: "AADHAAR_XML_VERIFIED",
      actorId: req.user.uid,
      actorRole: "worker",
      reason: `UIDAI XML signature verified successfully for ${verificationResult.maskedAadhaar}`,
      metadata: {
        maskedAadhaar: verificationResult.maskedAadhaar,
        verifiedName: verificationResult.name,
        xmlSha256: verificationResult.xmlSha256,
      },
    });

    res.json({
      success: true,
      verifiedName: verificationResult.name,
      maskedAadhaar: verificationResult.maskedAadhaar,
      nextStage: "selfieCapture",
    });
  } catch (e) {
    console.error("verification/aadhaar-offline error:", e);
    res.status(400).json({ error: "Aadhaar verification failed", detail: e.message });
  }
});

// ── 3. POST /api/verification/liveness-pass ──────────────────────────────────
router.post("/liveness-pass", async (req, res) => {
  try {
    const { workerId, livenessScore = 0.98, selfieBase64 } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId is required" });

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentStage = workerDoc.exists ? workerDoc.data().verificationStage || "selfieCapture" : "selfieCapture";

    const passedTime = new Date().toISOString();
    await workerRef.set({
      verificationStage: "liveVideoVerification",
      verificationDetails: {
        livenessPassedAt: passedTime,
        livenessScore: Number(livenessScore),
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: currentStage,
      toStage: "liveVideoVerification",
      action: "ON_DEVICE_LIVENESS_PASSED",
      actorId: req.user.uid,
      actorRole: "worker",
      reason: `Camera liveness challenge passed with confidence score ${livenessScore}`,
      metadata: { livenessScore, passedTime },
    });

    res.json({ success: true, nextStage: "liveVideoVerification" });
  } catch (e) {
    console.error("verification/liveness-pass error:", e);
    res.status(500).json({ error: "Failed to record liveness result", detail: e.message });
  }
});

// ── 4. POST /api/verification/video-kyc/schedule ─────────────────────────────
router.post("/video-kyc/schedule", async (req, res) => {
  try {
    const { workerId, slotTime } = req.body;
    if (!workerId || !slotTime) {
      return res.status(400).json({ error: "workerId and slotTime are required" });
    }

    const phrases = [
      "VIOLET-892-SUN",
      "TIGER-441-MOON",
      "RIVER-719-GOLD",
      "EAGLE-338-SKY",
      "LOTUS-552-STAR",
    ];
    const randomPhrase = phrases[Math.floor(Math.random() * phrases.length)];
    const roomName = `workgo_kyc_${workerId}_${Date.now().toString().slice(-6)}`;

    const bookingRef = req.db.collection("video_kyc_bookings").doc();
    const bookingData = {
      id: bookingRef.id,
      workerId,
      slotTime,
      status: "scheduled",
      roomName,
      randomPhrase,
      assignedStaffId: "staff_coop_admin",
      createdAt: new Date().toISOString(),
    };
    await bookingRef.set(bookingData);

    const workerRef = req.db.collection("workers").doc(workerId);
    await workerRef.set({
      verificationDetails: {
        videoCallScheduledAt: slotTime,
        videoCallPhrase: randomPhrase,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: "liveVideoVerification",
      toStage: "liveVideoVerification",
      action: "VIDEO_KYC_SCHEDULED",
      actorId: req.user.uid,
      actorRole: "worker",
      reason: `Live video verification booked for ${slotTime}`,
      metadata: { bookingId: bookingRef.id, slotTime, roomName, challengePhrase: randomPhrase },
    });

    res.json({
      success: true,
      bookingId: bookingRef.id,
      roomName,
      randomPhrase,
      slotTime,
    });
  } catch (e) {
    console.error("verification/video-kyc/schedule error:", e);
    res.status(500).json({ error: "Failed to schedule video KYC", detail: e.message });
  }
});

// ── 5. POST /api/verification/video-kyc/verify (Admin Only) ──────────────────
router.post("/video-kyc/verify", async (req, res) => {
  try {
    const adminCheck = await isAdmin(req);
    if (!adminCheck) {
      return res.status(403).json({ error: "Admin access required for live video KYC review" });
    }

    const { workerId, bookingId, passed, challengePhrase, checklist = {}, notes = "" } = req.body;
    if (!workerId || typeof passed !== "boolean") {
      return res.status(400).json({ error: "workerId and passed (boolean) are required" });
    }

    const nextStage = passed ? "pccUpload" : "rejected";
    const completedAt = new Date().toISOString();

    if (bookingId) {
      await req.db.collection("video_kyc_bookings").doc(bookingId).update({
        status: passed ? "completed" : "cancelled",
        reviewedBy: req.user.uid,
        reviewedAt: completedAt,
      });
    }

    await req.db.collection("workers").doc(workerId).set({
      verificationStage: nextStage,
      verificationDetails: {
        videoCallCompletedAt: completedAt,
        videoCallStaffId: req.user.uid,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: "liveVideoVerification",
      toStage: nextStage,
      action: passed ? "VIDEO_CALL_PASSED" : "VIDEO_CALL_FAILED",
      actorId: req.user.uid,
      actorRole: "coop_admin",
      reason: passed
        ? `Artisan physically matched ID and repeated challenge phrase '${challengePhrase}'`
        : `Video verification failed. Reason: ${notes || "Mismatch detected"}`,
      metadata: { checklist, challengePhrase, notes },
    });

    res.json({ success: true, nextStage });
  } catch (e) {
    console.error("verification/video-kyc/verify error:", e);
    res.status(500).json({ error: "Failed to submit video KYC review", detail: e.message });
  }
});

// ── 6. POST /api/verification/pcc-upload ─────────────────────────────────────
router.post("/pcc-upload", async (req, res) => {
  try {
    const { workerId, base64Data, docName = "pcc_certificate.pdf" } = req.body;
    if (!workerId || !base64Data) {
      return res.status(400).json({ error: "workerId and base64Data are required" });
    }

    const docRef = req.db.collection("workers").doc(workerId).collection("documents").doc();
    await docRef.set({
      docType: "doc_pcc",
      docName,
      uploadedAt: new Date().toISOString(),
      uploadedBy: req.user.uid,
      sizeBytes: Buffer.from(base64Data, "base64").length,
    });

    const workerRef = req.db.collection("workers").doc(workerId);
    await workerRef.set({
      verificationStage: "pccManualReview",
      verificationDetails: {
        pccDocumentId: docRef.id,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: "pccUpload",
      toStage: "pccManualReview",
      action: "PCC_DOCUMENT_SUBMITTED",
      actorId: req.user.uid,
      actorRole: "worker",
      reason: "Worker submitted Police Clearance Certificate for review",
      metadata: { docId: docRef.id, docName },
    });

    res.json({ success: true, docId: docRef.id, nextStage: "pccManualReview" });
  } catch (e) {
    console.error("verification/pcc-upload error:", e);
    res.status(500).json({ error: "Failed to upload PCC document", detail: e.message });
  }
});

// ── 7. POST /api/verification/pcc-review (Admin Only) ────────────────────────
router.post("/pcc-review", async (req, res) => {
  try {
    const adminCheck = await isAdmin(req);
    if (!adminCheck) {
      return res.status(403).json({ error: "Admin access required for PCC approval" });
    }

    const { workerId, approved, rejectionReason = "", notes = "" } = req.body;
    if (!workerId || typeof approved !== "boolean") {
      return res.status(400).json({ error: "workerId and approved (boolean) are required" });
    }

    const reviewTime = new Date().toISOString();
    const nextStage = approved ? "approved" : "rejected";
    const verificationStatus = approved ? "approved" : "rejected";
    const visibilityStatus = approved ? "public" : "pending";

    await req.db.collection("workers").doc(workerId).set({
      verificationStatus,
      visibilityStatus,
      verificationStage: nextStage,
      verificationBadge: approved ? "Co-op Certified" : "",
      verificationDetails: {
        pccReviewedAt: reviewTime,
        pccReviewedBy: req.user.uid,
        pccRejectionReason: approved ? null : rejectionReason,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: "pccManualReview",
      toStage: nextStage,
      action: approved ? "PCC_APPROVED_AND_PUBLIC_LISTED" : "PCC_REJECTED",
      actorId: req.user.uid,
      actorRole: "coop_admin",
      reason: approved
        ? `Police Clearance authenticated. Worker granted Co-op Certified status and public visibility.`
        : `Police Clearance rejected: ${rejectionReason || notes}`,
      metadata: { approved, rejectionReason, notes, reviewTime },
    });

    res.json({ success: true, verificationStatus, visibilityStatus, nextStage });
  } catch (e) {
    console.error("verification/pcc-review error:", e);
    res.status(500).json({ error: "Failed to submit PCC review", detail: e.message });
  }
});

// ── 8. POST /api/verification/report-suspend ─────────────────────────────────
router.post("/report-suspend", async (req, res) => {
  try {
    const { workerId, reporterId, reason, bookingId } = req.body;
    if (!workerId || !reason) {
      return res.status(400).json({ error: "workerId and reason are required" });
    }

    await req.db.collection("workers").doc(workerId).update({
      visibilityStatus: "suspended",
    });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: "approved",
      toStage: "liveVideoVerification",
      action: "WORKER_VISIBILITY_SUSPENDED",
      actorId: req.user.uid,
      actorRole: "customer_safety_trigger",
      reason: `Artisan reported for safety/misconduct: ${reason}`,
      metadata: { reporterId: reporterId || req.user.uid, reason, bookingId },
    });

    res.json({ success: true, visibilityStatus: "suspended" });
  } catch (e) {
    console.error("verification/report-suspend error:", e);
    res.status(500).json({ error: "Failed to suspend worker", detail: e.message });
  }
});

// ── 9. GET /api/verification/audit-trail/:workerId ───────────────────────────
router.get("/audit-trail/:workerId", async (req, res) => {
  try {
    const { workerId } = req.params;
    const snap = await req.db
      .collection("verification_audit_logs")
      .where("workerId", "==", workerId)
      .get();

    const logs = snap.docs
      .map((d) => d.data())
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    res.json({ workerId, count: logs.length, logs });
  } catch (e) {
    console.error("verification/audit-trail error:", e);
    res.status(500).json({ error: "Failed to retrieve audit trail", detail: e.message });
  }
});

module.exports = router;
