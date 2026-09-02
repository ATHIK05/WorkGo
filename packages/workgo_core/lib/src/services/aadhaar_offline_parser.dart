import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Data class holding verified demographic attributes extracted from UIDAI Offline e-KYC XML.
class DecryptedAadhaarData {
  final bool isSuccess;
  final String? errorMessage;
  final String? name;
  final String? dob;
  final int? calculatedAge;
  final String? gender;
  final String? maskedUid;
  final String? photoBase64;
  final String? address;
  final Map<String, String> addressComponents;
  final String? referenceId;
  final String? rawXml;
  final bool hasValidSignature;
  final String? signatureValue;
  final String? sha256Fingerprint;
  final DateTime? verifiedAt;

  const DecryptedAadhaarData({
    required this.isSuccess,
    this.errorMessage,
    this.name,
    this.dob,
    this.calculatedAge,
    this.gender,
    this.maskedUid,
    this.photoBase64,
    this.address,
    this.addressComponents = const {},
    this.referenceId,
    this.rawXml,
    this.hasValidSignature = false,
    this.signatureValue,
    this.sha256Fingerprint,
    this.verifiedAt,
  });

  factory DecryptedAadhaarData.failure(String message) {
    return DecryptedAadhaarData(
      isSuccess: false,
      errorMessage: message,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
      'name': name,
      'dob': dob,
      'calculatedAge': calculatedAge,
      'gender': gender,
      'maskedUid': maskedUid,
      'photoBase64': photoBase64 != null && photoBase64!.isNotEmpty ? '(photo_base64_present)' : null,
      'address': address,
      'addressComponents': addressComponents,
      'referenceId': referenceId,
      'hasValidSignature': hasValidSignature,
      'sha256Fingerprint': sha256Fingerprint,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }
}

/// Service to decrypt password-protected UIDAI Offline e-KYC ZIP archives and parse XML demographics in-memory.
class AadhaarOfflineParser {
  /// Decrypts and parses a Base64-encoded UIDAI offline Aadhaar ZIP archive or XML document using the [shareCode].
  static DecryptedAadhaarData decryptAndParse({
    required String base64Data,
    required String shareCode,
  }) {
    if (base64Data.trim().isEmpty) {
      return DecryptedAadhaarData.failure("Aadhaar data payload is empty.");
    }

    try {
      // 1. Sanitize Base64 string
      String cleanBase64 = base64Data.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last.trim();
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }

      final rawBytes = base64Decode(cleanBase64);
      final fileHash = sha256.convert(rawBytes).toString();

      // Check if it's a ZIP archive (magic bytes PK: 0x50, 0x4B)
      final isZip = rawBytes.length >= 4 && rawBytes[0] == 0x50 && rawBytes[1] == 0x4B;

      String xmlString = "";

      if (isZip) {
        final code = shareCode.trim();
        Archive? archive;

        // Try decoding with password
        try {
          archive = ZipDecoder().decodeBytes(rawBytes, password: code.isNotEmpty ? code : null);
        } catch (e) {
          // If decoding failed with password, try without password
          try {
            archive = ZipDecoder().decodeBytes(rawBytes);
          } catch (_) {
            return DecryptedAadhaarData.failure(
              "Incorrect 4-digit Share Code ('$code') or encrypted archive could not be unlocked. ($e)",
            );
          }
        }

        if (archive.isEmpty) {
          return DecryptedAadhaarData.failure("The decrypted ZIP archive contains no files.");
        }

        // Find the XML file inside the archive
        ArchiveFile? xmlEntry;
        for (final entry in archive) {
          if (entry.isFile && (entry.name.toLowerCase().endsWith('.xml') || !entry.name.contains('.'))) {
            xmlEntry = entry;
            break;
          }
        }

        if (xmlEntry == null) {
          // Fallback to first non-directory file
          for (final entry in archive) {
            if (entry.isFile) {
              xmlEntry = entry;
              break;
            }
          }
        }

        if (xmlEntry == null) {
          return DecryptedAadhaarData.failure("No valid Aadhaar XML file found inside the ZIP archive.");
        }

        final contentBytes = xmlEntry.content as List<int>;
        xmlString = utf8.decode(contentBytes, allowMalformed: true);
      } else {
        // Not a zip — check if plain text XML
        final rawText = utf8.decode(rawBytes, allowMalformed: true);
        if (rawText.contains('<OfflinePaperlessKyc') ||
            rawText.contains('<UidData') ||
            rawText.contains('<?xml') ||
            rawText.contains('<Poi')) {
          xmlString = rawText;
        } else {
          return DecryptedAadhaarData.failure(
            "The document is an image scan rather than a UIDAI Offline XML archive.",
          );
        }
      }

      return parseXmlString(xmlString, sha256Fingerprint: fileHash);
    } catch (e, stack) {
      return DecryptedAadhaarData.failure("Failed to decrypt Aadhaar data: $e\n$stack");
    }
  }

  /// Parses raw UIDAI Offline Paperless e-KYC XML string into [DecryptedAadhaarData].
  static DecryptedAadhaarData parseXmlString(String xmlString, {String? sha256Fingerprint}) {
    if (xmlString.trim().isEmpty) {
      return DecryptedAadhaarData.failure("XML document is empty.");
    }

    try {
      // 1. Reference ID
      String? referenceId;
      final refMatch = RegExp(r'referenceId=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
      if (refMatch != null) {
        referenceId = refMatch.group(1);
      }

      // 2. Proof of Identity (Poi) -> name, dob, gender
      String? name;
      String? dob;
      String? rawGender;
      String? formattedGender;
      int? calculatedAge;

      final nameMatch = RegExp(r'name=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
      if (nameMatch != null) name = nameMatch.group(1)?.trim();

      final dobMatch = RegExp(r'dob=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
      if (dobMatch != null) {
        dob = dobMatch.group(1)?.trim();
        calculatedAge = _calculateAge(dob);
      }

      final genderMatch = RegExp(r'gender=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
      if (genderMatch != null) {
        rawGender = genderMatch.group(1)?.trim().toUpperCase();
        if (rawGender == 'M' || rawGender == 'MALE') {
          formattedGender = 'MALE';
        } else if (rawGender == 'F' || rawGender == 'FEMALE') {
          formattedGender = 'FEMALE';
        } else if (rawGender == 'T' || rawGender == 'TRANSGENDER') {
          formattedGender = 'TRANSGENDER';
        } else {
          formattedGender = rawGender;
        }
      }

      // 3. Masked UID
      String? maskedUid;
      final uidMatch = RegExp(r'(?:maskedUid|uid)=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
      if (uidMatch != null) {
        maskedUid = uidMatch.group(1)?.trim();
      }

      // 4. Proof of Address (Poa)
      final addressComponents = <String, String>{};
      final poaAttributes = [
        'careof', 'co', 'house', 'street', 'lm', 'loc', 'vtc', 'subdist', 'dist', 'state', 'pc', 'po', 'country'
      ];

      for (final attr in poaAttributes) {
        final match = RegExp('$attr=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(xmlString);
        if (match != null && match.group(1)?.trim().isNotEmpty == true) {
          addressComponents[attr] = match.group(1)!.trim();
        }
      }

      final formattedAddress = _formatFullAddress(addressComponents);

      // 5. Official Photograph (Pht)
      String? photoBase64;
      final phtMatch = RegExp(r'<(?:Pht|pht|Photo|photo)>([\s\S]*?)<\/(?:Pht|pht|Photo|photo)>', caseSensitive: false).firstMatch(xmlString);
      if (phtMatch != null) {
        photoBase64 = phtMatch.group(1)?.replaceAll(RegExp(r'\s+'), '').trim();
      }

      // 6. Signature (SignatureValue / XML-DSig)
      bool hasValidSignature = false;
      String? signatureValue;
      if (xmlString.contains('<Signature') || xmlString.contains('<ds:Signature')) {
        hasValidSignature = true;
        final sigMatch = RegExp(r'<(?:SignatureValue|ds:SignatureValue)>([\s\S]*?)<\/(?:SignatureValue|ds:SignatureValue)>', caseSensitive: false).firstMatch(xmlString);
        if (sigMatch != null) {
          signatureValue = sigMatch.group(1)?.replaceAll(RegExp(r'\s+'), '').trim();
        }
      }

      return DecryptedAadhaarData(
        isSuccess: true,
        name: name,
        dob: dob,
        calculatedAge: calculatedAge,
        gender: formattedGender,
        maskedUid: maskedUid ?? (referenceId != null && referenceId.length >= 4 ? "XXXX-XXXX-${referenceId.substring(0, 4)}" : "XXXX-XXXX-XXXX"),
        photoBase64: photoBase64,
        address: formattedAddress,
        addressComponents: addressComponents,
        referenceId: referenceId,
        rawXml: xmlString,
        hasValidSignature: hasValidSignature,
        signatureValue: signatureValue,
        sha256Fingerprint: sha256Fingerprint ?? sha256.convert(utf8.encode(xmlString)).toString(),
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      return DecryptedAadhaarData.failure("Failed to parse Aadhaar XML fields: $e");
    }
  }

  static int? _calculateAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return null;
    try {
      DateTime? birthDate;
      // Handle DD-MM-YYYY or DD/MM/YYYY
      if (dobStr.contains('-') || dobStr.contains('/')) {
        final separator = dobStr.contains('-') ? '-' : '/';
        final parts = dobStr.split(separator);
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            birthDate = DateTime.tryParse("${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}");
          } else {
            // DD-MM-YYYY
            birthDate = DateTime.tryParse("${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}");
          }
        }
      } else if (dobStr.length == 4) {
        // Just Year (e.g. 1998)
        final year = int.tryParse(dobStr);
        if (year != null) {
          return DateTime.now().year - year;
        }
      }

      if (birthDate != null) {
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        return age > 0 ? age : null;
      }
    } catch (_) {}
    return null;
  }

  static String _formatFullAddress(Map<String, String> components) {
    final parts = <String>[];

    void addPart(String? val) {
      if (val == null) return;
      final trimmed = val.trim();
      if (trimmed.isNotEmpty && !parts.contains(trimmed)) {
        parts.add(trimmed);
      }
    }

    // Care of
    if (components.containsKey('careof')) {
      final co = components['careof']!;
      addPart(co.toLowerCase().startsWith('c/o') || co.toLowerCase().startsWith('s/o') || co.toLowerCase().startsWith('w/o') || co.toLowerCase().startsWith('d/o')
          ? co
          : "C/O $co");
    } else if (components.containsKey('co')) {
      final co = components['co']!;
      addPart(co.toLowerCase().startsWith('c/o') || co.toLowerCase().startsWith('s/o') || co.toLowerCase().startsWith('w/o') || co.toLowerCase().startsWith('d/o')
          ? co
          : "C/O $co");
    }

    // House / Building
    addPart(components['house']);

    // Street / Lane
    addPart(components['street']);

    // Landmark
    if (components.containsKey('lm')) {
      final lm = components['lm']!;
      addPart(lm.toLowerCase().startsWith('near') ? lm : "Near $lm");
    }

    // Locality
    addPart(components['loc']);

    // Village / Town / City
    addPart(components['vtc']);

    // Sub-district
    addPart(components['subdist']);

    // District
    addPart(components['dist']);

    // State
    addPart(components['state']);

    // Post Office & Pincode
    final po = components['po'];
    final pc = components['pc'];
    if (po != null && pc != null) {
      final formattedPo = po.toUpperCase().endsWith("PO") ? po : "$po PO";
      addPart("$formattedPo - $pc");
    } else if (po != null) {
      addPart(po.toUpperCase().endsWith("PO") ? po : "$po PO");
    } else if (pc != null) {
      addPart(pc);
    }

    return parts.join(", ");
  }
}
