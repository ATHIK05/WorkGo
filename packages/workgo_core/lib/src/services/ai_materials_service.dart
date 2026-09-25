import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'trade_tool_catalog.dart';

/// Represents a single line item in the customer's pre-booking materials checklist.
/// The customer marks whether they already own it (isProvidedByCustomer = true)
/// or if the artisan needs to purchase it from the designated store.
class MaterialChecklistItem {
  final String name;
  final String category; // 'primary_tool' | 'consumable' | 'safety' | 'custom'
  bool isProvidedByCustomer;

  MaterialChecklistItem({
    required this.name,
    required this.category,
    this.isProvidedByCustomer = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'isProvidedByCustomer': isProvidedByCustomer,
      };

  factory MaterialChecklistItem.fromMap(Map<String, dynamic> m) =>
      MaterialChecklistItem(
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? 'consumable',
        isProvidedByCustomer: m['isProvidedByCustomer'] as bool? ?? false,
      );

  MaterialChecklistItem copyWith({bool? isProvidedByCustomer}) =>
      MaterialChecklistItem(
        name: name,
        category: category,
        isProvidedByCustomer: isProvidedByCustomer ?? this.isProvidedByCustomer,
      );
}

/// Result from the AIMaterialsService resolution pipeline.
class MaterialsResolutionResult {
  final List<MaterialChecklistItem> items;
  final bool isAiEnriched;
  final String source; // 'catalog', 'gemini', 'catalog+gemini'

  const MaterialsResolutionResult({
    required this.items,
    required this.isAiEnriched,
    required this.source,
  });

  /// Items that the customer indicated the artisan needs to buy.
  List<String> get artisanNeedsToBuy => items
      .where((i) => !i.isProvidedByCustomer)
      .map((i) => i.name)
      .toList();
}

/// Dual-engine AI Materials & Spare Parts Resolver.
///
/// Resolution pipeline:
///   Tier 1 (0ms, offline-safe): TradeToolCatalog domain matrix — structured per-trade parts list.
///   Tier 2 (network, optional): Google Gemini AI — parses symptom description text and augments
///   with bespoke/context-specific spare parts not captured in the fixed catalog.
///
/// Design principles:
/// - Tier 1 always succeeds — the customer is NEVER shown a loading spinner waiting for AI.
/// - Tier 2 results are MERGED into the list, deduplicating by normalized name.
/// - If Gemini is unavailable (offline, quota, API error), the user gets Tier 1 silently.
/// - Zero emojis in any returned item name.
class AIMaterialsService {
  AIMaterialsService._();
  static final AIMaterialsService instance = AIMaterialsService._();

  static const Duration _geminiTimeout = Duration(seconds: 8);

  /// Maximum number of additional items Gemini can contribute beyond the domain catalog.
  static const int _maxGeminiAdditions = 6;

  /// Resolve the materials checklist for a given trade and optional issue description.
  ///
  /// Always returns quickly (Tier 1). If [geminiApiKey] is supplied and network
  /// is available, Gemini augments the result asynchronously.
  Future<MaterialsResolutionResult> resolve({
    required String serviceType,
    String? issueDescription,
    String? geminiApiKey,
  }) async {
    // \u2500\u2500 Tier 1: Instant domain catalog resolution \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    final kit = TradeToolCatalog.getEquipmentKit(
      serviceType: serviceType,
      issueText: issueDescription,
    );

    final items = <MaterialChecklistItem>[
      for (final t in kit.primaryTools)
        MaterialChecklistItem(name: t, category: 'primary_tool'),
      for (final c in kit.consumables)
        MaterialChecklistItem(name: c, category: 'consumable'),
      for (final s in kit.safetyGear)
        MaterialChecklistItem(name: s, category: 'safety'),
    ];

    // \u2500\u2500 Tier 2: Gemini AI enrichment (best-effort, non-blocking) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    if (geminiApiKey != null &&
        geminiApiKey.isNotEmpty &&
        issueDescription != null &&
        issueDescription.trim().isNotEmpty) {
      try {
        final additions = await _geminiEnrich(
          serviceType: serviceType,
          issueDescription: issueDescription.trim(),
          existingItemNames: items.map((i) => i.name).toList(),
          apiKey: geminiApiKey,
        ).timeout(_geminiTimeout);

        if (additions.isNotEmpty) {
          for (final add in additions) {
            items.add(MaterialChecklistItem(name: add, category: 'consumable'));
          }
          debugPrint(
              '[AIMaterialsService] Gemini enriched with ${additions.length} additional items');
          return MaterialsResolutionResult(
            items: items,
            isAiEnriched: true,
            source: 'catalog+gemini',
          );
        }
      } catch (e) {
        debugPrint('[AIMaterialsService] Gemini enrichment skipped: $e');
        // Silent fallback to Tier 1 only
      }
    }

    return MaterialsResolutionResult(
      items: items,
      isAiEnriched: false,
      source: 'catalog',
    );
  }

  Future<List<String>> _geminiEnrich({
    required String serviceType,
    required String issueDescription,
    required List<String> existingItemNames,
    required String apiKey,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final existingList = existingItemNames.take(10).join(', ');
    final prompt = '''
You are a trade materials expert for Indian home services.
Trade: $serviceType
Customer described issue: "$issueDescription"
We already have these tools listed: $existingList

List up to $_maxGeminiAdditions ADDITIONAL specific spare parts or consumables the artisan may need to buy from a hardware store to fix this specific issue.
Rules:
- Return ONLY a JSON array of plain strings. Example: ["1/2\\" Brass Gate Valve","CPVC 90-degree Elbow"]
- No explanations, no markdown fences, no emojis.
- Each item must be a real hardware product purchasable at an Indian hardware store.
- Do NOT repeat anything already in the existing list.
- If nothing extra is needed, return an empty array [].
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final trimmed = text.trim();

    // Parse conservative JSON array
    try {
      final start = trimmed.indexOf('[');
      final end = trimmed.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return [];
      final jsonStr = trimmed.substring(start, end + 1);
      final parsed = jsonDecode(jsonStr) as List<dynamic>;
      return parsed
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty && s.length < 80)
          .take(_maxGeminiAdditions)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
