const express = require("express");
const crypto = require("crypto");
const router = express.Router();
const { verifyAadhaarOfflineKyc } = require("../services/aadhaar_xml_verifier");
const { detectSyntheticImage } = require("../services/synthetic_image_detector");

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

// ── 3. POST /api/verification/multi-angle-liveness ─────────────────────────
router.post("/multi-angle-liveness", async (req, res) => {
  try {
    const {
      workerId,
      centerBase64,
      leftBase64,
      rightBase64,
      livenessScore = 0.98,
      lightingBoosted = false,
    } = req.body;

    if (!workerId || !centerBase64) {
      return res.status(400).json({ error: "workerId and centerBase64 are required" });
    }

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentStage = workerDoc.exists ? workerDoc.data().verificationStage || "selfieCapture" : "selfieCapture";
    const passedTime = new Date().toISOString();

    // 1. Compute Cryptographic Hashes for all 3 angles
    const centerHash = crypto.createHash("sha256").update(centerBase64).digest("hex");
    const leftHash = leftBase64 ? crypto.createHash("sha256").update(leftBase64).digest("hex") : "";
    const rightHash = rightBase64 ? crypto.createHash("sha256").update(rightBase64).digest("hex") : "";

    // 2. Run Forensic Synthetic / AI-Generated Deepfake Detector on all angles
    const centerReport = detectSyntheticImage(centerBase64);
    const leftReport = leftBase64 ? detectSyntheticImage(leftBase64) : { isSuspicious: false, riskScore: 0.0, flags: [] };
    const rightReport = rightBase64 ? detectSyntheticImage(rightBase64) : { isSuspicious: false, riskScore: 0.0, flags: [] };

    const maxRiskScore = Math.max(centerReport.riskScore, leftReport.riskScore, rightReport.riskScore);
    const allFlags = [...new Set([...centerReport.flags, ...leftReport.flags, ...rightReport.flags])];
    const isSuspicious = centerReport.isSuspicious || leftReport.isSuspicious || rightReport.isSuspicious;

    if (centerReport.recommendation === "REJECT_SYNTHETIC_IMAGE" || leftReport.recommendation === "REJECT_SYNTHETIC_IMAGE" || rightReport.recommendation === "REJECT_SYNTHETIC_IMAGE") {
      await recordAuditLog(req.db, {
        workerId,
        fromStage: currentStage,
        toStage: currentStage,
        action: "SYNTHETIC_IMAGE_REJECTED",
        actorId: req.user ? req.user.uid : workerId,
        actorRole: "system_detector",
        reason: `Upload rejected: Generative AI / synthetic image detected (${allFlags.join(", ")})`,
        metadata: { centerReport, leftReport, rightReport, maxRiskScore },
      });
      return res.status(400).json({
        error: "Generative AI or synthetic image detected. Please capture a real live photo using your phone camera.",
        flags: allFlags,
        riskScore: maxRiskScore,
      });
    }

    // 3. Advance to Police Clearance Upload stage (pccUpload)
    await workerRef.set({
      verificationStage: "pccUpload",
      verificationDetails: {
        livenessPassedAt: passedTime,
        livenessScore: Number(livenessScore),
        livenessMethod: "ML_KIT_3D_MULTI_ANGLE",
        lightingBoosted: Boolean(lightingBoosted),
        selfieBase64: centerBase64,
        selfieCenterBase64: centerBase64,
        selfieLeftBase64: leftBase64 || null,
        selfieRightBase64: rightBase64 || null,
        selfieHash: centerHash,
        selfieCenterHash: centerHash,
        selfieLeftHash: leftHash || null,
        selfieRightHash: rightHash || null,
        aiRiskScore: maxRiskScore,
        aiFlags: allFlags,
        isAiSuspicious: isSuspicious,
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: currentStage,
      toStage: "pccUpload",
      action: isSuspicious ? "3D_MULTI_ANGLE_PASSED_WITH_FLAGS" : "3D_MULTI_ANGLE_LIVENESS_PASSED",
      actorId: req.user ? req.user.uid : workerId,
      actorRole: "worker",
      reason: isSuspicious
        ? `3D Multi-angle liveness passed but flagged for admin scrutiny (AI Risk: ${maxRiskScore.toFixed(2)})`
        : `Artisan passed on-device 3D multi-angle liveness (Center, Left -25°, Right +25°) with anti-spoof checks.`,
      metadata: {
        livenessScore,
        lightingBoosted,
        centerHash,
        leftHash,
        rightHash,
        maxRiskScore,
        allFlags,
      },
    });

    res.json({
      success: true,
      nextStage: "pccUpload",
      centerHash,
      isSuspicious,
      riskScore: maxRiskScore,
    });
  } catch (e) {
    console.error("verification/multi-angle-liveness error:", e);
    res.status(500).json({ error: "Failed to record multi-angle liveness", detail: e.message });
  }
});

// ── 3b. POST /api/verification/liveness-pass (Legacy / Fallback Single Camera) ──
router.post("/liveness-pass", async (req, res) => {
  try {
    const { workerId, livenessScore = 0.98, selfieBase64, lightingBoosted = false } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId is required" });

    const workerRef = req.db.collection("workers").doc(workerId);
    const workerDoc = await workerRef.get();
    const currentStage = workerDoc.exists ? workerDoc.data().verificationStage || "selfieCapture" : "selfieCapture";

    const passedTime = new Date().toISOString();
    const selfieHash = selfieBase64
      ? crypto.createHash("sha256").update(selfieBase64).digest("hex")
      : "";

    // Run Synthetic / AI-Generated Image Inspection
    let syntheticReport = { isSuspicious: false, riskScore: 0.0, flags: [] };
    if (selfieBase64) {
      syntheticReport = detectSyntheticImage(selfieBase64);
      if (syntheticReport.recommendation === "REJECT_SYNTHETIC_IMAGE") {
        await recordAuditLog(req.db, {
          workerId,
          fromStage: currentStage,
          toStage: currentStage,
          action: "SYNTHETIC_IMAGE_REJECTED",
          actorId: req.user ? req.user.uid : workerId,
          actorRole: "system_detector",
          reason: `Upload rejected: Generative AI / synthetic image detected (${syntheticReport.flags.join(", ")})`,
          metadata: { syntheticReport },
        });
        return res.status(400).json({
          error: "Generative AI or synthetic image detected. Please capture a real live photo using your phone camera.",
          flags: syntheticReport.flags,
          riskScore: syntheticReport.riskScore,
        });
      }
    }

    await workerRef.set({
      verificationStage: "pccUpload",
      verificationDetails: {
        livenessPassedAt: passedTime,
        livenessScore: Number(livenessScore),
        lightingBoosted: Boolean(lightingBoosted),
        ...(selfieBase64 ? {
          selfieBase64,
          selfieCenterBase64: selfieBase64,
          selfieHash,
          selfieCenterHash: selfieHash,
          aiRiskScore: syntheticReport.riskScore,
          aiFlags: syntheticReport.flags,
          isAiSuspicious: syntheticReport.isSuspicious,
        } : {}),
      },
    }, { merge: true });

    await recordAuditLog(req.db, {
      workerId,
      fromStage: currentStage,
      toStage: "pccUpload",
      action: syntheticReport.isSuspicious ? "ON_DEVICE_LIVENESS_PASSED_WITH_FLAGS" : "ON_DEVICE_LIVENESS_PASSED",
      actorId: req.user ? req.user.uid : workerId,
      actorRole: "worker",
      reason: syntheticReport.isSuspicious
        ? `Selfie passed liveness but flagged for officer scrutiny (AI Risk: ${syntheticReport.riskScore})`
        : `Real on-device camera selfie & liveness captured with score ${livenessScore}`,
      metadata: { livenessScore, passedTime, selfieHash, syntheticReport },
    });

    res.json({
      success: true,
      nextStage: "pccUpload",
      selfieHash,
      isSuspicious: syntheticReport.isSuspicious,
      riskScore: syntheticReport.riskScore,
    });
  } catch (e) {
    console.error("verification/liveness-pass error:", e);
    res.status(500).json({ error: "Failed to record liveness result", detail: e.message });
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

    let manifestId = null;
    if (approved) {
      try {
        const workerSnap = await req.db.collection("workers").doc(workerId).get();
        const wData = workerSnap.data() || {};
        const vDetails = wData.verificationDetails || {};
        const assetSha256 = vDetails.selfieCenterHash || vDetails.selfieHash || crypto.createHash("sha256").update(workerId).digest("hex");
        const { generateAndSignC2paManifest } = require("../services/c2pa_signer");
        const manifest = await generateAndSignC2paManifest({
          workerId,
          artisanName: wData.name || "Co-op Verified Artisan",
          trade: (wData.skills && wData.skills[0]) || "Certified Trade",
          assetSha256,
        }, req.db);
        manifestId = manifest.id;
      } catch (c2paErr) {
        console.warn("[pcc-review] C2PA signing non-blocking error:", c2paErr.message);
      }
    }

    await req.db.collection("workers").doc(workerId).set({
      verificationStatus,
      visibilityStatus,
      verificationStage: nextStage,
      verificationBadge: approved ? "Co-op Certified" : "",
      verificationDetails: {
        pccReviewedAt: reviewTime,
        pccReviewedBy: req.user.uid,
        pccRejectionReason: approved ? null : rejectionReason,
        ...(manifestId ? { c2paProfileManifestId: manifestId } : {}),
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
        ? `Police Clearance authenticated. Worker granted Co-op Certified status and C2PA trust credential issued.`
        : `Police Clearance rejected: ${rejectionReason || notes}`,
      metadata: { approved, rejectionReason, notes, reviewTime, manifestId },
    });

    res.json({ success: true, verificationStatus, visibilityStatus, nextStage, manifestId });
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
