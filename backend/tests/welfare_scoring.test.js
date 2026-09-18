const {
  computeClaimConfidence,
  getApprovalThreshold,
} = require("../src/services/welfare_scoring");

describe("Worker Welfare Claim Confidence Scoring Engine", () => {
  // Helper to create a mock Firestore instance
  const createMockDb = ({ rejectedClaims = [], claimsInWindow = [] } = {}) => ({
    collection: jest.fn().mockImplementation((col) => {
      if (col === "welfare_claims") {
        return {
          where: jest.fn().mockImplementation((field, op, val) => {
            if (field === "workerId") {
              return {
                where: jest.fn().mockImplementation((subField, subOp, subVal) => {
                  if (subField === "status" && subVal === "rejected") {
                    return {
                      get: jest.fn().mockResolvedValue({
                        docs: rejectedClaims.map((c) => ({
                          id: c.id || "claim_rej_id",
                          data: () => c,
                        })),
                      }),
                    };
                  }
                  return { get: jest.fn().mockResolvedValue({ docs: [] }) };
                }),
                get: jest.fn().mockResolvedValue({
                  docs: claimsInWindow.map((c) => ({
                    id: c.id || "claim_id",
                    data: () => c,
                  })),
                }),
              };
            }
            return { get: jest.fn().mockResolvedValue({ docs: [] }) };
          }),
        };
      }
      return { get: jest.fn().mockResolvedValue({ docs: [] }) };
    }),
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SAFETY INVARIANT TEST
  // ──────────────────────────────────────────────────────────────────────────
  test("SAFETY INVARIANT: zero admin verifications with full evidence stays at 33% (booking) and 40% (no-booking), and cannot cross 1st-claim threshold even with max trust bonus", async () => {
    // Evidence provided: hospitalRecord and photo passes check.
    // Admin verifications: all false.
    const unverifiedEvidenceClaimBooking = {
      id: "claim_inv_booking",
      bookingId: "b_12345",
      doctorCallConfirmed: false,
      customerCallConfirmed: false,
      sosCorroborated: false,
      hospitalRecordDocId: "doc_hosp_01",
      injuryPhotoDocId: "doc_photo_01",
      photoFlagged: false,
    };

    const unverifiedEvidenceClaimNoBooking = {
      id: "claim_inv_nobooking",
      doctorCallConfirmed: false,
      sosCorroborated: false,
      hospitalRecordDocId: "doc_hosp_01",
      injuryPhotoDocId: "doc_photo_01",
      photoFlagged: false,
    };

    // A worker with zero history (no bonuses)
    const freshWorker = {
      id: "w_fresh",
      createdAt: new Date(), // 0 days tenure
      avgRating: 4.0, // < 4.5
    };

    // DB with a rejected claim so zero-rejected bonus is not awarded
    const dbWithRejection = createMockDb({
      rejectedClaims: [{ id: "claim_old_rej", status: "rejected" }],
    });

    const bookingResult = await computeClaimConfidence(
      unverifiedEvidenceClaimBooking,
      freshWorker,
      dbWithRejection
    );
    const noBookingResult = await computeClaimConfidence(
      unverifiedEvidenceClaimNoBooking,
      freshWorker,
      dbWithRejection
    );

    // Assert base scores match the exact table percentages without admin verification
    expect(bookingResult.weightTableUsed).toBe("booking");
    expect(bookingResult.baseScore).toBe(33); // 25% (hospital) + 8% (photo)
    expect(bookingResult.totalScore).toBe(33);

    expect(noBookingResult.weightTableUsed).toBe("no_booking");
    expect(noBookingResult.baseScore).toBe(40); // 30% (hospital) + 10% (photo)
    expect(noBookingResult.totalScore).toBe(40);

    // Now test with MAX POSSIBLE TRUST BONUS (+10%: tenure + rating + clean history)
    const veteranStarWorker = {
      id: "w_veteran",
      createdAt: new Date(Date.now() - 400 * 86400 * 1000), // > 365 days (+3%)
      avgRating: 4.9, // >= 4.5 (+3%)
    };
    const cleanDb = createMockDb({ rejectedClaims: [] }); // 0 rejected claims (+4%)

    const bookingMaxBonus = await computeClaimConfidence(
      unverifiedEvidenceClaimBooking,
      veteranStarWorker,
      cleanDb
    );
    const noBookingMaxBonus = await computeClaimConfidence(
      unverifiedEvidenceClaimNoBooking,
      veteranStarWorker,
      cleanDb
    );

    expect(bookingMaxBonus.trustBonus).toBe(10);
    expect(bookingMaxBonus.totalScore).toBe(43); // 33 + 10 = 43%

    expect(noBookingMaxBonus.trustBonus).toBe(10);
    expect(noBookingMaxBonus.totalScore).toBe(50); // 40 + 10 = 50%

    // Threshold check: 1st claim threshold is 50.
    // Confirm strict superiority requirement (totalScore > threshold):
    // Booking case (43%) is strictly below 50.
    const tier1Threshold = 50;
    const bookingCrosses = bookingMaxBonus.totalScore > tier1Threshold;
    expect(bookingCrosses).toBe(false);

    // No-booking case sits exactly on the 50 boundary: confirm it does NOT cross
    const noBookingCrosses = noBookingMaxBonus.totalScore > tier1Threshold;
    expect(noBookingCrosses).toBe(false);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 2. NOTE LENGTH SAFETY CHECK (< 20 CHARS REJECTION)
  // ──────────────────────────────────────────────────────────────────────────
  test("rejects verification factor if note length is under 20 characters even if boolean is true", async () => {
    const claimShortNote = {
      id: "claim_short_note",
      bookingId: "b_test_note",
      doctorCallConfirmed: true,
      doctorCallNote: "Called doctor ok", // 16 characters -> under 20
      customerCallConfirmed: true,
      customerCallNote: "Yes verified", // 12 characters -> under 20
      sosCorroborated: true,
      sosNote: "Short note", // 10 characters -> under 20
    };

    const resultShort = await computeClaimConfidence(claimShortNote, {}, null);

    expect(resultShort.factors.doctorCallConfirmed).toBe(false);
    expect(resultShort.factors.customerCallConfirmed).toBe(false);
    expect(resultShort.factors.sosCorroborated).toBe(false);
    expect(resultShort.baseScore).toBe(0);

    // Now supply valid notes of >= 20 characters
    const claimValidNote = {
      id: "claim_valid_note",
      bookingId: "b_test_note",
      doctorCallConfirmed: true,
      doctorCallNote: "Spoke with Dr. Rajan at Erode Govt Hospital; confirmed burn treatment.",
      customerCallConfirmed: true,
      customerCallNote: "Customer confirmed electrical spark incident occurred on their premises.",
      sosCorroborated: true,
      sosNote: "Live SOS beacon was broadcast at same GPS location within 3 minutes.",
    };

    const resultValid = await computeClaimConfidence(claimValidNote, {}, null);

    expect(resultValid.factors.doctorCallConfirmed).toBe(true);
    expect(resultValid.factors.customerCallConfirmed).toBe(true);
    expect(resultValid.factors.sosCorroborated).toBe(true);
    expect(resultValid.baseScore).toBe(35 + 20 + 12); // 67
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 3. LIVE QUERY FOR "NO PRIOR REJECTED CLAIMS" BONUS
  // ──────────────────────────────────────────────────────────────────────────
  test("computes 'no prior rejected claims' bonus via live Firestore query at call time", async () => {
    const claim = { id: "claim_current" };
    const worker = { id: "w_test_live_query", avgRating: 4.0 };

    // When live query returns ZERO rejected claims -> +4% awarded
    const cleanDb = createMockDb({ rejectedClaims: [] });
    const resultClean = await computeClaimConfidence(claim, worker, cleanDb);
    expect(resultClean.trustBonus).toBe(4);

    // When live query returns a rejected claim -> +4% withheld
    const dirtyDb = createMockDb({
      rejectedClaims: [{ id: "claim_prev_fraud", status: "rejected" }],
    });
    const resultDirty = await computeClaimConfidence(claim, worker, dirtyDb);
    expect(resultDirty.trustBonus).toBe(0);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 4. TENURE BONUS USING WORKER.CREATEDAT / BACKFILLED DATE
  // ──────────────────────────────────────────────────────────────────────────
  test("correctly applies +3% tenure bonus for workers registered >= 365 days ago, including backfilled dates", async () => {
    const claim = { id: "claim_tenure" };

    // Case A: Backfilled date from 400 days ago
    const backfilledDate = new Date(Date.now() - 400 * 86400 * 1000);
    const workerBackfilled = {
      id: "w_backfilled",
      createdAt: backfilledDate,
      avgRating: 4.0,
    };
    const dbWithRejection = createMockDb({
      rejectedClaims: [{ id: "prev_rej", status: "rejected" }],
    });

    const resultBackfilled = await computeClaimConfidence(
      claim,
      workerBackfilled,
      dbWithRejection
    );
    expect(resultBackfilled.trustBonus).toBe(3);

    // Case B: Worker created 200 days ago (< 365 days)
    const recentDate = new Date(Date.now() - 200 * 86400 * 1000);
    const workerRecent = {
      id: "w_recent",
      createdAt: recentDate,
      avgRating: 4.0,
    };
    const resultRecent = await computeClaimConfidence(
      claim,
      workerRecent,
      dbWithRejection
    );
    expect(resultRecent.trustBonus).toBe(0);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 5. GETAPPROVALTHRESHOLD INDEPENDENT 24-MONTH ROLLING WINDOW TESTS
  // ──────────────────────────────────────────────────────────────────────────
  test("getApprovalThreshold returns 50 for 1st claim, 75 for 2nd, 90 for 3rd+, and excludes claims older than 24 months", async () => {
    const refDate = new Date("2026-09-14T12:00:00Z");

    // Helper to generate dates relative to refDate
    const monthsAgo = (m) => {
      const d = new Date(refDate);
      d.setMonth(d.getMonth() - m);
      return d;
    };

    // Case 1: Only 1 claim in window (e.g. 2 months ago) -> Tier 1 (50%)
    const db1 = createMockDb({
      claimsInWindow: [{ id: "c1", incidentDate: monthsAgo(2), status: "pending" }],
    });
    const threshold1 = await getApprovalThreshold("w_t1", db1, refDate);
    expect(threshold1).toBe(50);

    // Case 2: 2 claims in window (e.g. 2 months ago, 10 months ago) -> Tier 2 (75%)
    const db2 = createMockDb({
      claimsInWindow: [
        { id: "c1", incidentDate: monthsAgo(2), status: "approved" },
        { id: "c2", incidentDate: monthsAgo(10), status: "rejected" },
      ],
    });
    const threshold2 = await getApprovalThreshold("w_t2", db2, refDate);
    expect(threshold2).toBe(75);

    // Case 3: 3 claims in window -> Tier 3 (90%)
    const db3 = createMockDb({
      claimsInWindow: [
        { id: "c1", incidentDate: monthsAgo(2), status: "approved" },
        { id: "c2", incidentDate: monthsAgo(8), status: "approved" },
        { id: "c3", incidentDate: monthsAgo(18), status: "pending" },
      ],
    });
    const threshold3 = await getApprovalThreshold("w_t3", db3, refDate);
    expect(threshold3).toBe(90);

    // Case 4: 1 claim in window (4 months ago) and 1 claim outside window (25 months ago)
    // The claim from 25 months ago MUST NOT count -> stays at Tier 1 (50%)
    const dbWithOldClaim = createMockDb({
      claimsInWindow: [
        { id: "c_recent", incidentDate: monthsAgo(4), status: "approved" },
        { id: "c_expired", incidentDate: monthsAgo(25), status: "approved" },
      ],
    });
    const thresholdExpired = await getApprovalThreshold("w_exp", dbWithOldClaim, refDate);
    expect(thresholdExpired).toBe(50);
  });
});
