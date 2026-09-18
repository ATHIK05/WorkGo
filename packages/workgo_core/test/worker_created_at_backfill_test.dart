import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  group("Worker createdAt & joinedAt Backfill-Approximation Tests", () {
    test("selects the EARLIEST verification timestamp when aadhaar is earliest", () {
      final t1 = DateTime(2023, 1, 15, 10, 30); // Earliest
      final t2 = DateTime(2023, 3, 20, 14, 0);
      final t3 = DateTime(2023, 6, 5, 9, 15);

      final workerMap = <String, dynamic>{
        "id": "w_test_earliest_aadhaar",
        "name": "Mani Kandan",
        "skills": ["Plumbing"],
        "verificationDetails": {
          "aadhaarVerifiedAt": Timestamp.fromDate(t1),
          "livenessPassedAt": Timestamp.fromDate(t2),
          "pccReviewedAt": Timestamp.fromDate(t3),
        },
      };

      final worker = Worker.fromMap(workerMap, "w_test_earliest_aadhaar");
      expect(worker.createdAt, equals(t1));
      expect(worker.joinedAt, equals(t1));
    });

    test("selects the EARLIEST verification timestamp when liveness or pcc is earliest (scrambled order)", () {
      final t1 = DateTime(2023, 8, 10);
      final t2 = DateTime(2022, 11, 2); // Earliest across all
      final t3 = DateTime(2023, 2, 18);
      final t4 = DateTime(2024, 1, 1);

      final workerMap = <String, dynamic>{
        "id": "w_test_earliest_pcc",
        "name": "Adithya",
        "skills": ["Electrical"],
        "verificationDetails": {
          "aadhaarVerifiedAt": Timestamp.fromDate(t1),
          "pccReviewedAt": Timestamp.fromDate(t2), // Earliest
          "eshramVerifiedAt": Timestamp.fromDate(t3),
          "livenessPassedAt": Timestamp.fromDate(t4),
        },
      };

      final worker = Worker.fromMap(workerMap, "w_test_earliest_pcc");
      expect(worker.createdAt, equals(t2));
      expect(worker.joinedAt, equals(t2));
    });

    test("falls back to checkedInAt if verification timestamps are absent", () {
      final checkInTime = DateTime(2023, 7, 4, 8, 0);

      final workerMap = <String, dynamic>{
        "id": "w_test_checkin_fallback",
        "name": "Mohamed Athik",
        "skills": ["Carpentry"],
        "checkedInAt": Timestamp.fromDate(checkInTime),
      };

      final worker = Worker.fromMap(workerMap, "w_test_checkin_fallback");
      expect(worker.createdAt, equals(checkInTime));
      expect(worker.joinedAt, equals(checkInTime));
    });

    test("falls back to DateTime.now() when zero candidate timestamps exist", () {
      final before = DateTime.now();

      final workerMap = <String, dynamic>{
        "id": "w_test_zero_candidates",
        "name": "New Artisan",
        "skills": ["Painting"],
      };

      final worker = Worker.fromMap(workerMap, "w_test_zero_candidates");
      final after = DateTime.now();

      expect(worker.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(worker.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      expect(worker.joinedAt, equals(worker.createdAt));
    });

    test("explicit createdAt present skips backfill entirely", () {
      final explicitJoined = DateTime(2021, 5, 1, 12, 0);
      final laterVerification = DateTime(2023, 9, 15);

      final workerMap = <String, dynamic>{
        "id": "w_test_explicit_created",
        "name": "Veteran Artisan",
        "skills": ["Plumbing", "Electrical"],
        "createdAt": Timestamp.fromDate(explicitJoined),
        "verificationDetails": {
          "aadhaarVerifiedAt": Timestamp.fromDate(laterVerification),
          "livenessPassedAt": Timestamp.fromDate(laterVerification),
        },
      };

      final worker = Worker.fromMap(workerMap, "w_test_explicit_created");
      expect(worker.createdAt, equals(explicitJoined));
      expect(worker.joinedAt, equals(explicitJoined));
    });

    test("explicit joinedAt alias present skips backfill entirely", () {
      final explicitJoined = DateTime(2020, 3, 10);
      final laterVerification = DateTime(2022, 4, 1);

      final workerMap = <String, dynamic>{
        "id": "w_test_explicit_joined_alias",
        "name": "Senior Artisan",
        "skills": ["Masonry"],
        "joinedAt": Timestamp.fromDate(explicitJoined),
        "verificationDetails": {
          "aadhaarVerifiedAt": Timestamp.fromDate(laterVerification),
        },
      };

      final worker = Worker.fromMap(workerMap, "w_test_explicit_joined_alias");
      expect(worker.createdAt, equals(explicitJoined));
      expect(worker.joinedAt, equals(explicitJoined));
    });
  });
}
