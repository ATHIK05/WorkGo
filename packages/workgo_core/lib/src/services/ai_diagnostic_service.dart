import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../api_client/workgo_api_client.dart';
import '../models/symptom_catalog.dart';
import 'semantic_triage_matcher.dart';

/// On-device self-learning cache: remembers high-confidence Tier 3 (Gemini) diagnoses
/// and serves them as instantaneous 0ms Tier 1.5 hits for identical or normalized queries.
///
/// Uses a `LinkedHashMap` as a pure-Dart LRU store: every read or write moves the
/// touched entry to the most-recently-used (end) position, and eviction always
/// removes the entry at the front (least-recently-used).
class TriageAdaptiveCache {
  static final TriageAdaptiveCache instance = TriageAdaptiveCache._();
  TriageAdaptiveCache._();

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  static const int _maxCacheSize = 300;
  static const double _minPutConfidence = 0.80;

  /// Learned diagnoses go stale as the catalog, pricing, and the cloud model
  /// itself improve. Without a ceiling, a bad Tier 3 read from months ago
  /// could keep winning over a much better current answer. 21 days keeps the
  /// 0ms-hit benefit for the normal repeat-symptom window (same appliance
  /// misbehaving again within a few weeks) without calcifying forever.
  static const Duration maxEntryAge = Duration(days: 21);

  int _hits = 0;
  int _misses = 0;

  /// Observability for tuning [_maxCacheSize] / [maxEntryAge] against real
  /// traffic. Diagnostics-only; never consulted by the cascade.
  int get hitCount => _hits;
  int get missCount => _misses;
  double get hitRatio => (_hits + _misses) == 0 ? 0.0 : _hits / (_hits + _misses);

  /// Regional / colloquial filler words that carry no diagnostic signal but
  /// commonly appear in Tanglish / Hinglish speech-to-text transcripts.
  /// Stripping these before sorting tokens means "AC la sound varudhu" and
  /// "sound varudhu AC la" normalize to the identical cache key.
  static const Set<String> _fillerStopwords = {
    // Tanglish fillers
    'irukku', 'iruku', 'varudhu', 'varuthu', 'aagudhu', 'aaguthu', 'pannuna',
    'pannunga', 'please', 'sir', 'madam', 'kindly', 'anna', 'aunty', 'uncle',
    'namba', 'enna', 'romba', 'konjam', 'illa', 'illai', 'thaan', 'than',
    // Hinglish fillers
    'raha', 'rahi', 'rahe', 'hoga', 'hogi', 'hoti', 'nahi', 'nahin', 'mera',
    'meri', 'mujhe', 'humein', 'kripya', 'thoda', 'thora', 'hain', 'hai',
    'wala', 'waali', 'kar', 'kro', 'karo',
    // Generic English fillers
    'the', 'and', 'for', 'from', 'with', 'this', 'that', 'not', 'very',
    'just', 'some', 'also', 'again', 'now',
  };

  String _normalizeKey(String query) {
    final cleaned = query
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s\u0900-\u0D7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    // A LinkedHashSet both dedupes repeated tokens (so "sound sound varudhu"
    // and "sound varudhu" key identically) and preserves first-seen order
    // before the explicit sort below.
    final words = LinkedHashSet<String>.from(
      cleaned.split(' ').where((w) => w.length >= 3 && !_fillerStopwords.contains(w)),
    ).toList()
      ..sort();
    return words.join(' ');
  }

  /// Retrieves a cached result, promoting it to most-recently-used on hit.
  /// Entries older than [maxEntryAge] are treated as a miss and evicted —
  /// a learned diagnosis that's three weeks stale is a liability, not an
  /// optimization.
  DiagnosticResult? get(String query) {
    final key = _normalizeKey(query);
    if (key.isEmpty) return null;
    final entry = _cache.remove(key);
    if (entry == null) {
      _misses++;
      return null;
    }
    if (DateTime.now().difference(entry.cachedAt) > maxEntryAge) {
      _misses++;
      return null; // already removed above; treat as a cold miss
    }
    // Re-insert to move this entry to the MRU (end) position.
    _cache[key] = entry;
    _hits++;
    return entry.result;
  }

  /// Returns true if a normalized entry for [query] currently exists, without
  /// affecting LRU order. Useful for diagnostics / cache-hit dashboards.
  bool hasKey(String query) {
    final key = _normalizeKey(query);
    if (key.isEmpty) return false;
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) <= maxEntryAge;
  }

  void put(String query, DiagnosticResult result) {
    if (result.isOutOfScope || result.confidence < _minPutConfidence) return;
    final key = _normalizeKey(query);
    if (key.isEmpty) return;

    // Drop any existing entry first so the re-insert below lands at MRU.
    _cache.remove(key);

    if (_cache.length >= _maxCacheSize) {
      // LinkedHashMap iterates in insertion order, so the first key is LRU.
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CacheEntry(
      DiagnosticResult(
        symptomQuery: result.symptomQuery,
        primaryCategory: result.primaryCategory,
        secondaryCategory: result.secondaryCategory,
        confidence: result.confidence,
        equipmentTag: result.equipmentTag,
        summary: result.summary,
        likelyCauses: result.likelyCauses,
        clarifyingQuestions: result.clarifyingQuestions,
        suggestedKeywords: result.suggestedKeywords,
        suggestedToolsNeeded: result.suggestedToolsNeeded,
        requiresSmartDiagnosticVisit: result.requiresSmartDiagnosticVisit,
        diagnosticFee: result.diagnosticFee,
        isAiGenerated: true,
        isOutOfScope: false,
      ),
      DateTime.now(),
    );
  }

  /// Invalidates a single normalized entry, if present. Returns true if an
  /// entry was actually removed.
  bool invalidate(String query) {
    final key = _normalizeKey(query);
    if (key.isEmpty) return false;
    return _cache.remove(key) != null;
  }

  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  int get size => _cache.length;

  /// Snapshot of normalized keys currently resident, most-recently-used last.
  /// Diagnostics-only; not used by the cascade itself.
  List<String> get keysByRecency => List.unmodifiable(_cache.keys);
}

/// Internal wrapper pairing a learned [DiagnosticResult] with the moment it
/// was cached, so [TriageAdaptiveCache] can expire stale entries.
class _CacheEntry {
  final DiagnosticResult result;
  final DateTime cachedAt;
  const _CacheEntry(this.result, this.cachedAt);
}

/// WorkGo AI Diagnostic Service — 4-Tier Hybrid Cascade with Adaptive Learning
///
/// Diagnoses household repair symptoms with zero API rate-limit risk,
/// zero APK bloat, and 100 % offline resilience.
///
/// Tier 1 — On-Device Exact / Stem / Fuzzy Keyword Match (0 ms, 0 cost)
///   SymptomCatalog: 800 + Tanglish / Hinglish / native-script tokens with
///   Levenshtein phonetic tolerance for speech-to-text slips.
///   Returns instantly when confidence ≥ 0.72.
///
/// Tier 1.5 — On-Device Adaptive Learning Cache (0 ms, 0 network)
///   TriageAdaptiveCache: Learns high-confidence (≥ 0.80) cloud triage results
///   locally in an LRU store (300-entry capacity). Subsequent matching queries —
///   including word-order variants once filler stopwords are stripped — resolve
///   instantly offline with 0 cloud calls.
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
/// Circuit breaker guarding the Tier 3 cloud call (classic Closed / Open /
/// Half-Open state machine — see Fowler, "CircuitBreaker", and the Azure
/// Architecture Center's Circuit Breaker pattern).
///
/// Without this, a sustained backend outage means *every* diagnosis pays the
/// full 4-second [AiDiagnosticService._backendTimeout] before falling back to
/// Tier 4, one call at a time. Once 3 consecutive Tier 3 calls fail, the
/// breaker opens and subsequent calls skip straight to Tier 4 for 30 seconds,
/// then allows a single half-open probe through to test recovery.
class _Tier3CircuitBreaker {
  static const int _failureThreshold = 3;
  static const Duration _openDuration = Duration(seconds: 30);

  bool _open = false;
  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  /// Whether a Tier 3 call should be attempted right now. Calling this also
  /// performs the Open → Half-Open transition once [_openDuration] elapses.
  bool get allowsRequest {
    if (!_open) return true;
    final openedAt = _openedAt;
    if (openedAt != null && DateTime.now().difference(openedAt) >= _openDuration) {
      return true; // half-open: let exactly one trial call through
    }
    return false;
  }

  void recordSuccess() {
    _open = false;
    _consecutiveFailures = 0;
    _openedAt = null;
  }

  void recordFailure() {
    _consecutiveFailures++;
    // Any failure while half-open (i.e. already past _openDuration) re-opens
    // immediately; otherwise open once the consecutive-failure threshold hits.
    if (_open || _consecutiveFailures >= _failureThreshold) {
      _open = true;
      _openedAt = DateTime.now();
    }
  }

  bool get isOpen => _open;
}

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

  // ── Tier confidence gates ────────────────────────────────────────────────
  static const double _tier1MinConfidence = 0.72;
  static const double _tier1_5MinConfidence = 0.80; // enforced in TriageAdaptiveCache.put
  static const double _tier2MinConfidence = 0.22; // enforced in SemanticTriageMatcher

  // ── Tier 3 timeout ────────────────────────────────────────────────────────
  static const Duration _backendTimeout = Duration(seconds: 4);

  final _Tier3CircuitBreaker _tier3Breaker = _Tier3CircuitBreaker();

  /// In-flight Tier 3 (+ Tier 4 fallback) futures keyed by normalized query.
  /// Implements request coalescing / "singleflight": if a user double-taps
  /// "Diagnose" or two screens independently diagnose the same symptom while
  /// a cloud call is already in progress, every caller shares that one
  /// Future instead of firing a second Gemini request for the same query.
  final Map<String, Future<DiagnosticResult>> _tier3InFlight = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Diagnoses [symptomQuery] through the 4-tier cascade.
  ///
  /// [languageCode] is an ISO-639-1 code (e.g. 'ta', 'hi', 'te', 'ml').
  /// It is forwarded to the backend as a hint for Gemini's multilingual prompt.
  /// It has no effect on Tier 1 or Tier 2 (those are language-agnostic by design).
  ///
  /// [contextEquipmentHint] is an optional hint (e.g. 'Air Conditioner', 'Water Heater / Geyser')
  /// from the user's registered home appliances or booking history to disambiguate identical
  /// symptoms. It is threaded through to both the Tier 1 catalog lookup and the Tier 4
  /// deterministic fallback so equipment context is never lost even when the cascade
  /// bottoms out.
  Future<DiagnosticResult> diagnoseSymptom(
    String symptomQuery, {
    String? languageCode,
    String? contextEquipmentHint,
  }) async {
    final query = symptomQuery.trim();
    if (query.isEmpty) {
      return SymptomCatalog.matchSymptom('', contextEquipmentHint: contextEquipmentHint);
    }

    // ── Tier 1: On-Device Keyword / Stem / Fuzzy Match ───────────────────
    final t1 = SymptomCatalog.matchSymptom(query, contextEquipmentHint: contextEquipmentHint);
    if (!t1.isOutOfScope && t1.confidence >= _tier1MinConfidence) {
      debugPrint('[AiDiagnosticService] Tier 1 HIT  cat=${t1.primaryCategory}  conf=${t1.confidence}');
      return t1;
    }
    debugPrint('[AiDiagnosticService] Tier 1 MISS  conf=${t1.confidence} → Checking Tier 1.5 Adaptive Cache');

    // ── Tier 1.5: On-Device Adaptive Learning Cache (0 ms, 0 network) ────
    final cachedResult = TriageAdaptiveCache.instance.get(query);
    if (cachedResult != null) {
      debugPrint('[AiDiagnosticService] Tier 1.5 ADAPTIVE CACHE HIT  cat=${cachedResult.primaryCategory}  conf=${cachedResult.confidence}');
      return cachedResult;
    }

    // ── Tier 2: On-Device Semantic TF-IDF ─────────────────────────────────
    if (SemanticTriageMatcher.instance.isReady) {
      try {
        final t2 = await SemanticTriageMatcher.instance.findBestMatch(query);
        if (t2 != null && t2.confidence >= _tier2MinConfidence) {
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

    // ── Tier 3 (+ Tier 4 fallback), coalesced ──────────────────────────────
    // Keyed on query + language + equipment hint, since those together fully
    // determine the backend request and its fallback.
    final flightKey = '$query\u0000${languageCode ?? 'en'}\u0000${contextEquipmentHint ?? ''}';
    final existingFlight = _tier3InFlight[flightKey];
    if (existingFlight != null) {
      debugPrint('[AiDiagnosticService] Tier 3 COALESCED with an identical in-flight request');
      return existingFlight;
    }

    final flight = _resolveTier3ThenFallback(
      query: query,
      languageCode: languageCode,
      contextEquipmentHint: contextEquipmentHint,
    );
    _tier3InFlight[flightKey] = flight;
    try {
      return await flight;
    } finally {
      _tier3InFlight.remove(flightKey);
    }
  }

  /// Attempts the Tier 3 cloud call (guarded by the [_tier3Breaker]) and
  /// always falls through to the Tier 4 deterministic safety net on any
  /// failure, timeout, or open circuit. Never throws.
  Future<DiagnosticResult> _resolveTier3ThenFallback({
    required String query,
    required String? languageCode,
    required String? contextEquipmentHint,
  }) async {
    if (_tier3Breaker.allowsRequest) {
      try {
        final dynamic raw = await WorkGoApiClient()
            .post('/api/ai/triage', {
              'query': query,
              'language': languageCode ?? 'en',
            })
            .timeout(_backendTimeout);

        if (raw is Map) {
          final result = DiagnosticResult.fromMap(Map<String, dynamic>.from(raw));
          _tier3Breaker.recordSuccess();
          debugPrint(
            '[AiDiagnosticService] Tier 3 HIT  '
            'source=${raw['source']}  cat=${result.primaryCategory}  conf=${result.confidence}',
          );
          // Adaptive feedback loop: Learn high-confidence cloud triage for 0ms future hits
          if (result.confidence >= _tier1_5MinConfidence && !result.isOutOfScope) {
            TriageAdaptiveCache.instance.put(query, result);
          }
          return result;
        }
        // Backend responded but not with the expected shape — treat as a
        // failure for breaker purposes so a misbehaving deploy still trips it.
        _tier3Breaker.recordFailure();
        debugPrint('[AiDiagnosticService] Tier 3 MALFORMED RESPONSE → Tier 4');
      } on TimeoutException {
        _tier3Breaker.recordFailure();
        debugPrint('[AiDiagnosticService] Tier 3 TIMEOUT after ${_backendTimeout.inSeconds}s → Tier 4');
      } catch (e) {
        _tier3Breaker.recordFailure();
        debugPrint('[AiDiagnosticService] Tier 3 ERROR (network/offline): $e → Tier 4');
      }
    } else {
      debugPrint('[AiDiagnosticService] Tier 3 CIRCUIT OPEN (backend degraded) → skipping straight to Tier 4');
    }

    // ── Tier 4: Deterministic Safety Net ──────────────────────────────────
    debugPrint('[AiDiagnosticService] Tier 4 FALLBACK  (SymptomCatalog deterministic)');
    return SymptomCatalog.matchSymptom(query, contextEquipmentHint: contextEquipmentHint);
  }

  /// True while the Tier 3 circuit breaker is open, i.e. the backend is
  /// considered degraded and calls are skipping straight to Tier 4.
  /// Diagnostics-only — useful for a status banner ("running offline").
  bool get isCloudTierDegraded => _tier3Breaker.isOpen;

  /// Refines a diagnosis when a customer selects an answer to a clarifying
  /// triage question.
  ///
  /// Trade relationship handling:
  /// - If the selected category **confirms** the original primary category,
  ///   the original secondary category is preserved as the fallback trade.
  /// - If the selected category **reroutes** to a different trade than the
  ///   original primary, the original primary is demoted to secondary so it
  ///   remains available as a fallback for the dispatcher/technician.
  ///
  /// Fee handling:
  /// - A confirmed trade means the clarifying question has fully resolved the
  ///   ambiguity that justified a paid smart-diagnostic visit, so the visit
  ///   requirement and its fee are waived.
  /// - A rerouted trade means the fault sits with a different specialist than
  ///   originally predicted, so the smart-diagnostic visit (and its fee, if
  ///   any) is preserved to let that specialist confirm on-site.
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

    final bool tradeConfirmed = selectedProbableCategory == baseResult.primaryCategory;

    final String? refinedSecondary =
        tradeConfirmed ? baseResult.secondaryCategory : baseResult.primaryCategory;

    final bool refinedRequiresVisit =
        tradeConfirmed ? false : baseResult.requiresSmartDiagnosticVisit;
    final double refinedFee = refinedRequiresVisit ? baseResult.diagnosticFee : 0.0;

    return DiagnosticResult(
      symptomQuery: baseResult.symptomQuery,
      primaryCategory: selectedProbableCategory,
      secondaryCategory: refinedSecondary,
      confidence: 0.94,
      equipmentTag: baseResult.equipmentTag,
      summary:
          'Diagnosis refined based on observation: "$selectedOptionLabel". '
          'Specialist dispatch routed to $selectedProbableCategory.',
      likelyCauses: updatedCauses,
      clarifyingQuestions: const [],
      suggestedKeywords: baseResult.suggestedKeywords,
      suggestedToolsNeeded: baseResult.suggestedToolsNeeded,
      requiresSmartDiagnosticVisit: refinedRequiresVisit,
      diagnosticFee: refinedFee,
      isAiGenerated: baseResult.isAiGenerated,
    );
  }
}
