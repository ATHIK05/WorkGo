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

enum VideoKycStatus { scheduled, inLobby, inCall, completed, missed, cancelled, rejected }

class VideoKycBooking {
  final String id;
  final String workerId;
  final DateTime slotTime;
  final VideoKycStatus status;
  final String workerStatus; // 'in_lobby', 'in_call', 'completed'
  final String adminStatus; // 'pending', 'joined', 'in_call', 'completed'
  final String roomName;
  final String roomUrl;
  final String randomPhrase;
  final String? assignedStaffId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastPingAt;

  VideoKycBooking({
    required this.id,
    required this.workerId,
    required this.slotTime,
    required this.status,
    this.workerStatus = "in_lobby",
    this.adminStatus = "pending",
    required this.roomName,
    this.roomUrl = "",
    required this.randomPhrase,
    this.assignedStaffId,
    this.notes,
    required this.createdAt,
    this.lastPingAt,
  });

  factory VideoKycBooking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = d["status"] ?? "scheduled";
    final roomName = d["roomName"] ?? "workgo_kyc_${doc.id}";
    return VideoKycBooking(
      id: doc.id,
      workerId: d["workerId"] ?? "",
      slotTime: _parseDateTime(d["slotTime"]) ?? DateTime.now(),
      status: _parseStatus(statusStr),
      workerStatus: d["workerStatus"] ?? "in_lobby",
      adminStatus: d["adminStatus"] ?? "pending",
      roomName: roomName,
      roomUrl: d["roomUrl"] ?? "https://meet.jit.si/$roomName#config.prejoinPageEnabled=false",
      randomPhrase: d["randomPhrase"] ?? "CHALLENGE-2026",
      assignedStaffId: d["assignedStaffId"],
      notes: d["notes"],
      createdAt: _parseDateTime(d["createdAt"]) ?? DateTime.now(),
      lastPingAt: _parseDateTime(d["lastPingAt"]),
    );
  }

  static VideoKycStatus _parseStatus(String str) {
    switch (str.toLowerCase()) {
      case "in_lobby":
      case "inlobby":
        return VideoKycStatus.inLobby;
      case "in_call":
      case "incall":
      case "inprogress":
        return VideoKycStatus.inCall;
      case "completed":
        return VideoKycStatus.completed;
      case "rejected":
        return VideoKycStatus.rejected;
      case "missed":
        return VideoKycStatus.missed;
      case "cancelled":
        return VideoKycStatus.cancelled;
      default:
        return VideoKycStatus.scheduled;
    }
  }

  Map<String, dynamic> toFirestore() => {
    "workerId": workerId,
    "slotTime": Timestamp.fromDate(slotTime),
    "status": status.name,
    "workerStatus": workerStatus,
    "adminStatus": adminStatus,
    "roomName": roomName,
    "roomUrl": roomUrl,
    "randomPhrase": randomPhrase,
    "assignedStaffId": assignedStaffId,
    "notes": notes,
    "createdAt": Timestamp.fromDate(createdAt),
    "lastPingAt": lastPingAt != null ? Timestamp.fromDate(lastPingAt!) : null,
  };

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
