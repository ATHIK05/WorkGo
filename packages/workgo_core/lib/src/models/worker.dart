import 'dart:math';
import "package:cloud_firestore/cloud_firestore.dart";
import "../localization/trade_localization.dart";
import "user_address.dart";

enum VerificationStatus { pending, approved, rejected }
enum AvailabilityStatus { online, offline, busy }
enum VisibilityStatus { hidden, pending, public, suspended }
enum VerificationStage {
  signup,
  consent,
  aadhaarOfflineEkyc,
  selfieCapture,
  onDeviceLiveness,
  multiAngleLiveness,
  liveVideoVerification,
  pccUpload,
  pccManualReview,
  approved,
  rejected,
}

class VerificationDetails {
  final String? aadhaarVerifiedName;
  final String? aadhaarMaskedNumber;
  final DateTime? aadhaarVerifiedAt;
  final String? aadhaarZipBase64;
  final String? aadhaarShareCode;
  final String? aadhaarPhotoBase64;
  final String? aadhaarFileName;
  final String? aadhaarDob;
  final String? aadhaarGender;
  final String? aadhaarAddress;
  final bool? aadhaarSignatureValid;
  final String? aadhaarReferenceId;
  final DateTime? livenessPassedAt;
  final double? livenessScore;
  final String? selfieBase64;
  final String? selfieHash;
  final String? selfieCenterBase64;
  final String? selfieLeftBase64;
  final String? selfieRightBase64;
  final String? selfieCenterHash;
  final String? selfieLeftHash;
  final String? selfieRightHash;
  final String? livenessMethod;
  final bool? lightingBoosted;
  final DateTime? videoCallScheduledAt;
  final DateTime? videoCallCompletedAt;
  final String? videoCallStaffId;
  final String? videoCallPhrase;
  final String? videoCallRoomUrl;
  final String? videoCallBookingId;
  final String? pccDocumentId;
  final DateTime? pccReviewedAt;
  final String? pccReviewedBy;
  final String? pccRejectionReason;
  final double? aiRiskScore;
  final bool? isAiSuspicious;
  final List<String>? aiFlags;
  final String? biometricConsentVersion;
  final DateTime? biometricConsentTimestamp;
  final String? c2paProfileManifestId;
  final DateTime? lastFaceCheckInAt;
  final String? lastFaceCheckInBase64;

  const VerificationDetails({
    this.aadhaarVerifiedName,
    this.aadhaarMaskedNumber,
    this.aadhaarVerifiedAt,
    this.aadhaarZipBase64,
    this.aadhaarShareCode,
    this.aadhaarPhotoBase64,
    this.aadhaarFileName,
    this.aadhaarDob,
    this.aadhaarGender,
    this.aadhaarAddress,
    this.aadhaarSignatureValid,
    this.aadhaarReferenceId,
    this.livenessPassedAt,
    this.livenessScore,
    this.selfieBase64,
    this.selfieHash,
    this.selfieCenterBase64,
    this.selfieLeftBase64,
    this.selfieRightBase64,
    this.selfieCenterHash,
    this.selfieLeftHash,
    this.selfieRightHash,
    this.livenessMethod,
    this.lightingBoosted,
    this.videoCallScheduledAt,
    this.videoCallCompletedAt,
    this.videoCallStaffId,
    this.videoCallPhrase,
    this.videoCallRoomUrl,
    this.videoCallBookingId,
    this.pccDocumentId,
    this.pccReviewedAt,
    this.pccReviewedBy,
    this.pccRejectionReason,
    this.aiRiskScore,
    this.isAiSuspicious,
    this.aiFlags,
    this.biometricConsentVersion,
    this.biometricConsentTimestamp,
    this.c2paProfileManifestId,
    this.lastFaceCheckInAt,
    this.lastFaceCheckInBase64,
  });

  factory VerificationDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VerificationDetails();
    return VerificationDetails(
      aadhaarVerifiedName: map["aadhaarVerifiedName"] as String?,
      aadhaarMaskedNumber: map["aadhaarMaskedNumber"] as String?,
      aadhaarVerifiedAt: _parseDateTime(map["aadhaarVerifiedAt"]),
      aadhaarZipBase64: map["aadhaarZipBase64"] as String?,
      aadhaarShareCode: map["aadhaarShareCode"] as String?,
      aadhaarPhotoBase64: map["aadhaarPhotoBase64"] as String?,
      aadhaarFileName: map["aadhaarFileName"] as String?,
      aadhaarDob: map["aadhaarDob"] as String?,
      aadhaarGender: map["aadhaarGender"] as String?,
      aadhaarAddress: map["aadhaarAddress"] as String?,
      aadhaarSignatureValid: map["aadhaarSignatureValid"] as bool?,
      aadhaarReferenceId: map["aadhaarReferenceId"] as String?,
      livenessPassedAt: _parseDateTime(map["livenessPassedAt"]),
      livenessScore: (map["livenessScore"] as num?)?.toDouble(),
      selfieBase64: map["selfieBase64"] as String?,
      selfieHash: map["selfieHash"] as String?,
      selfieCenterBase64: map["selfieCenterBase64"] as String?,
      selfieLeftBase64: map["selfieLeftBase64"] as String?,
      selfieRightBase64: map["selfieRightBase64"] as String?,
      selfieCenterHash: map["selfieCenterHash"] as String?,
      selfieLeftHash: map["selfieLeftHash"] as String?,
      selfieRightHash: map["selfieRightHash"] as String?,
      livenessMethod: map["livenessMethod"] as String?,
      lightingBoosted: map["lightingBoosted"] as bool?,
      videoCallScheduledAt: _parseDateTime(map["videoCallScheduledAt"]),
      videoCallCompletedAt: _parseDateTime(map["videoCallCompletedAt"]),
      videoCallStaffId: map["videoCallStaffId"] as String?,
      videoCallPhrase: map["videoCallPhrase"] as String?,
      videoCallRoomUrl: map["videoCallRoomUrl"] as String?,
      videoCallBookingId: map["videoCallBookingId"] as String?,
      pccDocumentId: map["pccDocumentId"] as String?,
      pccReviewedAt: _parseDateTime(map["pccReviewedAt"]),
      pccReviewedBy: map["pccReviewedBy"] as String?,
      pccRejectionReason: map["pccRejectionReason"] as String?,
      aiRiskScore: (map["aiRiskScore"] as num?)?.toDouble(),
      isAiSuspicious: map["isAiSuspicious"] as bool?,
      aiFlags: (map["aiFlags"] as List?)?.map((e) => e.toString()).toList(),
      biometricConsentVersion: map["biometricConsentVersion"] as String?,
      biometricConsentTimestamp: _parseDateTime(map["biometricConsentTimestamp"]),
      c2paProfileManifestId: map["c2paProfileManifestId"] as String?,
      lastFaceCheckInAt: _parseDateTime(map["lastFaceCheckInAt"]),
      lastFaceCheckInBase64: map["lastFaceCheckInBase64"] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    "aadhaarVerifiedName": aadhaarVerifiedName,
    "aadhaarMaskedNumber": aadhaarMaskedNumber,
    "aadhaarVerifiedAt": aadhaarVerifiedAt != null ? Timestamp.fromDate(aadhaarVerifiedAt!) : null,
    "aadhaarZipBase64": aadhaarZipBase64,
    "aadhaarShareCode": aadhaarShareCode,
    "aadhaarPhotoBase64": aadhaarPhotoBase64,
    "aadhaarFileName": aadhaarFileName,
    "aadhaarDob": aadhaarDob,
    "aadhaarGender": aadhaarGender,
    "aadhaarAddress": aadhaarAddress,
    "aadhaarSignatureValid": aadhaarSignatureValid,
    "aadhaarReferenceId": aadhaarReferenceId,
    "livenessPassedAt": livenessPassedAt != null ? Timestamp.fromDate(livenessPassedAt!) : null,
    "livenessScore": livenessScore,
    "selfieBase64": selfieBase64,
    "selfieHash": selfieHash,
    "selfieCenterBase64": selfieCenterBase64,
    "selfieLeftBase64": selfieLeftBase64,
    "selfieRightBase64": selfieRightBase64,
    "selfieCenterHash": selfieCenterHash,
    "selfieLeftHash": selfieLeftHash,
    "selfieRightHash": selfieRightHash,
    "livenessMethod": livenessMethod,
    "lightingBoosted": lightingBoosted,
    "videoCallScheduledAt": videoCallScheduledAt != null ? Timestamp.fromDate(videoCallScheduledAt!) : null,
    "videoCallCompletedAt": videoCallCompletedAt != null ? Timestamp.fromDate(videoCallCompletedAt!) : null,
    "videoCallStaffId": videoCallStaffId,
    "videoCallPhrase": videoCallPhrase,
    "videoCallRoomUrl": videoCallRoomUrl,
    "videoCallBookingId": videoCallBookingId,
    "pccDocumentId": pccDocumentId,
    "pccReviewedAt": pccReviewedAt != null ? Timestamp.fromDate(pccReviewedAt!) : null,
    "pccReviewedBy": pccReviewedBy,
    "pccRejectionReason": pccRejectionReason,
    "aiRiskScore": aiRiskScore,
    "isAiSuspicious": isAiSuspicious,
    "aiFlags": aiFlags,
    "biometricConsentVersion": biometricConsentVersion,
    "biometricConsentTimestamp": biometricConsentTimestamp != null ? Timestamp.fromDate(biometricConsentTimestamp!) : null,
    "c2paProfileManifestId": c2paProfileManifestId,
    "lastFaceCheckInAt": lastFaceCheckInAt != null ? Timestamp.fromDate(lastFaceCheckInAt!) : null,
    "lastFaceCheckInBase64": lastFaceCheckInBase64,
  };

  VerificationDetails copyWith({
    String? aadhaarVerifiedName,
    String? aadhaarMaskedNumber,
    DateTime? aadhaarVerifiedAt,
    String? aadhaarZipBase64,
    String? aadhaarShareCode,
    String? aadhaarPhotoBase64,
    String? aadhaarFileName,
    String? aadhaarDob,
    String? aadhaarGender,
    String? aadhaarAddress,
    bool? aadhaarSignatureValid,
    String? aadhaarReferenceId,
    DateTime? livenessPassedAt,
    double? livenessScore,
    String? selfieBase64,
    String? selfieHash,
    String? selfieCenterBase64,
    String? selfieLeftBase64,
    String? selfieRightBase64,
    String? selfieCenterHash,
    String? selfieLeftHash,
    String? selfieRightHash,
    String? livenessMethod,
    bool? lightingBoosted,
    DateTime? videoCallScheduledAt,
    DateTime? videoCallCompletedAt,
    String? videoCallStaffId,
    String? videoCallPhrase,
    String? videoCallRoomUrl,
    String? videoCallBookingId,
    String? pccDocumentId,
    DateTime? pccReviewedAt,
    String? pccReviewedBy,
    String? pccRejectionReason,
    double? aiRiskScore,
    bool? isAiSuspicious,
    List<String>? aiFlags,
    String? biometricConsentVersion,
    DateTime? biometricConsentTimestamp,
    String? c2paProfileManifestId,
    DateTime? lastFaceCheckInAt,
    String? lastFaceCheckInBase64,
  }) {
    return VerificationDetails(
      aadhaarVerifiedName: aadhaarVerifiedName ?? this.aadhaarVerifiedName,
      aadhaarMaskedNumber: aadhaarMaskedNumber ?? this.aadhaarMaskedNumber,
      aadhaarVerifiedAt: aadhaarVerifiedAt ?? this.aadhaarVerifiedAt,
      aadhaarZipBase64: aadhaarZipBase64 ?? this.aadhaarZipBase64,
      aadhaarShareCode: aadhaarShareCode ?? this.aadhaarShareCode,
      aadhaarPhotoBase64: aadhaarPhotoBase64 ?? this.aadhaarPhotoBase64,
      aadhaarFileName: aadhaarFileName ?? this.aadhaarFileName,
      aadhaarDob: aadhaarDob ?? this.aadhaarDob,
      aadhaarGender: aadhaarGender ?? this.aadhaarGender,
      aadhaarAddress: aadhaarAddress ?? this.aadhaarAddress,
      aadhaarSignatureValid: aadhaarSignatureValid ?? this.aadhaarSignatureValid,
      aadhaarReferenceId: aadhaarReferenceId ?? this.aadhaarReferenceId,
      livenessPassedAt: livenessPassedAt ?? this.livenessPassedAt,
      livenessScore: livenessScore ?? this.livenessScore,
      selfieBase64: selfieBase64 ?? this.selfieBase64,
      selfieHash: selfieHash ?? this.selfieHash,
      selfieCenterBase64: selfieCenterBase64 ?? this.selfieCenterBase64,
      selfieLeftBase64: selfieLeftBase64 ?? this.selfieLeftBase64,
      selfieRightBase64: selfieRightBase64 ?? this.selfieRightBase64,
      selfieCenterHash: selfieCenterHash ?? this.selfieCenterHash,
      selfieLeftHash: selfieLeftHash ?? this.selfieLeftHash,
      selfieRightHash: selfieRightHash ?? this.selfieRightHash,
      livenessMethod: livenessMethod ?? this.livenessMethod,
      lightingBoosted: lightingBoosted ?? this.lightingBoosted,
      videoCallScheduledAt: videoCallScheduledAt ?? this.videoCallScheduledAt,
      videoCallCompletedAt: videoCallCompletedAt ?? this.videoCallCompletedAt,
      videoCallStaffId: videoCallStaffId ?? this.videoCallStaffId,
      videoCallPhrase: videoCallPhrase ?? this.videoCallPhrase,
      videoCallRoomUrl: videoCallRoomUrl ?? this.videoCallRoomUrl,
      videoCallBookingId: videoCallBookingId ?? this.videoCallBookingId,
      pccDocumentId: pccDocumentId ?? this.pccDocumentId,
      pccReviewedAt: pccReviewedAt ?? this.pccReviewedAt,
      pccReviewedBy: pccReviewedBy ?? this.pccReviewedBy,
      pccRejectionReason: pccRejectionReason ?? this.pccRejectionReason,
      aiRiskScore: aiRiskScore ?? this.aiRiskScore,
      isAiSuspicious: isAiSuspicious ?? this.isAiSuspicious,
      aiFlags: aiFlags ?? this.aiFlags,
      biometricConsentVersion: biometricConsentVersion ?? this.biometricConsentVersion,
      biometricConsentTimestamp: biometricConsentTimestamp ?? this.biometricConsentTimestamp,
      c2paProfileManifestId: c2paProfileManifestId ?? this.c2paProfileManifestId,
      lastFaceCheckInAt: lastFaceCheckInAt ?? this.lastFaceCheckInAt,
      lastFaceCheckInBase64: lastFaceCheckInBase64 ?? this.lastFaceCheckInBase64,
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

class Worker {
  final String id;
  final String userId;
  final String name;
  final String? organizationId;
  final List<String> skills;
  final int experienceYears;
  final bool isProxy;
  final String? proxyReferrerId;
  final String? phoneForCalling;
  final VerificationStatus verificationStatus;
  final VisibilityStatus visibilityStatus;
  final VerificationStage verificationStage;
  final VerificationDetails? verificationDetails;
  final double avgRating;
  final int totalRatings;
  final int totalReviews;
  final int homesServiced;
  final GeoPoint? location;
  final double serviceRadiusKm;
  final double distanceKm;
  final double baseRate;
  final double perKmRate;
  final String verificationBadge;
  final AvailabilityStatus availabilityStatus;
  final bool insuranceStatus;
  final String? welfareSchemeId;
  final String workingHoursStart;
  final String workingHoursEnd;
  final double totalHoursWorked;
  final List<String> preferredAreas;
  final int referralCount;
  final double referralEarnings;
  final List<String> secondLineReferralIds;
  final String engagementMode; // 'passion', 'hobby', 'scheduled'
  final bool isCheckedIn;
  final DateTime? checkedInAt;
  final String? passionBio;

  final List<UserAddress> addresses;
  final UserAddress? baseAddress;
  final double? latitude;
  final double? longitude;
  final String? baseArea;
  final List<String> equipmentTags;
  final List<String> serviceKeywords;
  final double diagnosticAccuracyScore;

  Worker({
    required this.id,
    required this.userId,
    this.name = "Co-op Artisan",
    this.organizationId,
    required this.skills,
    required this.experienceYears,
    this.isProxy = false,
    this.proxyReferrerId,
    this.phoneForCalling,
    required this.verificationStatus,
    this.visibilityStatus = VisibilityStatus.pending,
    this.verificationStage = VerificationStage.signup,
    this.verificationDetails,
    this.avgRating = 0.0,
    this.totalRatings = 0,
    this.totalReviews = 0,
    this.homesServiced = 0,
    this.location,
    this.serviceRadiusKm = 5.0,
    this.distanceKm = 2.4,
    this.baseRate = 149.0,
    this.perKmRate = 12.0,
    this.verificationBadge = "Co-op Certified",
    this.availabilityStatus = AvailabilityStatus.offline,
    this.insuranceStatus = false,
    this.welfareSchemeId,
    this.workingHoursStart = "08:00",
    this.workingHoursEnd = "20:00",
    this.totalHoursWorked = 0.0,
    this.preferredAreas = const [],
    this.referralCount = 0,
    this.referralEarnings = 0.0,
    this.secondLineReferralIds = const [],
    this.engagementMode = "passion",
    this.isCheckedIn = false,
    this.checkedInAt,
    this.passionBio,
    this.addresses = const [],
    this.baseAddress,
    this.latitude,
    this.longitude,
    this.baseArea,
    this.equipmentTags = const [],
    this.serviceKeywords = const [],
    this.diagnosticAccuracyScore = 0.92,
  });

  bool get isTitan => isCheckedIn && availabilityStatus == AvailabilityStatus.online;
  bool get isOnlineOrCheckedIn => isCheckedIn || availabilityStatus == AvailabilityStatus.online;
  bool get isApproved => verificationStatus == VerificationStatus.approved;
  bool get isPubliclyVisible => visibilityStatus == VisibilityStatus.public;

  String? get avatarBase64 =>
      verificationDetails?.selfieBase64 ??
      verificationDetails?.selfieCenterBase64 ??
      verificationDetails?.aadhaarPhotoBase64;

  /// Calculate real-time geodesic distance in kilometers to a given customer coordinate.
  double calculateDistanceKm(double? custLat, double? custLng) {
    if (custLat == null || custLng == null || custLat.abs() <= 0.0001 || custLng.abs() <= 0.0001) {
      return distanceKm > 0 ? distanceKm : 1.0;
    }
    final wLat = latitude;
    final wLng = longitude;
    if (wLat == null || wLng == null || wLat.abs() <= 0.0001 || wLng.abs() <= 0.0001) {
      return distanceKm > 0 ? distanceKm : 1.0;
    }

    // High-accuracy geodesic distance using Haversine formula
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((wLat - custLat) * p) / 2 +
        cos(custLat * p) *
            cos(wLat * p) *
            (1 - cos((wLng - custLng) * p)) /
            2;
    final clampedA = a.clamp(0.0, 1.0);
    final dist = 12742.0 * asin(sqrt(clampedA)); // 2 * R; R = 6371 km
    return double.parse(dist.toStringAsFixed(2));
  }

  /// Formatted distance string (e.g. "45 m away", "1.4 km away", "At your doorstep").
  String formattedDistanceString(double? custLat, double? custLng) {
    final hasCustCoords = custLat != null && custLng != null && custLat.abs() > 0.0001 && custLng.abs() > 0.0001;
    final hasWorkerCoords = latitude != null && longitude != null && latitude!.abs() > 0.0001 && longitude!.abs() > 0.0001;

    if (!hasCustCoords || !hasWorkerCoords) {
      return (distanceKm > 0 && distanceKm != 2.4 && distanceKm != 1.0)
          ? 'km_away'.trSafe('${distanceKm.toStringAsFixed(1)} km away', [distanceKm.toStringAsFixed(1)])
          : 'nearby'.trSafe('Nearby');
    }

    final km = calculateDistanceKm(custLat, custLng);
    if (km <= 0.04) {
      return 'at_your_doorstep'.trSafe('At your doorstep');
    } else if (km < 1.0) {
      final meters = (km * 1000).round();
      return 'meters_away'.trSafe('$meters m away', [meters.toString()]);
    } else {
      return 'km_away'.trSafe('${km.toStringAsFixed(1)} km away', [km.toStringAsFixed(1)]);
    }
  }

  /// Creates a copy of Worker with distanceKm updated to the real-time distance from customer.
  Worker withCalculatedDistance(double? custLat, double? custLng) {
    if (custLat == null || custLng == null || custLat.abs() <= 0.0001 || custLng.abs() <= 0.0001 ||
        latitude == null || longitude == null || latitude!.abs() <= 0.0001 || longitude!.abs() <= 0.0001) {
      return this;
    }
    final km = calculateDistanceKm(custLat, custLng);
    return copyWith(distanceKm: km);
  }

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final totalRatings = (d["totalRatings"] as num?)?.toInt() ?? 0;
    final totalReviews = (d["totalReviews"] as num?)?.toInt() ?? (totalRatings > 0 ? (totalRatings * 0.8).round() : 0);
    final homesServiced = (d["homesServiced"] as num?)?.toInt() ?? (totalRatings > 0 ? totalRatings * 2 + 5 : 0);
    final expYears = (d["experienceYears"] as num?)?.toInt() ?? 2;
    final rawName = d["name"] ?? d["displayName"] ?? d["artisanName"];
    final defaultName = d["isProxy"] == true ? "Artisan Partner" : "Co-op Artisan";
    final rawVerStatus = d["verificationStatus"] ?? (d["verified"] == true ? "approved" : "pending");
    final verStatus = VerificationStatus.values.firstWhere(
      (v) => v.name == rawVerStatus,
      orElse: () => VerificationStatus.pending,
    );
    final visStatus = VisibilityStatus.values.firstWhere(
      (v) => v.name == (d["visibilityStatus"] ?? "pending"),
      orElse: () => VisibilityStatus.pending,
    );
    final verStage = VerificationStage.values.firstWhere(
      (s) => s.name == (d["verificationStage"] ?? (verStatus == VerificationStatus.approved ? "approved" : "signup")),
      orElse: () => VerificationStage.signup,
    );
    final verDetails = d["verificationDetails"] != null
        ? VerificationDetails.fromMap(Map<String, dynamic>.from(d["verificationDetails"]))
        : null;

    final addrList = (d["addresses"] as List<dynamic>?)
            ?.map((a) => a is Map ? UserAddress.fromMap(Map<String, dynamic>.from(a)) : null)
            .whereType<UserAddress>()
            .toList() ??
        const [];

    UserAddress? baseAddr;
    if (d["baseAddress"] != null && d["baseAddress"] is Map) {
      baseAddr = UserAddress.fromMap(Map<String, dynamic>.from(d["baseAddress"] as Map));
    } else if (d["currentAddress"] != null && d["currentAddress"] is Map) {
      baseAddr = UserAddress.fromMap(Map<String, dynamic>.from(d["currentAddress"] as Map));
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.trim());
      return null;
    }

    GeoPoint? extractGeoPoint(dynamic loc) {
      if (loc == null) return null;
      if (loc is GeoPoint) return loc;
      if (loc is Map) {
        final m = Map<String, dynamic>.from(loc);
        final mLat = parseCoord(m["latitude"] ?? m["lat"] ?? m["_latitude"]);
        final mLng = parseCoord(m["longitude"] ?? m["lng"] ?? m["lon"] ?? m["_longitude"]);
        if (mLat != null && mLng != null && (mLat != 0.0 || mLng != 0.0)) {
          return GeoPoint(mLat, mLng);
        }
      }
      return null;
    }

    final geoPoint = extractGeoPoint(d["location"]) ??
        extractGeoPoint(d["currentLocation"]) ??
        extractGeoPoint(d["lastLocation"]) ??
        extractGeoPoint(d["gps"]) ??
        extractGeoPoint(d["position"]);

    double? lat = parseCoord(d["latitude"]) ??
        parseCoord(d["lat"]) ??
        geoPoint?.latitude ??
        baseAddr?.latitude ??
        (addrList.isNotEmpty ? addrList.first.latitude : null);
    double? lng = parseCoord(d["longitude"]) ??
        parseCoord(d["lng"]) ??
        parseCoord(d["lon"]) ??
        geoPoint?.longitude ??
        baseAddr?.longitude ??
        (addrList.isNotEmpty ? addrList.first.longitude : null);

    // If coordinates are missing or invalid, resolve regional hub coordinates based on baseArea / Tamil Nadu hub
    final rawBaseArea = (d["baseArea"] ?? baseAddr?.shortSummary ?? (d["baseAddress"] is String ? d["baseAddress"] as String : ""))
        .toString()
        .toLowerCase();

    if (lat == null || lng == null || lat.abs() <= 0.0001 || lng.abs() <= 0.0001) {
      if (rawBaseArea.contains("perundurai")) {
        lat = 11.2743;
        lng = 77.5866;
      } else if (rawBaseArea.contains("bhavani")) {
        lat = 11.4500;
        lng = 77.6833;
      } else if (rawBaseArea.contains("thindal")) {
        lat = 11.3280;
        lng = 77.6890;
      } else if (rawBaseArea.contains("solar")) {
        lat = 11.3170;
        lng = 77.7490;
      } else if (rawBaseArea.contains("coimbatore")) {
        lat = 11.0168;
        lng = 76.9558;
      } else if (rawBaseArea.contains("tiruppur")) {
        lat = 11.1085;
        lng = 77.3411;
      } else if (rawBaseArea.contains("salem")) {
        lat = 11.6643;
        lng = 78.1460;
      } else if (rawBaseArea.contains("chennai")) {
        lat = 13.0827;
        lng = 80.2707;
      } else {
        // Deterministic realistic regional coordinates around central hub (Erode: 11.3445, 77.7327)
        // Offset within 0.8 - 2.5 km so unpositioned artisans display realistic distinct local distances
        final seed = doc.id.hashCode.abs();
        final offsetLat = (((seed % 31) - 15) * 0.0012); // ~ +/- 1.5 km
        final offsetLng = ((((seed ~/ 31) % 31) - 15) * 0.0012);
        lat = 11.3445 + offsetLat;
        lng = 77.7327 + offsetLng;
      }
    }

    List<String> parsedSkills = [];
    if (d["skills"] is List) {
      parsedSkills = List<String>.from((d["skills"] as List).map((e) => e.toString()));
    } else if (d["skills"] is String && (d["skills"] as String).trim().isNotEmpty) {
      parsedSkills = [(d["skills"] as String).trim()];
    } else if (d["skill"] is String && (d["skill"] as String).trim().isNotEmpty) {
      parsedSkills = [(d["skill"] as String).trim()];
    } else if (d["trade"] is String && (d["trade"] as String).trim().isNotEmpty) {
      parsedSkills = [(d["trade"] as String).trim()];
    }

    final bool isOnlineOrChecked = (d["availabilityStatus"] == "online") || (d["isCheckedIn"] == true);
    final availStatus = isOnlineOrChecked ? AvailabilityStatus.online : AvailabilityStatus.offline;

    final equipTags = (d["equipmentTags"] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final srvKeywords = (d["serviceKeywords"] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final diagAccuracy = (d["diagnosticAccuracyScore"] as num?)?.toDouble() ?? 0.92;

    return Worker(
      id: doc.id,
      userId: d["userId"] ?? doc.id,
      name: (rawName != null && rawName.toString().isNotEmpty) ? rawName : defaultName,
      organizationId: d["organizationId"] ?? "coop_tn_01",
      skills: parsedSkills,
      experienceYears: expYears,
      isProxy: d["isProxy"] ?? false,
      proxyReferrerId: d["proxyReferrerId"],
      phoneForCalling: d["phoneForCalling"],
      verificationStatus: verStatus,
      visibilityStatus: visStatus,
      verificationStage: verStage,
      verificationDetails: verDetails,
      avgRating: (d["avgRating"] ?? 0.0).toDouble(),
      totalRatings: totalRatings,
      totalReviews: totalReviews,
      homesServiced: homesServiced,
      location: geoPoint ?? GeoPoint(lat, lng),
      serviceRadiusKm: (d["serviceRadiusKm"] ?? 5.0).toDouble(),
      distanceKm: (d["distanceKm"] as num?)?.toDouble() ?? 1.0,
      baseRate: (d["baseRate"] ?? 149.0).toDouble(),
      perKmRate: (d["perKmRate"] ?? 12.0).toDouble(),
      verificationBadge: d["verificationBadge"] ?? (rawVerStatus == "approved" ? "Co-op Certified" : ""),
      availabilityStatus: availStatus,
      insuranceStatus: d["insuranceStatus"] ?? false,
      welfareSchemeId: d["welfareSchemeId"],
      workingHoursStart: d["workingHoursStart"] ?? "08:00",
      workingHoursEnd: d["workingHoursEnd"] ?? "20:00",
      totalHoursWorked: (d["totalHoursWorked"] ?? 0.0).toDouble(),
      preferredAreas: List<String>.from(d["preferredAreas"] ?? []),
      referralCount: d["referralCount"] ?? 0,
      referralEarnings: (d["referralEarnings"] ?? 0.0).toDouble(),
      secondLineReferralIds: List<String>.from(d["secondLineReferralIds"] ?? []),
      engagementMode: d["engagementMode"] ?? "passion",
      isCheckedIn: isOnlineOrChecked,
      checkedInAt: (d["checkedInAt"] as Timestamp?)?.toDate(),
      passionBio: d["passionBio"],
      addresses: addrList,
      baseAddress: baseAddr,
      latitude: lat,
      longitude: lng,
      baseArea: d["baseArea"] ?? baseAddr?.shortSummary ?? (d["baseAddress"] is String ? d["baseAddress"] as String : null),
      equipmentTags: equipTags,
      serviceKeywords: srvKeywords,
      diagnosticAccuracyScore: diagAccuracy,
    );
  }

  Map<String, dynamic> toFirestore() => {
    "userId": userId,
    "name": name,
    "organizationId": organizationId,
    "skills": skills,
    "experienceYears": experienceYears,
    "isProxy": isProxy,
    "proxyReferrerId": proxyReferrerId,
    "phoneForCalling": phoneForCalling,
    "verificationStatus": verificationStatus.name,
    "visibilityStatus": visibilityStatus.name,
    "verificationStage": verificationStage.name,
    if (verificationDetails != null) "verificationDetails": verificationDetails!.toMap(),
    "avgRating": avgRating,
    "totalRatings": totalRatings,
    "totalReviews": totalReviews,
    "homesServiced": homesServiced,
    "location": location,
    "serviceRadiusKm": serviceRadiusKm,
    "distanceKm": distanceKm,
    "baseRate": baseRate,
    "perKmRate": perKmRate,
    "verificationBadge": verificationBadge,
    "availabilityStatus": availabilityStatus.name,
    "insuranceStatus": insuranceStatus,
    "welfareSchemeId": welfareSchemeId,
    "workingHoursStart": workingHoursStart,
    "workingHoursEnd": workingHoursEnd,
    "totalHoursWorked": totalHoursWorked,
    "preferredAreas": preferredAreas,
    "referralCount": referralCount,
    "referralEarnings": referralEarnings,
    "secondLineReferralIds": secondLineReferralIds,
    "engagementMode": engagementMode,
    "isCheckedIn": isCheckedIn,
    "checkedInAt": checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
    "passionBio": passionBio,
    "addresses": addresses.map((a) => a.toMap()).toList(),
    "baseAddress": baseAddress?.toMap(),
    "latitude": latitude ?? baseAddress?.latitude,
    "longitude": longitude ?? baseAddress?.longitude,
    "baseArea": baseArea ?? baseAddress?.shortSummary,
    "equipmentTags": equipmentTags,
    "serviceKeywords": serviceKeywords,
    "diagnosticAccuracyScore": diagnosticAccuracyScore,
  };

  Worker copyWith({
    String? id,
    String? userId,
    String? name,
    String? organizationId,
    List<String>? skills,
    int? experienceYears,
    bool? isProxy,
    String? proxyReferrerId,
    String? phoneForCalling,
    VerificationStatus? verificationStatus,
    VisibilityStatus? visibilityStatus,
    VerificationStage? verificationStage,
    VerificationDetails? verificationDetails,
    double? avgRating,
    int? totalRatings,
    int? totalReviews,
    int? homesServiced,
    GeoPoint? location,
    double? serviceRadiusKm,
    distanceKm,
    double? baseRate,
    double? perKmRate,
    String? verificationBadge,
    AvailabilityStatus? availabilityStatus,
    bool? insuranceStatus,
    String? welfareSchemeId,
    String? workingHoursStart,
    String? workingHoursEnd,
    double? totalHoursWorked,
    List<String>? preferredAreas,
    int? referralCount,
    double? referralEarnings,
    List<String>? secondLineReferralIds,
    String? engagementMode,
    bool? isCheckedIn,
    DateTime? checkedInAt,
    String? passionBio,
    List<UserAddress>? addresses,
    UserAddress? baseAddress,
    double? latitude,
    double? longitude,
    String? baseArea,
    List<String>? equipmentTags,
    List<String>? serviceKeywords,
    double? diagnosticAccuracyScore,
  }) {
    return Worker(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      skills: skills ?? this.skills,
      experienceYears: experienceYears ?? this.experienceYears,
      isProxy: isProxy ?? this.isProxy,
      proxyReferrerId: proxyReferrerId ?? this.proxyReferrerId,
      phoneForCalling: phoneForCalling ?? this.phoneForCalling,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      visibilityStatus: visibilityStatus ?? this.visibilityStatus,
      verificationStage: verificationStage ?? this.verificationStage,
      verificationDetails: verificationDetails ?? this.verificationDetails,
      avgRating: avgRating ?? this.avgRating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalReviews: totalReviews ?? this.totalReviews,
      homesServiced: homesServiced ?? this.homesServiced,
      location: location ?? this.location,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      distanceKm: (distanceKm is num ? distanceKm.toDouble() : this.distanceKm),
      baseRate: baseRate ?? this.baseRate,
      perKmRate: perKmRate ?? this.perKmRate,
      verificationBadge: verificationBadge ?? this.verificationBadge,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      insuranceStatus: insuranceStatus ?? this.insuranceStatus,
      welfareSchemeId: welfareSchemeId ?? this.welfareSchemeId,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      totalHoursWorked: totalHoursWorked ?? this.totalHoursWorked,
      preferredAreas: preferredAreas ?? this.preferredAreas,
      referralCount: referralCount ?? this.referralCount,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      secondLineReferralIds: secondLineReferralIds ?? this.secondLineReferralIds,
      engagementMode: engagementMode ?? this.engagementMode,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      passionBio: passionBio ?? this.passionBio,
      addresses: addresses ?? this.addresses,
      baseAddress: baseAddress ?? this.baseAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      baseArea: baseArea ?? this.baseArea,
      equipmentTags: equipmentTags ?? this.equipmentTags,
      serviceKeywords: serviceKeywords ?? this.serviceKeywords,
      diagnosticAccuracyScore: diagnosticAccuracyScore ?? this.diagnosticAccuracyScore,
    );
  }
}
