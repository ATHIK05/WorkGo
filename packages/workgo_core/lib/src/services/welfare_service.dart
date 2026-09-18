import 'package:cloud_firestore/cloud_firestore.dart';
import '../api_client/workgo_api_client.dart';
import '../models/welfare_claim.dart';

/// Service for interacting with WorkGo Worker Welfare & Micro-Insurance APIs (SIH 26089).
/// Handles encrypted medical document uploads, claim submissions, status streams,
/// and administrative review workflows.
class WelfareService {
  final WorkGoApiClient _apiClient = WorkGoApiClient();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Uploads an encrypted document into workers/{workerId}/documents via AES-256-CBC backend route.
  Future<Map<String, dynamic>> uploadEncryptedDocument({
    required String workerId,
    required String docType,
    required String base64Data,
    String? fileName,
  }) async {
    final res = await _apiClient.post("/api/documents/upload", {
      "workerId": workerId,
      "docType": docType,
      "base64Data": base64Data,
      "fileName": fileName ?? "$docType.dat",
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Decrypts and retrieves a document from workers/{workerId}/documents via backend route.
  Future<Map<String, dynamic>> getDecryptedDocument({
    required String workerId,
    required String docId,
  }) async {
    final res = await _apiClient.get("/api/documents/$workerId/$docId");
    return Map<String, dynamic>.from(res as Map);
  }

  /// Submits a new welfare claim through backend route (validates doctor certificate & ownership).
  Future<Map<String, dynamic>> submitClaim({
    required String workerId,
    required String doctorCertificateDocId,
    String? bookingId,
    String? injuryPhotoDocId,
    String? hospitalRecordDocId,
    DateTime? incidentDate,
    String? description,
  }) async {
    final res = await _apiClient.post("/api/welfare/claims/submit", {
      "workerId": workerId,
      "doctorCertificateDocId": doctorCertificateDocId,
      if (bookingId != null && bookingId.isNotEmpty) "bookingId": bookingId,
      if (injuryPhotoDocId != null && injuryPhotoDocId.isNotEmpty) "injuryPhotoDocId": injuryPhotoDocId,
      if (hospitalRecordDocId != null && hospitalRecordDocId.isNotEmpty) "hospitalRecordDocId": hospitalRecordDocId,
      if (incidentDate != null) "incidentDate": incidentDate.toIso8601String(),
      if (description != null) "description": description,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Real-time stream of welfare claims for a specific worker.
  Stream<List<WelfareClaim>> streamWorkerClaims(String workerId) {
    return _db
        .collection("welfare_claims")
        .where("workerId", isEqualTo: workerId)
        .snapshots()
        .map((snap) {
          final claims = snap.docs.map((d) => WelfareClaim.fromFirestore(d)).toList();
          claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
          return claims;
        });
  }

  /// Real-time stream of all welfare claims (admin inspection).
  Stream<List<WelfareClaim>> streamAllClaims({String? status}) {
    Query query = _db.collection("welfare_claims");
    if (status != null && status != "all") {
      query = query.where("status", isEqualTo: status);
    }
    return query.snapshots().map((snap) {
      final claims = snap.docs.map((d) => WelfareClaim.fromFirestore(d)).toList();
      claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return claims;
    });
  }

  /// Admin endpoint: GET /api/welfare/claims
  Future<Map<String, dynamic>> getClaimsList({String status = "pending_review", int page = 1, int limit = 50}) async {
    final res = await _apiClient.get("/api/welfare/claims?status=$status&page=$page&limit=$limit");
    return Map<String, dynamic>.from(res as Map);
  }

  /// Admin/Worker endpoint: GET /api/welfare/claims/:claimId (returns raw map)
  Future<Map<String, dynamic>> getClaimDetail(String claimId) async {
    final res = await _apiClient.get("/api/welfare/claims/$claimId");
    return Map<String, dynamic>.from(res as Map);
  }

  /// Admin/Worker endpoint: GET /api/welfare/claims/:claimId (returns typed WelfareClaimDetailResponse)
  Future<WelfareClaimDetailResponse> fetchClaimDetail(String claimId) async {
    final res = await _apiClient.get("/api/welfare/claims/$claimId");
    return WelfareClaimDetailResponse.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Admin endpoint: PATCH /api/welfare/claims/:claimId/verify
  Future<Map<String, dynamic>> verifyClaim({
    required String claimId,
    bool? doctorCallConfirmed,
    String? doctorCallNote,
    bool? customerCallConfirmed,
    String? customerCallNote,
    bool? sosCorroborated,
    String? sosNote,
    bool? photoOverride,
    String? photoOverrideNote,
  }) async {
    final body = <String, dynamic>{
      if (doctorCallConfirmed != null) "doctorCallConfirmed": doctorCallConfirmed,
      if (doctorCallNote != null) "doctorCallNote": doctorCallNote,
      if (customerCallConfirmed != null) "customerCallConfirmed": customerCallConfirmed,
      if (customerCallNote != null) "customerCallNote": customerCallNote,
      if (sosCorroborated != null) "sosCorroborated": sosCorroborated,
      if (sosNote != null) "sosNote": sosNote,
      if (photoOverride != null) "photoOverride": photoOverride,
      if (photoOverrideNote != null) "photoOverrideNote": photoOverrideNote,
    };
    final res = await _apiClient.patch("/api/welfare/claims/$claimId/verify", body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Admin endpoint: POST /api/welfare/claims/:claimId/decision
  Future<Map<String, dynamic>> submitDecision({
    required String claimId,
    required String decision,
    required String decisionNote,
  }) async {
    final res = await _apiClient.post("/api/welfare/claims/$claimId/decision", {
      "decision": decision,
      "decisionNote": decisionNote,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}
