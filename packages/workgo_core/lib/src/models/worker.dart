import "package:cloud_firestore/cloud_firestore.dart";
import "user_address.dart";

enum VerificationStatus { pending, approved, rejected }
enum AvailabilityStatus { online, offline, busy }
enum VisibilityStatus { hidden, pending, public, suspended }
enum VerificationStage {
  signup,
  aadhaarOfflineEkyc,
  selfieCapture,
  onDeviceLiveness,
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
  final DateTime? livenessPassedAt;
  final double? livenessScore;
  final String? selfieBase64;
  final String? selfieHash;
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

  const VerificationDetails({
    this.aadhaarVerifiedName,
    this.aadhaarMaskedNumber,
    this.aadhaarVerifiedAt,
    this.livenessPassedAt,
    this.livenessScore,
    this.selfieBase64,
    this.selfieHash,
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
  });

  factory VerificationDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VerificationDetails();
    return VerificationDetails(
      aadhaarVerifiedName: map["aadhaarVerifiedName"] as String?,
      aadhaarMaskedNumber: map["aadhaarMaskedNumber"] as String?,
      aadhaarVerifiedAt: _parseDateTime(map["aadhaarVerifiedAt"]),
      livenessPassedAt: _parseDateTime(map["livenessPassedAt"]),
      livenessScore: (map["livenessScore"] as num?)?.toDouble(),
      selfieBase64: map["selfieBase64"] as String?,
      selfieHash: map["selfieHash"] as String?,
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
    );
  }

  Map<String, dynamic> toMap() => {
    "aadhaarVerifiedName": aadhaarVerifiedName,
    "aadhaarMaskedNumber": aadhaarMaskedNumber,
    "aadhaarVerifiedAt": aadhaarVerifiedAt != null ? Timestamp.fromDate(aadhaarVerifiedAt!) : null,
    "livenessPassedAt": livenessPassedAt != null ? Timestamp.fromDate(livenessPassedAt!) : null,
    "livenessScore": livenessScore,
    "selfieBase64": selfieBase64,
    "selfieHash": selfieHash,
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
  };

  VerificationDetails copyWith({
    String? aadhaarVerifiedName,
    String? aadhaarMaskedNumber,
    DateTime? aadhaarVerifiedAt,
    DateTime? livenessPassedAt,
    double? livenessScore,
    String? selfieBase64,
    String? selfieHash,
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
  }) {
    return VerificationDetails(
      aadhaarVerifiedName: aadhaarVerifiedName ?? this.aadhaarVerifiedName,
      aadhaarMaskedNumber: aadhaarMaskedNumber ?? this.aadhaarMaskedNumber,
      aadhaarVerifiedAt: aadhaarVerifiedAt ?? this.aadhaarVerifiedAt,
      livenessPassedAt: livenessPassedAt ?? this.livenessPassedAt,
      livenessScore: livenessScore ?? this.livenessScore,
      selfieBase64: selfieBase64 ?? this.selfieBase64,
      selfieHash: selfieHash ?? this.selfieHash,
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
    required this.availabilityStatus,
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
  });

  bool get isTitan => isCheckedIn || availabilityStatus == AvailabilityStatus.online;
  bool get isApproved => verificationStatus == VerificationStatus.approved;
  bool get isPubliclyVisible => visibilityStatus == VisibilityStatus.public;

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final totalRatings = d["totalRatings"] ?? 0;
    final totalReviews = d["totalReviews"] ?? (totalRatings > 0 ? (totalRatings * 0.8).round() : 0);
    final homesServiced = d["homesServiced"] ?? (totalRatings > 0 ? totalRatings * 2 + 5 : 0);
    final rawName = d["name"] ?? d["displayName"] ?? d["artisanName"];
    final defaultName = d["isProxy"] == true ? "Artisan Partner" : "Co-op Artisan";

    final addrList = (d["addresses"] as List<dynamic>?)
            ?.map((a) => UserAddress.fromMap(a as Map<String, dynamic>))
            .toList() ??
        [];

    final baseAddrMap = d["baseAddress"] as Map<String, dynamic>?;
    final baseAddr = baseAddrMap != null
        ? UserAddress.fromMap(baseAddrMap)
        : (addrList.isNotEmpty ? addrList.firstWhere((a) => a.isDefault, orElse: () => addrList.first) : null);

    final rawVerStatus = d["verificationStatus"] ?? "pending";
    final verStatus = VerificationStatus.values.firstWhere(
      (v) => v.name == rawVerStatus,
      orElse: () => VerificationStatus.pending,
    );

    final visStatus = d["visibilityStatus"] != null
        ? VisibilityStatus.values.firstWhere(
            (v) => v.name == d["visibilityStatus"],
            orElse: () => verStatus == VerificationStatus.approved ? VisibilityStatus.public : VisibilityStatus.pending,
          )
        : (verStatus == VerificationStatus.approved ? VisibilityStatus.public : VisibilityStatus.pending);

    final verStage = d["verificationStage"] != null
        ? VerificationStage.values.firstWhere(
            (s) => s.name == d["verificationStage"],
            orElse: () => verStatus == VerificationStatus.approved ? VerificationStage.approved : VerificationStage.signup,
          )
        : (verStatus == VerificationStatus.approved ? VerificationStage.approved : VerificationStage.signup);

    final verDetails = d["verificationDetails"] != null
        ? VerificationDetails.fromMap(d["verificationDetails"] as Map<String, dynamic>)
        : null;

    return Worker(
      id: doc.id,
      userId: d["userId"] ?? "",
      name: (rawName != null && rawName.toString().trim().isNotEmpty) ? rawName.toString().trim() : defaultName,
      organizationId: d["organizationId"],
      skills: List<String>.from(d["skills"] ?? []),
      experienceYears: d["experienceYears"] ?? 0,
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
      location: d["location"],
      serviceRadiusKm: (d["serviceRadiusKm"] ?? 5.0).toDouble(),
      distanceKm: (d["distanceKm"] ?? 2.4).toDouble(),
      baseRate: (d["baseRate"] ?? 149.0).toDouble(),
      perKmRate: (d["perKmRate"] ?? 12.0).toDouble(),
      verificationBadge: d["verificationBadge"] ?? (rawVerStatus == "approved" ? "Co-op Certified" : ""),
      availabilityStatus: AvailabilityStatus.values.firstWhere(
        (a) => a.name == (d["availabilityStatus"] ?? "offline"),
        orElse: () => AvailabilityStatus.offline,
      ),
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
      isCheckedIn: d["isCheckedIn"] ?? (d["availabilityStatus"] == "online"),
      checkedInAt: (d["checkedInAt"] as Timestamp?)?.toDate(),
      passionBio: d["passionBio"],
      addresses: addrList,
      baseAddress: baseAddr,
      latitude: (d["latitude"] as num?)?.toDouble() ?? baseAddr?.latitude,
      longitude: (d["longitude"] as num?)?.toDouble() ?? baseAddr?.longitude,
      baseArea: d["baseArea"] ?? baseAddr?.shortSummary,
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
    );
  }
}
