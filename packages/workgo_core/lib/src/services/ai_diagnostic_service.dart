import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/symptom_catalog.dart';

/// AI Diagnostic Service using Google Generative AI (Gemini) with on-device semantic fallback.
class AiDiagnosticService {
  static final AiDiagnosticService instance = AiDiagnosticService._();
  AiDiagnosticService._();

  // API Key can be supplied via compile-time --dart-define or runtime initialization
  static String? _apiKey;

  static void initialize({String? apiKey}) {
    _apiKey = apiKey;
  }

  static String get _resolvedApiKey {
    if (_apiKey != null && _apiKey!.isNotEmpty) return _apiKey!;
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    const workgoKey = String.fromEnvironment('WORKGO_GEMINI_KEY');
    return workgoKey;
  }

  /// Diagnose a symptom or customer problem description.
  /// If Gemini API is available and succeeds, returns AI-generated structured diagnosis.
  /// Otherwise, gracefully falls back to the deterministic on-device Symptom Catalog.
  Future<DiagnosticResult> diagnoseSymptom(String symptomQuery) async {
    final query = symptomQuery.trim();
    if (query.isEmpty) {
      return SymptomCatalog.matchSymptom('');
    }

    final key = _resolvedApiKey;
    if (key.isNotEmpty) {
      try {
        final result = await _callGemini(query, key);
        if (result != null) return result;
      } catch (e) {
        debugPrint('[AiDiagnosticService] Gemini API call skipped or failed: $e');
      }
    }

    // High-performance on-device catalog fallback (0ms latency, 100% reliable offline)
    return SymptomCatalog.matchSymptom(query);
  }

  /// Calls Gemini 1.5 Flash with structured prompt for Indian household trades.
  Future<DiagnosticResult?> _callGemini(String query, String apiKey) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
      systemInstruction: Content.system('''
You are the WorkGo AI Diagnostic Engine for Indian household repairs.
Your task is to analyze customer symptom descriptions (including Indian English, Hinglish, Tanglish e.g. "motor la sound varudhu", "paani nahi aa raha", "geyser shock adikkudhu") and map them to the correct artisan craft trade.

Supported craft trades:
- "Electrician"
- "Plumber"
- "Carpenter"
- "Painter"
- "Cleaning"
- "Appliance Repair"
- "Masonry"
- "Welder / Metal"

Trade & Equipment Classification Rules:
1. "Electrician":
   - Household Fans: Ceiling fan, table fan, exhaust fan, pedestal fan, regulator ("fan not working", "fan slow", "pankha", "kaathadi") -> equipmentTag: "Ceiling Fan / Home Appliance". NEVER classify as "Air Conditioner".
   - Power & Safety: Switchboard, MCB tripping, fuse blown, wire sparking, electric shocks, earth leakage, Inverter & battery backup.
2. "Plumber":
   - Piping & Fixtures: Concealed pipe leak, dripping tap/faucet, broken angle cock, shower mixer, toilet cistern flush.
   - Drainage: Clogged sink, choked toilet, blocked bathroom floor trap, stagnant sewer water ("adaipu", "water standing").
3. "Appliance Repair":
   - Cooling & Thermal: Refrigerator/Fridge (ice buildup, not cooling), Air Conditioner (only if user specifies AC/cooling gas/split unit), Geyser / Water Heater (leaks or cold water), Microwave Oven.
   - Motorized Kitchen & Home: Washing Machine, Mixer Grinder (overload trip, coupler jammed, smoke), RO Water Purifier.
4. "Carpenter":
   - Doors & Locks: Main door key stuck, lock cylinder jammed ("pootu", "saavi", "darwaza"), door dragging on floor, loose hinges.
   - Furniture & Cabinets: Wardrobe drawer sliders, modular kitchen hinges, wooden bed/table/sofa fixing.
5. "Painter":
   - Surface & Coatings: Wall paint flaking/peeling, damp patches, putty touch-up, waterproofing, exterior/interior emulsion ("sunnam", "vannam", "safedi").
6. "Cleaning":
   - Specialized Deep Cleaning: Bathroom tile acid descaling, kitchen chimney grease jetting, sofa/mattress shampooing, full house sanitization.
7. "Welder / Metal":
   - Metal & Fabrication: Iron main gate broken hinge, balcony safety grill loose, rolling shutter stuck, metal railing welding ("irumbu", "loha").
8. "Masonry":
   - Civil, Tiles & Cement: Broken or hollow floor/wall tiles, re-grouting, cement plaster chipping/cracks, brickwork, granite/marble slab chipping ("kothanar", "mistri", "patthar").
9. Kitchen Gas Stove & Hob:
   - Under "Appliance Repair": LPG brass burner clogged, yellow flame, gas leak odor, auto-ignition spark failure ("gas aduppu", "chulha").

Disambiguation Rules:
- Refrigerator water leak: "Appliance Repair" (defrost drain clog), NOT "Plumber".
- AC indoor unit water drip: "Appliance Repair" (condensate drain line), NOT "Plumber".
- Ceiling fan, table fan, exhaust fan: "Electrician" (Ceiling Fan / Home Appliance), NEVER "Air Conditioner".
- Water motor / borewell pump: "Electrician" & "Plumber" cross-disciplinary, NOT general appliance.

Negative / Out-of-Scope Rule:
If the user's input refers to non-household services (such as stationery like "pen broken", personal electronics like "phone screen/laptop", vehicles like "car/bike puncture", food orders, medicine, clothing, salon, tutoring, banking, or unrecognized gibberish):
You MUST classify as:
"primaryCategory": "Out of Scope", "confidence": 0.0, "equipmentTag": "Non-Household Service", "requiresSmartDiagnosticVisit": false, "diagnosticFee": 0.0, "isOutOfScope": true.
NEVER guess or fall back to Electrician, Plumber, or any trade for out-of-scope or non-household requests.

For cross-disciplinary issues (e.g. Water motor failure which could be an electrical capacitor/winding failure OR a plumbing foot-valve/suction blockage; or AC not cooling which could be appliance gas leak OR electrician PCB power surge):
1. Identify primaryCategory (the most logical first responder).
2. Identify secondaryCategory (the cross-skill peer who may need to assist).
3. Set requiresSmartDiagnosticVisit to true if cross-disciplinary or root cause cannot be verified without on-site testing.
4. Provide 1 clarifying question with 2-3 specific options to help the customer disambiguate.
5. Provide 3-5 specific equipment and service keywords (e.g. "Submersible Pump", "Foot Valve", "Capacitor", "Inverter").

6. Suggest 3-5 specific tactical inspection tools, testing meters, and equipment needed by the artisan on-site (e.g. ["Manifold Gauge", "Capacitor Tester", "Nitrogen Leak Detector", "Multimeter"]).

Output ONLY valid JSON with keys:
{
  "primaryCategory": string,
  "secondaryCategory": string or null,
  "confidence": number between 0.0 and 0.98,
  "equipmentTag": string,
  "summary": string,
  "likelyCauses": [string, string, ...],
  "clarifyingQuestions": [
    {
      "id": "q1",
      "questionText": string,
      "options": [
        {"label": string, "probableCategory": string, "likelyCause": string}
      ]
    }
  ],
  "suggestedKeywords": [string, string, ...],
  "suggestedToolsNeeded": [string, string, ...],
  "requiresSmartDiagnosticVisit": boolean,
  "diagnosticFee": number,
  "isOutOfScope": boolean
}
'''),
    );

    final response = await model.generateContent([
      Content.text('Diagnose this household symptom: "$query"')
    ]);

    final rawJson = response.text;
    if (rawJson == null || rawJson.trim().isEmpty) return null;

    final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
    final isOutOfScope = parsed['isOutOfScope'] as bool? ?? (parsed['primaryCategory'] == 'Out of Scope');

    return DiagnosticResult(
      symptomQuery: query,
      primaryCategory: parsed['primaryCategory'] as String? ?? 'Electrician',
      secondaryCategory: parsed['secondaryCategory'] as String?,
      confidence: (parsed['confidence'] as num?)?.toDouble() ?? (isOutOfScope ? 0.0 : 0.85),
      equipmentTag: parsed['equipmentTag'] as String? ?? (isOutOfScope ? 'Non-Household Service' : 'Home Appliance'),
      summary: parsed['summary'] as String? ?? 'AI Diagnostic analysis completed.',
      likelyCauses: (parsed['likelyCauses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      clarifyingQuestions: (parsed['clarifyingQuestions'] as List<dynamic>?)
              ?.map((q) => TriageQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
              .toList() ??
          const [],
      suggestedKeywords: (parsed['suggestedKeywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      suggestedToolsNeeded: (parsed['suggestedToolsNeeded'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      requiresSmartDiagnosticVisit: isOutOfScope ? false : (parsed['requiresSmartDiagnosticVisit'] as bool? ?? true),
      diagnosticFee: isOutOfScope ? 0.0 : ((parsed['diagnosticFee'] as num?)?.toDouble() ?? 99.0),
      isAiGenerated: true,
      isOutOfScope: isOutOfScope,
    );
  }

  /// Refines diagnosis when user selects an answer to a clarifying triage question.
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
      summary: 'Diagnosis refined based on observation: "$selectedOptionLabel". Specialist dispatch routed to $selectedProbableCategory.',
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
