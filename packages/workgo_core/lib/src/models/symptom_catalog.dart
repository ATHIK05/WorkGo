import 'dart:math';

/// A micro-triage clarifying question to disambiguate root causes.
class TriageOption {
  final String label;
  final String probableCategory;
  final String? likelyCause;

  const TriageOption({
    required this.label,
    required this.probableCategory,
    this.likelyCause,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'probableCategory': probableCategory,
        'likelyCause': likelyCause,
      };

  factory TriageOption.fromMap(Map<String, dynamic> map) => TriageOption(
        label: map['label'] as String? ?? '',
        probableCategory: map['probableCategory'] as String? ?? '',
        likelyCause: map['likelyCause'] as String?,
      );
}

class TriageQuestion {
  final String id;
  final String questionText;
  final List<TriageOption> options;

  const TriageQuestion({
    required this.id,
    required this.questionText,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'questionText': questionText,
        'options': options.map((o) => o.toMap()).toList(),
      };

  factory TriageQuestion.fromMap(Map<String, dynamic> map) => TriageQuestion(
        id: map['id'] as String? ?? '',
        questionText: map['questionText'] as String? ?? '',
        options: (map['options'] as List<dynamic>?)
                ?.map((o) => TriageOption.fromMap(Map<String, dynamic>.from(o as Map)))
                .toList() ??
            const [],
      );
}

/// Catalog entry for symptom-first triage.
class SymptomItem {
  final String id;
  final String title;
  final String description;
  final String equipmentTag;
  final String primaryCategory;
  final String secondaryCategory;
  final List<String> searchTokens;
  final List<String> likelyCauses;
  final List<TriageQuestion> clarifyingQuestions;
  final List<String> suggestedToolsNeeded;
  final bool isAmbiguous;

  const SymptomItem({
    required this.id,
    required this.title,
    required this.description,
    required this.equipmentTag,
    required this.primaryCategory,
    required this.secondaryCategory,
    required this.searchTokens,
    required this.likelyCauses,
    this.clarifyingQuestions = const [],
    this.suggestedToolsNeeded = const [],
    this.isAmbiguous = false,
  });
}

/// Result produced by either Gemini AI or Local Semantic Catalog Matcher.
class DiagnosticResult {
  final String symptomQuery;
  final String primaryCategory;
  final String? secondaryCategory;
  final double confidence;
  final String equipmentTag;
  final String summary;
  final List<String> likelyCauses;
  final List<TriageQuestion> clarifyingQuestions;
  final List<String> suggestedKeywords;
  final List<String> suggestedToolsNeeded;
  final bool requiresSmartDiagnosticVisit;
  final double diagnosticFee;
  final bool isAiGenerated;

  const DiagnosticResult({
    required this.symptomQuery,
    required this.primaryCategory,
    this.secondaryCategory,
    this.confidence = 0.85,
    required this.equipmentTag,
    required this.summary,
    this.likelyCauses = const [],
    this.clarifyingQuestions = const [],
    this.suggestedKeywords = const [],
    this.suggestedToolsNeeded = const [],
    this.requiresSmartDiagnosticVisit = true,
    this.diagnosticFee = 99.0,
    this.isAiGenerated = false,
  });

  Map<String, dynamic> toMap() => {
        'symptomQuery': symptomQuery,
        'primaryCategory': primaryCategory,
        'secondaryCategory': secondaryCategory,
        'confidence': confidence,
        'equipmentTag': equipmentTag,
        'summary': summary,
        'likelyCauses': likelyCauses,
        'clarifyingQuestions': clarifyingQuestions.map((q) => q.toMap()).toList(),
        'suggestedKeywords': suggestedKeywords,
        'suggestedToolsNeeded': suggestedToolsNeeded,
        'requiresSmartDiagnosticVisit': requiresSmartDiagnosticVisit,
        'diagnosticFee': diagnosticFee,
        'isAiGenerated': isAiGenerated,
      };

  factory DiagnosticResult.fromMap(Map<String, dynamic> map) => DiagnosticResult(
        symptomQuery: map['symptomQuery'] as String? ?? '',
        primaryCategory: map['primaryCategory'] as String? ?? 'Electrician',
        secondaryCategory: map['secondaryCategory'] as String?,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.80,
        equipmentTag: map['equipmentTag'] as String? ?? 'General Appliance',
        summary: map['summary'] as String? ?? '',
        likelyCauses: (map['likelyCauses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        clarifyingQuestions: (map['clarifyingQuestions'] as List<dynamic>?)
                ?.map((q) => TriageQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
                .toList() ??
            const [],
        suggestedKeywords: (map['suggestedKeywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        suggestedToolsNeeded: (map['suggestedToolsNeeded'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        requiresSmartDiagnosticVisit: map['requiresSmartDiagnosticVisit'] as bool? ?? true,
        diagnosticFee: (map['diagnosticFee'] as num?)?.toDouble() ?? 99.0,
        isAiGenerated: map['isAiGenerated'] as bool? ?? false,
      );
}

/// Comprehensive symptom catalog with multi-skill ambiguity resolution.
class SymptomCatalog {
  SymptomCatalog._();

  static final List<SymptomItem> items = [
    // 1. Water Motor / Submersible Pump (Classic cross-disciplinary: Electrician vs Plumber)
    const SymptomItem(
      id: 'water_motor_failure',
      title: 'Water Motor / Submersible Not Pumping Water',
      description: 'Motor runs or hums, but water is not lifting to the overhead tank, or trips breaker.',
      equipmentTag: 'Submersible Pump',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'motor', 'pump', 'submersible', 'borewell', 'water pump', 'thanni motor', 'paani motor',
        'humming', 'sound', 'not pumping', 'no water', 'dry run', 'capacitor', 'winding'
      ],
      likelyCauses: [
        'Capacitor failure or burnt motor start winding (Electrical)',
        'Foot valve / non-return valve leakage or air lock in suction pipe (Plumbing)',
        'Impeller wear & tear or jammed shaft bearing (Mechanical / Electrician)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'motor_q1',
          questionText: 'What sound does the motor make when switched on?',
          options: [
            TriageOption(
              label: 'Low humming sound, does not spin',
              probableCategory: 'Electrician',
              likelyCause: 'Weak starting capacitor or jammed rotor shaft',
            ),
            TriageOption(
              label: 'Spins normally, but zero water reaches the tank',
              probableCategory: 'Plumber',
              likelyCause: 'Foot valve leak, air lock, or pipe blockage',
            ),
            TriageOption(
              label: 'Main MCB / fuse trips immediately on switch on',
              probableCategory: 'Electrician',
              likelyCause: 'Coil short-circuit or earth fault in underground cable',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Multimeter', 'Pipe Wrench', 'Megger Insulation Tester', 'Capacitor Tester'],
      isAmbiguous: true,
    ),

    // 2. Inverter / Home Battery System
    const SymptomItem(
      id: 'inverter_backup_failure',
      title: 'Inverter Beeping or Fast Battery Drain',
      description: 'Inverter beeps continuously, does not charge, or shuts off immediately during power cuts.',
      equipmentTag: 'Inverter & Battery',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Appliance Repair',
      searchTokens: [
        'inverter', 'battery', 'ups', 'beeping', 'backup', 'power cut', 'charging', 'acid', 'tubular',
        'overload', 'current cut'
      ],
      likelyCauses: [
        'Low distilled water or sulfated battery plates (Battery maintenance)',
        'Inverter MOSFET / motherboard charging circuit blown (Electrical)',
        'Neutral loopback or home overload fault (Electrical)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'inverter_q1',
          questionText: 'What does the inverter front panel display or sound?',
          options: [
            TriageOption(
              label: 'Continuous beep with Overload / Fault red LED',
              probableCategory: 'Electrician',
              likelyCause: 'Internal board failure or line short circuit',
            ),
            TriageOption(
              label: 'Dies within 5-10 minutes of power cut',
              probableCategory: 'Electrician',
              likelyCause: 'Battery dead cells or electrolyte depletion',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Hydrometer', 'Clamp Meter', 'Battery Terminal Cleaner'],
      isAmbiguous: false,
    ),

    // 3. Geyser / Instant Water Heater (Electrician vs Plumber)
    const SymptomItem(
      id: 'geyser_heating_issue',
      title: 'Geyser Not Heating or Leaking Water',
      description: 'Water stays cold, heating takes too long, water leaks from bottom, or gives minor shocks.',
      equipmentTag: 'Water Heater / Geyser',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'geyser', 'water heater', 'instant geyser', 'heating', 'hot water', 'shock', 'leakage',
        'thermostat', 'coil', 'suudu thanni'
      ],
      likelyCauses: [
        'Heating element / coil calcified or open-circuit (Electrical)',
        'Thermostat cut-off switch tripped or faulty (Electrical)',
        'Inlet/outlet braided hose gasket deteriorated or inner tank puncture (Plumbing)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'geyser_q1',
          questionText: 'What is the exact observation?',
          options: [
            TriageOption(
              label: 'Indicator lights turn on, but water remains lukewarm or cold',
              probableCategory: 'Electrician',
              likelyCause: 'Burnt heating element',
            ),
            TriageOption(
              label: 'Water continuously drips from the body or connections',
              probableCategory: 'Plumber',
              likelyCause: 'Inlet hose burst, PRV valve leak, or tank weld corrosion',
            ),
            TriageOption(
              label: 'Mild electric tingling sensation in running tap water',
              probableCategory: 'Electrician',
              likelyCause: 'Severe heating coil insulation breakdown / improper earthing',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Socket Wrench', 'Multimeter', 'Teflon Tape', 'Spanner Set'],
      isAmbiguous: true,
    ),

    // 4. Split AC / Inverter AC
    const SymptomItem(
      id: 'ac_cooling_failure',
      title: 'AC Blower Running but No Cooling',
      description: 'Air conditioner blows ambient air, outdoor unit does not kick in, or indoor unit drips water.',
      equipmentTag: 'Air Conditioner',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'ac', 'air conditioner', 'split ac', 'inverter ac', 'cooling', 'ice', 'gas leak', 'refrigerant',
        'outdoor unit', 'water dripping', 'drip', 'dripping', 'ac leaking', 'ac leak', 'ac sound'
      ],
      likelyCauses: [
        'Refrigerant / freon gas leak at copper flare nut (Appliance)',
        'Outdoor compressor capacitor blown or PCB inverter board fault (Electrician/Appliance)',
        'Drain pipe clogged with algae causing indoor water overflow (Appliance)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'ac_q1',
          questionText: 'Is the outdoor compressor unit turning on?',
          options: [
            TriageOption(
              label: 'Outdoor fan runs, but air is not chilled at all',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Gas leakage or compressor capacitor failure',
            ),
            TriageOption(
              label: 'Water is dripping from the indoor unit onto the floor/wall',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Drain line blockage or frozen cooling coil',
            ),
            TriageOption(
              label: 'AC trips the MCB within 3 seconds of switching on',
              probableCategory: 'Electrician',
              likelyCause: 'Compressor winding grounded or stabilizer short',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Manifold Pressure Gauge', 'Nitrogen Leak Detector', 'Capacitor Tester', 'Jet Wash Pump'],
      isAmbiguous: true,
    ),

    // 5. MCB / Fuse / Switchboard Sparking
    const SymptomItem(
      id: 'mcb_tripping_spark',
      title: 'Main MCB Tripping or Switchboard Sparking',
      description: 'Breaker flips down repeatedly, burning smell from switchboard, or flickering lights.',
      equipmentTag: 'Switchboard & Distribution Board',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'mcb', 'fuse', 'trip', 'tripping', 'spark', 'sparking', 'switch', 'socket', 'plug',
        'smoke', 'burning smell', 'flicker', 'short circuit', 'current'
      ],
      likelyCauses: [
        'Neutral wire short circuit or neutral overload (Electrical)',
        'Faulty individual appliance drawing heavy surge current (Electrical)',
        'Loose copper terminal causing arcing and charred plastic (Electrical)'
      ],
      suggestedToolsNeeded: ['Insulated Screwdriver Set', 'Digital Clamp Meter', 'Infrared Thermometer'],
      isAmbiguous: false,
    ),

    // 6. Plumbing Pipe Leakage & Wall Dampness
    const SymptomItem(
      id: 'pipe_leakage_dampness',
      title: 'Concealed Pipe Leakage or Wall Dampness',
      description: 'Water seepage on walls, low tap water pressure, continuous toilet flush running, or broken tap.',
      equipmentTag: 'Plumbing & Concealed Piping',
      primaryCategory: 'Plumber',
      secondaryCategory: 'Carpenter',
      searchTokens: [
        'pipe', 'leak', 'water leak', 'tap', 'faucet', 'flush', 'toilet', 'seepage', 'dampness',
        'moisture', 'pressure', 'tank overflow', 'thanni ottudhu'
      ],
      likelyCauses: [
        'Concealed CPVC/UPVC pipe joint fissure inside wall (Plumbing)',
        'Worn washer / ceramic spindle in angle cock or sink tap (Plumbing)',
        'Faulty siphon valve or flush ball cock in toilet cistern (Plumbing)'
      ],
      suggestedToolsNeeded: ['Pipe Cutter', 'Thread Sealant', 'Basin Wrench', 'Solvent Cement'],
      isAmbiguous: false,
    ),

    // 7. RO Water Purifier
    const SymptomItem(
      id: 'ro_purifier_issue',
      title: 'RO Water Purifier Taste Bad or Tank Not Filling',
      description: 'Water tastes salty, waste water flows endlessly, or UV/pump does not power on.',
      equipmentTag: 'RO Water Purifier',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'ro', 'water purifier', 'filter', 'membrane', 'tds', 'taste', 'kent', 'aquaguard',
        'pureit', 'waste water', 'sediment'
      ],
      likelyCauses: [
        'Choked sediment/carbon pre-filter or exhausted RO membrane (Appliance)',
        'SMPS power adapter / booster pump solenoid valve failure (Appliance)',
        'Low incoming tap water pressure from overhead tank (Plumbing)'
      ],
      suggestedToolsNeeded: ['TDS Meter', 'Filter Spanner', 'Pressure Gauge'],
      isAmbiguous: true,
    ),

    // 8. Washing Machine (Drain vs Motor vs Electronic)
    const SymptomItem(
      id: 'washing_machine_fault',
      title: 'Washing Machine Not Spinning or Water Not Draining',
      description: 'Drum makes loud thumping noise, drum does not rotate, or water error code on display.',
      equipmentTag: 'Washing Machine',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'washing machine', 'drum', 'spin', 'drain', 'drainage', 'vibration', 'noise', 'front load',
        'top load', 'inlet valve'
      ],
      likelyCauses: [
        'Drain pump filter clogged with lint/coins (Appliance)',
        'Drive belt loose or motor carbon brushes worn (Appliance)',
        'Inlet solenoid valve clogged with hard-water calcium scale (Plumber/Appliance)'
      ],
      suggestedToolsNeeded: ['Drain Pump Pliers', 'Multimeter', 'Nut Driver Set'],
      isAmbiguous: true,
    ),
  ];

  // English stop words that should never artificially inflate equipment matches
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'my', 'is', 'are', 'was', 'were', 'it', 'its', 'in', 'on', 'at',
    'to', 'for', 'of', 'and', 'or', 'do', 'does', 'did', 'not', 'no', 'very', 'too',
    'properly', 'please', 'can', 'give', 'me', 'have', 'has', 'had', 'got', 'getting',
    'some', 'any', 'with', 'from', 'this', 'that', 'there', 'here', 'issue', 'problem',
    'working', 'works', 'work'
  };

  // Primary equipment identifiers mapped to item IDs
  static const Map<String, List<String>> _equipmentTokens = {
    'water_motor_failure': ['motor', 'pump', 'submersible', 'borewell', 'water motor', 'sump pump', 'monoblock'],
    'inverter_backup_failure': ['inverter', 'battery', 'ups', 'home battery'],
    'geyser_heating_issue': ['geyser', 'water heater', 'instant geyser', 'solar geyser'],
    'ac_cooling_failure': ['ac', 'air conditioner', 'split ac', 'inverter ac', 'window ac', 'cassette ac'],
    'mcb_tripping_spark': ['mcb', 'fuse', 'switchboard', 'switch board', 'circuit breaker', 'socket', 'switch'],
    'pipe_leakage_dampness': ['pipe', 'tap', 'faucet', 'flush', 'toilet', 'cistern', 'seepage', 'pipeline', 'plumbing'],
    'ro_purifier_issue': ['ro', 'water purifier', 'purifier', 'kent', 'aquaguard', 'pureit', 'membrane filter'],
    'washing_machine_fault': ['washing machine', 'washer', 'dryer', 'front load', 'top load'],
  };

  /// Check whether a word or phrase matches inside text with exact word boundaries.
  /// Prevents "ac" from matching "machine", "is" from matching "display", etc.
  static bool _matchesWordOrPhrase(String text, String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (t.contains(' ')) {
      return text.contains(t);
    }
    final reg = RegExp(r'\b' + RegExp.escape(t) + r'\b', caseSensitive: false);
    return reg.hasMatch(text);
  }

  /// Token-based local triage matching algorithm for instantaneous offline response.
  static DiagnosticResult matchSymptom(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const DiagnosticResult(
        symptomQuery: '',
        primaryCategory: 'Electrician',
        secondaryCategory: 'Plumber',
        confidence: 0.5,
        equipmentTag: 'General Repair',
        summary: 'Enter your appliance or household problem to diagnose the right specialist.',
        likelyCauses: ['Please provide a description of the symptoms.'],
      );
    }

    final allWords = query.split(RegExp(r'[\s,.-]+')).where((w) => w.length > 1).toList();
    final contentWords = allWords.where((w) => !_stopWords.contains(w)).toList();

    SymptomItem? bestItem;
    int bestScore = 0;

    for (final item in items) {
      int score = 0;

      // 1. Primary Equipment Name Match (+20 points)
      // If customer explicitly mentions the equipment (e.g. "ac", "geyser", "motor"),
      // that equipment MUST take priority over unrelated appliances.
      final equipTokens = _equipmentTokens[item.id] ?? [];
      for (final eqTok in equipTokens) {
        if (_matchesWordOrPhrase(query, eqTok)) {
          score += 20;
          break; // Count once per item
        }
      }

      // 2. Specialized Symptom / Fault Descriptor Tokens
      for (final token in item.searchTokens) {
        if (_matchesWordOrPhrase(query, token)) {
          score += (token.length > 5 ? 5 : 3);
        }
      }

      // 3. Content Word Overlap (Stopwords strictly excluded)
      for (final word in contentWords) {
        if (_matchesWordOrPhrase(item.title.toLowerCase(), word)) {
          score += 4;
        }
        if (_matchesWordOrPhrase(item.description.toLowerCase(), word)) {
          score += 2;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }

    if (bestItem != null && bestScore >= 3) {
      final double confidence = min(0.95, 0.70 + (bestScore * 0.03));
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: bestItem.primaryCategory,
        secondaryCategory: bestItem.secondaryCategory != bestItem.primaryCategory ? bestItem.secondaryCategory : null,
        confidence: confidence,
        equipmentTag: bestItem.equipmentTag,
        summary: bestItem.isAmbiguous
            ? 'Cross-disciplinary issue: Both ${bestItem.primaryCategory} and ${bestItem.secondaryCategory} skill sets may be relevant.'
            : 'Specialist match identified: ${bestItem.primaryCategory}.',
        likelyCauses: bestItem.likelyCauses,
        clarifyingQuestions: bestItem.clarifyingQuestions,
        suggestedKeywords: bestItem.searchTokens.take(4).toList(),
        suggestedToolsNeeded: bestItem.suggestedToolsNeeded,
        requiresSmartDiagnosticVisit: bestItem.isAmbiguous,
        diagnosticFee: 99.0,
        isAiGenerated: false,
      );
    }

    // Heuristic fallback based on common trade words with word boundaries
    if (_matchesWordOrPhrase(query, 'water') ||
        _matchesWordOrPhrase(query, 'pipe') ||
        _matchesWordOrPhrase(query, 'tap') ||
        _matchesWordOrPhrase(query, 'leak') ||
        _matchesWordOrPhrase(query, 'drain') ||
        _matchesWordOrPhrase(query, 'flush')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Plumber',
        secondaryCategory: 'Electrician',
        confidence: 0.70,
        equipmentTag: 'Water & Plumbing System',
        summary: 'Likely plumbing fixture or water flow issue. A diagnostic inspection will verify concealed lines.',
        likelyCauses: ['Pipe joint leakage', 'Valve wear', 'Blockage in drain line'],
        suggestedToolsNeeded: const ['Pipe Wrench', 'Thread Seal Tape', 'Basin Wrench', 'Hacksaw'],
        requiresSmartDiagnosticVisit: true,
        diagnosticFee: 99.0,
      );
    }

    if (_matchesWordOrPhrase(query, 'light') ||
        _matchesWordOrPhrase(query, 'wire') ||
        _matchesWordOrPhrase(query, 'switch') ||
        _matchesWordOrPhrase(query, 'fan') ||
        _matchesWordOrPhrase(query, 'power') ||
        _matchesWordOrPhrase(query, 'shock') ||
        _matchesWordOrPhrase(query, 'trip')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Electrician',
        secondaryCategory: 'Appliance Repair',
        confidence: 0.75,
        equipmentTag: 'Electrical Fixture',
        summary: 'Electrical distribution or fixture failure. Technician will verify voltage and continuity.',
        likelyCauses: ['Wiring short circuit', 'Loose connection', 'Switch/fuse malfunction'],
        suggestedToolsNeeded: const ['Digital Multimeter', 'Insulated Screwdriver', 'Wire Strippers', 'Neon Tester'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // Default neutral triage
    return DiagnosticResult(
      symptomQuery: rawQuery,
      primaryCategory: 'Electrician',
      secondaryCategory: 'Plumber',
      confidence: 0.60,
      equipmentTag: 'Household Appliance',
      summary: 'Cross-functional failure suspected. We recommend a verified diagnostic visit to pinpoint the root cause.',
      likelyCauses: ['Mechanical wear', 'Power supply issue', 'Installation defect'],
      suggestedToolsNeeded: const ['Multi-bit Screwdriver', 'Digital Multimeter', 'Adjustable Spanner'],
      requiresSmartDiagnosticVisit: true,
      diagnosticFee: 99.0,
    );
  }
}
