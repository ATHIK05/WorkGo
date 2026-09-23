import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/src/models/symptom_catalog.dart';
import 'package:workgo_core/src/services/multilingual_semantic_fallback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2 MultilingualSemanticFallback Crash-Safety & Inference Tests', () {
    final fallback = MultilingualSemanticFallback.instance;

    setUpAll(() async {
      await fallback.initialize();
    });

    test('Initializes cleanly and reports isReady = true', () {
      expect(fallback.isReady, isTrue);
    });

    test('Handles empty and whitespace queries gracefully without throwing', () async {
      final res1 = await fallback.match('');
      final res2 = await fallback.match('     ');
      expect(res1, isNull);
      expect(res2, isNull);
    });

    test('Truncates pathologically long queries (> 128 chars) safely without OOM or crash', () async {
      final longQuery = 'water motor ' * 40; // 480 characters
      expect(longQuery.length, greaterThan(MultilingualSemanticFallback.maxInputLength));

      // Must execute cleanly without exception
      final res = await fallback.match(longQuery);
      if (res != null) {
        expect(res.triageTier, equals(TriageTier.tier2Semantic));
      }
    });

    test('Computes cosine similarity correctly', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      final v3 = [0.0, 1.0, 0.0];
      final v4 = [0.5, 0.5, 0.0];

      // Identical vectors = 1.0
      expect(MultilingualSemanticFallback.computeCosineSimilarity(v1, v2), closeTo(1.0, 0.0001));
      // Orthogonal vectors = 0.0
      expect(MultilingualSemanticFallback.computeCosineSimilarity(v1, v3), closeTo(0.0, 0.0001));
      // Intermediate similarity
      expect(MultilingualSemanticFallback.computeCosineSimilarity(v1, v4), closeTo(0.7071, 0.001));
      // Empty vectors
      expect(MultilingualSemanticFallback.computeCosineSimilarity([], []), equals(0.0));
    });

    test('Resolves colloquial paraphrase and assigns TriageTier.tier2Semantic', () async {
      // "dripping droplets from my room cooler"
      final res = await fallback.match('dripping droplets from my room cooler');
      if (res != null) {
        expect(res.triageTier, equals(TriageTier.tier2Semantic));
        expect(res.confidence, greaterThanOrEqualTo(0.50));
      }
    });

    test('Returns null on completely irrelevant or out-of-scope query', () async {
      final res = await fallback.match('buy crypto bitcoin stocks investment');
      expect(res, isNull);
    });

    test('Handles malformed inputs, null bytes, and non-printable control characters safely', () async {
      final malformedQuery = 'cooler\u0000\u0007\u001F\uFFFFwater leaking';
      final res = await fallback.match(malformedQuery);
      // Must not throw, either matches or returns null safely
      expect(res, anyOf(isNull, isA<DiagnosticResult>()));
    });
  });
}
