import "package:cloud_firestore/cloud_firestore.dart";

enum BookingStatus { pending, accepted, inProgress, completed, cancelled }
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
  final bool deletedByCustomer;
  final DateTime? startedAt;
  final DateTime? completedAt;

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
    this.deletedByCustomer = false,
    this.startedAt,
    this.completedAt,
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
  });

  double get totalAmount => amount + urgencyBonus;
  bool get isDiagnosticVisit => bookingType == 'diagnostic' || diagnosticFee > 0;
  bool get hasActiveHandoff => handoffStatus == 'requested' || handoffStatus == 'accepted';

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
      deletedByCustomer: d["deletedByCustomer"] ?? d["hiddenForCustomer"] ?? false,
      startedAt: (d["startedAt"] as Timestamp?)?.toDate(),
      completedAt: (d["completedAt"] as Timestamp?)?.toDate(),
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
    "startedAt": startedAt != null ? Timestamp.fromDate(startedAt!) : null,
    "completedAt": completedAt != null ? Timestamp.fromDate(completedAt!) : null,
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
    bool? deletedByCustomer,
    DateTime? startedAt,
    DateTime? completedAt,
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
      deletedByCustomer: deletedByCustomer ?? this.deletedByCustomer,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
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
    );
  }
}
