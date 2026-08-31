class C2paAssertion {
  final String label;
  final Map<String, dynamic> data;

  const C2paAssertion({required this.label, required this.data});

  factory C2paAssertion.fromMap(Map<String, dynamic> map) {
    return C2paAssertion(
      label: map["label"] ?? "",
      data: Map<String, dynamic>.from(map["data"] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    "label": label,
    "data": data,
  };
}

class C2paManifestRecord {
  final String manifestId;
  final String workerId;
  final String artisanName;
  final String trade;
  final String assetSha256;
  final String signature;
  final DateTime signedAt;
  final String signingAuthority;
  final bool isAuthentic;
  final List<C2paAssertion> assertions;
  final String? assetUrl;

  const C2paManifestRecord({
    required this.manifestId,
    required this.workerId,
    required this.artisanName,
    required this.trade,
    required this.assetSha256,
    required this.signature,
    required this.signedAt,
    this.signingAuthority = "WorkGo Platform Hardware KMS · SIH2026",
    this.isAuthentic = true,
    this.assertions = const [],
    this.assetUrl,
  });

  factory C2paManifestRecord.fromMap(Map<String, dynamic> map) {
    final assertionsList = (map["assertions"] as List<dynamic>?)
            ?.map((a) => C2paAssertion.fromMap(a as Map<String, dynamic>))
            .toList() ??
        [];

    final signedAtRaw = map["signedAt"];
    DateTime parsedSignedAt;
    if (signedAtRaw is String) {
      parsedSignedAt = DateTime.tryParse(signedAtRaw) ?? DateTime.now();
    } else {
      parsedSignedAt = DateTime.now();
    }

    return C2paManifestRecord(
      manifestId: map["manifestId"] ?? map["id"] ?? "",
      workerId: map["workerId"] ?? "",
      artisanName: map["artisanName"] ?? "Verified Artisan",
      trade: map["trade"] ?? "Cooperative Trade",
      assetSha256: map["assetSha256"] ?? "",
      signature: map["signature"] ?? "",
      signedAt: parsedSignedAt,
      signingAuthority: map["signingAuthority"] ?? "WorkGo Platform Hardware KMS · SIH2026",
      isAuthentic: map["isAuthentic"] ?? true,
      assertions: assertionsList,
      assetUrl: map["assetUrl"],
    );
  }

  Map<String, dynamic> toMap() => {
    "manifestId": manifestId,
    "workerId": workerId,
    "artisanName": artisanName,
    "trade": trade,
    "assetSha256": assetSha256,
    "signature": signature,
    "signedAt": signedAt.toIso8601String(),
    "signingAuthority": signingAuthority,
    "isAuthentic": isAuthentic,
    "assertions": assertions.map((a) => a.toMap()).toList(),
    "assetUrl": assetUrl,
  };
}
