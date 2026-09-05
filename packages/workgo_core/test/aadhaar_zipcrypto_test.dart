import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/src/services/aadhaar_offline_parser.dart';

/// Implements standard PKWARE ZipCrypto encryption to produce realistic UIDAI-style password-protected ZIP archives.
class TestZipCrypto {
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

  Uint8List encrypt(Uint8List plain, int checkByte) {
    final rng = math.Random(42);
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

  Uint8List decrypt(Uint8List encrypted) {
    if (encrypted.length < 12) return Uint8List(0);
    for (var i = 0; i < 12; i++) {
      final b = encrypted[i] ^ decryptByte();
      updateKeys(b);
    }
    final out = Uint8List(encrypted.length - 12);
    for (var i = 12; i < encrypted.length; i++) {
      final b = encrypted[i] ^ decryptByte();
      updateKeys(b);
      out[i - 12] = b;
    }
    return out;
  }
}

/// Builds a real ZIP binary containing one ZipCrypto password-encrypted file.
Uint8List createZipCryptoArchive({
  required String filename,
  required Uint8List content,
  required String password,
  bool deflate = true,
}) {
  final crc = getCrc32(content);
  final uncompressedSize = content.length;

  Uint8List compressedPayload;
  int compressionMethod;

  if (deflate) {
    compressionMethod = 8;
    compressedPayload = Uint8List.fromList(const ZLibEncoder().encode(content, level: 6));
    // Strip zlib header (2 bytes) and adler32 (4 bytes) to get raw deflate stream
    if (compressedPayload.length > 6) {
      compressedPayload = compressedPayload.sublist(2, compressedPayload.length - 4);
    }
  } else {
    compressionMethod = 0;
    compressedPayload = content;
  }

  final checkByte = (crc >> 24) & 0xFF;
  final crypto = TestZipCrypto()..init(password);
  final encryptedData = crypto.encrypt(compressedPayload, checkByte);
  final compressedSize = encryptedData.length;

  final fnBytes = utf8.encode(filename);
  final localHeaderOffset = 0;

  final out = BytesBuilder();

  // 1. Local File Header (0x04034b50)
  out.add([0x50, 0x4b, 0x03, 0x04]);
  out.add([20, 0]); // version needed (2.0)
  out.add([0x01, 0x08]); // flags (bit 0 = encrypted, bit 11 = utf8)
  out.add([compressionMethod & 0xFF, (compressionMethod >> 8) & 0xFF]);
  out.add([0, 0]); // mod time
  out.add([0, 0]); // mod date
  out.add([crc & 0xFF, (crc >> 8) & 0xFF, (crc >> 16) & 0xFF, (crc >> 24) & 0xFF]);
  out.add([compressedSize & 0xFF, (compressedSize >> 8) & 0xFF, (compressedSize >> 16) & 0xFF, (compressedSize >> 24) & 0xFF]);
  out.add([uncompressedSize & 0xFF, (uncompressedSize >> 8) & 0xFF, (uncompressedSize >> 16) & 0xFF, (uncompressedSize >> 24) & 0xFF]);
  out.add([fnBytes.length & 0xFF, (fnBytes.length >> 8) & 0xFF]);
  out.add([0, 0]); // extra field len
  out.add(fnBytes);
  out.add(encryptedData);

  final centralDirStart = out.length;

  // 2. Central Directory Header (0x02014b50)
  out.add([0x50, 0x4b, 0x01, 0x02]);
  out.add([20, 0]); // version made by
  out.add([20, 0]); // version needed
  out.add([0x01, 0x08]); // flags
  out.add([compressionMethod & 0xFF, (compressionMethod >> 8) & 0xFF]);
  out.add([0, 0]); // mod time
  out.add([0, 0]); // mod date
  out.add([crc & 0xFF, (crc >> 8) & 0xFF, (crc >> 16) & 0xFF, (crc >> 24) & 0xFF]);
  out.add([compressedSize & 0xFF, (compressedSize >> 8) & 0xFF, (compressedSize >> 16) & 0xFF, (compressedSize >> 24) & 0xFF]);
  out.add([uncompressedSize & 0xFF, (uncompressedSize >> 8) & 0xFF, (uncompressedSize >> 16) & 0xFF, (uncompressedSize >> 24) & 0xFF]);
  out.add([fnBytes.length & 0xFF, (fnBytes.length >> 8) & 0xFF]);
  out.add([0, 0]); // extra len
  out.add([0, 0]); // comment len
  out.add([0, 0]); // disk num
  out.add([0, 0]); // internal attr
  out.add([0, 0, 0, 0]); // external attr
  out.add([localHeaderOffset & 0xFF, (localHeaderOffset >> 8) & 0xFF, (localHeaderOffset >> 16) & 0xFF, (localHeaderOffset >> 24) & 0xFF]);
  out.add(fnBytes);

  final centralDirSize = out.length - centralDirStart;

  // 3. End of Central Directory Record (0x06054b50)
  out.add([0x50, 0x4b, 0x05, 0x06]);
  out.add([0, 0]); // disk num
  out.add([0, 0]); // disk with central dir
  out.add([1, 0]); // entries on this disk
  out.add([1, 0]); // total entries
  out.add([centralDirSize & 0xFF, (centralDirSize >> 8) & 0xFF, (centralDirSize >> 16) & 0xFF, (centralDirSize >> 24) & 0xFF]);
  out.add([centralDirStart & 0xFF, (centralDirStart >> 8) & 0xFF, (centralDirStart >> 16) & 0xFF, (centralDirStart >> 24) & 0xFF]);
  out.add([0, 0]); // comment len

  return out.toBytes();
}

void main() {
  const sampleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<OfflinePaperlessKyc referenceId="193920260901">
  <UidData>
    <Poi name="Athik" dob="12/05/1995" gender="M"/>
    <Poa house="42" street="Cooperative Way" loc="Sector 5" vtc="Chennai" dist="Chennai" state="Tamil Nadu" pc="600001"/>
  </UidData>
</OfflinePaperlessKyc>''';

  test('ZipCrypto roundtrip with BigInt test', () {
    final raw = Uint8List.fromList(utf8.encode(sampleXml));
    final enc = (TestZipCrypto()..init('1939')).encrypt(raw, 0xAB);
    final dec = (TestZipCrypto()..init('1939')).decrypt(enc);
    expect(utf8.decode(dec), equals(sampleXml));
  });

  test('AadhaarOfflineParser successfully decrypts authentic ZipCrypto archives', () {
    final zipBytes = createZipCryptoArchive(
      filename: 'offlineaadhaar1939.xml',
      content: Uint8List.fromList(utf8.encode(sampleXml)),
      password: '1939',
      deflate: true, // DEFLATE (as UIDAI does)
    );

    // Verify that our new AadhaarOfflineParser decodes it with 100% precision
    final result = AadhaarOfflineParser.decryptAndParse(
      base64Data: base64Encode(zipBytes),
      shareCode: '1939',
    );
    expect(result.isSuccess, isTrue);
    expect(result.name, equals('Athik'));
    expect(result.referenceId, equals('193920260901'));

    // Verify wrong password failure
    final wrongResult = AadhaarOfflineParser.decryptAndParse(
      base64Data: base64Encode(zipBytes),
      shareCode: '0000',
    );
    expect(wrongResult.isSuccess, isFalse);
    expect(wrongResult.errorMessage, contains('0000'));
  });
}
