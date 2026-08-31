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
  final String? customerAddressText;
  final double? customerLatitude;
  final double? customerLongitude;

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
    this.customerAddressText,
    this.customerLatitude,
    this.customerLongitude,
  });

  double get totalAmount => amount + urgencyBonus;

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
      customerAddressText: d["customerAddressText"],
      customerLatitude: (d["customerLatitude"] as num?)?.toDouble(),
      customerLongitude: (d["customerLongitude"] as num?)?.toDouble(),
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
    "startOtp": startOtp,
    "workerLatitude": workerLatitude,
    "workerLongitude": workerLongitude,
    "customerAddressText": customerAddressText,
    "customerLatitude": customerLatitude,
    "customerLongitude": customerLongitude,
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
    String? customerAddressText,
    double? customerLatitude,
    double? customerLongitude,
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
      customerAddressText: customerAddressText ?? this.customerAddressText,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
    );
  }
}
