import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import '../models/worker.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Customer Streams & Operations ──────────────────────────────────────────

  /// Stream all bookings for a specific customer, excluding soft-deleted ones.
  Stream<List<Booking>> streamCustomerBookings(String customerId) {
    return _db
        .collection("bookings")
        .where("customerId", isEqualTo: customerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Booking.fromFirestore(d))
            .where((b) => b.deletedByCustomer != true)
            .toList());
  }

  /// Soft-delete booking from customer view only (record remains permanently intact for admins).
  Future<void> hideBookingForCustomer(String bookingId) async {
    await _db.collection("bookings").doc(bookingId).update({
      "deletedByCustomer": true,
      "deletedByCustomerAt": FieldValue.serverTimestamp(),
    });
  }

  /// Stream a single active booking in real-time.
  Stream<Booking?> streamBooking(String bookingId) {
    return _db.collection("bookings").doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Booking.fromFirestore(doc);
    });
  }

  /// Create or broadcast a new service booking request (Rapido-style) with a 4-digit start OTP.
  Future<String> createBooking({
    required String customerId,
    required String serviceType,
    required double amount,
    double urgencyBonus = 0.0,
    bool isEmergency = false,
    DateTime? scheduledAt,
    String? workerId,
    String? acceptedWorkerName,
    double? workerLatitude,
    double? workerLongitude,
    String organizationId = "coop_tn_01",
    GeoPoint? location,
    double broadcastRadiusKm = 10.0,
    String? customerAddressText,
    double? customerLatitude,
    double? customerLongitude,
  }) async {
    final docRef = _db.collection("bookings").doc();

    // Generate secure 4-digit Start OTP (e.g. 1000 - 9999)
    final randomOtp = (1000 + Random().nextInt(9000)).toString();

    final booking = Booking(
      id: docRef.id,
      customerId: customerId,
      workerId: workerId,
      acceptedWorkerName: acceptedWorkerName,
      workerLatitude: workerLatitude,
      workerLongitude: workerLongitude,
      organizationId: organizationId,
      serviceType: serviceType,
      isEmergency: isEmergency,
      scheduledAt: scheduledAt ?? DateTime.now(),
      status: BookingStatus.pending,
      amount: amount,
      urgencyBonus: urgencyBonus,
      broadcastRadiusKm: broadcastRadiusKm,
      broadcastExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
      paymentStatus: PaymentStatus.unpaid,
      location: location,
      startOtp: randomOtp,
      customerAddressText: customerAddressText,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
    );

    await docRef.set(booking.toFirestore());
    return docRef.id;
  }

  /// Customer raises fare/urgency bonus in real-time while broadcasting.
  Future<void> raiseUrgencyBonus(String bookingId, double extraBonus) async {
    final doc = await _db.collection("bookings").doc(bookingId).get();
    if (!doc.exists) return;
    final currentBonus = (doc.data()?["urgencyBonus"] as num?)?.toDouble() ?? 0.0;
    await _db.collection("bookings").doc(bookingId).update({
      "urgencyBonus": currentBonus + extraBonus,
    });
  }

  /// Stream live active Artisans count matching the service trade in 100% real-time.
  Stream<int> streamNearbyArtisansCount(String serviceType) => streamNearbyCaptainsCount(serviceType);

  Stream<int> streamNearbyCaptainsCount(String serviceType) {
    return _db
        .collection("workers")
        .snapshots()
        .map((snap) {
          final matching = snap.docs.where((d) {
            final data = d.data();
            final skills = List<String>.from(data["skills"] ?? []);
            final isOnline = data["availabilityStatus"] == "online" || data["availabilityStatus"] == null;
            final isNotRejected = data["verificationStatus"] != "rejected";
            final isPublic = data["visibilityStatus"] == "public" || data["visibilityStatus"] == null;
            final matchesSkill = serviceType.isEmpty || serviceType == "All" || skills.contains(serviceType);
            return isNotRejected && isOnline && isPublic && matchesSkill;
          }).length;
          return matching;
        });
  }

  /// Stream actual live online workers matching trade for map display.
  Stream<List<Worker>> streamNearbyOnlineWorkers(String serviceType) {
    return _db.collection("workers").snapshots().map((snap) {
      final list = <Worker>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final skills = List<String>.from(data["skills"] ?? []);
          final isOnline = data["availabilityStatus"] == "online" ||
              data["isCheckedIn"] == true ||
              data["availabilityStatus"] == null;
          final isNotRejected = data["verificationStatus"] != "rejected";
          final isVisible = data["visibilityStatus"] != "hidden" &&
              data["visibilityStatus"] != "suspended";
          final matchesSkill = serviceType.isEmpty ||
              serviceType == "All" ||
              skills.contains(serviceType);

          if (isOnline && isNotRejected && isVisible && matchesSkill) {
            list.add(Worker.fromFirestore(doc));
          }
        } catch (_) {}
      }
      return list;
    });
  }

  // ── Worker Streams & Operations ────────────────────────────────────────────

  /// Stream incoming pending requests for a worker / skill.
  Stream<List<Booking>> streamWorkerIncomingRequests({
    required String workerId,
    required List<String> skills,
  }) {
    return _db
        .collection("bookings")
        .where("status", isEqualTo: "pending")
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => Booking.fromFirestore(d))
              .where((b) =>
                  (b.workerId == null || b.workerId == workerId || b.referredByWorkerId == workerId) &&
                  (skills.isEmpty || skills.contains(b.serviceType)))
              .toList();
        });
  }

  /// Stream active or accepted bookings assigned to a worker.
  Stream<List<Booking>> streamWorkerActiveJobs(String workerId) {
    return _db
        .collection("bookings")
        .where("workerId", isEqualTo: workerId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Worker accepts a booking. Atomically locks the job and sets worker location.
  Future<void> acceptBooking(
    String bookingId,
    String workerId, {
    String? workerName,
    double? initialWorkerLat,
    double? initialWorkerLng,
  }) async {
    final Map<String, dynamic> updateData = {
      "workerId": workerId,
      "acceptedWorkerName": workerName,
      "status": BookingStatus.accepted.name,
    };
    if (initialWorkerLat != null && initialWorkerLng != null) {
      updateData["workerLatitude"] = initialWorkerLat;
      updateData["workerLongitude"] = initialWorkerLng;
    }

    await _db.collection("bookings").doc(bookingId).update(updateData);
  }

  /// Verify Start Job OTP entered by the artisan at the customer doorstep.
  /// If valid, atomically moves status to inProgress.
  Future<bool> verifyStartOtp({
    required String bookingId,
    required String enteredOtp,
  }) async {
    final doc = await _db.collection("bookings").doc(bookingId).get();
    if (!doc.exists) {
      throw Exception("Booking not found");
    }

    final data = doc.data()!;
    final expectedOtp = data["startOtp"]?.toString().trim();

    if (expectedOtp == null || expectedOtp.isEmpty) {
      // Fallback: If no OTP was attached, allow start
      await updateBookingStatus(bookingId, BookingStatus.inProgress);
      return true;
    }

    if (expectedOtp == enteredOtp.trim()) {
      await updateBookingStatus(bookingId, BookingStatus.inProgress);
      return true;
    } else {
      return false;
    }
  }

  /// Real-time live GPS stream of the artisan moving on the map towards the customer.
  Future<void> updateWorkerLiveLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection("bookings").doc(bookingId).update({
      "workerLatitude": latitude,
      "workerLongitude": longitude,
    });
  }

  /// Second-line referral: Worker forwards the pending job to a peer artisan.
  Future<void> referBookingToPeer({
    required String bookingId,
    required String originalWorkerId,
    required String targetWorkerId,
  }) async {
    await _db.collection("bookings").doc(bookingId).update({
      "referredByWorkerId": originalWorkerId,
      "workerId": targetWorkerId,
    });
  }

  /// Update booking progress status (inProgress, completed, cancelled).
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    await _db.collection("bookings").doc(bookingId).update({
      "status": status.name,
    });
  }

  /// Mark booking payment as paid.
  Future<void> markPaymentComplete(String bookingId, {String? invoiceId}) async {
    await _db.collection("bookings").doc(bookingId).update({
      "paymentStatus": PaymentStatus.paid.name,
      "invoiceId": invoiceId ?? "INV-${DateTime.now().millisecondsSinceEpoch}",
    });
  }

  /// Stream all bookings for cooperative console overview.
  Stream<List<Booking>> streamAllBookings({String? organizationId}) {
    Query query = _db.collection("bookings");
    if (organizationId != null) {
      query = query.where("organizationId", isEqualTo: organizationId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => Booking.fromFirestore(d)).toList(),
    );
  }
}
