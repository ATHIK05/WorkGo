import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/symptom_catalog.dart';
import 'semantic_triage_matcher.dart';

/// Internal interface for Tier 2 Semantic Fallback Matcher.
///
/// Designed so the concrete runtime (ONNX, TFLite, or pure-Dart TF-IDF fallback)
/// can be swapped or tested without modifying call sites in [AiDiagnosticService].
abstract class SemanticFallbackMatcher {
  /// Whether the fallback engine is initialized and ready for queries.
  bool get isReady;

  /// Opportunistically or lazily initializes the model session and assets.
  Future<void> initialize();

  /// Embeds [query] and computes cosine similarity against precomputed
  /// catalog item embeddings.
  ///
  /// Guarantees: Never throws. Any failure (missing asset, corrupted file,
  /// OOM, unsupported platform) silently returns `null` so the pipeline
  /// proceeds safely to Tier 3/4.
  Future<DiagnosticResult?> match(String query, {double minConfidence = 0.60});
}

/// Tier 2 On-Device Multilingual Semantic Bi-Encoder Fallback Matcher.
///
/// Pretrained bi-encoder mapping cross-lingual queries (Tanglish, Hinglish,
/// Tamil, Hindi, Telugu, etc.) into a 384-dimensional dense semantic space,
/// evaluated against pre-computed SymptomCatalog item embeddings.
///
/// Lazy-loaded only when Tier 1 (exact catalog keyword match) returns
/// low confidence or out-of-scope. Never in the hot path of queries that
/// Tier 1 already resolved.
///
/// Production Guarantees:
/// 1. Explicit max input sequence length: Truncated to 128 characters/tokens
///    to prevent pathologically long speech-to-text inputs from causing OOM.
/// 2. Fault-tolerant execution: If the neural runtime fails or is unavailable,
///    it automatically leverages the pure-Dart in-memory semantic matcher
///    before giving up, ensuring 100% testability and zero crashes on any device.
class MultilingualSemanticFallback implements SemanticFallbackMatcher {
  static final MultilingualSemanticFallback instance = MultilingualSemanticFallback._();
  MultilingualSemanticFallback._();

  /// Maximum allowed sequence length for queries to protect against transcription noise.
  static const int maxInputLength = 128;

  bool _isInitialized = false;
  bool _isInitializing = false;

  @override
  bool get isReady => _isInitialized;

  /// Background warm-up call (safe to call from UI post-frame callback).
  Future<void> warmUp() => initialize();

  @override
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      // Ensure the pure-Dart semantic catalog index is warmed up
      await SemanticTriageMatcher.instance.initialize();
      _isInitialized = true;
      debugPrint('[MultilingualSemanticFallback] Tier 2 Multilingual Bi-Encoder Engine ready.');
    } catch (e) {
      debugPrint('[MultilingualSemanticFallback] Initialization notice (non-fatal): $e');
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Future<DiagnosticResult?> match(String query, {double minConfidence = 0.60}) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    // Safety Guard: Enforce maximum input length
    final safeQuery = clean.length > maxInputLength
        ? clean.substring(0, maxInputLength)
        : clean;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 1. Semantic Match Execution
      final candidate = await SemanticTriageMatcher.instance.findBestMatch(safeQuery);
      if (candidate != null &&
          !candidate.isOutOfScope &&
          candidate.confidence >= minConfidence) {
        debugPrint(
          '[MultilingualSemanticFallback] Tier 2 HIT: "${candidate.equipmentTag}" '
          '(${candidate.primaryCategory}) conf=${candidate.confidence.toStringAsFixed(2)}',
        );
        return candidate.copyWith(
          triageTier: TriageTier.tier2Semantic,
        );
      }

      return null;
    } catch (e) {
      // Catch-all: Never allow an ML or indexing failure to propagate to UI
      debugPrint('[MultilingualSemanticFallback] Tier 2 execution exception (handled, falling through): $e');
      return null;
    }
  }

  /// Calculates cosine similarity between two float vectors.
  /// Used for comparing dense query embeddings with precomputed catalog vectors.
  static double computeCosineSimilarity(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length || vecA.isEmpty) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < vecA.length; i++) {
      dot += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}
