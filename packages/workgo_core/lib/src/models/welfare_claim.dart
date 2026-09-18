import "package:cloud_firestore/cloud_firestore.dart";

/// Represents an immutable entry in the claim's verification audit log.
class WelfareVerificationEntry {
  final String type; // "doctorCall" | "customerCall" | "sos" | "photoOverride"
  final String adminId;
  final DateTime timestamp;
  final String note;

  const WelfareVerificationEntry({
    required this.type,
    required this.adminId,
    required this.timestamp,
    required this.note,
  });

  factory WelfareVerificationEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDt(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return WelfareVerificationEntry(
      type: map["type"] as String? ?? "",
      adminId: map["adminId"] as String? ?? "",
      timestamp: parseDt(map["timestamp"]),
      note: map["note"] as String? ?? "",
    );
  }

  Map<String, dynamic> toMap() => {
        "type": type,
        "adminId": adminId,
        "timestamp": Timestamp.fromDate(timestamp),
        "note": note,
      };
}

/// Breakdown of individual corroboration factors evaluated by computeClaimConfidence in welfare_scoring.js.
class ClaimFactors {
  final bool doctorCallConfirmed;
  final bool hospitalRecordProvided;
  final bool sosCorroborated;
  final bool photoPassesTamperCheck;
  final bool customerCallConfirmed;

  const ClaimFactors({
    this.doctorCallConfirmed = false,
    this.hospitalRecordProvided = false,
    this.sosCorroborated = false,
    this.photoPassesTamperCheck = false,
    this.customerCallConfirmed = false,
  });

  factory ClaimFactors.fromMap(Map<String, dynamic> map) {
    return ClaimFactors(
      doctorCallConfirmed: map["doctorCallConfirmed"] as bool? ?? false,
      hospitalRecordProvided: map["hospitalRecordProvided"] as bool? ?? false,
      sosCorroborated: map["sosCorroborated"] as bool? ?? false,
      photoPassesTamperCheck: map["photoPassesTamperCheck"] as bool? ?? false,
      customerCallConfirmed: map["customerCallConfirmed"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        "doctorCallConfirmed": doctorCallConfirmed,
        "hospitalRecordProvided": hospitalRecordProvided,
        "sosCorroborated": sosCorroborated,
        "photoPassesTamperCheck": photoPassesTamperCheck,
        "customerCallConfirmed": customerCallConfirmed,
      };
}

/// Multi-factor confidence score object computed live by computeClaimConfidence in welfare_scoring.js.
class ClaimConfidenceScore {
  final int baseScore;
  final int trustBonus;
  final int totalScore;
  final String weightTableUsed; // "booking" | "no_booking"
  final ClaimFactors factors;
  final bool photoFlaggedForReview;

  const ClaimConfidenceScore({
    required this.baseScore,
    required this.trustBonus,
    required this.totalScore,
    required this.weightTableUsed,
    required this.factors,
    this.photoFlaggedForReview = false,
  });

  factory ClaimConfidenceScore.fromMap(Map<String, dynamic> map) {
    return ClaimConfidenceScore(
      baseScore: (map["baseScore"] as num?)?.toInt() ?? 0,
      trustBonus: (map["trustBonus"] as num?)?.toInt() ?? 0,
      totalScore: (map["totalScore"] as num?)?.toInt() ?? 0,
      weightTableUsed: map["weightTableUsed"] as String? ?? "no_booking",
      factors: map["factors"] is Map<String, dynamic>
          ? ClaimFactors.fromMap(map["factors"] as Map<String, dynamic>)
          : map["factors"] is Map
              ? ClaimFactors.fromMap(Map<String, dynamic>.from(map["factors"] as Map))
              : const ClaimFactors(),
      photoFlaggedForReview: map["photoFlaggedForReview"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        "baseScore": baseScore,
        "trustBonus": trustBonus,
        "totalScore": totalScore,
        "weightTableUsed": weightTableUsed,
        "factors": factors.toMap(),
        "photoFlaggedForReview": photoFlaggedForReview,
      };
}

/// Represents a Worker Welfare & Insurance micro-claim document in Firestore (`welfare_claims/{claimId}`).
/// Standardized strictly on the backend's exact schema in welfare.js (Step 4a):
/// uses `description` and `bookingId` with ZERO dual-writing.
class WelfareClaim {
  final String id;
  final String workerId;
  final String? bookingId;
  final String doctorCertificateDocId;
  final String? injuryPhotoDocId;
  final String? hospitalRecordDocId;
  final DateTime incidentDate;
  final String description;
  final String status; // "pending_review" | "approved" | "rejected"

  // Admin verification factor flags & notes
  final bool doctorCallConfirmed;
  final String? doctorCallNote;
  final bool customerCallConfirmed;
  final String? customerCallNote;
  final bool sosCorroborated;
  final String? sosNote;
  final bool photoOverride;
  final String? photoOverrideNote;
  final bool photoFlagged;
  final Map<String, dynamic>? photoDetectorResult;

  // Audit and verification history
  final List<WelfareVerificationEntry> verificationLog;
  final List<Map<String, dynamic>> auditLog;

  // Metadata
  final DateTime submittedAt;
  final String? submittedBy;

  // Immutable historical decision snapshot (populated when decided)
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;
  final int? snapshotScore;
  final int? snapshotThreshold;
  final Map<String, dynamic>? scoreSnapshot;

  const WelfareClaim({
    required this.id,
    required this.workerId,
    this.bookingId,
    required this.doctorCertificateDocId,
    this.injuryPhotoDocId,
    this.hospitalRecordDocId,
    required this.incidentDate,
    required this.description,
    this.status = "pending_review",
    this.doctorCallConfirmed = false,
    this.doctorCallNote,
    this.customerCallConfirmed = false,
    this.customerCallNote,
    this.sosCorroborated = false,
    this.sosNote,
    this.photoOverride = false,
    this.photoOverrideNote,
    this.photoFlagged = false,
    this.photoDetectorResult,
    this.verificationLog = const [],
    this.auditLog = const [],
    required this.submittedAt,
    this.submittedBy,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
    this.snapshotScore,
    this.snapshotThreshold,
    this.scoreSnapshot,
  });

  bool get isPending => status == "pending" || status == "pending_review";
  bool get isApproved => status == "approved";
  bool get isRejected => status == "rejected";
  bool get isBookingLinked => bookingId != null && bookingId!.trim().isNotEmpty;

  factory WelfareClaim.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return WelfareClaim.fromMap(d, doc.id);
  }

  factory WelfareClaim.fromMap(Map<String, dynamic> d, [String id = ""]) {
    DateTime parseDt(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final rawLog = d["verificationLog"] as List<dynamic>? ?? [];
    final parsedLog = rawLog
        .whereType<Map>()
        .map((e) => WelfareVerificationEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final rawAudit = d["auditLog"] as List<dynamic>? ?? [];
    final parsedAudit = rawAudit
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return WelfareClaim(
      id: (d["id"] as String?) ?? id,
      workerId: d["workerId"] as String? ?? "",
      bookingId: d["bookingId"] as String?,
      doctorCertificateDocId: d["doctorCertificateDocId"] as String? ?? "",
      injuryPhotoDocId: d["injuryPhotoDocId"] as String?,
      hospitalRecordDocId: d["hospitalRecordDocId"] as String?,
      incidentDate: parseDt(d["incidentDate"]),
      description: d["description"] as String? ?? "",
      status: d["status"] as String? ?? "pending_review",
      doctorCallConfirmed: d["doctorCallConfirmed"] as bool? ?? false,
      doctorCallNote: d["doctorCallNote"] as String?,
      customerCallConfirmed: d["customerCallConfirmed"] as bool? ?? false,
      customerCallNote: d["customerCallNote"] as String?,
      sosCorroborated: d["sosCorroborated"] as bool? ?? false,
      sosNote: d["sosNote"] as String?,
      photoOverride: d["photoOverride"] as bool? ?? false,
      photoOverrideNote: d["photoOverrideNote"] as String?,
      photoFlagged: d["photoFlagged"] as bool? ?? false,
      photoDetectorResult: d["photoDetectorResult"] != null
          ? Map<String, dynamic>.from(d["photoDetectorResult"] as Map)
          : null,
      verificationLog: parsedLog,
      auditLog: parsedAudit,
      submittedAt: parseDt(d["submittedAt"]),
      submittedBy: d["submittedBy"] as String?,
      decidedBy: d["decidedBy"] as String?,
      decidedAt: d["decidedAt"] != null ? parseDt(d["decidedAt"]) : null,
      decisionNote: d["decisionNote"] as String?,
      snapshotScore: (d["snapshotScore"] as num?)?.toInt(),
      snapshotThreshold: (d["snapshotThreshold"] as num?)?.toInt(),
      scoreSnapshot: d["scoreSnapshot"] != null
          ? Map<String, dynamic>.from(d["scoreSnapshot"] as Map)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        "id": id,
        "workerId": workerId,
        "bookingId": bookingId,
        "doctorCertificateDocId": doctorCertificateDocId,
        "injuryPhotoDocId": injuryPhotoDocId,
        "hospitalRecordDocId": hospitalRecordDocId,
        "incidentDate": Timestamp.fromDate(incidentDate),
        "description": description,
        "status": status,
        "doctorCallConfirmed": doctorCallConfirmed,
        "doctorCallNote": doctorCallNote,
        "customerCallConfirmed": customerCallConfirmed,
        "customerCallNote": customerCallNote,
        "sosCorroborated": sosCorroborated,
        "sosNote": sosNote,
        "photoOverride": photoOverride,
        "photoOverrideNote": photoOverrideNote,
        "photoFlagged": photoFlagged,
        "photoDetectorResult": photoDetectorResult,
        "verificationLog": verificationLog.map((e) => e.toMap()).toList(),
        "auditLog": auditLog,
        "submittedAt": Timestamp.fromDate(submittedAt),
        "submittedBy": submittedBy,
        "decidedBy": decidedBy,
        "decidedAt": decidedAt != null ? Timestamp.fromDate(decidedAt!) : null,
        "decisionNote": decisionNote,
        "snapshotScore": snapshotScore,
        "snapshotThreshold": snapshotThreshold,
        "scoreSnapshot": scoreSnapshot,
      };

  Map<String, dynamic> toMap() => toFirestore();

  WelfareClaim copyWith({
    String? id,
    String? workerId,
    String? bookingId,
    String? doctorCertificateDocId,
    String? injuryPhotoDocId,
    String? hospitalRecordDocId,
    DateTime? incidentDate,
    String? description,
    String? status,
    bool? doctorCallConfirmed,
    String? doctorCallNote,
    bool? customerCallConfirmed,
    String? customerCallNote,
    bool? sosCorroborated,
    String? sosNote,
    bool? photoOverride,
    String? photoOverrideNote,
    bool? photoFlagged,
    Map<String, dynamic>? photoDetectorResult,
    List<WelfareVerificationEntry>? verificationLog,
    List<Map<String, dynamic>>? auditLog,
    DateTime? submittedAt,
    String? submittedBy,
    String? decidedBy,
    DateTime? decidedAt,
    String? decisionNote,
    int? snapshotScore,
    int? snapshotThreshold,
    Map<String, dynamic>? scoreSnapshot,
  }) {
    return WelfareClaim(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      bookingId: bookingId ?? this.bookingId,
      doctorCertificateDocId: doctorCertificateDocId ?? this.doctorCertificateDocId,
      injuryPhotoDocId: injuryPhotoDocId ?? this.injuryPhotoDocId,
      hospitalRecordDocId: hospitalRecordDocId ?? this.hospitalRecordDocId,
      incidentDate: incidentDate ?? this.incidentDate,
      description: description ?? this.description,
      status: status ?? this.status,
      doctorCallConfirmed: doctorCallConfirmed ?? this.doctorCallConfirmed,
      doctorCallNote: doctorCallNote ?? this.doctorCallNote,
      customerCallConfirmed: customerCallConfirmed ?? this.customerCallConfirmed,
      customerCallNote: customerCallNote ?? this.customerCallNote,
      sosCorroborated: sosCorroborated ?? this.sosCorroborated,
      sosNote: sosNote ?? this.sosNote,
      photoOverride: photoOverride ?? this.photoOverride,
      photoOverrideNote: photoOverrideNote ?? this.photoOverrideNote,
      photoFlagged: photoFlagged ?? this.photoFlagged,
      photoDetectorResult: photoDetectorResult ?? this.photoDetectorResult,
      verificationLog: verificationLog ?? this.verificationLog,
      auditLog: auditLog ?? this.auditLog,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      decisionNote: decisionNote ?? this.decisionNote,
      snapshotScore: snapshotScore ?? this.snapshotScore,
      snapshotThreshold: snapshotThreshold ?? this.snapshotThreshold,
      scoreSnapshot: scoreSnapshot ?? this.scoreSnapshot,
    );
  }
}

/// Exact response envelope returned by GET /api/welfare/claims/:claimId and PATCH /verify in welfare.js.
class WelfareClaimDetailResponse {
  final bool success;
  final WelfareClaim claim;
  final Map<String, dynamic>? worker;
  final ClaimConfidenceScore? score;
  final String? scoreReason; // "no_admin_verification_yet" when score is null
  final int approvalThreshold; // 50, 75, or 90

  const WelfareClaimDetailResponse({
    required this.success,
    required this.claim,
    this.worker,
    this.score,
    this.scoreReason,
    required this.approvalThreshold,
  });

  /// True if confidence score exists and meets or exceeds the required frequency tier threshold.
  bool get meetsApprovalThreshold => score != null && score!.totalScore >= approvalThreshold;

  factory WelfareClaimDetailResponse.fromMap(Map<String, dynamic> map) {
    final claimData = map["claim"] is Map ? Map<String, dynamic>.from(map["claim"] as Map) : <String, dynamic>{};
    final scoreData = map["score"] is Map ? Map<String, dynamic>.from(map["score"] as Map) : null;
    final workerData = map["worker"] is Map ? Map<String, dynamic>.from(map["worker"] as Map) : null;

    return WelfareClaimDetailResponse(
      success: map["success"] as bool? ?? true,
      claim: WelfareClaim.fromMap(claimData),
      worker: workerData,
      score: scoreData != null ? ClaimConfidenceScore.fromMap(scoreData) : null,
      scoreReason: map["scoreReason"] as String?,
      approvalThreshold: (map["approvalThreshold"] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toMap() => {
        "success": success,
        "claim": claim.toMap(),
        "worker": worker,
        "score": score?.toMap(),
        "scoreReason": scoreReason,
        "approvalThreshold": approvalThreshold,
      };
}
