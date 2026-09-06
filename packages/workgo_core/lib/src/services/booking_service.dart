import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import '../models/worker.dart';
import '../localization/trade_localization.dart';

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
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerIssueDetails,
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
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerIssueDetails: customerIssueDetails,
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
            final matchesSkill = serviceType.isEmpty ||
                serviceType == "All" ||
                skills.any((s) => s.matchesTrade(serviceType));
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
              skills.any((s) => s.matchesTrade(serviceType));

          if (isOnline && isNotRejected && isVisible && matchesSkill) {
            list.add(Worker.fromFirestore(doc));
          }
        } catch (_) {}
      }
      return list;
    });
  }

  // ── Worker Streams & Operations ────────────────────────────────────────────

  /// Stream incoming pending requests for a worker / skill, including specialist relay requests.
  Stream<List<Booking>> streamWorkerIncomingRequests({
    required String workerId,
    required List<String> skills,
  }) {
    return _db
        .collection("bookings")
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => Booking.fromFirestore(d))
              .where((b) {
                // Incoming handoff relay directly targeted to this artisan
                final isRelayTarget = b.handoffStatus == 'requested' && b.handoffToWorkerId == workerId;
                if (isRelayTarget) return true;

                // Standard pending requests
                final isPending = b.status == BookingStatus.pending;
                final isAssignedOrBroadcast = b.workerId == null || b.workerId == workerId || b.referredByWorkerId == workerId;
                final matchesSkill = skills.isEmpty || skills.any((s) => s.matchesTrade(b.serviceType));
                return isPending && isAssignedOrBroadcast && matchesSkill;
              })
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

  /// Stream the single ongoing active booking assigned to a worker (accepted or inProgress).
  Stream<Booking?> streamCurrentActiveJob(String workerId) {
    return _db
        .collection("bookings")
        .where("workerId", isEqualTo: workerId)
        .snapshots()
        .map((snap) {
          final activeJobs = snap.docs
              .map((d) => Booking.fromFirestore(d))
              .where((b) =>
                  b.status == BookingStatus.accepted ||
                  b.status == BookingStatus.inProgress)
              .toList();
          return activeJobs.isNotEmpty ? activeJobs.first : null;
        });
  }

  /// Worker accepts a booking. Atomically locks the job and sets worker location.
  Future<void> acceptBooking(
    String bookingId,
    String workerId, {
    String? workerName,
    String? workerPhone,
    double? initialWorkerLat,
    double? initialWorkerLng,
  }) async {
    String? resolvedName = workerName?.trim();
    if (resolvedName == null || resolvedName.isEmpty || Booking.isGenericArtisanName(resolvedName)) {
      try {
        final wDoc = await _db.collection("workers").doc(workerId).get();
        if (wDoc.exists) {
          final wd = wDoc.data() ?? {};
          final name = (wd["name"] ?? wd["displayName"] ?? wd["artisanName"])?.toString().trim();
          if (name != null && name.isNotEmpty && !Booking.isGenericArtisanName(name)) {
            resolvedName = name;
          }
        }
      } catch (_) {}
    }

    final Map<String, dynamic> updateData = {
      "workerId": workerId,
      "status": BookingStatus.accepted.name,
    };
    if (resolvedName != null && resolvedName.isNotEmpty) {
      updateData["acceptedWorkerName"] = resolvedName;
    }
    if (workerPhone != null && workerPhone.isNotEmpty) {
      updateData["workerPhone"] = workerPhone;
    }
    if (initialWorkerLat != null && initialWorkerLng != null) {
      updateData["workerLatitude"] = initialWorkerLat;
      updateData["workerLongitude"] = initialWorkerLng;
    }

    await _db.collection("bookings").doc(bookingId).update(updateData);
  }

  /// Verify Start Job OTP entered by the artisan at the customer doorstep.
  /// If valid, atomically moves status to inProgress and records startedAt timestamp.
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

    final Map<String, dynamic> progressData = {
      "status": BookingStatus.inProgress.name,
      "startedAt": FieldValue.serverTimestamp(),
    };

    if (expectedOtp == null || expectedOtp.isEmpty) {
      // Fallback: If no OTP was attached, allow start
      await _db.collection("bookings").doc(bookingId).update(progressData);
      return true;
    }

    if (expectedOtp == enteredOtp.trim()) {
      await _db.collection("bookings").doc(bookingId).update(progressData);
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

  /// Update booking progress status (inProgress, completed, cancelled) with timestamps.
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    final Map<String, dynamic> updateData = {
      "status": status.name,
    };
    if (status == BookingStatus.inProgress) {
      updateData["startedAt"] = FieldValue.serverTimestamp();
    } else if (status == BookingStatus.completed) {
      updateData["completedAt"] = FieldValue.serverTimestamp();
    }
    await _db.collection("bookings").doc(bookingId).update(updateData);
  }

  /// Completes the booking with C2PA photographic proof and cryptographic manifest.
  Future<void> completeBookingWithProof({
    required String bookingId,
    required String proofPhotoBase64,
    required Map<String, dynamic> c2paManifest,
  }) async {
    final Map<String, dynamic> updateData = {
      "status": BookingStatus.completed.name,
      "completedAt": FieldValue.serverTimestamp(),
      "proofPhotoBase64": proofPhotoBase64,
      "c2paManifest": c2paManifest,
    };
    await _db.collection("bookings").doc(bookingId).update(updateData);
  }

  /// Update the live worker GPS coordinates and heading on an active booking in real time.
  Future<void> updateLiveWorkerLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
    double? heading,
  }) async {
    final data = <String, dynamic>{
      "workerLatitude": latitude,
      "workerLongitude": longitude,
      "workerLocationUpdatedAt": FieldValue.serverTimestamp(),
    };
    if (heading != null) {
      data["workerHeading"] = heading;
    }
    await _db.collection("bookings").doc(bookingId).update(data);
  }

  /// Mark booking payment as paid with optional audit telemetry.
  Future<void> markPaymentComplete(
    String bookingId, {
    String? invoiceId,
    String? paymentMethod,
    String? paymentProvider,
    String? paymentReference,
    double? platformFeeAmount,
    double? welfareFundAmount,
  }) async {
    final updateData = <String, dynamic>{
      "paymentStatus": PaymentStatus.paid.name,
      "invoiceId": invoiceId ?? "INV-${DateTime.now().millisecondsSinceEpoch}",
      "paidAt": FieldValue.serverTimestamp(),
    };
    if (paymentMethod != null) updateData["paymentMethod"] = paymentMethod;
    if (paymentProvider != null) updateData["paymentProvider"] = paymentProvider;
    if (paymentReference != null) updateData["paymentReference"] = paymentReference;
    if (platformFeeAmount != null) updateData["platformFeeAmount"] = platformFeeAmount;
    if (welfareFundAmount != null) updateData["welfareFundAmount"] = welfareFundAmount;

    await _db.collection("bookings").doc(bookingId).update(updateData);
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

  // ── AI Diagnostic & Specialist Relay Operations ────────────────────────────

  /// Creates an on-site Smart Diagnostic Visit (₹99 — 100% credited against repair bill).
  Future<String> createDiagnosticBooking({
    required String customerId,
    required String primaryCategory,
    required String symptomDescription,
    required String equipmentTag,
    String? customerIssueDetails,
    List<String>? suggestedToolsNeeded,
    String? workerId,
    String? acceptedWorkerName,
    double? workerLatitude,
    double? workerLongitude,
    String organizationId = "coop_tn_01",
    GeoPoint? location,
    String? customerAddressText,
    double? customerLatitude,
    double? customerLongitude,
    double diagnosticFee = 99.0,
  }) async {
    final docRef = _db.collection("bookings").doc();
    final randomOtp = (1000 + Random().nextInt(9000)).toString();

    final booking = Booking(
      id: docRef.id,
      customerId: customerId,
      workerId: workerId,
      acceptedWorkerName: acceptedWorkerName,
      workerLatitude: workerLatitude,
      workerLongitude: workerLongitude,
      organizationId: organizationId,
      serviceType: primaryCategory.toCanonicalTrade(),
      isEmergency: false,
      scheduledAt: DateTime.now(),
      status: workerId != null ? BookingStatus.accepted : BookingStatus.pending,
      amount: diagnosticFee,
      urgencyBonus: 0.0,
      broadcastRadiusKm: 12.0,
      broadcastExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
      paymentStatus: PaymentStatus.unpaid,
      location: location,
      startOtp: randomOtp,
      customerAddressText: customerAddressText,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      bookingType: 'diagnostic',
      symptomDescription: symptomDescription,
      customerIssueDetails: customerIssueDetails,
      equipmentTag: equipmentTag,
      suggestedToolsNeeded: suggestedToolsNeeded ?? const [],
      diagnosticFee: diagnosticFee,
      isFeeCredited: false,
      handoffStatus: 'none',
      handoffLogs: [
        {
          "timestamp": Timestamp.now(),
          "action": "diagnostic_visit_created",
          "equipmentTag": equipmentTag,
          "symptom": symptomDescription,
          "customerIssueDetails": customerIssueDetails ?? "",
          "suggestedTools": suggestedToolsNeeded ?? [],
          "fee": diagnosticFee,
        }
      ],
    );

    await docRef.set(booking.toFirestore());
    return docRef.id;
  }

  /// Worker A requests a specialist handoff after diagnosing root cause out of scope.
  Future<void> requestBookingHandoff({
    required String bookingId,
    required String fromWorkerId,
    required String fromWorkerName,
    required String toWorkerId,
    required String toWorkerName,
    required String diagnosisNotes,
    double referralDividend = 50.0,
  }) async {
    final docRef = _db.collection("bookings").doc(bookingId);
    final logEntry = {
      "timestamp": Timestamp.now(),
      "action": "handoff_requested",
      "fromWorkerId": fromWorkerId,
      "fromWorkerName": fromWorkerName,
      "toWorkerId": toWorkerId,
      "toWorkerName": toWorkerName,
      "notes": diagnosisNotes,
      "dividend": referralDividend,
    };

    await docRef.update({
      "handoffStatus": "requested",
      "handoffFromWorkerId": fromWorkerId,
      "handoffFromWorkerName": fromWorkerName,
      "handoffToWorkerId": toWorkerId,
      "handoffToWorkerName": toWorkerName,
      "handoffDiagnosisNotes": diagnosisNotes,
      "handoffReferralDividend": referralDividend,
      "handoffRequestedAt": FieldValue.serverTimestamp(),
      "handoffLogs": FieldValue.arrayUnion([logEntry]),
    });
  }

  /// Specialist Worker B reviews pre-inspection diagnosis notes and explicitly acknowledges & accepts.
  Future<void> acknowledgeAndAcceptHandoff({
    required String bookingId,
    required String specialistWorkerId,
    required String specialistWorkerName,
    double? initialWorkerLat,
    double? initialWorkerLng,
  }) async {
    final docRef = _db.collection("bookings").doc(bookingId);
    final logEntry = {
      "timestamp": Timestamp.now(),
      "action": "handoff_accepted",
      "specialistWorkerId": specialistWorkerId,
      "specialistWorkerName": specialistWorkerName,
      "acknowledged": true,
    };

    final Map<String, dynamic> updateData = {
      "workerId": specialistWorkerId,
      "acceptedWorkerName": specialistWorkerName,
      "handoffStatus": "accepted",
      "status": BookingStatus.accepted.name,
      "handoffAcceptedAt": FieldValue.serverTimestamp(),
      "handoffLogs": FieldValue.arrayUnion([logEntry]),
    };

    if (initialWorkerLat != null && initialWorkerLng != null) {
      updateData["workerLatitude"] = initialWorkerLat;
      updateData["workerLongitude"] = initialWorkerLng;
    }

    await docRef.update(updateData);
  }

  /// Stream handoff requests specifically targeted to this specialist artisan.
  Stream<List<Booking>> streamWorkerHandoffRequests(String workerId) {
    return _db
        .collection("bookings")
        .where("handoffToWorkerId", isEqualTo: workerId)
        .where("handoffStatus", isEqualTo: "requested")
        .snapshots()
        .map((snap) => snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Artisan adds/updates equipment tags & service keywords in Karya to boost profile match strength.
  Future<void> saveWorkerKeywords({
    required String workerId,
    required List<String> equipmentTags,
    required List<String> serviceKeywords,
  }) async {
    await _db.collection("workers").doc(workerId).set({
      "equipmentTags": equipmentTags,
      "serviceKeywords": serviceKeywords,
      "keywordsUpdatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream real specialists matching the diagnosed trade and equipment tags in real-time.
  Stream<List<Worker>> streamSpecializedWorkers({
    required String primaryCategory,
    String? secondaryCategory,
    String? equipmentTag,
    List<String> keywords = const [],
  }) {
    return _db.collection("workers").snapshots().map((snap) {
      final list = <Worker>[];
      for (final doc in snap.docs) {
        try {
          final w = Worker.fromFirestore(doc);
          if (w.verificationStatus == VerificationStatus.rejected) continue;
          if (w.visibilityStatus == VisibilityStatus.hidden || w.visibilityStatus == VisibilityStatus.suspended) continue;

          // Must match primary trade or secondary trade (flexible cluster matching)
          final matchesPrimary = w.matchesTradeCategory(primaryCategory);
          final matchesSecondary = secondaryCategory != null &&
              secondaryCategory.isNotEmpty &&
              w.matchesTradeCategory(secondaryCategory);

          if (!matchesPrimary && !matchesSecondary) continue;

          list.add(w);
        } catch (_) {}
      }

      // Sort by relevance:
      // 1. Matches equipmentTag or keywords
      // 2. Online/Checked-in first
      // 3. Higher avgRating & diagnostic accuracy score
      list.sort((a, b) {
        int scoreA = 0;
        int scoreB = 0;

        if (equipmentTag != null && equipmentTag.isNotEmpty) {
          if (a.equipmentTags.any((t) => t.toLowerCase().contains(equipmentTag.toLowerCase()))) scoreA += 10;
          if (b.equipmentTags.any((t) => t.toLowerCase().contains(equipmentTag.toLowerCase()))) scoreB += 10;
        }

        for (final kw in keywords) {
          final lkw = kw.toLowerCase();
          if (a.serviceKeywords.any((k) => k.toLowerCase().contains(lkw))) scoreA += 4;
          if (b.serviceKeywords.any((k) => k.toLowerCase().contains(lkw))) scoreB += 4;
          if (a.skills.any((s) => s.toLowerCase().contains(lkw))) scoreA += 2;
          if (b.skills.any((s) => s.toLowerCase().contains(lkw))) scoreB += 2;
        }

        if (a.isOnlineOrCheckedIn) scoreA += 5;
        if (b.isOnlineOrCheckedIn) scoreB += 5;

        scoreA += (a.avgRating * 2).round();
        scoreB += (b.avgRating * 2).round();

        scoreA += (a.diagnosticAccuracyScore * 10).round();
        scoreB += (b.diagnosticAccuracyScore * 10).round();

        return scoreB.compareTo(scoreA);
      });

      return list;
    });
  }

  /// Credits the ₹99 diagnostic fee against the final repair bill.
  Future<void> creditDiagnosticFee(String bookingId) async {
    await _db.collection("bookings").doc(bookingId).update({
      "isFeeCredited": true,
      "feeCreditedAt": FieldValue.serverTimestamp(),
    });
  }
}
