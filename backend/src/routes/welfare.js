/**
 * Worker Welfare & Insurance Claim Routes (SIH 26089)
 *
 * Provides endpoints for claim submission, admin queue listing, claim detail inspection,
 * verification checklist review, and manual decision auditing.
 *
 * WHY THIS DESIGN (Core Architectural & Safety Invariants):
 * 1. Certificate remains a hard submission gate, enforced at the API layer,
 *    not just implied by the scoring math — a claim without doctorCertificateDocId
 *    must be REJECTED at submission (400), never created in a partial state.
 * 2. Scoring is NEVER computed on submission. It is only computed once an admin
 *    has entered at least one verification checkbox, because a claim with zero
 *    admin input is meaningless to score (see Step 3's safety invariant — it would
 *    just show a low number that looks like a real assessment when no human has
 *    looked at anything yet).
 * 3. The system NEVER auto-approves or auto-rejects. computeClaimConfidence and
 *    getApprovalThreshold only ever produce a SUGGESTION shown to the admin. The
 *    actual approve/reject action is a separate, explicit admin decision, always
 *    recorded with the deciding admin's uid + timestamp, regardless of what the score says.
 * 4. workerId/proxyReferrerId access checks for welfare_claims already exist in
 *    firestore.rules from Step 1 — reuse that pattern for the route-level auth as well,
 *    don't reinvent it.
 */

const express = require("express");
const router = express.Router();
const { computeClaimConfidence, getApprovalThreshold } = require("../services/welfare_scoring");
const { NotificationEngine } = require("../services/notification_engine");

/**
 * Checks if a given UID has the admin role in the 'users' collection.
 *
 * @param {string} uid
 * @param {Object} db
 * @returns {Promise<boolean>}
 */
async function isUserAdmin(uid, db) {
  if (!uid || !db) return false;
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.exists && userDoc.data().role === "admin";
  } catch (_) {
    return false;
  }
}

/**
 * Middleware: restricts endpoint access to authenticated administrators.
 */
const adminOnly = async (req, res, next) => {
  const isAdmin = await isUserAdmin(req.user && req.user.uid, req.db);
  if (!isAdmin) {
    return res.status(403).json({ error: "Admin access required" });
  }
  return next();
};

/**
 * Validates whether the caller is authorized to act on behalf of workerId.
 * Allowed if:
 * 1. Caller has admin role.
 * 2. Caller UID equals workerId.
 * 3. Caller UID equals worker's userId (covers proxy-registered artisans).
 * 4. Caller UID equals worker's proxyReferrerId.
 *
 * @param {string} reqUserUid
 * @param {string} workerId
 * @param {Object} db
 * @returns {Promise<boolean>}
 */
async function canAccessWorker(reqUserUid, workerId, db) {
  if (!reqUserUid || !workerId || !db) return false;
  if (reqUserUid === workerId) return true;

  try {
    if (await isUserAdmin(reqUserUid, db)) return true;

    const workerDoc = await db.collection("workers").doc(workerId).get();
    if (workerDoc.exists) {
      const data = workerDoc.data() || {};
      if (data.userId === reqUserUid || data.proxyReferrerId === reqUserUid) {
        return true;
      }
    }
  } catch (e) {
    console.error("[welfare] canAccessWorker check failed:", e.message);
  }
  return false;
}

// ── STEP 4a: POST /claims/submit (Worker-facing, verifyToken auth) ─────────────
router.post("/claims/submit", async (req, res) => {
  try {
    const {
      workerId,
      bookingId,
      doctorCertificateDocId,
      injuryPhotoDocId,
      hospitalRecordDocId,
      incidentDate,
      description,
    } = req.body || {};

    // 1. Mandatory workerId validation
    if (!workerId || typeof workerId !== "string" || !workerId.trim()) {
      return res.status(400).json({ error: "workerId is required" });
    }

    // 2. Hard submission gate: doctor certificate is strictly required
    if (
      !doctorCertificateDocId ||
      typeof doctorCertificateDocId !== "string" ||
      !doctorCertificateDocId.trim()
    ) {
      return res.status(400).json({
        error: "doctorCertificateDocId is required. A claim cannot be submitted without a medical certificate.",
      });
    }

    // 3. Authorization check: worker themselves or authorized proxy referrer
    const isAuthorized = await canAccessWorker(req.user && req.user.uid, workerId, req.db);
    if (!isAuthorized) {
      return res.status(403).json({
        error: "Unauthorized: caller is not the worker or their authorized proxy",
      });
    }

    // 4. Verify each referenced docId exists in workers/{workerId}/documents
    // to prevent cross-worker document reference tampering.
    const docsToCheck = [
      { id: doctorCertificateDocId.trim(), field: "doctorCertificateDocId" },
    ];
    if (injuryPhotoDocId && typeof injuryPhotoDocId === "string" && injuryPhotoDocId.trim()) {
      docsToCheck.push({ id: injuryPhotoDocId.trim(), field: "injuryPhotoDocId" });
    }
    if (
      hospitalRecordDocId &&
      typeof hospitalRecordDocId === "string" &&
      hospitalRecordDocId.trim()
    ) {
      docsToCheck.push({ id: hospitalRecordDocId.trim(), field: "hospitalRecordDocId" });
    }

    for (const item of docsToCheck) {
      const docSnap = await req.db
        .collection("workers")
        .doc(workerId)
        .collection("documents")
        .doc(item.id)
        .get();

      if (!docSnap.exists) {
        return res.status(400).json({
          error: `Referenced document ${item.field} "${item.id}" does not exist in worker's vault`,
        });
      }

      if (item.field === "doctorCertificateDocId") {
        const docData = docSnap.data() || {};
        if (docData.docType !== "welfareCertificate") {
          return res.status(400).json({
            error: `doctorCertificateDocId must reference a document with docType 'welfareCertificate' (found '${docData.docType || "unknown"}')`,
          });
        }
      }
    }

    // 5. Persist claim document with status 'pending_review'
    // Safety Invariant: NEVER compute or store a score at submission time.
    const claimRef = req.db.collection("welfare_claims").doc();
    const nowIso = new Date().toISOString();

    const claimData = {
      workerId: workerId.trim(),
      bookingId: bookingId && String(bookingId).trim().length > 0 ? String(bookingId).trim() : null,
      doctorCertificateDocId: doctorCertificateDocId.trim(),
      injuryPhotoDocId: injuryPhotoDocId && String(injuryPhotoDocId).trim().length > 0 ? String(injuryPhotoDocId).trim() : null,
      hospitalRecordDocId: hospitalRecordDocId && String(hospitalRecordDocId).trim().length > 0 ? String(hospitalRecordDocId).trim() : null,
      incidentDate: incidentDate || nowIso,
      description: description || "",
      status: "pending_review",
      doctorCallConfirmed: false,
      doctorCallNote: null,
      customerCallConfirmed: false,
      customerCallNote: null,
      sosCorroborated: false,
      sosNote: null,
      photoOverride: false,
      photoOverrideNote: null,
      auditLog: [],
      verificationLog: [],
      submittedAt: nowIso,
      submittedBy: req.user.uid,
    };

    await claimRef.set(claimData);

    return res.status(200).json({
      success: true,
      claimId: claimRef.id,
    });
  } catch (e) {
    console.error("[welfare/submit] Error:", e);
    return res.status(500).json({ error: "Failed to submit welfare claim", detail: e.message });
  }
});

// ── STEP 4b: GET /claims (Admin-facing, verifyToken + adminOnly) ──────────────
router.get("/claims", adminOnly, async (req, res) => {
  try {
    const status = req.query.status || "pending_review";
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));

    let query = req.db.collection("welfare_claims");
    if (status !== "all") {
      query = query.where("status", "==", status);
    }

    const snapshot = await query.get();
    const claims = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

    // Sort descending by submittedAt
    claims.sort((a, b) => {
      const timeA = new Date(a.submittedAt || 0).getTime();
      const timeB = new Date(b.submittedAt || 0).getTime();
      return timeB - timeA;
    });

    const startIndex = (page - 1) * limit;
    const paginatedClaims = claims.slice(startIndex, startIndex + limit);

    // Join basic worker info and approval threshold for administrative overview
    const enrichedClaims = await Promise.all(
      paginatedClaims.map(async (claim) => {
        let workerInfo = null;
        try {
          const workerSnap = await req.db.collection("workers").doc(claim.workerId).get();
          if (workerSnap.exists) {
            const w = workerSnap.data() || {};
            workerInfo = {
              id: workerSnap.id,
              name: w.name || "Artisan",
              org: w.cooperativeOrg || w.org || w.coopOrg || "WorkGo Co-op",
              phone: w.phone,
              avgRating: w.avgRating,
            };
          }
        } catch (err) {
          console.warn(`[welfare] Failed to fetch worker ${claim.workerId}:`, err.message);
        }

        const approvalThreshold = await getApprovalThreshold(claim.workerId, req.db);

        return {
          ...claim,
          worker: workerInfo,
          approvalThreshold,
        };
      })
    );

    return res.json({
      success: true,
      claims: enrichedClaims,
      total: claims.length,
      page,
      limit,
    });
  } catch (e) {
    console.error("[welfare/list] Error:", e);
    return res.status(500).json({ error: "Failed to fetch welfare claims", detail: e.message });
  }
});

// ── STEP 4c: GET /claims/:claimId (Admin OR owning worker/proxy) ───────────────
router.get("/claims/:claimId", async (req, res) => {
  try {
    const { claimId } = req.params;
    const claimDoc = await req.db.collection("welfare_claims").doc(claimId).get();

    if (!claimDoc.exists) {
      return res.status(404).json({ error: "Welfare claim not found" });
    }

    const claim = { id: claimDoc.id, ...claimDoc.data() };

    // Authorization: Admin, owning artisan, or authorized proxy
    const isAuthorized = await canAccessWorker(req.user && req.user.uid, claim.workerId, req.db);
    if (!isAuthorized) {
      return res.status(403).json({ error: "Access denied" });
    }

    // Fetch associated worker details
    let worker = { id: claim.workerId };
    try {
      const workerSnap = await req.db.collection("workers").doc(claim.workerId).get();
      if (workerSnap.exists) {
        worker = { id: workerSnap.id, ...workerSnap.data() };
      }
    } catch (err) {
      console.warn(`[welfare] Failed to fetch worker ${claim.workerId}:`, err.message);
    }

    const approvalThreshold = await getApprovalThreshold(claim.workerId, req.db);

    // Invariant: Scoring is only computed once an admin has checked at least one verification box.
    // Otherwise return score: null with scoreReason: "no_admin_verification_yet"
    const hasAdminVerification = Boolean(
      claim.doctorCallConfirmed || claim.customerCallConfirmed || claim.sosCorroborated
    );

    let score = null;
    let scoreReason = null;

    if (hasAdminVerification) {
      score = await computeClaimConfidence(claim, worker, req.db);
    } else {
      scoreReason = "no_admin_verification_yet";
    }

    return res.json({
      success: true,
      claim,
      worker: {
        id: worker.id,
        name: worker.name,
        org: worker.cooperativeOrg || worker.org || worker.coopOrg,
        phone: worker.phone,
        avgRating: worker.avgRating,
        createdAt: worker.createdAt || worker.joinedAt,
      },
      score,
      scoreReason,
      approvalThreshold,
    });
  } catch (e) {
    console.error("[welfare/get] Error:", e);
    return res.status(500).json({ error: "Failed to get welfare claim", detail: e.message });
  }
});

// ── STEP 4d: PATCH /claims/:claimId/verify (Admin-only) ────────────────────────
router.patch("/claims/:claimId/verify", adminOnly, async (req, res) => {
  try {
    const { claimId } = req.params;
    const claimRef = req.db.collection("welfare_claims").doc(claimId);
    const claimDoc = await claimRef.get();

    if (!claimDoc.exists) {
      return res.status(404).json({ error: "Welfare claim not found" });
    }

    const claim = { id: claimDoc.id, ...claimDoc.data() };
    const {
      doctorCallConfirmed,
      doctorCallNote,
      customerCallConfirmed,
      customerCallNote,
      sosCorroborated,
      sosNote,
      photoOverride,
      photoOverrideNote,
    } = req.body || {};

    // Safety guard: Reject with 400 if a checkbox is being set true without a paired note >= 20 chars
    if (doctorCallConfirmed === true) {
      const note = doctorCallNote !== undefined ? doctorCallNote : claim.doctorCallNote;
      if (!note || typeof note !== "string" || note.trim().length < 20) {
        return res.status(400).json({
          error: "doctorCallConfirmed requires a doctorCallNote of at least 20 characters",
        });
      }
    }

    if (customerCallConfirmed === true) {
      const note = customerCallNote !== undefined ? customerCallNote : claim.customerCallNote;
      if (!note || typeof note !== "string" || note.trim().length < 20) {
        return res.status(400).json({
          error: "customerCallConfirmed requires a customerCallNote of at least 20 characters",
        });
      }
    }

    if (sosCorroborated === true) {
      const note = sosNote !== undefined ? sosNote : claim.sosNote;
      if (!note || typeof note !== "string" || note.trim().length < 20) {
        return res.status(400).json({
          error: "sosCorroborated requires a sosNote of at least 20 characters",
        });
      }
    }

    if (photoOverride === true || (photoOverrideNote !== undefined && photoOverrideNote !== null)) {
      const note = photoOverrideNote !== undefined ? photoOverrideNote : claim.photoOverrideNote;
      if (!note || typeof note !== "string" || note.trim().length < 20) {
        return res.status(400).json({
          error: "photoOverride requires a photoOverrideNote of at least 20 characters",
        });
      }
    }

    const timestamp = new Date().toISOString();
    const updates = {};
    const changes = {};

    if (doctorCallConfirmed !== undefined) {
      updates.doctorCallConfirmed = Boolean(doctorCallConfirmed);
      changes.doctorCallConfirmed = Boolean(doctorCallConfirmed);
    }
    if (doctorCallNote !== undefined) {
      updates.doctorCallNote = doctorCallNote;
      changes.doctorCallNote = doctorCallNote;
    }
    if (customerCallConfirmed !== undefined) {
      updates.customerCallConfirmed = Boolean(customerCallConfirmed);
      changes.customerCallConfirmed = Boolean(customerCallConfirmed);
    }
    if (customerCallNote !== undefined) {
      updates.customerCallNote = customerCallNote;
      changes.customerCallNote = customerCallNote;
    }
    if (sosCorroborated !== undefined) {
      updates.sosCorroborated = Boolean(sosCorroborated);
      changes.sosCorroborated = Boolean(sosCorroborated);
    }
    if (sosNote !== undefined) {
      updates.sosNote = sosNote;
      changes.sosNote = sosNote;
    }
    if (photoOverride !== undefined) {
      updates.photoOverride = Boolean(photoOverride);
      changes.photoOverride = Boolean(photoOverride);
    }
    if (photoOverrideNote !== undefined) {
      const hasValidOverride = Boolean(photoOverrideNote && photoOverrideNote.trim().length >= 20);
      updates.photoOverride = photoOverride !== undefined ? Boolean(photoOverride) : hasValidOverride;
      updates.photoOverrideNote = photoOverrideNote;
      changes.photoOverride = updates.photoOverride;
      changes.photoOverrideNote = photoOverrideNote;
    }

    // Append to auditLog array (do NOT overwrite) to preserve complete administrative history
    const existingAuditLog = Array.isArray(claim.auditLog) ? [...claim.auditLog] : [];
    const existingVerificationLog = Array.isArray(claim.verificationLog) ? [...claim.verificationLog] : [];

    existingAuditLog.push({
      adminId: req.user.uid,
      timestamp,
      changes,
    });
    updates.auditLog = existingAuditLog;

    // Synchronize verificationLog for welfare_scoring entry lookup
    if (doctorCallNote && doctorCallNote.trim().length >= 20) {
      existingVerificationLog.push({
        type: "doctorCall",
        note: doctorCallNote.trim(),
        adminId: req.user.uid,
        timestamp,
      });
    }
    if (customerCallNote && customerCallNote.trim().length >= 20) {
      existingVerificationLog.push({
        type: "customerCall",
        note: customerCallNote.trim(),
        adminId: req.user.uid,
        timestamp,
      });
    }
    if (sosNote && sosNote.trim().length >= 20) {
      existingVerificationLog.push({
        type: "sos",
        note: sosNote.trim(),
        adminId: req.user.uid,
        timestamp,
      });
    }
    if (photoOverrideNote && photoOverrideNote.trim().length >= 20) {
      existingVerificationLog.push({
        type: "photoOverride",
        note: photoOverrideNote.trim(),
        adminId: req.user.uid,
        timestamp,
      });
    }
    updates.verificationLog = existingVerificationLog;

    if (typeof claimRef.update === "function") {
      await claimRef.update(updates);
    } else {
      await claimRef.set(updates, { merge: true });
    }

    // Recompute score and threshold immediately so admin UI updates without second round trip
    const updatedClaim = { ...claim, ...updates };
    let worker = { id: claim.workerId };
    try {
      const workerSnap = await req.db.collection("workers").doc(claim.workerId).get();
      if (workerSnap.exists) {
        worker = { id: workerSnap.id, ...workerSnap.data() };
      }
    } catch (err) {
      console.warn(`[welfare] Failed to fetch worker ${claim.workerId}:`, err.message);
    }

    const recomputedScore = await computeClaimConfidence(updatedClaim, worker, req.db);
    const approvalThreshold = await getApprovalThreshold(claim.workerId, req.db);

    return res.json({
      success: true,
      claim: updatedClaim,
      score: recomputedScore,
      approvalThreshold,
    });
  } catch (e) {
    console.error("[welfare/verify] Error:", e);
    return res.status(500).json({ error: "Failed to update claim verification", detail: e.message });
  }
});

// ── STEP 4e: POST /claims/:claimId/decision (Admin-only) ───────────────────────
router.post("/claims/:claimId/decision", adminOnly, async (req, res) => {
  try {
    const { claimId } = req.params;
    const { decision, decisionNote } = req.body || {};

    // 1. Mandatory manual action: decision must be 'approved' or 'rejected'
    if (decision !== "approved" && decision !== "rejected") {
      return res.status(400).json({
        error: "decision must be either 'approved' or 'rejected'",
      });
    }

    // 2. Justification requirement: decisionNote must be at least 10 chars
    if (!decisionNote || typeof decisionNote !== "string" || decisionNote.trim().length < 10) {
      return res.status(400).json({
        error: "decisionNote is required and must be at least 10 characters",
      });
    }

    const claimRef = req.db.collection("welfare_claims").doc(claimId);
    const claimDoc = await claimRef.get();

    if (!claimDoc.exists) {
      return res.status(404).json({ error: "Welfare claim not found" });
    }

    const claim = { id: claimDoc.id, ...claimDoc.data() };

    // Fetch worker document for scoring and notification dispatch
    let worker = { id: claim.workerId };
    try {
      const workerSnap = await req.db.collection("workers").doc(claim.workerId).get();
      if (workerSnap.exists) {
        worker = { id: workerSnap.id, ...workerSnap.data() };
      }
    } catch (err) {
      console.warn(`[welfare] Failed to fetch worker ${claim.workerId}:`, err.message);
    }

    // 3. Score & Threshold Snapshot:
    // Snapshot score and threshold at the exact moment of decision onto the claim document.
    // Future mutations (e.g. worker rating changes) must NEVER rewrite this historical snapshot.
    const scoreAtDecision = await computeClaimConfidence(claim, worker, req.db);
    const thresholdAtDecision = await getApprovalThreshold(claim.workerId, req.db);

    const timestamp = new Date().toISOString();
    const existingAuditLog = Array.isArray(claim.auditLog) ? [...claim.auditLog] : [];

    existingAuditLog.push({
      action: "decision",
      decision,
      decisionNote: decisionNote.trim(),
      adminId: req.user.uid,
      timestamp,
      snapshotScore: scoreAtDecision.totalScore,
      snapshotThreshold: thresholdAtDecision,
    });

    const decisionPayload = {
      status: decision,
      decidedBy: req.user.uid,
      decidedAt: timestamp,
      decisionNote: decisionNote.trim(),
      snapshotScore: scoreAtDecision.totalScore,
      snapshotThreshold: thresholdAtDecision,
      scoreAtDecision: scoreAtDecision.totalScore,
      thresholdAtDecision: thresholdAtDecision,
      scoreSnapshot: {
        totalScore: scoreAtDecision.totalScore,
        baseScore: scoreAtDecision.baseScore,
        trustBonus: scoreAtDecision.trustBonus,
        approvalThreshold: thresholdAtDecision,
        decidedAt: timestamp,
        decidedBy: req.user.uid,
      },
      auditLog: existingAuditLog,
    };

    if (typeof claimRef.update === "function") {
      await claimRef.update(decisionPayload);
    } else {
      await claimRef.set(decisionPayload, { merge: true });
    }

    // 4. Dispatch notification to the worker using the existing NotificationEngine
    try {
      const notificationEngine = new NotificationEngine(req.db, req.messaging);
      const targetUserId = worker.userId || claim.workerId;
      const eventKey = decision === "approved" ? "WELFARE_CLAIM_APPROVED" : "WELFARE_CLAIM_REJECTED";

      await notificationEngine.sendToUser(
        targetUserId,
        eventKey,
        {
          claimId: claimDoc.id,
          reason: decisionNote.trim(),
          decisionNote: decisionNote.trim(),
        },
        {
          claimId: claimDoc.id,
          status: decision,
        }
      );
    } catch (notifErr) {
      console.warn("[welfare] NotificationEngine dispatch warning:", notifErr.message);
    }

    return res.json({
      success: true,
      claimId: claimDoc.id,
      decision,
      snapshotScore: scoreAtDecision.totalScore,
      snapshotThreshold: thresholdAtDecision,
      decidedBy: req.user.uid,
      decidedAt: timestamp,
    });
  } catch (e) {
    console.error("[welfare/decision] Error:", e);
    return res.status(500).json({ error: "Failed to record claim decision", detail: e.message });
  }
});

module.exports = router;
