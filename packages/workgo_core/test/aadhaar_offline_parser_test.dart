import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('AadhaarOfflineParser Tests', () {
    const sampleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<OfflinePaperlessKyc referenceId="20260901065022174">
  <UidData>
    <Poi name="Athik Rathi" dob="15/08/1998" gender="M" e="hash" m="hash"/>
    <Poa house="Plot 42" street="1st Main Road" lm="Near Tower" loc="Anna Nagar" vtc="Chennai" subdist="Egmore" dist="Chennai" state="Tamil Nadu" pc="600040" po="Anna Nagar PO"/>
    <Pht>/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=</Pht>
  </UidData>
  <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    <SignedInfo><SignatureValue>MEQCIA23456789==</SignatureValue></SignedInfo>
  </Signature>
</OfflinePaperlessKyc>''';

    test('should parse plain XML string successfully', () {
      final data = AadhaarOfflineParser.parseXmlString(sampleXml);
      expect(data.isSuccess, isTrue);
      expect(data.name, equals('Athik Rathi'));
      expect(data.dob, equals('15/08/1998'));
      expect(data.calculatedAge, isNotNull);
      expect(data.gender, equals('MALE'));
      expect(data.referenceId, equals('20260901065022174'));
      expect(data.address, equals('Plot 42, 1st Main Road, Near Tower, Anna Nagar, Chennai, Egmore, Tamil Nadu, Anna Nagar PO - 600040'));
      expect(data.photoBase64, isNotEmpty);
      expect(data.hasValidSignature, isTrue);
    });

    test('should decode and parse ZIP archive in-memory', () {
      final xmlBytes = utf8.encode(sampleXml);
      final archive = Archive();
      archive.addFile(ArchiveFile('offlineaadhaar20260901065022174.xml', xmlBytes.length, xmlBytes));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      expect(zipBytes, isNotNull);

      final base64Zip = base64Encode(zipBytes!);

      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: base64Zip,
        shareCode: '1939',
      );

      expect(result.isSuccess, isTrue);
      expect(result.name, equals('Athik Rathi'));
      expect(result.dob, equals('15/08/1998'));
      expect(result.gender, equals('MALE'));
      expect(result.address, contains('Anna Nagar'));
      expect(result.photoBase64, isNotEmpty);
      expect(result.hasValidSignature, isTrue);
    });

    test('should decode and parse ZIP archive even when preceded by folders or non-dot entries', () {
      final xmlBytes = utf8.encode(sampleXml);
      final archive = Archive();
      // Add empty folder and non-dot dummy entry before the XML file
      archive.addFile(ArchiveFile('OfflinePaperlessKycFolder', 0, Uint8List(0)));
      archive.addFile(ArchiveFile('META-INF', 0, Uint8List(0)));
      archive.addFile(ArchiveFile('offlineaadhaar20260901065022174.xml', xmlBytes.length, xmlBytes));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      expect(zipBytes, isNotNull);

      final base64Zip = base64Encode(zipBytes!);

      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: base64Zip,
        shareCode: '1939',
      );

      expect(result.isSuccess, isTrue);
      expect(result.name, equals('Athik Rathi'));
      expect(result.dob, equals('15/08/1998'));
      expect(result.address, contains('Anna Nagar'));
    });

    test('should decrypt password-protected ZIP archive when correct share code is provided', () {
      final xmlBytes = utf8.encode(sampleXml);
      final archive = Archive();
      archive.addFile(ArchiveFile('offlineaadhaar.xml', xmlBytes.length, xmlBytes));

      final zipEncoder = ZipEncoder(password: '1234');
      final encryptedBytes = zipEncoder.encode(archive)!;
      final base64Zip = base64Encode(encryptedBytes);

      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: base64Zip,
        shareCode: '1234',
      );

      expect(result.isSuccess, isTrue);
      expect(result.name, equals('Athik Rathi'));
    });

    test('should fail gracefully with clear error when share code is wrong', () {
      final xmlBytes = utf8.encode(sampleXml);
      final archive = Archive();
      archive.addFile(ArchiveFile('offlineaadhaar.xml', xmlBytes.length, xmlBytes));

      final zipEncoder = ZipEncoder(password: '1234');
      final encryptedBytes = zipEncoder.encode(archive)!;
      final base64Zip = base64Encode(encryptedBytes);

      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: base64Zip,
        shareCode: '9999',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Share Code'));
    });

    test('should fail gracefully when given non-xml non-zip garbage payload', () {
      final garbageBytes = utf8.encode("This is not a zip or xml document.");
      final base64Garbage = base64Encode(garbageBytes);

      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: base64Garbage,
        shareCode: '0000',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('should handle empty or malformed base64', () {
      final result = AadhaarOfflineParser.decryptAndParse(
        base64Data: '',
        shareCode: '1234',
      );
      expect(result.isSuccess, isFalse);
    });
  });
}
