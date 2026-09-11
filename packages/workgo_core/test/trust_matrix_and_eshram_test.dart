import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

Worker _buildWorker({
  required String id,
  String? phone,
  int trustScore = 0,
  VerificationDetails? vd,
}) {
  return Worker(
    id: id,
    userId: 'u_$id',
    name: 'Artisan $id',
    skills: const ['Carpentry'],
    experienceYears: 3,
    verificationStatus: VerificationStatus.approved,
    phoneForCalling: phone,
    trustScore: trustScore,
    verificationDetails: vd,
  );
}

void main() {
  group('5-Signal Trust Matrix & Worker Model Tests', () {
    test('trustSignalCount calculates correctly from individual verification signals', () {
      // 0 signals
      final w0 = _buildWorker(id: 'w0');
      expect(w0.trustSignalCount, 0);
      expect(w0.isRadarEligible, false);
      expect(w0.trustBadgeLabel, '');

      // 1 signal: Phone OTP only
      final w1 = _buildWorker(
        id: 'w1',
        phone: '+919876543210',
      );
      expect(w1.trustSignalCount, 1);
      expect(w1.isRadarEligible, false);

      // 2 signals: Phone + Aadhaar QR
      final w2 = _buildWorker(
        id: 'w2',
        phone: '+919876543210',
        vd: const VerificationDetails(
          aadhaarQrVerified: true,
          aadhaarDistrict: 'Chennai',
        ),
      );
      expect(w2.trustSignalCount, 2);
      expect(w2.isRadarEligible, false);

      // 3 signals: Phone + Aadhaar + Liveness (Radar Eligible)
      final w3 = _buildWorker(
        id: 'w3',
        phone: '+919876543210',
        vd: VerificationDetails(
          aadhaarQrVerified: true,
          livenessPassedAt: DateTime(2026, 1, 1),
        ),
      );
      expect(w3.trustSignalCount, 3);
      expect(w3.isRadarEligible, true);
      expect(w3.trustBadgeLabel, 'verified_badge');

      // 4 signals: Phone + Aadhaar + Liveness + e-Shram
      final w4 = _buildWorker(
        id: 'w4',
        phone: '+919876543210',
        vd: VerificationDetails(
          aadhaarQrVerified: true,
          livenessPassedAt: DateTime(2026, 1, 1),
          eshramUan: '123456789012',
          eshramTrade: 'Electrician',
        ),
      );
      expect(w4.trustSignalCount, 4);
      expect(w4.isRadarEligible, true);
      expect(w4.trustBadgeLabel, 'verified_badge');

      // 5 signals: Phone + Aadhaar + Liveness + e-Shram + PCC (Co-op Pro)
      final w5 = _buildWorker(
        id: 'w5',
        phone: '+919876543210',
        trustScore: 5,
        vd: VerificationDetails(
          aadhaarQrVerified: true,
          livenessPassedAt: DateTime(2026, 1, 1),
          eshramUan: '123456789012',
          eshramTrade: 'Electrician',
          pccDocumentId: 'pcc_doc_001',
          pccReviewedAt: DateTime(2026, 1, 1),
        ),
      );
      expect(w5.trustSignalCount, 5);
      expect(w5.isRadarEligible, true);
      expect(w5.trustBadgeLabel, 'coop_pro_badge');
    });

    test('VerificationDetails.fromMap parses e-Shram and QR fields correctly', () {
      final map = {
        'aadhaarQrVerified': true,
        'aadhaarDistrict': 'Coimbatore',
        'eshramUan': '987654321098',
        'eshramTrade': 'Plumber',
        'eshramDistrict': 'Coimbatore',
        'eshramNameMatch': true,
        'eshramVerifiedAt': '2026-03-01T10:00:00.000Z',
      };

      final vd = VerificationDetails.fromMap(map);
      expect(vd.aadhaarQrVerified, true);
      expect(vd.aadhaarDistrict, 'Coimbatore');
      expect(vd.eshramTrade, 'Plumber');
      expect(vd.eshramUan, '987654321098');
      expect(vd.eshramDistrict, 'Coimbatore');
      expect(vd.eshramNameMatch, true);
      expect(vd.eshramVerifiedAt, isNotNull);

      final worker = _buildWorker(
        id: 'w_test_100',
        phone: '+919876543210',
        trustScore: 5,
        vd: vd,
      );
      expect(worker.trustScore, 5);
      expect(worker.verificationDetails?.eshramTrade, 'Plumber');
      expect(worker.isRadarEligible, true);
      expect(worker.trustBadgeLabel, 'coop_pro_badge');
    });

    test('AppUser serializes and deserializes trustScore correctly', () {
      final user = AppUser(
        uid: 'u_101',
        email: 'ravi@example.com',
        displayName: 'Ravi Kumar',
        role: UserRole.worker,
        region: 'Tamil Nadu',
        phoneNumber: '+919876543210',
        trustScore: 4,
      );

      final map = user.toMap();
      expect(map['trustScore'], 4);

      final revived = AppUser.fromMap(map);
      expect(revived.trustScore, 4);
      expect(revived.uid, 'u_101');
      expect(revived.displayName, 'Ravi Kumar');

      final copy = revived.copyWith(trustScore: 5);
      expect(copy.trustScore, 5);
    });
  });
}
