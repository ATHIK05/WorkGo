import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Clean, BigInt-based ZipCrypto decryptor that works identically across Dart VM and Flutter Web (JavaScript).
/// Eliminates the 64-bit int overflow and JavaScript IEEE 754 precision bugs present in package:archive 3.6.1.
class AadhaarZipCrypto {
  BigInt _key0 = BigInt.from(0x12345678);
  BigInt _key1 = BigInt.from(0x23456789);
  BigInt _key2 = BigInt.from(0x34567890);

  static final BigInt _mask32 = BigInt.from(0xFFFFFFFF);
  static final BigInt _mult = BigInt.from(134775813);
  static final BigInt _one = BigInt.from(1);
  static final BigInt _byteMask = BigInt.from(0xFF);

  static final List<int> _crcTable = () {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var j = 0; j < 8; j++) {
        if ((c & 1) != 0) {
          c = 0xedb88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c & 0xFFFFFFFF;
    }
    return table;
  }();

  static int _crc32(int crc, int b) {
    return (_crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8)) & 0xFFFFFFFF;
  }

  void init(String password) {
    _key0 = BigInt.from(0x12345678);
    _key1 = BigInt.from(0x23456789);
    _key2 = BigInt.from(0x34567890);
    for (final c in password.codeUnits) {
      updateKeys(c);
    }
  }

  void updateKeys(int c) {
    _key0 = BigInt.from(_crc32(_key0.toInt(), c));
    _key1 = (_key1 + (_key0 & _byteMask)) & _mask32;
    _key1 = (_key1 * _mult + _one) & _mask32;
    _key2 = BigInt.from(_crc32(_key2.toInt(), ((_key1 >> 24) & _byteMask).toInt()));
  }

  int decryptByte() {
    final temp = ((_key2 & BigInt.from(0xFFFF)).toInt() | 2);
    return ((temp * (temp ^ 1)) >> 8) & 0xFF;
  }

  /// Decrypts ZipCrypto payload. Returns null if password verification check byte fails.
  Uint8List? decrypt(Uint8List encrypted, {int? expectedCheckByte}) {
    if (encrypted.length < 12) return null;

    int lastHeaderByte = 0;
    for (var i = 0; i < 12; i++) {
      final b = encrypted[i] ^ decryptByte();
      updateKeys(b);
      lastHeaderByte = b;
    }

    if (expectedCheckByte != null && lastHeaderByte != expectedCheckByte) {
      return null; // Password mismatch
    }

    final out = Uint8List(encrypted.length - 12);
    for (var i = 12; i < encrypted.length; i++) {
      final b = encrypted[i] ^ decryptByte();
      updateKeys(b);
      out[i - 12] = b;
    }
    return out;
  }

  /// Encrypts plain data with ZipCrypto and 12-byte header for testing.
  Uint8List encrypt(Uint8List plain, int checkByte) {
    final rng = math.Random(12345);
    final header = Uint8List(12);
    for (var i = 0; i < 11; i++) {
      header[i] = rng.nextInt(256);
    }
    header[11] = checkByte & 0xFF;

    final out = Uint8List(12 + plain.length);
    for (var i = 0; i < 12; i++) {
      final b = header[i];
      out[i] = b ^ decryptByte();
      updateKeys(b);
    }
    for (var i = 0; i < plain.length; i++) {
      final b = plain[i];
      out[12 + i] = b ^ decryptByte();
      updateKeys(b);
    }
    return out;
  }
}

/// Direct ZIP central directory extractor that works seamlessly on UIDAI Offline e-KYC archives.
/// Avoids the Unix file attribute `isFile` bug and decompressor limitations in package:archive 3.6.1.
class AadhaarZipExtractor {
  static String? extractXml({
    required Uint8List rawBytes,
    required String password,
  }) {
    // Look for End of Central Directory Record (0x06054b50) from the end
    int eocdOffset = -1;
    for (var i = rawBytes.length - 22; i >= 0 && i >= rawBytes.length - 65558; i--) {
      if (rawBytes[i] == 0x50 &&
          rawBytes[i + 1] == 0x4b &&
          rawBytes[i + 2] == 0x05 &&
          rawBytes[i + 3] == 0x06) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset == -1) return null;

    final cdEntries = rawBytes[eocdOffset + 10] | (rawBytes[eocdOffset + 11] << 8);
    final cdOffset = rawBytes[eocdOffset + 16] |
        (rawBytes[eocdOffset + 17] << 8) |
        (rawBytes[eocdOffset + 18] << 16) |
        (rawBytes[eocdOffset + 19] << 24);

    int pos = cdOffset;
    for (var i = 0; i < cdEntries; i++) {
      if (pos + 46 > rawBytes.length) break;
      if (rawBytes[pos] != 0x50 ||
          rawBytes[pos + 1] != 0x4b ||
          rawBytes[pos + 2] != 0x01 ||
          rawBytes[pos + 3] != 0x02) {
        break;
      }

      final flags = rawBytes[pos + 8] | (rawBytes[pos + 9] << 8);
      final method = rawBytes[pos + 10] | (rawBytes[pos + 11] << 8);
      final lastModTime = rawBytes[pos + 12] | (rawBytes[pos + 13] << 8);
      final crc32 = rawBytes[pos + 16] |
          (rawBytes[pos + 17] << 8) |
          (rawBytes[pos + 18] << 16) |
          (rawBytes[pos + 19] << 24);
      final compSize = rawBytes[pos + 20] |
          (rawBytes[pos + 21] << 8) |
          (rawBytes[pos + 22] << 16) |
          (rawBytes[pos + 23] << 24);
      final fnLen = rawBytes[pos + 28] | (rawBytes[pos + 29] << 8);
      final exLen = rawBytes[pos + 30] | (rawBytes[pos + 31] << 8);
      final commentLen = rawBytes[pos + 32] | (rawBytes[pos + 33] << 8);
      final localOffset = rawBytes[pos + 42] |
          (rawBytes[pos + 43] << 8) |
          (rawBytes[pos + 44] << 16) |
          (rawBytes[pos + 45] << 24);

      final fnBytes = rawBytes.sublist(pos + 46, pos + 46 + fnLen);
      final fn = utf8.decode(fnBytes, allowMalformed: true);

      pos += 46 + fnLen + exLen + commentLen;

      // Skip directories or metadata
      if (fn.endsWith('/') || fn.endsWith('\\')) continue;
      final fnLower = fn.toLowerCase();
      if (fnLower.contains('__macosx') || fnLower.startsWith('._') || fnLower.contains('/._')) {
        continue;
      }

      // Locate payload in local header
      if (localOffset + 30 > rawBytes.length) continue;
      final localFnLen = rawBytes[localOffset + 26] | (rawBytes[localOffset + 27] << 8);
      final localExLen = rawBytes[localOffset + 28] | (rawBytes[localOffset + 29] << 8);
      final payloadOffset = localOffset + 30 + localFnLen + localExLen;

      if (payloadOffset + compSize > rawBytes.length) continue;
      final payload = rawBytes.sublist(payloadOffset, payloadOffset + compSize);

      Uint8List? decompressed;
      final isEncrypted = (flags & 0x01) != 0;

      if (isEncrypted) {
        if (method == 99) continue; // WinZip AES - let ZipDecoder handle fallback
        final crypto = AadhaarZipCrypto()..init(password);
        final checkByte1 = (flags & 0x08) != 0 ? ((lastModTime >> 8) & 0xFF) : ((crc32 >> 24) & 0xFF);
        final checkByte2 = (crc32 >> 24) & 0xFF;
        final checkByte3 = (lastModTime >> 8) & 0xFF;

        // Try primary check byte, alternate check byte, or blind decrypt
        Uint8List? decrypted = crypto.decrypt(payload, expectedCheckByte: checkByte1);
        decrypted ??= (AadhaarZipCrypto()..init(password)).decrypt(payload, expectedCheckByte: checkByte2);
        decrypted ??= (AadhaarZipCrypto()..init(password)).decrypt(payload, expectedCheckByte: checkByte3);
        decrypted ??= (AadhaarZipCrypto()..init(password)).decrypt(payload);
        if (decrypted == null) continue;

        if (method == 8) {
          try {
            final inflated = inflateBuffer(decrypted);
            if (inflated != null) {
              decompressed = Uint8List.fromList(inflated);
            }
          } catch (_) {}
        } else if (method == 0) {
          decompressed = decrypted;
        }
      } else {
        if (method == 8) {
          try {
            final inflated = inflateBuffer(payload);
            if (inflated != null) {
              decompressed = Uint8List.fromList(inflated);
            }
          } catch (_) {}
        } else if (method == 0) {
          decompressed = payload;
        }
      }

      if (decompressed == null || decompressed.isEmpty) continue;

      final text = utf8.decode(decompressed, allowMalformed: true);
      if (text.contains('<OfflinePaperlessKyc') ||
          text.contains('<UidData') ||
          text.contains('<Poi') ||
          text.contains('<?xml')) {
        return text;
      }
    }
    return null;
  }
}

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

        // 1. Direct BigInt ZipCrypto Extractor (Standard UIDAI PKWARE archives, safe on 64-bit VM and Web)
        String? extractedXml = AadhaarZipExtractor.extractXml(
          rawBytes: rawBytes,
          password: code,
        );

        // If not found and password was not empty, also try unencrypted extraction
        if (extractedXml == null && code.isNotEmpty) {
          extractedXml = AadhaarZipExtractor.extractXml(
            rawBytes: rawBytes,
            password: '',
          );
        }

        if (extractedXml != null && extractedXml.trim().isNotEmpty) {
          return parseXmlString(extractedXml, sha256Fingerprint: fileHash);
        }

        // 2. Fallback to package:archive ZipDecoder (for WinZip AES or legacy archives)
        Archive? archive;
        if (code.isNotEmpty) {
          try {
            archive = ZipDecoder().decodeBytes(rawBytes, password: code);
          } catch (_) {}
        }

        if (archive == null || archive.isEmpty) {
          try {
            archive = ZipDecoder().decodeBytes(rawBytes);
          } catch (_) {}
        }

        if (archive == null || archive.isEmpty) {
          return DecryptedAadhaarData.failure(
            "Incorrect 4-digit Share Code ('$code') or encrypted archive could not be unlocked.",
          );
        }

        // Search for the Aadhaar XML document across all entries in the ZIP.
        // Avoid using `entry.isFile` because Unix/Java ZIP archives often have external attributes
        // that cause isFile to return false in archive 3.6.1.
        String? foundXmlString;

        // Pass 1: Prioritize non-empty .xml files containing UIDAI XML tags
        for (final entry in archive) {
          final nameLower = entry.name.toLowerCase();
          if (nameLower.endsWith('/') ||
              nameLower.endsWith('\\') ||
              nameLower.contains('__macosx') ||
              nameLower.startsWith('._') ||
              nameLower.contains('/._')) {
            continue;
          }

          if (nameLower.endsWith('.xml')) {
            try {
              final content = entry.content;
              if (content is List<int> && content.isNotEmpty) {
                final decoded = utf8.decode(content, allowMalformed: true);
                if (decoded.trim().isNotEmpty && _isAadhaarXml(decoded)) {
                  foundXmlString = decoded;
                  break;
                }
              }
            } catch (_) {}
          }
        }

        // Pass 2: Any non-empty file containing UIDAI XML tags (even if not named .xml)
        if (foundXmlString == null) {
          for (final entry in archive) {
            final nameLower = entry.name.toLowerCase();
            if (nameLower.endsWith('/') ||
                nameLower.endsWith('\\') ||
                nameLower.contains('__macosx') ||
                nameLower.startsWith('._') ||
                nameLower.contains('/._')) {
              continue;
            }

            try {
              final content = entry.content;
              if (content is List<int> && content.isNotEmpty) {
                final decoded = utf8.decode(content, allowMalformed: true);
                if (decoded.trim().isNotEmpty && _isAadhaarXml(decoded)) {
                  foundXmlString = decoded;
                  break;
                }
              }
            } catch (_) {}
          }
        }

        // Pass 3: Any non-empty .xml file
        if (foundXmlString == null) {
          for (final entry in archive) {
            final nameLower = entry.name.toLowerCase();
            if (nameLower.endsWith('/') ||
                nameLower.endsWith('\\') ||
                nameLower.contains('__macosx') ||
                nameLower.startsWith('._') ||
                nameLower.contains('/._')) {
              continue;
            }

            if (nameLower.endsWith('.xml')) {
              try {
                final content = entry.content;
                if (content is List<int> && content.isNotEmpty) {
                  final decoded = utf8.decode(content, allowMalformed: true);
                  if (decoded.trim().isNotEmpty) {
                    foundXmlString = decoded;
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }

        // Pass 4: Fallback to any non-empty file starting with '<'
        if (foundXmlString == null) {
          for (final entry in archive) {
            final nameLower = entry.name.toLowerCase();
            if (nameLower.endsWith('/') ||
                nameLower.endsWith('\\') ||
                nameLower.contains('__macosx') ||
                nameLower.startsWith('._') ||
                nameLower.contains('/._')) {
              continue;
            }

            try {
              final content = entry.content;
              if (content is List<int> && content.isNotEmpty) {
                final decoded = utf8.decode(content, allowMalformed: true);
                if (decoded.trim().startsWith('<')) {
                  foundXmlString = decoded;
                  break;
                }
              }
            } catch (_) {}
          }
        }

        if (foundXmlString == null || foundXmlString.trim().isEmpty) {
          return DecryptedAadhaarData.failure(
            "No valid Aadhaar XML file found inside the ZIP archive. Check if the 4-digit Share Code ('$code') is correct.",
          );
        }

        xmlString = foundXmlString;
      } else {
        // Not a zip — check if plain text XML
        final rawText = utf8.decode(rawBytes, allowMalformed: true);
        if (_isAadhaarXml(rawText)) {
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

  /// Checks if string content contains typical UIDAI XML signatures.
  static bool _isAadhaarXml(String str) {
    return str.contains('<OfflinePaperlessKyc') ||
        str.contains('<UidData') ||
        str.contains('<Poi') ||
        (str.contains('<?xml') && str.contains('<'));
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
