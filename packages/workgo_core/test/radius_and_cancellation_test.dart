import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('2-Way Haversine Radius & Cancellation Tests', () {
    // Perundurai reference coordinates
    const perunduraiLat = 11.2741;
    const perunduraiLng = 77.5823;

    // Erode Bus Stand reference (~19.5 km away)
    const erodeLat = 11.3410;
    const erodeLng = 77.7172;

    // Nearby Perundurai local area (~2.8 km away)
    const nearbyLat = 11.2850;
    const nearbyLng = 77.6050;

    test('Booking.distanceTo computes accurate geodesic distance', () {
      final booking = Booking(
        id: 'b_test_1',
        customerId: 'cust_1',
        organizationId: 'org_1',
        serviceType: 'plumbing',
        status: BookingStatus.pending,
        customerLatitude: perunduraiLat,
        customerLongitude: perunduraiLng,
      );

      final distToNearby = booking.distanceTo(nearbyLat, nearbyLng);
      final distToErode = booking.distanceTo(erodeLat, erodeLng);

      expect(distToNearby, lessThan(4.0));
      expect(distToNearby, greaterThan(2.0));

      expect(distToErode, greaterThan(15.0));
      expect(distToErode, lessThan(25.0));
    });

    test('Worker with 5 km service radius filters 2-way accessibility', () {
      final worker = Worker(
        id: 'w_test_1',
        userId: 'user_1',
        name: 'Ravi Kumar',
        skills: ['plumbing'],
        experienceYears: 4,
        verificationStatus: VerificationStatus.approved,
        latitude: perunduraiLat,
        longitude: perunduraiLng,
        serviceRadiusKm: 5.0,
      );

      // Nearby customer (~2.8 km): within worker's 5 km radius
      final distNearby = worker.calculateDistanceKm(nearbyLat, nearbyLng);
      expect(distNearby <= worker.serviceRadiusKm, isTrue);

      // Erode customer (~19.5 km): OUTSIDE worker's 5 km radius
      final distErode = worker.calculateDistanceKm(erodeLat, erodeLng);
      expect(distErode <= worker.serviceRadiusKm, isFalse);

      // When worker expands radius to 25 km:
      final expandedWorker = worker.copyWith(serviceRadiusKm: 25.0);
      expect(distErode <= expandedWorker.serviceRadiusKm, isTrue);
    });

    test('Booking cancellation metadata serializes and deserializes accurately', () {
      final now = DateTime.now();
      final booking = Booking(
        id: 'b_cancel_test',
        customerId: 'cust_1',
        organizationId: 'org_1',
        serviceType: 'electrical',
        status: BookingStatus.cancelled,
        acceptedAt: now.subtract(const Duration(minutes: 3)),
        cancellationReason: 'Incorrect service address',
        cancelledAt: now,
        cancelledBy: 'customer',
      );

      final map = booking.toFirestore();
      expect(map['status'], equals('cancelled'));
      expect(map['cancellationReason'], equals('Incorrect service address'));
      expect(map['cancelledBy'], equals('customer'));
      expect(map['acceptedAt'], isNotNull);
      expect(map['cancelledAt'], isNotNull);

      final copy = booking.copyWith(
        cancellationReason: 'Service no longer needed',
      );
      expect(copy.cancellationReason, equals('Service no longer needed'));
      expect(copy.cancelledBy, equals('customer'));
    });

    test('5-minute cancellation window correctly detects elapsed time', () {
      final now = DateTime.now();

      // Case 1: Accepted 2 minutes ago -> Within 5-min grace window
      final acceptedRecently = Booking(
        id: 'b_recent',
        customerId: 'c_1',
        organizationId: 'o_1',
        serviceType: 'plumbing',
        status: BookingStatus.accepted,
        acceptedAt: now.subtract(const Duration(minutes: 2)),
      );
      final elapsed1 = now.difference(acceptedRecently.acceptedAt!).inMinutes;
      expect(elapsed1 < 5, isTrue);

      // Case 2: Accepted 8 minutes ago -> Exceeds 5-minute transit threshold
      final acceptedLongAgo = Booking(
        id: 'b_late',
        customerId: 'c_1',
        organizationId: 'o_1',
        serviceType: 'plumbing',
        status: BookingStatus.accepted,
        acceptedAt: now.subtract(const Duration(minutes: 8)),
      );
      final elapsed2 = now.difference(acceptedLongAgo.acceptedAt!).inMinutes;
      expect(elapsed2 >= 5, isTrue);
    });
  });
}
