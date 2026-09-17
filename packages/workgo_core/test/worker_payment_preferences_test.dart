import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('Worker Payment Preferences & Cash on Delivery Tests', () {
    test('Worker defaults acceptsCash to false', () {
      final worker = Worker(
        id: 'w1',
        userId: 'u1',
        name: 'Ramesh Carpenter',
        skills: ['Carpenter'],
        experienceYears: 5,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 4.8,
        totalRatings: 10,
        totalReviews: 8,
        homesServiced: 20,
        distanceKm: 2.0,
      );

      expect(worker.acceptsCash, isFalse);
      expect(worker.hasValidUpi, isFalse);
      expect(worker.canAcceptPayments, isFalse);
    });

    test('canAcceptPayments is true when hasValidUpi is present', () {
      final worker = Worker(
        id: 'w2',
        userId: 'u2',
        name: 'Suresh Electrician',
        skills: ['Electrician'],
        experienceYears: 7,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 4.9,
        totalRatings: 50,
        totalReviews: 45,
        homesServiced: 80,
        distanceKm: 1.5,
        upiId: 'suresh@okhdfcbank',
        acceptsCash: false,
      );

      expect(worker.hasValidUpi, isTrue);
      expect(worker.acceptsCash, isFalse);
      expect(worker.canAcceptPayments, isTrue);
    });

    test('canAcceptPayments is true when acceptsCash is enabled without UPI', () {
      final worker = Worker(
        id: 'w3',
        userId: 'u3',
        name: 'Murugan Plumber',
        skills: ['Plumber'],
        experienceYears: 4,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 4.7,
        totalRatings: 30,
        totalReviews: 25,
        homesServiced: 40,
        distanceKm: 3.2,
        upiId: null,
        acceptsCash: true,
      );

      expect(worker.hasValidUpi, isFalse);
      expect(worker.acceptsCash, isTrue);
      expect(worker.canAcceptPayments, isTrue);
    });

    test('acceptsCash and upiId serialize cleanly to/from map', () {
      final worker = Worker(
        id: 'w4',
        userId: 'u4',
        name: 'Anand Painter',
        skills: ['Painter'],
        experienceYears: 6,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 5.0,
        totalRatings: 100,
        totalReviews: 90,
        homesServiced: 150,
        distanceKm: 1.0,
        upiId: 'anand@ybl',
        acceptsCash: true,
      );

      final map = worker.toFirestore();
      expect(map['upiId'], equals('anand@ybl'));
      expect(map['acceptsCash'], isTrue);

      final copied = worker.copyWith(acceptsCash: false);
      expect(copied.acceptsCash, isFalse);
      expect(copied.upiId, equals('anand@ybl'));
      expect(copied.canAcceptPayments, isTrue);
    });
  });
}
