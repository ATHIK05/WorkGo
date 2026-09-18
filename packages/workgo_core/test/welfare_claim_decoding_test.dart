import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  group("WelfareClaim & WelfareClaimDetailResponse Real JSON Fixture Decoding", () {
    // ── FIXTURE 1: Exact JSON payload from GET /api/welfare/claims/:claimId (corroborated) ──
    // Copied directly from live node execution of backend route and scoring engine
    const rawCorroboratedJson = r'''
{
  "success": true,
  "claim": {
    "id": "claim_2026_test_01",
    "workerId": "worker_tn_441",
    "bookingId": "booking_9921",
    "doctorCertificateDocId": "doc_cert_123",
    "injuryPhotoDocId": "doc_photo_456",
    "hospitalRecordDocId": "doc_hosp_789",
    "incidentDate": "2026-09-14T10:00:00.000Z",
    "description": "Artisan hand injured by mechanical saw while completing booked cabinet work.",
    "status": "pending_review",
    "doctorCallConfirmed": true,
    "doctorCallNote": "Spoke directly with Dr. Sivakumar at GH Erode. Laceration sutured.",
    "customerCallConfirmed": true,
    "customerCallNote": "Customer confirmed accident occurred during booked carpentry dispatch.",
    "sosCorroborated": false,
    "sosNote": null,
    "photoOverride": false,
    "photoOverrideNote": null,
    "photoFlagged": false,
    "auditLog": [
      {
        "adminId": "admin_root",
        "timestamp": "2026-09-14T11:00:00.000Z",
        "changes": {
          "doctorCallConfirmed": true
        }
      }
    ],
    "verificationLog": [
      {
        "type": "doctorCall",
        "note": "Spoke directly with Dr. Sivakumar at GH Erode. Laceration sutured.",
        "adminId": "admin_root",
        "timestamp": "2026-09-14T11:00:00.000Z"
      }
    ],
    "submittedAt": "2026-09-14T10:30:00.000Z",
    "submittedBy": "worker_tn_441"
  },
  "worker": {
    "id": "worker_tn_441",
    "name": "Murugan K",
    "org": "Erode Carpentry Guild",
    "phone": "+919876543210",
    "avgRating": 4.8,
    "createdAt": "2025-01-01T00:00:00.000Z"
  },
  "score": {
    "baseScore": 88,
    "trustBonus": 6,
    "totalScore": 94,
    "weightTableUsed": "booking",
    "factors": {
      "doctorCallConfirmed": true,
      "hospitalRecordProvided": true,
      "sosCorroborated": false,
      "photoPassesTamperCheck": true,
      "customerCallConfirmed": true
    },
    "photoFlaggedForReview": false
  },
  "scoreReason": null,
  "approvalThreshold": 50
}
''';

    // ── FIXTURE 2: Exact JSON payload from GET /api/welfare/claims/:claimId (unreviewed) ──
    const rawUnreviewedJson = r'''
{
  "success": true,
  "claim": {
    "id": "claim_2026_test_02",
    "workerId": "worker_tn_442",
    "bookingId": null,
    "doctorCertificateDocId": "doc_cert_999",
    "injuryPhotoDocId": null,
    "hospitalRecordDocId": null,
    "incidentDate": "2026-09-14T08:00:00.000Z",
    "description": "Fell while loading supplies at depot.",
    "status": "pending_review",
    "doctorCallConfirmed": false,
    "doctorCallNote": null,
    "customerCallConfirmed": false,
    "customerCallNote": null,
    "sosCorroborated": false,
    "sosNote": null,
    "photoOverride": false,
    "photoOverrideNote": null,
    "photoFlagged": false,
    "auditLog": [],
    "verificationLog": [],
    "submittedAt": "2026-09-14T08:30:00.000Z",
    "submittedBy": "worker_tn_442"
  },
  "worker": {
    "id": "worker_tn_442",
    "name": "Venkatesh R",
    "org": "Salem Weavers Guild",
    "phone": "+919811223344",
    "avgRating": 4.2,
    "createdAt": "2025-06-01T00:00:00.000Z"
  },
  "score": null,
  "scoreReason": "no_admin_verification_yet",
  "approvalThreshold": 75
}
''';

    // ── FIXTURE 3: Exact JSON payload after decision is recorded (Step 4e snapshot) ──
    const rawDecidedJson = r'''
{
  "success": true,
  "claim": {
    "id": "claim_2026_test_03",
    "workerId": "worker_tn_443",
    "bookingId": "booking_7711",
    "doctorCertificateDocId": "doc_cert_555",
    "injuryPhotoDocId": "doc_photo_555",
    "hospitalRecordDocId": "doc_hosp_555",
    "incidentDate": "2026-09-14T09:00:00.000Z",
    "description": "On-duty chemical burn on arm during painting job.",
    "status": "approved",
    "doctorCallConfirmed": true,
    "doctorCallNote": "Confirmed second-degree burn treated at Coimbatore ESI Hospital.",
    "customerCallConfirmed": true,
    "customerCallNote": "Customer confirmed incident occurred on paint site premises.",
    "sosCorroborated": false,
    "sosNote": null,
    "photoOverride": false,
    "photoOverrideNote": null,
    "photoFlagged": false,
    "auditLog": [
      {
        "action": "decision",
        "decision": "approved",
        "decisionNote": "Medical and customer evidence verified in full. Disbursing ₹25,000 relief.",
        "adminId": "admin_chief",
        "timestamp": "2026-09-14T11:45:00.000Z",
        "snapshotScore": 94,
        "snapshotThreshold": 50
      }
    ],
    "verificationLog": [
      {
        "type": "doctorCall",
        "note": "Confirmed second-degree burn treated at Coimbatore ESI Hospital.",
        "adminId": "admin_chief",
        "timestamp": "2026-09-14T11:30:00.000Z"
      }
    ],
    "submittedAt": "2026-09-14T09:30:00.000Z",
    "submittedBy": "worker_tn_443",
    "decidedBy": "admin_chief",
    "decidedAt": "2026-09-14T11:45:00.000Z",
    "decisionNote": "Medical and customer evidence verified in full. Disbursing ₹25,000 relief.",
    "snapshotScore": 94,
    "snapshotThreshold": 50,
    "scoreSnapshot": {
      "totalScore": 94,
      "baseScore": 88,
      "trustBonus": 6,
      "approvalThreshold": 50,
      "decidedAt": "2026-09-14T11:45:00.000Z",
      "decidedBy": "admin_chief"
    }
  },
  "worker": {
    "id": "worker_tn_443",
    "name": "Karthik S"
  },
  "score": {
    "baseScore": 88,
    "trustBonus": 6,
    "totalScore": 94,
    "weightTableUsed": "booking",
    "factors": {
      "doctorCallConfirmed": true,
      "hospitalRecordProvided": true,
      "sosCorroborated": false,
      "photoPassesTamperCheck": true,
      "customerCallConfirmed": true
    },
    "photoFlaggedForReview": false
  },
  "scoreReason": null,
  "approvalThreshold": 50
}
''';

    test("1. Decodes real backend GET /claims/:id fixture into non-default WelfareClaim and score properties", () {
      final decoded = json.decode(rawCorroboratedJson) as Map<String, dynamic>;
      final response = WelfareClaimDetailResponse.fromMap(decoded);

      expect(response.success, isTrue);

      // Verify Claim parsing matches backend field names exactly (no defaults!)
      final claim = response.claim;
      expect(claim.id, equals("claim_2026_test_01"));
      expect(claim.workerId, equals("worker_tn_441"));
      expect(claim.bookingId, equals("booking_9921"));
      expect(claim.isBookingLinked, isTrue);
      expect(claim.doctorCertificateDocId, equals("doc_cert_123"));
      expect(claim.injuryPhotoDocId, equals("doc_photo_456"));
      expect(claim.hospitalRecordDocId, equals("doc_hosp_789"));
      expect(claim.description, equals("Artisan hand injured by mechanical saw while completing booked cabinet work."));
      expect(claim.status, equals("pending_review"));
      expect(claim.isPending, isTrue);
      expect(claim.isApproved, isFalse);

      // Verify Admin Checkbox & Note parsing
      expect(claim.doctorCallConfirmed, isTrue);
      expect(claim.doctorCallNote, equals("Spoke directly with Dr. Sivakumar at GH Erode. Laceration sutured."));
      expect(claim.customerCallConfirmed, isTrue);
      expect(claim.customerCallNote, equals("Customer confirmed accident occurred during booked carpentry dispatch."));
      expect(claim.sosCorroborated, isFalse);
      expect(claim.sosNote, isNull);
      expect(claim.photoOverride, isFalse);
      expect(claim.photoFlagged, isFalse);

      // Verify Audit & Verification log parsing
      expect(claim.auditLog.length, equals(1));
      expect(claim.auditLog.first["adminId"], equals("admin_root"));
      expect(claim.verificationLog.length, equals(1));
      expect(claim.verificationLog.first.type, equals("doctorCall"));
      expect(claim.verificationLog.first.adminId, equals("admin_root"));
      expect(claim.verificationLog.first.note, contains("Dr. Sivakumar"));

      // Verify Score object parsing (matching welfare_scoring.js exactly)
      expect(response.score, isNotNull);
      final score = response.score!;
      expect(score.baseScore, equals(88));
      expect(score.trustBonus, equals(6));
      expect(score.totalScore, equals(94));
      expect(score.weightTableUsed, equals("booking"));
      expect(score.photoFlaggedForReview, isFalse);

      // Verify individual corroboration factors
      expect(score.factors.doctorCallConfirmed, isTrue);
      expect(score.factors.hospitalRecordProvided, isTrue);
      expect(score.factors.customerCallConfirmed, isTrue);
      expect(score.factors.photoPassesTamperCheck, isTrue);
      expect(score.factors.sosCorroborated, isFalse);

      // Verify threshold & recommendation
      expect(response.approvalThreshold, equals(50));
      expect(response.scoreReason, isNull);
      expect(response.meetsApprovalThreshold, isTrue); // 94 >= 50
    });

    test("2. Decodes unreviewed claim with score: null and scoreReason: 'no_admin_verification_yet'", () {
      final decoded = json.decode(rawUnreviewedJson) as Map<String, dynamic>;
      final response = WelfareClaimDetailResponse.fromMap(decoded);

      expect(response.success, isTrue);
      expect(response.claim.id, equals("claim_2026_test_02"));
      expect(response.claim.bookingId, isNull);
      expect(response.claim.isBookingLinked, isFalse);
      expect(response.claim.description, equals("Fell while loading supplies at depot."));
      expect(response.claim.doctorCallConfirmed, isFalse);

      // Score must be explicitly null
      expect(response.score, isNull);
      expect(response.scoreReason, equals("no_admin_verification_yet"));
      expect(response.approvalThreshold, equals(75)); // Tier 2 worker
      expect(response.meetsApprovalThreshold, isFalse);
    });

    test("3. Decodes decided claim with immutable snapshotScore and snapshotThreshold", () {
      final decoded = json.decode(rawDecidedJson) as Map<String, dynamic>;
      final response = WelfareClaimDetailResponse.fromMap(decoded);

      final claim = response.claim;
      expect(claim.status, equals("approved"));
      expect(claim.isApproved, isTrue);
      expect(claim.isPending, isFalse);
      expect(claim.decidedBy, equals("admin_chief"));
      expect(claim.decidedAt, isNotNull);
      expect(claim.decisionNote, contains("Disbursing ₹25,000 relief."));
      expect(claim.snapshotScore, equals(94));
      expect(claim.snapshotThreshold, equals(50));
      expect(claim.scoreSnapshot, isNotNull);
      expect(claim.scoreSnapshot!["totalScore"], equals(94));
      expect(claim.scoreSnapshot!["approvalThreshold"], equals(50));
    });

    test("4. Decodes direct Firestore document written by POST /claims/:id/decision into WelfareClaim", () {
      const rawFirestoreDecisionDoc = r'''
{
  "id": "claim_2026_test_decision",
  "workerId": "worker_tn_772",
  "bookingId": "booking_5512",
  "doctorCertificateDocId": "doc_cert_333",
  "injuryPhotoDocId": "doc_photo_333",
  "hospitalRecordDocId": "doc_hosp_333",
  "incidentDate": "2026-09-14T08:00:00.000Z",
  "description": "Hand laceration sustained during on-site metal fabrication dispatch.",
  "status": "approved",
  "doctorCallConfirmed": true,
  "doctorCallNote": "Spoke directly with Dr. Ezhil at Salem Ortho Center. Laceration sutured.",
  "customerCallConfirmed": true,
  "customerCallNote": "Customer confirmed mechanical failure occurred during active booking.",
  "sosCorroborated": false,
  "sosNote": null,
  "photoOverride": false,
  "photoOverrideNote": null,
  "photoFlagged": false,
  "auditLog": [
    {
      "adminId": "admin_officer",
      "timestamp": "2026-09-14T09:00:00.000Z",
      "changes": {
        "doctorCallConfirmed": true
      }
    },
    {
      "action": "decision",
      "decision": "approved",
      "decisionNote": "Comprehensive corroboration confirmed by doctor call and customer dispatch confirmation. Micro-insurance payout approved.",
      "adminId": "admin_super_01",
      "timestamp": "2026-09-14T09:45:00.000Z",
      "snapshotScore": 94,
      "snapshotThreshold": 50
    }
  ],
  "verificationLog": [
    {
      "type": "doctorCall",
      "note": "Spoke directly with Dr. Ezhil at Salem Ortho Center. Laceration sutured.",
      "adminId": "admin_officer",
      "timestamp": "2026-09-14T09:00:00.000Z"
    }
  ],
  "submittedAt": "2026-09-14T08:15:00.000Z",
  "submittedBy": "worker_tn_772",
  "decidedBy": "admin_super_01",
  "decidedAt": "2026-09-14T09:45:00.000Z",
  "decisionNote": "Comprehensive corroboration confirmed by doctor call and customer dispatch confirmation. Micro-insurance payout approved.",
  "snapshotScore": 94,
  "snapshotThreshold": 50,
  "scoreAtDecision": 94,
  "thresholdAtDecision": 50,
  "scoreSnapshot": {
    "totalScore": 94,
    "baseScore": 88,
    "trustBonus": 6,
    "approvalThreshold": 50,
    "decidedAt": "2026-09-14T09:45:00.000Z",
    "decidedBy": "admin_super_01"
  }
}
''';
      final map = json.decode(rawFirestoreDecisionDoc) as Map<String, dynamic>;
      final claim = WelfareClaim.fromMap(map);

      expect(claim.id, equals("claim_2026_test_decision"));
      expect(claim.workerId, equals("worker_tn_772"));
      expect(claim.bookingId, equals("booking_5512"));
      expect(claim.description, equals("Hand laceration sustained during on-site metal fabrication dispatch."));
      expect(claim.status, equals("approved"));
      expect(claim.isApproved, isTrue);
      expect(claim.isPending, isFalse);

      // Verify exact decision snapshot fields
      expect(claim.decidedBy, equals("admin_super_01"));
      expect(claim.decidedAt, equals(DateTime.parse("2026-09-14T09:45:00.000Z")));
      expect(claim.decisionNote, equals("Comprehensive corroboration confirmed by doctor call and customer dispatch confirmation. Micro-insurance payout approved."));
      expect(claim.snapshotScore, equals(94));
      expect(claim.snapshotThreshold, equals(50));

      expect(claim.scoreSnapshot, isNotNull);
      expect(claim.scoreSnapshot!["totalScore"], equals(94));
      expect(claim.scoreSnapshot!["baseScore"], equals(88));
      expect(claim.scoreSnapshot!["trustBonus"], equals(6));
      expect(claim.scoreSnapshot!["approvalThreshold"], equals(50));
      expect(claim.scoreSnapshot!["decidedBy"], equals("admin_super_01"));
      expect(claim.scoreSnapshot!["decidedAt"], equals("2026-09-14T09:45:00.000Z"));

      // Verify round-trip back into Firestore map maintains all exact keys
      final outputMap = claim.toFirestore();
      expect(outputMap["bookingId"], equals("booking_5512"));
      expect(outputMap["description"], equals("Hand laceration sustained during on-site metal fabrication dispatch."));
      expect(outputMap["snapshotScore"], equals(94));
      expect(outputMap["snapshotThreshold"], equals(50));
      expect(outputMap["decidedBy"], equals("admin_super_01"));
    });
  });
}

