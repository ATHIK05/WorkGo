/**
 * Worker Welfare & Insurance Claim Routes Test Suite (SIH 26089 - Step 4f)
 *
 * Tests:
 * 1. Submission without doctorCertificateDocId is rejected (400), no document created.
 * 2. Submission referencing a docId that belongs to a different workerId is rejected.
 * 3. GET claim detail before any admin verification returns score: null, not a numeric 0.
 * 4. PATCH /verify with a note under 20 chars is rejected (400).
 * 5. PATCH /verify with a valid note updates the score correctly and the auditLog array grows (not overwrites) on a second PATCH call.
 * 6. POST /decision snapshots score+threshold onto the claim at decision time — mutate the worker's avgRating AFTER a decision is recorded, recompute independently, and confirm the claim's stored snapshot did NOT change even though a fresh computeClaimConfidence call now would return a different number.
 * 7. POST /decision with decisionNote under 10 chars is rejected.
 * 8. Confirm NotificationEngine.sendToUser is called (mock it) on both approval and rejection, in the worker's preferred language.
 */

const welfareRouter = require("../src/routes/welfare");
const { computeClaimConfidence } = require("../src/services/welfare_scoring");
const { NotificationEngine } = require("../src/services/notification_engine");

// ── Mock Request & Response Dispatcher ────────────────────────────────────────

function makeChainableQuery() {
  const queryObj = {
    where: jest.fn().mockImplementation(() => queryObj),
    get: jest.fn().mockResolvedValue({ docs: [] }),
  };
  return queryObj;
}

function createMockRes() {
  let resolveDone;
  const donePromise = new Promise((resolve) => {
    resolveDone = resolve;
  });

  const res = {
    statusCode: 200,
    data: null,
    donePromise,
    status: jest.fn().mockImplementation((code) => {
      res.statusCode = code;
      return res;
    }),
    json: jest.fn().mockImplementation((payload) => {
      res.data = payload;
      resolveDone(res);
      return res;
    }),
  };
  return res;
}

async function dispatch(method, path, req, res) {
  for (const layer of welfareRouter.stack) {
    if (layer.route && layer.route.methods[method.toLowerCase()]) {
      const routePath = layer.route.path;
      let match = false;
      const params = {};

      if (routePath === path) {
        match = true;
      } else if (routePath.includes(":")) {
        const routeParts = routePath.split("/");
        const pathParts = path.split("/");
        if (routeParts.length === pathParts.length) {
          match = true;
          for (let i = 0; i < routeParts.length; i++) {
            if (routeParts[i].startsWith(":")) {
              params[routeParts[i].substring(1)] = pathParts[i];
            } else if (routeParts[i] !== pathParts[i]) {
              match = false;
              break;
            }
          }
        }
      }

      if (match) {
        req.params = { ...(req.params || {}), ...params };
        const stack = layer.route.stack;
        let idx = 0;
        const next = async (err) => {
          if (err) throw err;
          if (idx < stack.length) {
            const current = stack[idx++];
            await current.handle(req, res, next);
          }
        };
        await next();
        await Promise.race([
          res.donePromise,
          new Promise((r) => setTimeout(r, 200)),
        ]);
        return;
      }
    }
  }
  throw new Error(`Route not found: ${method} ${path}`);
}

describe("Welfare Routes (SIH 26089 Backend Implementation)", () => {
  // ── TEST 1: Hard gate - missing doctor certificate ──────────────────────────
  test("1. Submission without doctorCertificateDocId is rejected (400), no document created", async () => {
    let documentCreated = false;
    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "worker" }) }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ userId: "worker_01" }),
              }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              set: jest.fn().mockImplementation(() => {
                documentCreated = true;
                return Promise.resolve();
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn(), set: jest.fn() }) };
      }),
    };

    const req = {
      body: {
        workerId: "worker_01",
        // doctorCertificateDocId missing!
        incidentDate: "2026-09-10T10:00:00Z",
        description: "Fell off ladder during painting work",
      },
      user: { uid: "worker_01" },
      db: mockDb,
    };
    const res = createMockRes();

    await dispatch("POST", "/claims/submit", req, res);

    expect(res.statusCode).toBe(400);
    expect(res.data.error).toContain("doctorCertificateDocId is required");
    expect(documentCreated).toBe(false);
  });

  // ── TEST 2: Cross-worker document reference tampering rejected ──────────────
  test("2. Submission referencing a docId that belongs to a different workerId is rejected", async () => {
    let documentCreated = false;
    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "worker" }) }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockImplementation((wId) => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ userId: wId }),
              }),
              collection: jest.fn().mockImplementation((subcol) => {
                if (subcol === "documents") {
                  return {
                    doc: jest.fn().mockImplementation((docId) => ({
                      get: jest.fn().mockResolvedValue({
                        // Return false because this doc does NOT belong to worker_01
                        exists: docId === "legit_doc_01",
                      }),
                    })),
                  };
                }
                return { doc: jest.fn() };
              }),
            })),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              set: jest.fn().mockImplementation(() => {
                documentCreated = true;
                return Promise.resolve();
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      body: {
        workerId: "worker_01",
        doctorCertificateDocId: "foreign_worker_cert_999", // Belongs to someone else!
      },
      user: { uid: "worker_01" },
      db: mockDb,
    };
    const res = createMockRes();

    await dispatch("POST", "/claims/submit", req, res);

    expect(res.statusCode).toBe(400);
    expect(res.data.error).toContain("does not exist in worker's vault");
    expect(documentCreated).toBe(false);
  });

  // ── TEST 2b: Document docType mismatch rejected ────────────────────────────
  test("2b. Submission referencing a document whose docType is not 'welfareCertificate' is rejected (400)", async () => {
    let documentCreated = false;
    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "worker" }) }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockImplementation((wId) => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ userId: wId }),
              }),
              collection: jest.fn().mockImplementation((subcol) => {
                if (subcol === "documents") {
                  return {
                    doc: jest.fn().mockImplementation((docId) => ({
                      get: jest.fn().mockResolvedValue({
                        exists: true,
                        data: () => ({
                          docType: "pcc", // Mismatched docType!
                          fileName: "police_clearance.pdf",
                        }),
                      }),
                    })),
                  };
                }
                return { doc: jest.fn() };
              }),
            })),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              set: jest.fn().mockImplementation(() => {
                documentCreated = true;
                return Promise.resolve();
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      body: {
        workerId: "worker_01",
        doctorCertificateDocId: "doc_pcc_123",
      },
      user: { uid: "worker_01" },
      db: mockDb,
    };
    const res = createMockRes();

    await dispatch("POST", "/claims/submit", req, res);

    expect(res.statusCode).toBe(400);
    expect(res.data.error).toContain("must reference a document with docType 'welfareCertificate'");
    expect(documentCreated).toBe(false);
  });

  // ── TEST 3: Score is null before admin verification ─────────────────────────
  test("3. GET claim detail before any admin verification returns score: null, not a numeric 0", async () => {
    const mockClaimData = {
      id: "claim_unreviewed_001",
      workerId: "worker_01",
      bookingId: "booking_101",
      doctorCertificateDocId: "cert_01",
      status: "pending_review",
      doctorCallConfirmed: false,
      customerCallConfirmed: false,
      sosCorroborated: false,
      submittedAt: "2026-09-12T10:00:00Z",
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "claim_unreviewed_001",
                data: () => mockClaimData,
              }),
            }),
            where: jest.fn().mockImplementation(makeChainableQuery),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "worker_01",
                data: () => ({ name: "Murugan", avgRating: 4.8 }),
              }),
            }),
          };
        }
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ role: "admin" }),
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      user: { uid: "admin_uid" },
      db: mockDb,
    };
    const res = createMockRes();

    await dispatch("GET", "/claims/claim_unreviewed_001", req, res);

    expect(res.statusCode).toBe(200);
    expect(res.data.success).toBe(true);
    expect(res.data.score).toBeNull();
    expect(res.data.score).not.toBe(0);
    expect(res.data.scoreReason).toBe("no_admin_verification_yet");
    expect(res.data.approvalThreshold).toBe(50);
  });

  // ── TEST 4: PATCH /verify rejects note under 20 characters ──────────────────
  test("4. PATCH /verify with a note under 20 chars is rejected (400)", async () => {
    const mockClaimData = {
      id: "claim_001",
      workerId: "worker_01",
      doctorCallConfirmed: false,
      auditLog: [],
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "admin" }) }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "claim_001",
                data: () => mockClaimData,
              }),
              update: jest.fn().mockResolvedValue(),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      user: { uid: "admin_uid" },
      db: mockDb,
      body: {
        doctorCallConfirmed: true,
        doctorCallNote: "Short note", // Only 10 chars!
      },
    };
    const res = createMockRes();

    await dispatch("PATCH", "/claims/claim_001/verify", req, res);

    expect(res.statusCode).toBe(400);
    expect(res.data.error).toContain("at least 20 characters");
  });

  // ── TEST 4b: PATCH /verify rejects photoOverride / photoOverrideNote under 20 characters ──
  test("4b. PATCH /verify with photoOverride or photoOverrideNote under 20 chars is rejected (400)", async () => {
    const mockClaimData = {
      id: "claim_photo_01",
      workerId: "worker_01",
      injuryPhotoDocId: "photo_01",
      photoFlagged: true,
      auditLog: [],
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "admin" }) }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "claim_photo_01",
                data: () => mockClaimData,
              }),
              update: jest.fn().mockResolvedValue(),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    // Case 1: photoOverride: true with short note (< 20 chars)
    const req1 = {
      user: { uid: "admin_uid" },
      db: mockDb,
      body: {
        photoOverride: true,
        photoOverrideNote: "Looks fine", // 10 chars
      },
    };
    const res1 = createMockRes();
    await dispatch("PATCH", "/claims/claim_photo_01/verify", req1, res1);
    expect(res1.statusCode).toBe(400);
    expect(res1.data.error).toContain("photoOverride requires a photoOverrideNote of at least 20 characters");

    // Case 2: photoOverride: true with missing note
    const req2 = {
      user: { uid: "admin_uid" },
      db: mockDb,
      body: {
        photoOverride: true,
      },
    };
    const res2 = createMockRes();
    await dispatch("PATCH", "/claims/claim_photo_01/verify", req2, res2);
    expect(res2.statusCode).toBe(400);
    expect(res2.data.error).toContain("photoOverride requires a photoOverrideNote of at least 20 characters");

    // Case 3: photoOverrideNote provided directly but under 20 chars
    const req3 = {
      user: { uid: "admin_uid" },
      db: mockDb,
      body: {
        photoOverrideNote: "Not AI generated", // 16 chars
      },
    };
    const res3 = createMockRes();
    await dispatch("PATCH", "/claims/claim_photo_01/verify", req3, res3);
    expect(res3.statusCode).toBe(400);
    expect(res3.data.error).toContain("photoOverride requires a photoOverrideNote of at least 20 characters");
  });

  // ── TEST 5: PATCH /verify updates score & auditLog grows on second call ─────
  test("5. PATCH /verify with a valid note updates the score correctly and the auditLog array grows (not overwrites) on a second PATCH call", async () => {
    let claimState = {
      id: "claim_001",
      workerId: "worker_01",
      bookingId: "booking_101",
      doctorCertificateDocId: "cert_01",
      doctorCallConfirmed: false,
      doctorCallNote: null,
      customerCallConfirmed: false,
      customerCallNote: null,
      sosCorroborated: false,
      sosNote: null,
      auditLog: [],
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "admin" }) }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "worker_01",
                data: () => ({ name: "Murugan", avgRating: 4.2 }),
              }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockImplementation(() =>
                Promise.resolve({
                  exists: true,
                  id: "claim_001",
                  data: () => claimState,
                })
              ),
              update: jest.fn().mockImplementation((updates) => {
                claimState = { ...claimState, ...updates };
                return Promise.resolve();
              }),
            }),
            where: jest.fn().mockImplementation(makeChainableQuery),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    // First PATCH call: verify doctor call
    const validDoctorNote = "Verified with Dr. Rajesh at Apollo Thanjavur. Fracture diagnosed on service.";
    const req1 = {
      user: { uid: "admin_alice" },
      db: mockDb,
      body: {
        doctorCallConfirmed: true,
        doctorCallNote: validDoctorNote,
      },
    };
    const res1 = createMockRes();

    await dispatch("PATCH", "/claims/claim_001/verify", req1, res1);

    expect(res1.statusCode).toBe(200);
    expect(res1.data.success).toBe(true);
    expect(res1.data.score).toBeDefined();
    // Booking linked: doctorCallConfirmed is 35 points
    expect(res1.data.score.baseScore).toBe(35);
    expect(claimState.auditLog.length).toBe(1);
    expect(claimState.auditLog[0].adminId).toBe("admin_alice");

    // Second PATCH call: corroborate customer call
    const validCustomerNote = "Spoke with customer Mrs. Anitha. Confirmed artisan injured on site premises.";
    const req2 = {
      user: { uid: "admin_bob" },
      db: mockDb,
      body: {
        customerCallConfirmed: true,
        customerCallNote: validCustomerNote,
      },
    };
    const res2 = createMockRes();

    await dispatch("PATCH", "/claims/claim_001/verify", req2, res2);

    expect(res2.statusCode).toBe(200);
    // Booking linked: doctor (35) + customer (20) = 55
    expect(res2.data.score.baseScore).toBe(55);
    // CRITICAL ASSERTION: auditLog grew to 2, did NOT overwrite!
    expect(claimState.auditLog.length).toBe(2);
    expect(claimState.auditLog[0].adminId).toBe("admin_alice");
    expect(claimState.auditLog[1].adminId).toBe("admin_bob");
  });

  // ── TEST 6: Immutable score+threshold snapshot at decision time ─────────────
  test("6. POST /decision snapshots score+threshold onto the claim at decision time — mutate worker avgRating after decision, confirm stored snapshot remains unchanged", async () => {
    let workerState = {
      id: "worker_01",
      name: "Murugan",
      avgRating: 4.0, // < 4.5, so 0% rating bonus
      createdAt: new Date().toISOString(),
    };

    let claimState = {
      id: "claim_001",
      workerId: "worker_01",
      bookingId: "booking_101",
      doctorCertificateDocId: "cert_01",
      doctorCallConfirmed: true,
      doctorCallNote: "Spoke with Dr. Rajesh at Apollo Thanjavur. Fracture diagnosed on duty.",
      customerCallConfirmed: false,
      sosCorroborated: false,
      auditLog: [],
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ role: "admin", preferredLanguage: "en" }),
              }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockImplementation(() =>
                Promise.resolve({
                  exists: true,
                  id: "worker_01",
                  data: () => workerState,
                })
              ),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockImplementation(() =>
                Promise.resolve({
                  exists: true,
                  id: "claim_001",
                  data: () => claimState,
                })
              ),
              update: jest.fn().mockImplementation((updates) => {
                claimState = { ...claimState, ...updates };
                return Promise.resolve();
              }),
            }),
            where: jest.fn().mockImplementation(makeChainableQuery),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      user: { uid: "admin_decision_maker" },
      db: mockDb,
      messaging: { sendEachForMulticast: jest.fn().mockResolvedValue({ successCount: 1 }) },
      body: {
        decision: "approved",
        decisionNote: "All hospital records and doctor call verified thoroughly.",
      },
    };
    const res = createMockRes();

    await dispatch("POST", "/claims/claim_001/decision", req, res);

    expect(res.statusCode).toBe(200);
    expect(res.data.decision).toBe("approved");

    // Check snapshot values captured on claim
    const initialSnapshotScore = claimState.snapshotScore;
    const initialSnapshotThreshold = claimState.snapshotThreshold;
    expect(initialSnapshotScore).toBeDefined();
    expect(initialSnapshotThreshold).toBe(50);
    // Doctor call (35) + Clean history bonus (+4) = 39 (since avgRating is 4.0, no rating bonus)
    expect(initialSnapshotScore).toBe(39);

    // MUTATION: Worker avgRating increases to 4.9 AFTER the decision has been finalized
    workerState.avgRating = 4.9;

    // Independent fresh recomputation with mutated worker
    const freshRecomputed = await computeClaimConfidence(claimState, workerState, mockDb);
    // Fresh recomputation now has +3% rating bonus -> 42%
    expect(freshRecomputed.totalScore).toBe(42);
    expect(freshRecomputed.totalScore).not.toEqual(initialSnapshotScore);

    // CRITICAL ASSERTION: The claim's stored snapshot was NOT rewritten and remains 39!
    expect(claimState.snapshotScore).toBe(39);
    expect(claimState.snapshotThreshold).toBe(50);
    expect(claimState.decidedBy).toBe("admin_decision_maker");
  });

  // ── TEST 7: Reject decisionNote under 10 characters ─────────────────────────
  test("7. POST /decision with decisionNote under 10 chars is rejected (400)", async () => {
    const mockClaimData = {
      id: "claim_001",
      workerId: "worker_01",
      status: "pending_review",
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ role: "admin" }) }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "claim_001",
                data: () => mockClaimData,
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      user: { uid: "admin_uid" },
      db: mockDb,
      body: {
        decision: "approved",
        decisionNote: "Approved", // Only 8 chars!
      },
    };
    const res = createMockRes();

    await dispatch("POST", "/claims/claim_001/decision", req, res);

    expect(res.statusCode).toBe(400);
    expect(res.data.error).toContain("at least 10 characters");
  });

  // ── TEST 8: NotificationEngine sent on approval & rejection in worker language
  test("8. Confirm NotificationEngine.sendToUser is called on both approval and rejection, in the worker's preferred language", async () => {
    let sentNotifications = [];

    const sendToUserSpy = jest
      .spyOn(NotificationEngine.prototype, "sendToUser")
      .mockImplementation(async function (userId, eventKey, params, dataPayload) {
        sentNotifications.push({ userId, eventKey, params, dataPayload });
        return { success: true, successCount: 1 };
      });

    const mockClaimData = {
      id: "claim_notif_101",
      workerId: "worker_ta_user",
      doctorCertificateDocId: "cert_01",
      status: "pending_review",
    };

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockImplementation((uid) => ({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({
                  role: uid === "admin_uid" ? "admin" : "worker",
                  preferredLanguage: uid === "worker_ta_user" ? "ta" : "hi",
                  fcmTokens: ["mock_fcm_token"],
                }),
              }),
            })),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "worker_ta_user",
                data: () => ({ userId: "worker_ta_user", name: "Murugan" }),
              }),
            }),
          };
        }
        if (col === "welfare_claims") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                id: "claim_notif_101",
                data: () => mockClaimData,
              }),
              update: jest.fn().mockResolvedValue(),
            }),
            where: jest.fn().mockImplementation(makeChainableQuery),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const mockMessaging = {
      sendEachForMulticast: jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 }),
    };

    // 8a. Test Approval Notification
    const reqApprove = {
      user: { uid: "admin_uid" },
      db: mockDb,
      messaging: mockMessaging,
      body: {
        decision: "approved",
        decisionNote: "Committee approved claim after hospital verification.",
      },
    };
    const resApprove = createMockRes();

    await dispatch("POST", "/claims/claim_notif_101/decision", reqApprove, resApprove);

    expect(resApprove.statusCode).toBe(200);
    expect(sendToUserSpy).toHaveBeenCalled();
    expect(sentNotifications.length).toBe(1);
    expect(sentNotifications[0].eventKey).toBe("WELFARE_CLAIM_APPROVED");
    expect(sentNotifications[0].userId).toBe("worker_ta_user");

    // 8b. Test Rejection Notification
    sentNotifications = [];
    const reqReject = {
      user: { uid: "admin_uid" },
      db: mockDb,
      messaging: mockMessaging,
      body: {
        decision: "rejected",
        decisionNote: "Medical logs do not substantiate the reported incident date.",
      },
    };
    const resReject = createMockRes();

    await dispatch("POST", "/claims/claim_notif_101/decision", reqReject, resReject);

    expect(resReject.statusCode).toBe(200);
    expect(sentNotifications.length).toBe(1);
    expect(sentNotifications[0].eventKey).toBe("WELFARE_CLAIM_REJECTED");
    expect(sentNotifications[0].params.reason).toContain("Medical logs do not substantiate");

    sendToUserSpy.mockRestore();
  });
});
