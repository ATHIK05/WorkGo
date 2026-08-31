import "package:cloud_firestore/cloud_firestore.dart";

class VerificationAuditLog {
  final String id;
  final String workerId;
  final String fromStage;
  final String toStage;
  final String action;
  final String actorId;
  final String actorRole;
  final String reason;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  VerificationAuditLog({
    required this.id,
    required this.workerId,
    required this.fromStage,
    required this.toStage,
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.reason,
    this.metadata = const {},
    required this.timestamp,
  });

  factory VerificationAuditLog.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return VerificationAuditLog(
      id: doc.id,
      workerId: d["workerId"] ?? "",
      fromStage: d["fromStage"] ?? "",
      toStage: d["toStage"] ?? "",
      action: d["action"] ?? "",
      actorId: d["actorId"] ?? "",
      actorRole: d["actorRole"] ?? "",
      reason: d["reason"] ?? "",
      metadata: Map<String, dynamic>.from(d["metadata"] ?? {}),
      timestamp: _parseDateTime(d["timestamp"]) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    "workerId": workerId,
    "fromStage": fromStage,
    "toStage": toStage,
    "action": action,
    "actorId": actorId,
    "actorRole": actorRole,
    "reason": reason,
    "metadata": metadata,
    "timestamp": Timestamp.fromDate(timestamp),
  };

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

enum VideoKycStatus { scheduled, inProgress, completed, missed, cancelled }

class VideoKycBooking {
  final String id;
  final String workerId;
  final DateTime slotTime;
  final VideoKycStatus status;
  final String roomName;
  final String randomPhrase;
  final String? assignedStaffId;
  final DateTime createdAt;

  VideoKycBooking({
    required this.id,
    required this.workerId,
    required this.slotTime,
    required this.status,
    required this.roomName,
    required this.randomPhrase,
    this.assignedStaffId,
    required this.createdAt,
  });

  factory VideoKycBooking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = d["status"] ?? "scheduled";
    return VideoKycBooking(
      id: doc.id,
      workerId: d["workerId"] ?? "",
      slotTime: _parseDateTime(d["slotTime"]) ?? DateTime.now(),
      status: VideoKycStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => VideoKycStatus.scheduled,
      ),
      roomName: d["roomName"] ?? "workgo_kyc_${doc.id}",
      randomPhrase: d["randomPhrase"] ?? "CHALLENGE-2026",
      assignedStaffId: d["assignedStaffId"],
      createdAt: _parseDateTime(d["createdAt"]) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    "workerId": workerId,
    "slotTime": Timestamp.fromDate(slotTime),
    "status": status.name,
    "roomName": roomName,
    "randomPhrase": randomPhrase,
    "assignedStaffId": assignedStaffId,
    "createdAt": Timestamp.fromDate(createdAt),
  };

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
