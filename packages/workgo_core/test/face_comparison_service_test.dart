import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('FaceComparisonService Tests', () {
    // Generate valid sample image bytes
    final sampleBytes1 = List<int>.generate(256, (i) => (i * 7) % 256);
    final sampleBytes2 = List<int>.generate(256, (i) => (i * 13) % 256);
    final base64Image1 = base64Encode(sampleBytes1);
    final base64Image2 = base64Encode(sampleBytes2);

    test('identical face images should yield 100% confidence match', () async {
      final result = await FaceComparisonService.instance.compareFaces(
        liveFaceBase64: base64Image1,
        registeredKycFaceBase64: base64Image1,
      );

      expect(result.isMatch, isTrue);
      expect(result.confidenceScore, equals(1.0));
      expect(result.confidencePercentage, equals(100));
      expect(result.errorMessage, isNull);
    });

    test('different face byte payloads should be computed without errors', () async {
      final result = await FaceComparisonService.instance.compareFaces(
        liveFaceBase64: base64Image1,
        registeredKycFaceBase64: base64Image2,
      );

      expect(result.errorMessage, isNull);
      expect(result.confidenceScore, greaterThanOrEqualTo(0.0));
      expect(result.confidenceScore, lessThanOrEqualTo(1.0));
    });

    test('invalid or empty base64 strings should return failure result gracefully', () async {
      final result = await FaceComparisonService.instance.compareFaces(
        liveFaceBase64: '',
        registeredKycFaceBase64: base64Image1,
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('landmark ratio calculations should compute invariant facial proportions', () {
      final ratios1 = FaceComparisonService.computeLandmarkRatios(
        leftEye: const math.Point(100.0, 100.0),
        rightEye: const math.Point(200.0, 100.0),
        noseBase: const math.Point(150.0, 160.0),
        leftMouth: const math.Point(120.0, 220.0),
        rightMouth: const math.Point(180.0, 220.0),
      );

      expect(ratios1.containsKey("interOcularToNose"), isTrue);
      expect(ratios1.containsKey("mouthWidthToEyeDistance"), isTrue);
      expect(ratios1["interOcularToNose"], greaterThan(0.0));

      // Scaled up face (2x zoom) should have the exact same invariant ratios!
      final ratiosScaled = FaceComparisonService.computeLandmarkRatios(
        leftEye: const math.Point(200.0, 200.0),
        rightEye: const math.Point(400.0, 200.0),
        noseBase: const math.Point(300.0, 320.0),
        leftMouth: const math.Point(240.0, 440.0),
        rightMouth: const math.Point(360.0, 440.0),
      );

      expect(ratios1["interOcularToNose"]!, closeTo(ratiosScaled["interOcularToNose"]!, 0.001));
      expect(ratios1["mouthWidthToEyeDistance"]!, closeTo(ratiosScaled["mouthWidthToEyeDistance"]!, 0.001));
    });

    test('comparison with high-confidence landmark match should pass verification', () async {
      final ratios = FaceComparisonService.computeLandmarkRatios(
        leftEye: const math.Point(100.0, 100.0),
        rightEye: const math.Point(200.0, 100.0),
        noseBase: const math.Point(150.0, 160.0),
      );

      final result = await FaceComparisonService.instance.compareFaces(
        liveFaceBase64: base64Image1,
        registeredKycFaceBase64: base64Image1,
        liveLandmarkRatios: ratios,
        kycLandmarkRatios: ratios,
      );

      expect(result.isMatch, isTrue);
      expect(result.confidenceScore, greaterThanOrEqualTo(0.72));
    });
  });
}
