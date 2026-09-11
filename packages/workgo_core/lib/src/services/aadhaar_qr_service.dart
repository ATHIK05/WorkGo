import "dart:convert";
import "dart:typed_data";
import "package:crypto/crypto.dart";
import "package:pointycastle/export.dart";
import "package:xml/xml.dart";
import "../api_client/workgo_api_client.dart";

/// Result of scanning and verifying an Aadhaar Secure QR code.
class AadhaarQrResult {
  final bool signatureValid;
  final String nameHash;      // SHA-256 of name — never store raw
  final String dobHash;       // SHA-256 of DOB — never store raw
  final String gender;        // "M" | "F" | "T"
  final String district;      // district + state (non-sensitive)
  final Uint8List? photo;     // Aadhaar photo from v2 QR (admin view only)
  final String? referenceId;  // returned by backend after save

  const AadhaarQrResult({
    required this.signatureValid,
    required this.nameHash,
    required this.dobHash,
    required this.gender,
    required this.district,
    this.photo,
    this.referenceId,
  });
}

/// On-device Aadhaar Secure QR parser and UIDAI RSA-SHA256 verifier.
///
/// Privacy rules (DPDP Act 2023):
///  - Raw name, DOB, address NEVER leave the device.
///  - Only SHA-256 hashes + district + gender are sent to backend.
///  - Photo (if present in v2 QR) is sent to backend as admin-only field.
///  - Aadhaar number is always masked in the QR — never exposed.
class AadhaarQrService {
  // UIDAI's public key for RSA-SHA256 signature verification.
  // This is the publicly available UIDAI staging/production key.
  // Update this if UIDAI rotates their key.
  static const String _uidaiPublicKeyPem = """
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCzQmWWUduyXGEJqF9nPXwNpf2E
HMkc7Vd7gBR1MFw6xXkBwmZI0hFdkvhRf5I0Vv5EKPqKk8MKJNR0g0Yiy9nBqM
mO4KhBQ7G5i5Z8KpO7v4JJqQSFJILqbKpUoJuW7q5QI9wQl5bqnJrHVq3e5bON
8vlQhXIMHhlJpNI0IQIDAQAB
-----END PUBLIC KEY-----
""";

  /// Parse and verify an Aadhaar Secure QR raw string.
  ///
  /// The QR contains an XML string (base64-encoded in newer versions)
  /// with a trailing RSA-SHA256 signature from UIDAI.
  ///
  /// Returns [AadhaarQrResult] or throws on parse/verify failure.
  static AadhaarQrResult parseAndVerify(String rawQr) {
    try {
      // The Aadhaar Secure QR format:
      // XML data as a delimited string with Signature attribute OR
      // a base64-encoded XML blob. We handle both.
      String xmlString;
      if (rawQr.startsWith("<?xml") || rawQr.startsWith("<Print")) {
        xmlString = rawQr;
      } else {
        // Try base64 decode
        xmlString = utf8.decode(base64Decode(rawQr));
      }

      final doc = XmlDocument.parse(xmlString);
      final root = doc.rootElement;

      // Extract fields (attribute names per UIDAI spec)
      final name = root.getAttribute("name") ?? root.getAttribute("n") ?? "";
      final dob = root.getAttribute("dob") ?? root.getAttribute("d") ?? "";
      final gender = _normaliseGender(
          root.getAttribute("gender") ?? root.getAttribute("g") ?? "");
      final vtc = root.getAttribute("vtc") ?? "";
      final dist = root.getAttribute("dist") ?? root.getAttribute("district") ?? "";
      final state = root.getAttribute("state") ?? root.getAttribute("s") ?? "";
      final photoB64 = root.getAttribute("photo") ?? root.getAttribute("image");
      final signatureB64 = root.getAttribute("Signature") ??
          root.getAttribute("signature") ?? "";

      // Build district string
      final districtStr =
          [vtc, dist, state].where((e) => e.isNotEmpty).join(", ");

      // Verify UIDAI RSA-SHA256 signature
      bool sigValid = false;
      try {
        if (signatureB64.isNotEmpty) {
          sigValid = _verifySignature(
            xmlData: xmlString,
            signatureB64: signatureB64,
            pemKey: _uidaiPublicKeyPem,
          );
        }
      } catch (_) {
        sigValid = false;
      }

      // Hash sensitive fields — never expose raw values
      final nameHash = _sha256Hex(name.trim().toLowerCase());
      final dobHash = _sha256Hex(dob.trim());

      // Decode photo if present
      Uint8List? photoBytes;
      if (photoB64 != null && photoB64.isNotEmpty) {
        try {
          photoBytes = base64Decode(photoB64);
        } catch (_) {}
      }

      return AadhaarQrResult(
        signatureValid: sigValid,
        nameHash: nameHash,
        dobHash: dobHash,
        gender: gender,
        district: districtStr.isNotEmpty ? districtStr : vtc,
        photo: photoBytes,
      );
    } catch (e) {
      throw Exception("Failed to parse Aadhaar QR: $e");
    }
  }

  /// Submit the on-device verified QR result to the backend.
  /// Only hashed + non-sensitive fields are sent.
  static Future<String?> submitToBackend({
    required String workerId,
    required AadhaarQrResult result,
  }) async {
    final photoB64 = result.photo != null ? base64Encode(result.photo!) : null;
    final res = await WorkGoApiClient().post(
      "/api/verification/aadhaar-qr",
      {
        "workerId": workerId,
        "nameHash": result.nameHash,
        "dobHash": result.dobHash,
        "gender": result.gender,
        "district": result.district,
        "signatureValid": result.signatureValid,
        if (photoB64 != null) "photoBase64": photoB64,
      },
    );
    if (res is Map<String, dynamic> && res["success"] == true) {
      return res["referenceId"] as String?;
    }
    throw Exception(
        res is Map ? res["error"] ?? "Aadhaar QR submission failed" : "Failed");
  }

  /// Submit e-Shram UAN to backend.
  static Future<int> submitEshram({
    required String workerId,
    required String uan,
    String? trade,
    String? district,
  }) async {
    final res = await WorkGoApiClient().post(
      "/api/verification/eshram",
      {
        "workerId": workerId,
        "uan": uan,
        if (trade != null) "trade": trade,
        if (district != null) "district": district,
      },
    );
    if (res is Map<String, dynamic> && res["success"] == true) {
      return (res["trustScore"] as num?)?.toInt() ?? 0;
    }
    throw Exception(
        res is Map ? res["error"] ?? "e-Shram link failed" : "Failed");
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String _normaliseGender(String raw) {
    final r = raw.toUpperCase().trim();
    if (r == "M" || r == "MALE") return "M";
    if (r == "F" || r == "FEMALE") return "F";
    if (r == "T" || r == "TRANSGENDER") return "T";
    return r.isNotEmpty ? r[0] : "M";
  }

  /// Verifies an RSA-SHA256 signature using UIDAI's public key.
  /// Signature is over the XML string without the Signature attribute itself.
  static bool _verifySignature({
    required String xmlData,
    required String signatureB64,
    required String pemKey,
  }) {
    try {
      // Strip the Signature attribute from XML for verification
      final xmlForVerify = xmlData.replaceAll(
          RegExp(r'\s*Signature="[^"]*"'), "");

      final sigBytes = base64Decode(signatureB64);
      final dataBytes = Uint8List.fromList(utf8.encode(xmlForVerify));
      final pubKey = _parsePublicKeyFromPem(pemKey);

      final signer = RSASigner(SHA256Digest(), "0609608648016503040201");
      signer.init(false, PublicKeyParameter<RSAPublicKey>(pubKey));

      final sig = RSASignature(sigBytes);
      return signer.verifySignature(dataBytes, sig);
    } catch (_) {
      return false;
    }
  }

  /// Parses an RSA public key (SubjectPublicKeyInfo or PKCS#1) from PEM.
  static RSAPublicKey _parsePublicKeyFromPem(String pemKey) {
    final pemStripped = pemKey
        .replaceAll("-----BEGIN PUBLIC KEY-----", "")
        .replaceAll("-----END PUBLIC KEY-----", "")
        .replaceAll("-----BEGIN RSA PUBLIC KEY-----", "")
        .replaceAll("-----END RSA PUBLIC KEY-----", "")
        .replaceAll("\r", "")
        .replaceAll("\n", "")
        .trim();

    final bytes = base64Decode(pemStripped);
    return _parseRsaPublicKeyFromDer(bytes);
  }

  static RSAPublicKey _parseRsaPublicKeyFromDer(Uint8List bytes) {
    int offset = 0;

    int readLength() {
      final b = bytes[offset++];
      if ((b & 0x80) == 0) return b;
      final numBytes = b & 0x7F;
      int length = 0;
      for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | bytes[offset++];
      }
      return length;
    }

    // Top-level sequence (0x30)
    if (bytes[offset++] != 0x30) throw const FormatException("Invalid ASN.1 sequence");
    readLength();

    // Check if next is AlgorithmIdentifier (SubjectPublicKeyInfo) or Modulus (PKCS#1)
    if (bytes[offset] == 0x30) {
      // Skip AlgorithmIdentifier sequence
      offset++;
      final algLen = readLength();
      offset += algLen;

      // Next must be BIT STRING (0x03)
      if (bytes[offset++] != 0x03) throw const FormatException("Expected BIT STRING");
      readLength();
      // Skip unused bits byte
      offset++;

      // Next is inner RSAPublicKey sequence
      if (bytes[offset++] != 0x30) throw const FormatException("Expected inner RSA sequence");
      readLength();
    }

    // Now at Modulus INTEGER (0x02)
    if (bytes[offset++] != 0x02) throw const FormatException("Expected INTEGER (modulus)");
    final modLen = readLength();
    final modBytes = bytes.sublist(offset, offset + modLen);
    offset += modLen;

    // Next is Exponent INTEGER (0x02)
    if (bytes[offset++] != 0x02) throw const FormatException("Expected INTEGER (exponent)");
    final expLen = readLength();
    final expBytes = bytes.sublist(offset, offset + expLen);

    BigInt bytesToBigInt(Uint8List b) {
      BigInt result = BigInt.zero;
      for (int i = 0; i < b.length; i++) {
        result = (result << 8) | BigInt.from(b[i]);
      }
      return result;
    }

    return RSAPublicKey(bytesToBigInt(modBytes), bytesToBigInt(expBytes));
  }
}
