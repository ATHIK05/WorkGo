import 'dart:math' as math;
import "package:cloud_firestore/cloud_firestore.dart";
import "c2pa_manifest_model.dart";

enum BookingStatus { pending, accepted, inProgress, paymentPending, completed, cancelled }
enum PaymentStatus { unpaid, paid, refunded }

class Booking {
  final String id;
  final String customerId;
  final String? workerId;
  final String organizationId;
  final String serviceType;
  final bool isEmergency;
  final DateTime? scheduledAt;
  final BookingStatus status;
  final GeoPoint? location;
  final PaymentStatus paymentStatus;
  final double amount;
  final double urgencyBonus;
  final double broadcastRadiusKm;
  final DateTime? broadcastExpiresAt;
  final DateTime? acceptedAt;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? referredByWorkerId;
  final String? acceptedWorkerName;
  final String? invoiceId;
  final String? startOtp;
  final double? workerLatitude;
  final double? workerLongitude;
  final double? workerHeading;
  final DateTime? workerLocationUpdatedAt;
  final String? customerAddressText;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? workerPhone;
  final bool deletedByCustomer;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? proofSubmittedAt;
  final String? proofPhotoBase64;
  final Map<String, dynamic>? c2paManifest;

  // AI Diagnostic & Specialist Handoff extensions
  final String bookingType; // 'direct', 'broadcast', 'diagnostic'
  final String? symptomDescription;
  final String? customerIssueDetails;
  final String? equipmentTag;
  final List<String> suggestedToolsNeeded;
  final double diagnosticFee;
  final bool isFeeCredited;
  final String? handoffStatus; // 'none', 'requested', 'accepted', 'completed'
  final String? handoffFromWorkerId;
  final String? handoffFromWorkerName;
  final String? handoffDiagnosisNotes;
  final String? handoffToWorkerId;
  final String? handoffToWorkerName;
  final double handoffReferralDividend;
  final DateTime? handoffRequestedAt;
  final DateTime? handoffAcceptedAt;
  final List<Map<String, dynamic>> handoffLogs;

  // Rating & Review metadata
  final bool isRated;
  final double? rating;
  final String? reviewComment;
  final List<String> reviewTags;
  final DateTime? ratedAt;

  Booking({
    required this.id,
    required this.customerId,
    this.workerId,
    required this.organizationId,
    required this.serviceType,
    this.isEmergency = false,
    this.scheduledAt,
    required this.status,
    this.location,
    this.paymentStatus = PaymentStatus.unpaid,
    this.amount = 0.0,
    this.urgencyBonus = 0.0,
    this.broadcastRadiusKm = 5.0,
    this.broadcastExpiresAt,
    this.acceptedAt,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledBy,
    this.referredByWorkerId,
    this.acceptedWorkerName,
    this.invoiceId,
    this.startOtp,
    this.workerLatitude,
    this.workerLongitude,
    this.workerHeading,
    this.workerLocationUpdatedAt,
    this.customerAddressText,
    this.customerLatitude,
    this.customerLongitude,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.workerPhone,
    this.deletedByCustomer = false,
    this.startedAt,
    this.completedAt,
    this.proofSubmittedAt,
    this.proofPhotoBase64,
    this.c2paManifest,
    this.bookingType = 'direct',
    this.symptomDescription,
    this.customerIssueDetails,
    this.equipmentTag,
    this.suggestedToolsNeeded = const [],
    this.diagnosticFee = 0.0,
    this.isFeeCredited = false,
    this.handoffStatus = 'none',
    this.handoffFromWorkerId,
    this.handoffFromWorkerName,
    this.handoffDiagnosisNotes,
    this.handoffToWorkerId,
    this.handoffToWorkerName,
    this.handoffReferralDividend = 0.0,
    this.handoffRequestedAt,
    this.handoffAcceptedAt,
    this.handoffLogs = const [],
    this.isRated = false,
    this.rating,
    this.reviewComment,
    this.reviewTags = const [],
    this.ratedAt,
  });

  /// Real-time geodesic Haversine distance in kilometers from customer pickup location to target coordinates.
  double distanceTo(double? targetLat, double? targetLng) {
    final cLat = customerLatitude ?? location?.latitude;
    final cLng = customerLongitude ?? location?.longitude;
    if (cLat == null || cLng == null || targetLat == null || targetLng == null) {
      return double.infinity;
    }
    if (cLat.abs() <= 0.0001 || cLng.abs() <= 0.0001 || targetLat.abs() <= 0.0001 || targetLng.abs() <= 0.0001) {
      return double.infinity;
    }
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((targetLat - cLat) * p) / 2 +
        math.cos(cLat * p) *
            math.cos(targetLat * p) *
            (1 - math.cos((targetLng - cLng) * p)) /
            2;
    final clampedA = a.clamp(0.0, 1.0);
    final dist = 12742.0 * math.asin(math.sqrt(clampedA));
    return double.parse(dist.toStringAsFixed(2));
  }

  double get totalAmount => amount + urgencyBonus;
  bool get isDiagnosticVisit => bookingType == 'diagnostic' || diagnosticFee > 0;
  bool get hasActiveHandoff => handoffStatus == 'requested' || handoffStatus == 'accepted';
  bool get hasProofPhoto => proofPhotoBase64 != null && proofPhotoBase64!.isNotEmpty;
  C2paManifestRecord? get parsedC2paManifest =>
      c2paManifest != null ? C2paManifestRecord.fromMap(c2paManifest!) : null;

  /// Returns true if [name] is a generic role/title or placeholder rather than an artisan's authentic personal name.
  static bool isGenericArtisanName(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final lower = name.trim().toLowerCase();
    return lower == 'artisan' ||
        lower == 'cooperative artisan' ||
        lower == 'co-op artisan' ||
        lower == 'partner' ||
        lower == 'worker' ||
        lower == 'artisian' ||
        lower == 'verified pro' ||
        lower == 'verified artisan' ||
        lower == 'specialist' ||
        lower.contains('specialist');
  }

  /// Returns the genuine personal name of the assigned artisan if recorded and authentic, or null if placeholder/missing.
  String? get genuineArtisanName {
    final name = acceptedWorkerName?.trim();
    if (name == null || name.isEmpty) return null;
    return isGenericArtisanName(name) ? null : name;
  }

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      customerId: d["customerId"] ?? "",
      workerId: d["workerId"],
      organizationId: d["organizationId"] ?? "",
      serviceType: d["serviceType"] ?? "",
      isEmergency: d["isEmergency"] ?? false,
      scheduledAt: (d["scheduledAt"] as Timestamp?)?.toDate(),
      status: BookingStatus.values.firstWhere(
        (s) => s.name == (d["status"] ?? "pending"),
        orElse: () => BookingStatus.pending,
      ),
      location: d["location"],
      paymentStatus: PaymentStatus.values.firstWhere(
        (p) => p.name == (d["paymentStatus"] ?? "unpaid"),
        orElse: () => PaymentStatus.unpaid,
      ),
      amount: (d["amount"] ?? 0.0).toDouble(),
      urgencyBonus: (d["urgencyBonus"] ?? 0.0).toDouble(),
      broadcastRadiusKm: (d["broadcastRadiusKm"] ?? 5.0).toDouble(),
      broadcastExpiresAt: (d["broadcastExpiresAt"] as Timestamp?)?.toDate(),
      acceptedAt: (d["acceptedAt"] as Timestamp?)?.toDate(),
      cancellationReason: d["cancellationReason"],
      cancelledAt: (d["cancelledAt"] as Timestamp?)?.toDate(),
      cancelledBy: d["cancelledBy"],
      referredByWorkerId: d["referredByWorkerId"],
      acceptedWorkerName: d["acceptedWorkerName"],
      invoiceId: d["invoiceId"],
      startOtp: d["startOtp"],
      workerLatitude: (d["workerLatitude"] as num?)?.toDouble(),
      workerLongitude: (d["workerLongitude"] as num?)?.toDouble(),
      workerHeading: (d["workerHeading"] as num?)?.toDouble(),
      workerLocationUpdatedAt: (d["workerLocationUpdatedAt"] as Timestamp?)?.toDate(),
      customerAddressText: d["customerAddressText"],
      customerLatitude: (d["customerLatitude"] as num?)?.toDouble(),
      customerLongitude: (d["customerLongitude"] as num?)?.toDouble(),
      customerName: d["customerName"] ?? d["userName"] ?? d["name"],
      customerPhone: d["customerPhone"] ?? d["userPhone"] ?? d["phone"],
      customerEmail: d["customerEmail"] ?? d["userEmail"] ?? d["email"],
      workerPhone: d["workerPhone"] ?? d["artisanPhone"] ?? d["phoneForCalling"],
      deletedByCustomer: d["deletedByCustomer"] ?? d["hiddenForCustomer"] ?? false,
      startedAt: (d["startedAt"] as Timestamp?)?.toDate(),
      completedAt: (d["completedAt"] as Timestamp?)?.toDate(),
      proofSubmittedAt: (d["proofSubmittedAt"] as Timestamp?)?.toDate(),
      proofPhotoBase64: d["proofPhotoBase64"] ?? d["completionPhotoBase64"] ?? d["photoBase64"],
      c2paManifest: d["c2paManifest"] != null ? Map<String, dynamic>.from(d["c2paManifest"] as Map) : null,
      bookingType: d["bookingType"] ?? 'direct',
      symptomDescription: d["symptomDescription"],
      customerIssueDetails: d["customerIssueDetails"] ?? d["issueNotes"] ?? d["customerNotes"],
      equipmentTag: d["equipmentTag"],
      suggestedToolsNeeded: List<String>.from(d["suggestedToolsNeeded"] ?? []),
      diagnosticFee: (d["diagnosticFee"] as num?)?.toDouble() ?? 0.0,
      isFeeCredited: d["isFeeCredited"] ?? false,
      handoffStatus: d["handoffStatus"] ?? 'none',
      handoffFromWorkerId: d["handoffFromWorkerId"],
      handoffFromWorkerName: d["handoffFromWorkerName"],
      handoffDiagnosisNotes: d["handoffDiagnosisNotes"],
      handoffToWorkerId: d["handoffToWorkerId"],
      handoffToWorkerName: d["handoffToWorkerName"],
      handoffReferralDividend: (d["handoffReferralDividend"] as num?)?.toDouble() ?? 0.0,
      handoffRequestedAt: (d["handoffRequestedAt"] as Timestamp?)?.toDate(),
      handoffAcceptedAt: (d["handoffAcceptedAt"] as Timestamp?)?.toDate(),
      handoffLogs: (d["handoffLogs"] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      isRated: d["isRated"] ?? (d["rating"] != null),
      rating: (d["rating"] as num?)?.toDouble(),
      reviewComment: d["reviewComment"] ?? d["comment"],
      reviewTags: List<String>.from(d["reviewTags"] ?? d["tags"] ?? []),
      ratedAt: (d["ratedAt"] as Timestamp?)?.toDate() ?? (d["reviewedAt"] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    "customerId": customerId,
    "workerId": workerId,
    "organizationId": organizationId,
    "serviceType": serviceType,
    "isEmergency": isEmergency,
    "scheduledAt": scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
    "status": status.name,
    "location": location,
    "paymentStatus": paymentStatus.name,
    "amount": amount,
    "urgencyBonus": urgencyBonus,
    "broadcastRadiusKm": broadcastRadiusKm,
    "broadcastExpiresAt": broadcastExpiresAt != null ? Timestamp.fromDate(broadcastExpiresAt!) : null,
    "acceptedAt": acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    "cancellationReason": cancellationReason,
    "cancelledAt": cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
    "cancelledBy": cancelledBy,
    "referredByWorkerId": referredByWorkerId,
    "acceptedWorkerName": acceptedWorkerName,
    "invoiceId": invoiceId,
    "deletedByCustomer": deletedByCustomer,
    "startOtp": startOtp,
    "workerLatitude": workerLatitude,
    "workerLongitude": workerLongitude,
    "workerHeading": workerHeading,
    "workerLocationUpdatedAt": workerLocationUpdatedAt != null ? Timestamp.fromDate(workerLocationUpdatedAt!) : null,
    "customerAddressText": customerAddressText,
    "customerLatitude": customerLatitude,
    "customerLongitude": customerLongitude,
    "customerName": customerName,
    "customerPhone": customerPhone,
    "customerEmail": customerEmail,
    "workerPhone": workerPhone,
    "startedAt": startedAt != null ? Timestamp.fromDate(startedAt!) : null,
    "completedAt": completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    "proofSubmittedAt": proofSubmittedAt != null ? Timestamp.fromDate(proofSubmittedAt!) : null,
    "proofPhotoBase64": proofPhotoBase64,
    "c2paManifest": c2paManifest,
    "bookingType": bookingType,
    "symptomDescription": symptomDescription,
    "customerIssueDetails": customerIssueDetails,
    "equipmentTag": equipmentTag,
    "suggestedToolsNeeded": suggestedToolsNeeded,
    "diagnosticFee": diagnosticFee,
    "isFeeCredited": isFeeCredited,
    "handoffStatus": handoffStatus,
    "handoffFromWorkerId": handoffFromWorkerId,
    "handoffFromWorkerName": handoffFromWorkerName,
    "handoffDiagnosisNotes": handoffDiagnosisNotes,
    "handoffToWorkerId": handoffToWorkerId,
    "handoffToWorkerName": handoffToWorkerName,
    "handoffReferralDividend": handoffReferralDividend,
    "handoffRequestedAt": handoffRequestedAt != null ? Timestamp.fromDate(handoffRequestedAt!) : null,
    "handoffAcceptedAt": handoffAcceptedAt != null ? Timestamp.fromDate(handoffAcceptedAt!) : null,
    "handoffLogs": handoffLogs,
    "isRated": isRated,
    "rating": rating,
    "reviewComment": reviewComment,
    "reviewTags": reviewTags,
    "ratedAt": ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
  };

  Booking copyWith({
    String? id,
    String? customerId,
    String? workerId,
    String? organizationId,
    String? serviceType,
    bool? isEmergency,
    DateTime? scheduledAt,
    BookingStatus? status,
    GeoPoint? location,
    PaymentStatus? paymentStatus,
    double? amount,
    double? urgencyBonus,
    double? broadcastRadiusKm,
    DateTime? broadcastExpiresAt,
    DateTime? acceptedAt,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? referredByWorkerId,
    String? acceptedWorkerName,
    String? invoiceId,
    String? startOtp,
    double? workerLatitude,
    double? workerLongitude,
    double? workerHeading,
    DateTime? workerLocationUpdatedAt,
    String? customerAddressText,
    double? customerLatitude,
    double? customerLongitude,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? workerPhone,
    bool? deletedByCustomer,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? proofSubmittedAt,
    String? proofPhotoBase64,
    Map<String, dynamic>? c2paManifest,
    String? bookingType,
    String? symptomDescription,
    String? customerIssueDetails,
    String? equipmentTag,
    List<String>? suggestedToolsNeeded,
    double? diagnosticFee,
    bool? isFeeCredited,
    String? handoffStatus,
    String? handoffFromWorkerId,
    String? handoffFromWorkerName,
    String? handoffDiagnosisNotes,
    String? handoffToWorkerId,
    String? handoffToWorkerName,
    double? handoffReferralDividend,
    DateTime? handoffRequestedAt,
    DateTime? handoffAcceptedAt,
    List<Map<String, dynamic>>? handoffLogs,
    bool? isRated,
    double? rating,
    String? reviewComment,
    List<String>? reviewTags,
    DateTime? ratedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      workerId: workerId ?? this.workerId,
      organizationId: organizationId ?? this.organizationId,
      serviceType: serviceType ?? this.serviceType,
      isEmergency: isEmergency ?? this.isEmergency,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      location: location ?? this.location,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amount: amount ?? this.amount,
      urgencyBonus: urgencyBonus ?? this.urgencyBonus,
      broadcastRadiusKm: broadcastRadiusKm ?? this.broadcastRadiusKm,
      broadcastExpiresAt: broadcastExpiresAt ?? this.broadcastExpiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      referredByWorkerId: referredByWorkerId ?? this.referredByWorkerId,
      acceptedWorkerName: acceptedWorkerName ?? this.acceptedWorkerName,
      invoiceId: invoiceId ?? this.invoiceId,
      startOtp: startOtp ?? this.startOtp,
      workerLatitude: workerLatitude ?? this.workerLatitude,
      workerLongitude: workerLongitude ?? this.workerLongitude,
      workerHeading: workerHeading ?? this.workerHeading,
      workerLocationUpdatedAt: workerLocationUpdatedAt ?? this.workerLocationUpdatedAt,
      customerAddressText: customerAddressText ?? this.customerAddressText,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      workerPhone: workerPhone ?? this.workerPhone,
      deletedByCustomer: deletedByCustomer ?? this.deletedByCustomer,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      proofSubmittedAt: proofSubmittedAt ?? this.proofSubmittedAt,
      proofPhotoBase64: proofPhotoBase64 ?? this.proofPhotoBase64,
      c2paManifest: c2paManifest ?? this.c2paManifest,
      bookingType: bookingType ?? this.bookingType,
      symptomDescription: symptomDescription ?? this.symptomDescription,
      customerIssueDetails: customerIssueDetails ?? this.customerIssueDetails,
      equipmentTag: equipmentTag ?? this.equipmentTag,
      suggestedToolsNeeded: suggestedToolsNeeded ?? this.suggestedToolsNeeded,
      diagnosticFee: diagnosticFee ?? this.diagnosticFee,
      isFeeCredited: isFeeCredited ?? this.isFeeCredited,
      handoffStatus: handoffStatus ?? this.handoffStatus,
      handoffFromWorkerId: handoffFromWorkerId ?? this.handoffFromWorkerId,
      handoffFromWorkerName: handoffFromWorkerName ?? this.handoffFromWorkerName,
      handoffDiagnosisNotes: handoffDiagnosisNotes ?? this.handoffDiagnosisNotes,
      handoffToWorkerId: handoffToWorkerId ?? this.handoffToWorkerId,
      handoffToWorkerName: handoffToWorkerName ?? this.handoffToWorkerName,
      handoffReferralDividend: handoffReferralDividend ?? this.handoffReferralDividend,
      handoffRequestedAt: handoffRequestedAt ?? this.handoffRequestedAt,
      handoffAcceptedAt: handoffAcceptedAt ?? this.handoffAcceptedAt,
      handoffLogs: handoffLogs ?? this.handoffLogs,
      isRated: isRated ?? this.isRated,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      reviewTags: reviewTags ?? this.reviewTags,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}
