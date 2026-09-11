import "package:cloud_firestore/cloud_firestore.dart";
import "user_address.dart";

enum UserRole { customer, worker, admin }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? avatarBase64;
  final UserRole role;
  final String? preferredLanguage; // e.g. "en", "hi", "ta" — managed by easy_localization
  final String region;
  final String? organizationId;

  final String? phoneNumber;
  final bool isPhoneVerified;
  final bool hasBackupPassword;
  final String? address;
  final GeoPoint? location;
  final bool isOnboardingComplete;

  final List<UserAddress> addresses;
  final UserAddress? currentAddress;
  final double? latitude;
  final double? longitude;
  final String? primaryArea;
  final int trustScore;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.avatarBase64,
    required this.role,
    this.preferredLanguage,
    required this.region,
    this.organizationId,
    this.phoneNumber,
    this.isPhoneVerified = false,
    this.hasBackupPassword = false,
    this.address,
    this.location,
    this.isOnboardingComplete = true,
    this.addresses = const [],
    this.currentAddress,
    this.latitude,
    this.longitude,
    this.primaryArea,
    this.trustScore = 0,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final addrList = (d["addresses"] as List<dynamic>?)
            ?.map((a) => UserAddress.fromMap(a as Map<String, dynamic>))
            .toList() ??
        [];

    final currentAddrMap = d["currentAddress"] as Map<String, dynamic>?;
    final currentAddr = currentAddrMap != null
        ? UserAddress.fromMap(currentAddrMap)
        : (addrList.isNotEmpty ? addrList.firstWhere((a) => a.isDefault, orElse: () => addrList.first) : null);

    return AppUser(
      uid: doc.id,
      email: d["email"] ?? "",
      displayName: d["displayName"] ?? "",
      photoUrl: d["photoUrl"],
      avatarBase64: d["avatarBase64"] ?? d["photoUrl"],
      role: UserRole.values.firstWhere(
        (r) => r.name == (d["role"] ?? "customer"),
        orElse: () => UserRole.customer,
      ),
      preferredLanguage: d["preferredLanguage"],
      region: d["region"] ?? "",
      organizationId: d["organizationId"],
      phoneNumber: d["phoneNumber"] ?? d["phone"] ?? d["mobile"] ?? d["phoneForCalling"],
      isPhoneVerified: d["phoneVerified"] == true || d["isPhoneVerified"] == true,
      hasBackupPassword: d["hasBackupPassword"] == true,
      address: d["address"],
      location: d["location"],
      isOnboardingComplete: d["isOnboardingComplete"] ?? true,
      addresses: addrList,
      currentAddress: currentAddr,
      latitude: (d["latitude"] as num?)?.toDouble() ?? currentAddr?.latitude,
      longitude: (d["longitude"] as num?)?.toDouble() ?? currentAddr?.longitude,
      primaryArea: d["primaryArea"] ?? currentAddr?.shortSummary,
      trustScore: (d["trustScore"] as num?)?.toInt() ?? 0,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> d) {
    final addrList = (d["addresses"] as List<dynamic>?)
            ?.map((a) => UserAddress.fromMap(Map<String, dynamic>.from(a as Map)))
            .toList() ??
        [];

    final currentAddrMap = d["currentAddress"] != null
        ? Map<String, dynamic>.from(d["currentAddress"] as Map)
        : null;
    final currentAddr = currentAddrMap != null
        ? UserAddress.fromMap(currentAddrMap)
        : (addrList.isNotEmpty ? addrList.firstWhere((a) => a.isDefault, orElse: () => addrList.first) : null);

    GeoPoint? loc;
    if (d["location"] != null) {
      if (d["location"] is GeoPoint) {
        loc = d["location"] as GeoPoint;
      } else if (d["location"] is Map) {
        final m = d["location"] as Map;
        final lat = (m["latitude"] as num?)?.toDouble() ?? 0.0;
        final lng = (m["longitude"] as num?)?.toDouble() ?? 0.0;
        loc = GeoPoint(lat, lng);
      }
    }

    return AppUser(
      uid: d["uid"] ?? d["id"] ?? "",
      email: d["email"] ?? "",
      displayName: d["displayName"] ?? "",
      photoUrl: d["photoUrl"],
      avatarBase64: d["avatarBase64"] ?? d["photoUrl"],
      role: UserRole.values.firstWhere(
        (r) => r.name == (d["role"] ?? "customer"),
        orElse: () => UserRole.customer,
      ),
      preferredLanguage: d["preferredLanguage"],
      region: d["region"] ?? "Tamil Nadu",
      organizationId: d["organizationId"],
      phoneNumber: d["phoneNumber"] ?? d["phone"] ?? d["mobile"] ?? d["phoneForCalling"],
      isPhoneVerified: d["phoneVerified"] == true || d["isPhoneVerified"] == true,
      hasBackupPassword: d["hasBackupPassword"] == true,
      address: d["address"],
      location: loc,
      isOnboardingComplete: d["isOnboardingComplete"] ?? true,
      addresses: addrList,
      currentAddress: currentAddr,
      latitude: (d["latitude"] as num?)?.toDouble() ?? currentAddr?.latitude,
      longitude: (d["longitude"] as num?)?.toDouble() ?? currentAddr?.longitude,
      primaryArea: d["primaryArea"] ?? currentAddr?.shortSummary,
      trustScore: (d["trustScore"] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    "uid": uid,
    "email": email,
    "displayName": displayName,
    "photoUrl": photoUrl ?? avatarBase64,
    "avatarBase64": avatarBase64,
    "role": role.name,
    "preferredLanguage": preferredLanguage,
    "region": region,
    "organizationId": organizationId,
    "phoneNumber": phoneNumber,
    "phoneVerified": isPhoneVerified,
    "hasBackupPassword": hasBackupPassword,
    "address": address,
    "location": location != null ? {"latitude": location!.latitude, "longitude": location!.longitude} : null,
    "isOnboardingComplete": isOnboardingComplete,
    "addresses": addresses.map((a) => a.toMap()).toList(),
    "currentAddress": currentAddress?.toMap(),
    "latitude": latitude ?? currentAddress?.latitude,
    "longitude": longitude ?? currentAddress?.longitude,
    "primaryArea": primaryArea ?? currentAddress?.shortSummary,
    "trustScore": trustScore,
  };

  Map<String, dynamic> toFirestore() => {
    "email": email,
    "displayName": displayName,
    "photoUrl": photoUrl ?? avatarBase64,
    "avatarBase64": avatarBase64,
    "role": role.name,
    "preferredLanguage": preferredLanguage,
    "region": region,
    "organizationId": organizationId,
    "phoneNumber": phoneNumber,
    "phoneVerified": isPhoneVerified,
    "hasBackupPassword": hasBackupPassword,
    "address": address,
    "location": location,
    "isOnboardingComplete": isOnboardingComplete,
    "addresses": addresses.map((a) => a.toMap()).toList(),
    "currentAddress": currentAddress?.toMap(),
    "latitude": latitude ?? currentAddress?.latitude,
    "longitude": longitude ?? currentAddress?.longitude,
    "primaryArea": primaryArea ?? currentAddress?.shortSummary,
    "trustScore": trustScore,
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? avatarBase64,
    UserRole? role,
    String? preferredLanguage,
    String? region,
    String? organizationId,
    String? phoneNumber,
    bool? isPhoneVerified,
    bool? hasBackupPassword,
    String? address,
    GeoPoint? location,
    bool? isOnboardingComplete,
    List<UserAddress>? addresses,
    UserAddress? currentAddress,
    double? latitude,
    double? longitude,
    String? primaryArea,
    int? trustScore,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      region: region ?? this.region,
      organizationId: organizationId ?? this.organizationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      hasBackupPassword: hasBackupPassword ?? this.hasBackupPassword,
      address: address ?? this.address,
      location: location ?? this.location,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      addresses: addresses ?? this.addresses,
      currentAddress: currentAddress ?? this.currentAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      primaryArea: primaryArea ?? this.primaryArea,
      trustScore: trustScore ?? this.trustScore,
    );
  }
}
