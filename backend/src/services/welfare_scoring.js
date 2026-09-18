/**
 * Worker Welfare & Insurance Claim Confidence Scoring Engine (SIH 26089)
 *
 * Implements:
 * 1. computeClaimConfidence(claim, worker, db): Pure multi-factor corroboration scoring
 *    across two weight tables (booking-linked vs no-booking), note-length safety guards,
 *    tamper check handling, and live trust bonus calculations.
 * 2. getApprovalThreshold(workerId, db, referenceDate): 24-month rolling window frequency tiering
 *    (1st claim -> 50, 2nd claim -> 75, 3rd+ claim -> 90).
 */

const MIN_NOTE_LENGTH = 20;

/**
 * Extracts a parsed Date object from various timestamp representations
 * (Firestore Timestamp, ISO String, or native Date).
 *
 * @param {any} val
 * @returns {Date|null}
 */
function toDate(val) {
  if (!val) return null;
  if (val instanceof Date) return val;
  if (typeof val.toDate === "function") return val.toDate();
  if (typeof val === "string" || typeof val === "number") {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * Validates whether an admin verification factor is genuinely confirmed:
 * requires the boolean flag to be true AND an associated note of at least 20 characters.
 *
 * @param {boolean} flag - The boolean checkbox value
 * @param {string|null} note - The verification note explaining the action
 * @param {Array} [verificationLog] - Optional audit log entries
 * @param {string} [type] - Verification entry type
 * @returns {boolean}
 */
function isFactorConfirmedWithNote(flag, note, verificationLog = [], type = "") {
  if (!flag) return false;

  const directNote = typeof note === "string" ? note.trim() : "";
  if (directNote.length >= MIN_NOTE_LENGTH) return true;

  if (Array.isArray(verificationLog) && type) {
    const entry = verificationLog.find((e) => e && e.type === type && typeof e.note === "string");
    if (entry && entry.note.trim().length >= MIN_NOTE_LENGTH) {
      return true;
    }
  }

  return false;
}

/**
 * Computes multi-factor corroboration confidence score for a welfare claim.
 *
 * Gate note: doctorCertificate is an absolute prerequisite enforced at submission time.
 * This function scores corroborating evidence on top of the already-certificated claim.
 *
 * @param {Object} claim - Welfare claim document data
 * @param {Object} worker - Worker document data
 * @param {Object} db - Firestore database instance (for live un-cached queries)
 * @returns {Promise<Object>} Scoring breakdown and total score
 */
async function computeClaimConfidence(claim, worker = {}, db = null) {
  if (!claim) {
    throw new Error("computeClaimConfidence requires a valid claim object");
  }

  const isBookingLinked = Boolean(
    (claim.bookingId && String(claim.bookingId).trim().length > 0) ||
    (claim.relatedBookingId && String(claim.relatedBookingId).trim().length > 0)
  );

  const verificationLog = Array.isArray(claim.verificationLog) ? claim.verificationLog : [];

  // 1. Evaluate individual factors with length safety guards
  const doctorCallConfirmed = isFactorConfirmedWithNote(
    Boolean(claim.doctorCallConfirmed),
    claim.doctorCallNote || claim.doctorCallConfirmedNote,
    verificationLog,
    "doctorCall"
  );

  const customerCallConfirmed = isBookingLinked
    ? isFactorConfirmedWithNote(
        Boolean(claim.customerCallConfirmed),
        claim.customerCallNote || claim.customerCallConfirmedNote,
        verificationLog,
        "customerCall"
      )
    : false;

  const sosCorroborated = isFactorConfirmedWithNote(
    Boolean(claim.sosCorroborated),
    claim.sosNote || claim.sosCorroboratedNote,
    verificationLog,
    "sos"
  );

  const hospitalRecordProvided = Boolean(
    claim.hospitalRecordDocId && String(claim.hospitalRecordDocId).trim().length > 0
  );

  // 2. Tamper check handling on injury photo
  const hasPhoto = Boolean(claim.injuryPhotoDocId && String(claim.injuryPhotoDocId).trim().length > 0);
  const photoFlagged = Boolean(
    claim.photoFlagged === true ||
    (claim.photoDetectorResult && claim.photoDetectorResult.isSuspicious === true)
  );

  const photoOverrideConfirmed = isFactorConfirmedWithNote(
    Boolean(claim.photoOverride === true || claim.photoOverrideNote),
    claim.photoOverrideNote,
    verificationLog,
    "photoOverride"
  );

  const photoFlaggedForReview = hasPhoto && photoFlagged;
  const photoPassesTamperCheck = hasPhoto && (!photoFlagged || photoOverrideConfirmed);

  // 3. Compute base score according to weight tables
  let baseScore = 0;
  const factors = {
    doctorCallConfirmed,
    hospitalRecordProvided,
    sosCorroborated,
    photoPassesTamperCheck,
  };

  if (isBookingLinked) {
    factors.customerCallConfirmed = customerCallConfirmed;
    if (doctorCallConfirmed) baseScore += 35;
    if (hospitalRecordProvided) baseScore += 25;
    if (customerCallConfirmed) baseScore += 20;
    if (sosCorroborated) baseScore += 12;
    if (photoPassesTamperCheck) baseScore += 8;
  } else {
    factors.customerCallConfirmed = false;
    if (doctorCallConfirmed) baseScore += 45;
    if (hospitalRecordProvided) baseScore += 30;
    if (sosCorroborated) baseScore += 15;
    if (photoPassesTamperCheck) baseScore += 10;
  }

  // 4. Compute trust bonuses (applied after base score, capped at +10% max)
  let trustBonus = 0;
  const now = new Date();

  // Tenure bonus: +3% if registered >= 365 days ago
  const workerCreatedAt = toDate(worker.createdAt) || toDate(worker.joinedAt);
  if (workerCreatedAt) {
    const ageMs = now.getTime() - workerCreatedAt.getTime();
    const oneYearMs = 365 * 24 * 60 * 60 * 1000;
    if (ageMs >= oneYearMs) {
      trustBonus += 3;
    }
  }

  // Rating bonus: +3% if avgRating >= 4.5
  const avgRating = Number(worker.avgRating || 0);
  if (avgRating >= 4.5) {
    trustBonus += 3;
  }

  // Live query bonus: +4% if zero prior rejected claims
  if (db && worker.id) {
    try {
      const rejectedSnapshot = await db
        .collection("welfare_claims")
        .where("workerId", "==", worker.id)
        .where("status", "==", "rejected")
        .get();

      // Filter out the current claim if it happens to have an id matching
      const priorRejectedDocs = rejectedSnapshot.docs.filter((doc) => doc.id !== claim.id);
      if (priorRejectedDocs.length === 0) {
        trustBonus += 4;
      }
    } catch (e) {
      console.warn("[welfare_scoring] Live query for rejected claims failed:", e.message);
    }
  }

  trustBonus = Math.min(10, Math.max(0, trustBonus));
  const totalScore = Math.min(100, Math.max(0, baseScore + trustBonus));

  return {
    baseScore,
    trustBonus,
    totalScore,
    weightTableUsed: isBookingLinked ? "booking" : "no_booking",
    factors,
    photoFlaggedForReview,
  };
}

/**
 * Calculates the required approval threshold based on claim count in the trailing 24 months.
 * Counts ALL claims (approved, rejected, pending) within the rolling window.
 *
 * Tier 1 (1st claim in window):  50%
 * Tier 2 (2nd claim in window):  75%
 * Tier 3 (3rd+ claim in window): 90%
 *
 * @param {string} workerId - Worker ID
 * @param {Object} db - Firestore instance
 * @param {Date} [referenceDate] - Current date/time for window boundary
 * @returns {Promise<number>} Required approval threshold (50, 75, or 90)
 */
async function getApprovalThreshold(workerId, db, referenceDate = new Date()) {
  if (!workerId || !db) return 50;

  const refDate = toDate(referenceDate) || new Date();
  // Rolling 24-month window boundary: 24 months prior to reference date
  const windowStart = new Date(refDate.getFullYear(), refDate.getMonth() - 24, refDate.getDate());

  let claimsInWindowCount = 0;
  try {
    const claimsSnapshot = await db
      .collection("welfare_claims")
      .where("workerId", "==", workerId)
      .get();

    for (const doc of claimsSnapshot.docs) {
      const data = doc.data() || {};
      const incidentDate = toDate(data.incidentDate) || toDate(data.submittedAt);
      if (incidentDate && incidentDate >= windowStart && incidentDate <= refDate) {
        claimsInWindowCount++;
      }
    }
  } catch (e) {
    console.warn("[welfare_scoring] Failed to count claims in 24m window:", e.message);
    return 50;
  }

  if (claimsInWindowCount <= 1) return 50;
  if (claimsInWindowCount === 2) return 75;
  return 90;
}

module.exports = {
  computeClaimConfidence,
  getApprovalThreshold,
  MIN_NOTE_LENGTH,
};
