import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client/workgo_api_client.dart';
import '../models/symptom_catalog.dart';
import 'semantic_triage_matcher.dart';

/// WorkGo AI Diagnostic Service — 4-Tier Hybrid Cascade
///
/// Diagnoses household repair symptoms with zero API rate-limit risk,
/// zero APK bloat, and 100 % offline resilience.
///
/// Tier 1 — On-Device Exact / Stem Keyword Match (0 ms, 0 cost)
///   SymptomCatalog: 800 + Tanglish / Hinglish / native-script tokens.
///   Returns instantly when confidence ≥ 0.72.
///
/// Tier 2 — On-Device Semantic TF-IDF Matcher (< 5 ms, 0 cost)
///   SemanticTriageMatcher: bigram/trigram cosine similarity.
///   Resolves synonyms ("oozing" → "leaking") and paraphrases offline.
///   Returns when cosine similarity ≥ 0.22.
///
/// Tier 3 — Cloud Gemini 1.5 Flash via Backend Proxy (≤ 2 s, ~₹0)
///   POST /api/ai/triage on Render workgo-api.
///   Firestore SHA-256 cache → 0 ms on repeated identical queries.
///   Handles complex, colloquial, and code-mixed text at cloud scale.
///   No request/month cap — Gemini is token-billed only.
///
/// Tier 4 — Deterministic Safety Net (0 ms, 0 cost, always succeeds)
///   SymptomCatalog.matchSymptom() forced return.
///   Guarantees an actionable result even in airplane mode / basements.
///
/// Usage:
/// ```dart
/// final result = await AiDiagnosticService.instance.diagnoseSymptom(
///   'motor la sound varudhu thani varala',
///   languageCode: 'ta',
/// );
/// ```
class AiDiagnosticService {
  static final AiDiagnosticService instance = AiDiagnosticService._();
  AiDiagnosticService._();

  // ── Tier confidence thresholds ─────────────────────────────────────────────
  static const double _tier1MinConfidence = 0.72;

  // ── Tier 3 timeout ────────────────────────────────────────────────────────
  static const Duration _backendTimeout = Duration(seconds: 4);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Diagnoses [symptomQuery] through the 4-tier cascade.
  ///
  /// [languageCode] is an ISO-639-1 code (e.g. 'ta', 'hi', 'te', 'ml').
  /// It is forwarded to the backend as a hint for Gemini's multilingual prompt.
  /// It has no effect on Tier 1 or Tier 2 (those are language-agnostic by design).
  Future<DiagnosticResult> diagnoseSymptom(
    String symptomQuery, {
    String? languageCode,
  }) async {
    final query = symptomQuery.trim();
    if (query.isEmpty) {
      return SymptomCatalog.matchSymptom('');
    }

    // ── Tier 1: On-Device Keyword / Stem Match ─────────────────────────────
    final t1 = SymptomCatalog.matchSymptom(query);
    if (!t1.isOutOfScope && t1.confidence >= _tier1MinConfidence) {
      debugPrint('[AiDiagnosticService] Tier 1 HIT  cat=${t1.primaryCategory}  conf=${t1.confidence}');
      return t1;
    }
    debugPrint('[AiDiagnosticService] Tier 1 MISS  conf=${t1.confidence} → Tier 2');

    // ── Tier 2: On-Device Semantic TF-IDF ─────────────────────────────────
    if (SemanticTriageMatcher.instance.isReady) {
      try {
        final t2 = await SemanticTriageMatcher.instance.findBestMatch(query);
        if (t2 != null) {
          debugPrint('[AiDiagnosticService] Tier 2 HIT  cat=${t2.primaryCategory}  conf=${t2.confidence}');
          return t2;
        }
      } catch (e) {
        debugPrint('[AiDiagnosticService] Tier 2 ERROR (non-fatal): $e');
      }
    } else {
      debugPrint('[AiDiagnosticService] Tier 2 SKIP  (SemanticTriageMatcher not ready)');
    }
    debugPrint('[AiDiagnosticService] Tier 2 MISS → Tier 3 (backend cloud)');

    // ── Tier 3: Cloud Gemini via Backend Proxy ─────────────────────────────
    try {
      final dynamic raw = await WorkGoApiClient()
          .post('/api/ai/triage', {
            'query': query,
            'language': languageCode ?? 'en',
          })
          .timeout(_backendTimeout);

      if (raw is Map) {
        final result = DiagnosticResult.fromMap(Map<String, dynamic>.from(raw));
        debugPrint(
          '[AiDiagnosticService] Tier 3 HIT  '
          'source=${raw['source']}  cat=${result.primaryCategory}  conf=${result.confidence}',
        );
        return result;
      }
    } on TimeoutException {
      debugPrint('[AiDiagnosticService] Tier 3 TIMEOUT after ${_backendTimeout.inSeconds}s → Tier 4');
    } catch (e) {
      debugPrint('[AiDiagnosticService] Tier 3 ERROR (network/offline): $e → Tier 4');
    }

    // ── Tier 4: Deterministic Safety Net ──────────────────────────────────
    debugPrint('[AiDiagnosticService] Tier 4 FALLBACK  (SymptomCatalog deterministic)');
    return SymptomCatalog.matchSymptom(query);
  }

  /// Refines a diagnosis when a customer selects an answer to a clarifying
  /// triage question (unchanged from original implementation).
  DiagnosticResult refineDiagnosis({
    required DiagnosticResult baseResult,
    required String selectedProbableCategory,
    required String selectedOptionLabel,
    String? likelyCause,
  }) {
    final updatedCauses = List<String>.from(baseResult.likelyCauses);
    if (likelyCause != null && !updatedCauses.contains(likelyCause)) {
      updatedCauses.insert(0, likelyCause);
    }

    return DiagnosticResult(
      symptomQuery: baseResult.symptomQuery,
      primaryCategory: selectedProbableCategory,
      secondaryCategory: selectedProbableCategory == baseResult.primaryCategory
          ? baseResult.secondaryCategory
          : baseResult.primaryCategory,
      confidence: 0.94,
      equipmentTag: baseResult.equipmentTag,
      summary:
          'Diagnosis refined based on observation: "$selectedOptionLabel". '
          'Specialist dispatch routed to $selectedProbableCategory.',
      likelyCauses: updatedCauses,
      clarifyingQuestions: const [],
      suggestedKeywords: baseResult.suggestedKeywords,
      suggestedToolsNeeded: baseResult.suggestedToolsNeeded,
      requiresSmartDiagnosticVisit: baseResult.requiresSmartDiagnosticVisit,
      diagnosticFee: baseResult.diagnosticFee,
      isAiGenerated: baseResult.isAiGenerated,
    );
  }
}
