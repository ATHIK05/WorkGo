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
  final bool isOutOfScope;

  bool get isValidHouseholdService => !isOutOfScope;

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
    this.isOutOfScope = false,
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
        'isOutOfScope': isOutOfScope,
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
        isOutOfScope: map['isOutOfScope'] as bool? ?? false,
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
        'humming', 'sound', 'not pumping', 'no water', 'dry run', 'capacitor', 'winding',
        // Romanized Tanglish / Hinglish / Manglish
        'motor la sound varudhu', 'thani varala', 'motor odala', 'motor chal nahi raha',
        'motor tiragatledu', 'motor chalda nahi', 'motor ghuri na', 'motor kaam nahi karta',
        'pani nahi aa raha', 'motor awaaz kar raha', 'paani motor nahi chal raha',
        'motor avde vellam varala', 'motor pravar thiitilla',
        // Native Tamil script
        'மோட்டார் ஓடல', 'தண்ணீர் வரல', 'மோட்டார் சத்தம்', 'தண்ணி வரல',
        // Native Hindi (Devanagari)
        'मोटर चल नहीं रही', 'पानी नहीं आ रहा', 'पंप बंद',
        // Native Telugu
        'మోటార్ పని చేయడం లేదు', 'నీళ్ళు రావడం లేదు',
        // Native Malayalam
        'മോട്ടോർ പ്രവർത്തിക്കുന്നില്ല', 'വെള്ളം വരുന്നില്ല',
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
        'thermostat', 'coil', 'suudu thanni',
        // Romanized Tanglish / Hinglish
        'geyser shock adikkudhu', 'suudu thanni varala', 'geyser se shock', 'geysur ka paani thanda',
        'geyser kaam nahi kar raha', 'geyser la current adikkudhu', 'boiler problem',
        // Native Tamil script
        'கீஸர் சரியில்லை', 'சூடு தண்ணி வரல', 'கீஸர் ஷாக் அடிக்குது',
        // Native Hindi
        'गीज़र खराब', 'गर्म पानी नहीं आ रहा', 'गीज़र से शॉक',
        // Native Telugu
        'గీజర్ పని చేయడం లేదు', 'వేడి నీళ్ళు రావడం లేదు',
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
        'outdoor unit', 'water dripping', 'drip', 'dripping', 'ac leaking', 'ac leak', 'ac sound',
        // Romanized Tanglish / Hinglish
        'ac kulirakala', 'ac kulir illa', 'ac thandi illai', 'ac blast', 'ac water varudhu',
        'ac thanda nahi de raha', 'ac se paani aata hai', 'ac gas khatam', 'ac gas leak',
        // Native Tamil script
        'ஏசி குளிர்ச்சி இல்லை', 'ஏசி தண்ணி வருது', 'ஏசி கேஸ் போச்சு',
        // Native Hindi
        'एसी ठंडा नहीं कर रहा', 'एसी से पानी आ रहा', 'एसी का गैस खत्म',
        // Native Telugu
        'ఏసీ చల్లగా లేదు', 'ఏసీ నీళ్ళు కారుతున్నాయి',
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
        'smoke', 'burning smell', 'flicker', 'short circuit', 'current',
        // Romanized Tanglish / Hinglish / Manglish
        'current poiduchu', 'bijli chali gayi', 'current poindi', 'current hoythu', 'light gayi',
        'bijli band', 'fuse ur gaya', 'switch spark', 'switchboard spark adikkudhu',
        'bijli board garam ho gaya', 'current adikkudhu', 'shock adikkudhu', 'fuse poiduchu',
        'light flicker aagudhu', 'mcb trip aagudhu', 'current problem',
        // Native Tamil script
        'ஸ்விட்ச் பார்டு நெருப்பு', 'மின்சாரம் போச்சு', 'ஸ்பார்க் அடிக்குது', 'கரண்ட் போச்சு',
        // Native Hindi
        'स्विचबोर्ड से चिंगारी', 'बिजली चली गई', 'MCB ट्रिप हो रहा', 'बिजली का झटका',
        // Native Telugu
        'స్విచ్ స్పార్క్ చేస్తోంది', 'కరెంట్ పోతోంది', 'ఫ్యూజ్ పోయింది',
        // Native Malayalam
        'കറന്റ് പോയി', 'ഷോക്ക് അടിക്കുന്നു',
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
        'moisture', 'pressure', 'tank overflow', 'thanni ottudhu', 'nal', 'nalwala',
        // Romanized Tanglish / Hinglish / Manglish / Benglish
        'thani varala', 'thanni varala', 'paani nahi', 'neellu ravatledu', 'neeru bartilla',
        'vellam varunnilla', 'pani aavtu nathi', 'paani aundi nahi', 'jol asche na', 'pani asuni',
        'thani sottudhu', 'pipe la leak varudhu', 'nal se paani tapak raha', 'thanni kottudhu',
        'wall se paani aa raha', 'bathroom leak', 'toilet flush kaam nahi kar raha',
        'pipe ottudhu', 'vellam ottunnu', 'pipe phateri gaya',
        // Native Tamil script
        'தண்ணீர் சொட்டுகிறது', 'குழாய் ஒழுகுகிறது', 'தண்ணி கசிவு', 'குழாய் உடைஞ்சது',
        // Native Hindi
        'पानी टपक रहा है', 'नल से पानी आ रहा', 'पाइप टूट गया', 'दीवार से पानी',
        // Native Telugu
        'పైపు లీక్ అవుతుంది', 'నీళ్ళు కారుతున్నాయి', 'గోడ నుండి నీళ్ళు',
        // Native Malayalam
        'വെള്ളം ഒലിക്കുന്നു', 'പൈപ്പ് ലീക്ക്', 'ചുമർ നനഞ്ഞിരിക്കുന്നു',
        // Native Kannada
        'ನೀರು ಸೋರುತ್ತಿದೆ', 'ಕೊಳವೆ ಒಡೆದಿದೆ',
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

    // 9. Ceiling Fan / Table Fan / Home Appliance (Electrician vs Appliance Repair)
    const SymptomItem(
      id: 'fan_repair_issue',
      title: 'Ceiling Fan Not Spinning, Humming, or Running Slow',
      description: 'Fan is humming, spinning very slowly, making squeaking noise, or regulator does not change speed.',
      equipmentTag: 'Ceiling Fan / Home Appliance',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Appliance Repair',
      searchTokens: [
        'fan', 'ceiling fan', 'table fan', 'exhaust fan', 'pedestal fan', 'wall fan',
        'regulator', 'fan slow', 'fan sound', 'fan bearing', 'capacitor', 'blade',
        'fan not spinning', 'fan humming', 'fan noise', 'fan speed', 'kaathadi', 'visiri', 'pankha',
        // Romanized Tanglish / Hinglish
        'fan suthu varudhu', 'fan slow-ah suthuthu', 'fan odala', 'fan blade suthala',
        'fan kazhiyadhu', 'pankha chalda nahi', 'pankha nahi ghum raha', 'pankha slow chal raha',
        'fan humming sound varudhu', 'fan spark adikkudhu', 'mirchi fan', 'fan ka regulator kaam nahi',
        'fan chikku budukku', 'fan kiriyal varudhu',
        // Native Tamil script
        'சின்னக்காத்தாடி ஓடல', 'பேன் மெதுவாக சுத்துது', 'பேன் ஓடல', 'காத்தாடி ஓடல',
        // Native Hindi
        'पंखा नहीं चल रहा', 'पंखा धीरे चल रहा', 'पंखा की आवाज़ आ रही',
        // Native Telugu
        'ఫ్యాన్ తిరగడం లేదు', 'ఫ్యాన్ నెమ్మదిగా తిరుగుతోంది',
        // Native Malayalam
        'ഫാൻ കറങ്ങുന്നില്ല', 'ഫാൻ പതുക്കെ കറങ്ങുന്നു',
      ],
      likelyCauses: [
        'Run capacitor (2.5µF) degraded or blown (fan spins very slowly or needs manual push to start)',
        'Speed regulator resistor/potentiometer loose or burnt (speed cannot be controlled)',
        'Ball bearings dry or seized with dust/rust (causes loud squeaking or humming noise)',
        'Stator coil winding open circuit or thermal fuse blown'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'fan_q1',
          questionText: 'What is the fan doing when switched on?',
          options: [
            TriageOption(
              label: 'Hums softly and needs a push by hand, or spins very slowly',
              probableCategory: 'Electrician',
              likelyCause: 'Weak starting/running capacitor (2.25/2.5 uF)',
            ),
            TriageOption(
              label: 'Makes a loud squeaking, grinding, or rattling sound',
              probableCategory: 'Electrician',
              likelyCause: 'Dry or worn-out ball bearings needing greasing or replacement',
            ),
            TriageOption(
              label: 'Completely dead - no sound, no movement at any regulator step',
              probableCategory: 'Electrician',
              likelyCause: 'Burnt stator winding or faulty regulator/switch',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Multimeter', 'Capacitor Tester', 'Bearing Puller', 'Insulated Screwdriver Set'],
      isAmbiguous: false,
    ),

    // 10. Refrigerator / Fridge (Appliance Repair vs Electrician)
    const SymptomItem(
      id: 'refrigerator_cooling_issue',
      title: 'Refrigerator Not Cooling, Excess Frost, or Leaking Water',
      description: 'Fridge compressor hums but food stays warm, excessive ice in freezer, or water pooling at bottom.',
      equipmentTag: 'Refrigerator / Fridge',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'fridge', 'refrigerator', 'freeze', 'freezer', 'frost', 'not cooling', 'ice buildup',
        'fridge leaking', 'fridge water', 'fridge smell', 'defrost', 'kuliralla', 'kulirchi illai',
        'thanni kottudhu', 'thanda nahi ho raha'
      ],
      likelyCauses: [
        'Defrost timer / bi-metal thermostat defective (freezer coils choked with thick ice)',
        'Compressor start relay / PTC thermistor blown or capacitor failure',
        'Refrigerant / freon gas leakage in cooling circuit',
        'Drain hole clogged causing melted water overflow onto shelves/floor'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'fridge_q1',
          questionText: 'What is happening inside the refrigerator compartments?',
          options: [
            TriageOption(
              label: 'Freezer is freezing rock solid, but lower cooling cabin is warm',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Evaporator fan motor jammed or defrost duct frozen shut',
            ),
            TriageOption(
              label: 'Compressor clicks every few minutes and shuts off, zero cooling anywhere',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Compressor start relay / overload protector burnt',
            ),
            TriageOption(
              label: 'Water continuously accumulates in the vegetable tray or under the fridge',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Defrost drain pipe choked with food debris/slime',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Manifold Gauge', 'Multimeter', 'Gas Charging Valve', 'Thermometer Probe'],
      isAmbiguous: false,
    ),

    // 11. Mixer Grinder / Kitchen Blender (Appliance Repair vs Electrician)
    const SymptomItem(
      id: 'mixer_grinder_repair',
      title: 'Mixer Grinder Stopped, Burning Smell, or Jar Coupler Jammed',
      description: 'Mixie does not start, red overload button tripped, sparks from motor, or blade does not rotate.',
      equipmentTag: 'Mixer Grinder / Home Appliance',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'mixer', 'grinder', 'mixie', 'blender', 'coupler', 'jar stuck', 'overload button',
        'mixer smoke', 'blade not rotating', 'mixi odala', 'poga varudhu', 'jaam', 'mixie repair'
      ],
      likelyCauses: [
        'Red overload protector switch at the bottom tripped due to thick batter / hard grinding',
        'Plastic/rubber drive coupler teeth stripped or sheared off',
        'Carbon brushes worn down or motor armature winding burnt',
        'Jar brass bush seized from water leakage through blade seal'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'mixer_q1',
          questionText: 'What happens when you operate the mixer?',
          options: [
            TriageOption(
              label: 'Motor makes loud humming and smoke/smell comes out',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Burnt field coils or seized jar bush causing motor stall',
            ),
            TriageOption(
              label: 'Completely dead - no sound or power when switch is turned',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Overload switch tripped (try pressing red button underneath) or wire cut',
            ),
            TriageOption(
              label: 'Motor spins fast, but the jar blade does not turn',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Drive coupler teeth stripped or broken',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Coupler Puller', 'Multimeter', 'Nut Driver', 'Bush Punch Tool'],
      isAmbiguous: false,
    ),

    // 12. Microwave Oven (Appliance Repair vs Electrician)
    const SymptomItem(
      id: 'microwave_oven_issue',
      title: 'Microwave Oven Running but Not Heating Food or Sparking',
      description: 'Microwave powers on and turntable spins, but food remains ice-cold, or loud sparking inside.',
      equipmentTag: 'Microwave Oven',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'microwave', 'oven', 'not heating', 'sparking', 'turntable', 'magnetron', 'tray not turning',
        'baking', 'door switch', 'grill oven', 'heat illa', 'thanda'
      ],
      likelyCauses: [
        'High-voltage magnetron tube burnt or filament open circuit',
        'Mica waveguide cover card burnt or contaminated with oil causing electrical arcing',
        'High-voltage capacitor or diode shorted to ground',
        'Door primary safety microswitch broken or misaligned'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'micro_q1',
          questionText: 'What is the exact symptom during heating cycle?',
          options: [
            TriageOption(
              label: 'Timer counts down and plate spins, but zero heat produced',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Magnetron or high-voltage diode failure',
            ),
            TriageOption(
              label: 'Loud crackling sparks and lightning inside the cooking chamber',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Burnt / carbonized mica wave cover sheet',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['High Voltage Discharge Probe', 'Digital Multimeter', 'Torx Security Screwdriver'],
      isAmbiguous: false,
    ),

    // 13. Drainage Clogged & Toilet / Sewerage Blockage (Plumber vs Cleaning)
    const SymptomItem(
      id: 'drain_block_sewerage',
      title: 'Drainage Clogged, Sink Water Stagnant, or Toilet Choked',
      description: 'Kitchen sink water does not drain, toilet bowl overflowing, or sewer gully trap bubbling back.',
      equipmentTag: 'Drainage & Sewerage',
      primaryCategory: 'Plumber',
      secondaryCategory: 'Cleaning',
      searchTokens: [
        'drain', 'clog', 'clogged', 'blocked', 'blockage', 'sink', 'basin', 'sewage', 'choke',
        'choked', 'toilet block', 'gully trap', 'water standing', 'thanni nikkudhu', 'adaipu',
        'adaichikichu', 'jaam'
      ],
      likelyCauses: [
        'Solidified cooking grease and food residues choking sink bottle trap / P-trap',
        'Hair, soap scum, or debris mass caught in shower floor drain',
        'Main sewer chamber / outlet inspection chamber backed up or roots intrusion',
        'Foreign sanitary object wedged in toilet S-trap'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'drain_q1',
          questionText: 'Where is the water backing up?',
          options: [
            TriageOption(
              label: 'Kitchen sink / washbasin only',
              probableCategory: 'Plumber',
              likelyCause: 'Clogged P-trap or waste outlet coupling under the sink',
            ),
            TriageOption(
              label: 'Toilet commode / bathroom floor drain bubbling up foul water',
              probableCategory: 'Plumber',
              likelyCause: 'Main stack pipe or external gully trap line blockage',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Drain Cleaning Snake Wire', 'Plunger', 'Pipe Wrench', 'Inspection Camera'],
      isAmbiguous: false,
    ),

    // 14. Doors, Locks, Hinges & Woodwork (Carpenter vs Welder)
    const SymptomItem(
      id: 'door_lock_woodwork',
      title: 'Door Lock Jammed, Hinges Squeaking, or Wood Dragging',
      description: 'Main door lock key stuck, wooden door rubs against floor/frame, or wardrobe slider off track.',
      equipmentTag: 'Doors, Locks & Woodwork',
      primaryCategory: 'Carpenter',
      secondaryCategory: 'Welder / Metal',
      searchTokens: [
        'door', 'lock', 'latch', 'hinge', 'handle', 'key stuck', 'wood', 'carpenter', 'door dragging',
        'drawer', 'cupboard', 'wardrobe', 'sliding door', 'lock broken', 'kathavu', 'pootu', 'saavi',
        'darwaza', 'woodwork', 'furniture',
        // Romanized Tanglish / Hinglish
        'kathavu poochu', 'pootu maatikichi', 'saavi maatikichi', 'door lock aagala',
        'darwaza nahi band ho raha', 'lock jam ho gaya', 'darwaza kholna mushkil',
        'almirah drawer atagirichu', 'wardrobe door pochi', 'door kiligichu',
        // Native Tamil script
        'கதவு திறக்கல', 'பூட்டு சாவி மாட்டிகிச்சு', 'கதவு இழுக்குது',
        // Native Hindi
        'दरवाज़ा नहीं खुल रहा', 'ताला जाम हो गया', 'चाबी अंदर फंसी',
        // Native Telugu
        'తలుపు తెరుచుకోవడం లేదు', 'తాళం వేసుకుపోయింది',
      ],
      likelyCauses: [
        'Mortise cylinder brass pins jammed with dust or worn out',
        'Wooden door expanded from humidity, rubbing against tile floor or door frame',
        'Loose hinge screws stripped out from wooden frame',
        'Telescopic channel ball bearings detached in wardrobe drawer'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'carpenter_q1',
          questionText: 'What is the main issue with the door or furniture?',
          options: [
            TriageOption(
              label: 'Key does not turn or cylinder latch is completely stuck',
              probableCategory: 'Carpenter',
              likelyCause: 'Damaged mortise lock cylinder or misaligned strike plate',
            ),
            TriageOption(
              label: 'Door scrapes the floor / requires heavy force to shut',
              probableCategory: 'Carpenter',
              likelyCause: 'Door sagged or swollen wood needs planing',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Wood Planer', 'Chisel Set', 'Cordless Drill', 'Lock Installation Kit'],
      isAmbiguous: false,
    ),

    // 15. Wall Paint Peeling & Seepage Crack (Painter vs Plumber)
    const SymptomItem(
      id: 'wall_dampness_painting',
      title: 'Wall Paint Peeling, Damp Patches, or Seepage Crack',
      description: 'Wall paint bubbling and flaking off, white salt powder (efflorescence), or hairline wall cracks.',
      equipmentTag: 'Painting & Waterproofing',
      primaryCategory: 'Painter',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'paint', 'painting', 'peel', 'peeling', 'wall damp', 'flaking', 'putty', 'primer',
        'waterproofing', 'exterior paint', 'interior paint', 'seepage', 'sunnam', 'vannam',
        'color adikka', 'rang', 'safedi',
        // Vernacular: Walls & Ceiling (22-language expansion)
        'paint adikanu', 'ghar rangna', 'deewar safedi', 'bith pe paint', 'chuna jhad raha', 'wall dampness'
      ],
      likelyCauses: [
        'Concealed water seepage behind wall from bathroom tile grout or pipeline joint',
        'Efflorescence salts breaking paint bond due to moisture trapped in plaster',
        'Old paint layer chalking without primer coat or structural hairline plaster cracks'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'paint_q1',
          questionText: 'What does the wall surface look like?',
          options: [
            TriageOption(
              label: 'Wet damp patch with paint bubbling / peeling near bathroom or kitchen',
              probableCategory: 'Plumber',
              likelyCause: 'Active water leak behind wall must be fixed before repainting',
            ),
            TriageOption(
              label: 'Dry flakes / cracks ready for fresh scraping and painting',
              probableCategory: 'Painter',
              likelyCause: 'Surface wear requiring putty touchup and acrylic emulsion paint',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Scraper Blade', 'Sanding Block', 'Moisture Meter', 'Putty Blade'],
      isAmbiguous: true,
    ),

    // 16. Deep Cleaning, Chimney Degreasing & Bathroom Descaling (Cleaning vs Plumber)
    const SymptomItem(
      id: 'deep_cleaning_sanitization',
      title: 'Deep Cleaning, Kitchen Chimney Degreasing, or Bathroom Descaling',
      description: 'Thick yellow scale on bathroom tiles/taps, greasy kitchen chimney baffles, or sofa shampooing.',
      equipmentTag: 'Deep Cleaning & Descaling',
      primaryCategory: 'Cleaning',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'cleaning', 'clean', 'deep clean', 'sanitize', 'bathroom clean', 'chimney cleaning',
        'sofa cleaning', 'kitchen grease', 'acid wash', 'stain', 'suththam', 'kazhuva', 'safai',
        'tile stains', 'hard water stain'
      ],
      likelyCauses: [
        'Heavy calcium/magnesium hard water scale encrusted on ceramic tiles and chrome faucets',
        'Baked-on cooking oil and carbon deposits choking chimney suction mesh',
        'Dust mite accumulation and fabric sweat stains in upholstery/mattresses'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'clean_q1',
          questionText: 'Which area needs specialized deep cleaning?',
          options: [
            TriageOption(
              label: 'Bathroom tile hard-water scale and tap rust/calcification',
              probableCategory: 'Cleaning',
              likelyCause: 'Requires industrial acidic descaler and motorized scrubber',
            ),
            TriageOption(
              label: 'Kitchen chimney, exhaust fan, and stovetop grease',
              probableCategory: 'Cleaning',
              likelyCause: 'Requires caustic grease dissolver and hot steam jetting',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['High Pressure Steam Cleaner', 'Rotary Scrubbing Machine', 'HEPA Vacuum', 'Alkaline Degreaser'],
      isAmbiguous: false,
    ),

    // 17. Metal Fabrication, Gate Hinge & Grill Welding (Welder / Metal vs Carpenter)
    const SymptomItem(
      id: 'metal_gate_welding',
      title: 'Gate Hinge Broken, Window Grill Loose, or Metal Railing Broken',
      description: 'Heavy iron gate dropped from hinge, balcony railing weld joint cracked, or shutter jammed.',
      equipmentTag: 'Metal Fabrication & Welding',
      primaryCategory: 'Welder / Metal',
      secondaryCategory: 'Carpenter',
      searchTokens: [
        'welding', 'weld', 'gate', 'grill', 'metal', 'iron', 'shutter', 'railing', 'broken hinge',
        'rust', 'iron gate', 'irumbu', 'patrai', 'loha', 'welder', 'gate welding',
        // Romanized Tanglish / Hinglish
        'gate hinge vudainju', 'iron gate keezha vizhundhuchu', 'grill loose aagidhu',
        'lohe ka darwaza tuta', 'gate weld toot gaya', 'shutter ka hinge toot gaya',
        // Native Tamil script
        'இரும்பு வாசல் கீழே விழுந்தது', 'கிரில் தளர்ந்தது',
        // Native Hindi
        'लोहे का गेट गिर गया', 'ग्रिल ढीला हो गया',
      ],
      likelyCauses: [
        'Severe rust corrosion weakening load-bearing weld joint on gate post',
        'Pivot hinge pin sheared off due to heavy gate weight sag',
        'Anchor fasteners worked loose from brick masonry pillar'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'weld_q1',
          questionText: 'What metal structure needs repair?',
          options: [
            TriageOption(
              label: 'Main entrance iron swing/sliding gate hinge or track broken',
              probableCategory: 'Welder / Metal',
              likelyCause: 'Requires on-site arc welding with 7018 rod and reinforcement plate',
            ),
            TriageOption(
              label: 'Balcony safety grill or staircase railing loose / cracked',
              probableCategory: 'Welder / Metal',
              likelyCause: 'Anchor re-pinning and MIG/arc tack welding needed',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Portable Arc Welder', 'Portable Arc Inverter Welder', 'Angle Grinder', 'Welding Helmet', 'Chipping Hammer'],
      isAmbiguous: false,
    ),

    // 18. Masonry, Tiles, Cement Plaster & Structural Repairs (Masonry vs Plumber vs Painter)
    const SymptomItem(
      id: 'masonry_tile_plaster_repair',
      title: 'Tile Broken, Hollow Floor Sound, or Wall Cement Plaster Cracking',
      description: 'Floor or wall tiles chipped/hollow, cement plaster peeling to brick, or granite counter damage.',
      equipmentTag: 'Masonry & Tile Works',
      primaryCategory: 'Masonry',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'masonry', 'mason', 'tile', 'tiles', 'plaster', 'cement', 'brick', 'granite', 'marble',
        'grout', 'hollow tile', 'floor cracked', 'wall crack', 'kothanar', 'mistri', 'chuna', 'patthar',
        // Romanized Tanglish / Hinglish
        'tile vudainju', 'tile vizhundhuchu', 'floor tile udaindhuchu', 'grout problem',
        'cement jhar raha', 'tiles toot gayi', 'wall crack aa gayi', 'floor pe crack',
        // Native Tamil script
        'டைல்ஸ் உடைஞ்சது', 'சிமெண்ட் கழண்டது', 'தரை வெடிப்பு',
        // Native Hindi
        'टाइल टूट गई', 'दीवार में दरार', 'सीमेंट उखड़ रहा',
        // Native Telugu
        'టైల్స్ విరిగిపోయాయి', 'గోడలో పగులు',
      ],
      likelyCauses: [
        'Hollow or debonded tile bed due to inadequate adhesive coverage during laying',
        'Structural settlement causing hairline shear cracks across cement plaster',
        'Water degradation of sub-floor screed causing tiles to lift and pop up'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'mason_q1',
          questionText: 'What civil or masonry repair is needed?',
          options: [
            TriageOption(
              label: 'Floor or bathroom tiles are loose, hollow, or cracked',
              probableCategory: 'Masonry',
              likelyCause: 'Requires localized tile removal, new adhesive bed, and epoxy regrouting',
            ),
            TriageOption(
              label: 'Wall plaster has deep cracks or cement is crumbling off',
              probableCategory: 'Masonry',
              likelyCause: 'Requires plaster chipping, polymer bonding coat, and re-plastering',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Notched Trowel', 'Tile Cutter', 'Rubber Mallet', 'Spirit Level'],
      isAmbiguous: false,
    ),

    // 19. Kitchen Gas Stove & Hob Repair (Appliance Repair vs Plumber)
    const SymptomItem(
      id: 'gas_stove_hob_repair',
      title: 'Gas Stove Burner Clogged, Yellow Flame, or Auto-Ignition Sparking Failed',
      description: 'LPG burner produces low flame, black soot on utensils, gas smell, or auto-ignition click not sparking.',
      equipmentTag: 'Kitchen Gas Stove & Hob',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'gas stove', 'hob', 'burner', 'gas leak', 'cylinder pipe', 'yellow flame', 'auto ignition',
        'gas aduppu', 'chulha', 'gas smell', 'stove repair', 'burner block'
      ],
      likelyCauses: [
        'Brass burner nozzle jet clogged with spilled food grease/milk residue',
        'Faulty spark generator or battery dead in auto-ignition system',
        'Air-fuel mixing shutter misaligned causing improper combustion and yellow flame',
        'Degraded rubber gas hose or loose clamp connection'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'stove_q1',
          questionText: 'What is happening with the gas stove or hob?',
          options: [
            TriageOption(
              label: 'Flame is very low or uneven across burner rings',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Carbon buildup in burner orifice needing jet pin clearing',
            ),
            TriageOption(
              label: 'Faint gas smell or gas hissing near hose/regulator',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Potential safety risk: Rubber hose degradation or regulator O-ring wear',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Nozzle Jet Pin Cleaner', 'Gas Leak Detector Spray', 'Brass Wire Brush'],
      isAmbiguous: false,
    ),

    // 20. Overhead Tank / Sump / Float Valve Overflow (Plumber vs Electrician)
    const SymptomItem(
      id: 'overhead_tank_overflow',
      title: 'Overhead Tank / Sump Overflowing or Float Valve Not Cutting Off',
      description: 'Water overflows continuously from the terrace tank, sump auto-starter does not cut off, or level sensor stays dry.',
      equipmentTag: 'Overhead Tank & Sump',
      primaryCategory: 'Plumber',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'overhead tank', 'sump', 'float valve', 'ball valve', 'tank overflow', 'water tank overflow',
        'auto starter', 'level sensor', 'water level controller', 'tank not stopping', 'sump pump',
        'water wasting', 'terrace tank leaking',
        // Romanized Tanglish / Hinglish / Manglish
        'tank overflow aagudhu', 'thanni tank thulumbudhu', 'float valve velaikala',
        'sump tank thanni poidhu', 'tank se paani gir raha', 'float valve kaam nahi kar raha',
        'auto starter band nahi ho raha', 'tanki bhar ke bhi paani aa raha',
        // Native Tamil script
        'தண்ணீர் தொட்டி நிரம்பி வழிகிறது', 'ஃப்ளோட் வால்வு வேலை செய்யல',
        // Native Hindi
        'टंकी ओवरफ्लो हो रही', 'फ्लोट वाल्व खराब', 'सम्प पंप बंद नहीं हो रहा',
        // Native Telugu
        'ట్యాంక్ ఓవర్ఫ్లో అవుతోంది', 'ఫ్లోట్ వాల్వ్ పని చేయడం లేదు',
        // Native Malayalam
        'ടാങ്ക് കവിഞ്ഞൊഴുകുന്നു', 'ഫ്ലോട്ട് വാൽവ് പ്രവർത്തിക്കുന്നില്ല',
        // Native Kannada
        'ಟ್ಯಾಂಕ್ ಉಕ್ಕಿ ಹರಿಯುತ್ತಿದೆ', 'ಫ್ಲೋಟ್ ವಾಲ್ವ್ ಕೆಲಸ ಮಾಡುತ್ತಿಲ್ಲ',
        // Native Bengali / Marathi / Gujarati / Punjabi / Urdu (vernacular expansion)
        'tanki upoche jachhe', 'tanki bharun vahate', 'tanki chhalakti hai', 'tanki vich pani vagda',
        'ٹینکی اوور فلو ہو رہی ہے',
      ],
      likelyCauses: [
        'Float valve rubber washer worn out or ball cock arm bent (Plumbing)',
        'Water level sensor probe corroded or auto-starter relay board stuck ON (Electrical)',
        'Sump submersible float switch jammed with debris (Electrical / Plumbing)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'tank_q1',
          questionText: 'Where exactly is the overflow happening?',
          options: [
            TriageOption(
              label: 'Terrace/overhead tank overflow pipe runs constantly',
              probableCategory: 'Plumber',
              likelyCause: 'Worn float valve washer or bent ball cock arm',
            ),
            TriageOption(
              label: 'Auto water level controller display shows FULL but motor keeps running',
              probableCategory: 'Electrician',
              likelyCause: 'Level sensor probe fault or stuck relay on the auto-starter panel',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Float Valve Kit', 'Multimeter', 'Water Level Controller Tester', 'Pipe Wrench'],
      isAmbiguous: true,
    ),

    // 21. Kitchen Chimney Exhaust & Baffle Motor Failure (Appliance Repair vs Cleaning)
    const SymptomItem(
      id: 'chimney_exhaust_failure',
      title: 'Kitchen Chimney Not Sucking Smoke or Motor Making Loud Noise',
      description: 'Chimney runs but does not pull smoke/oil fumes, baffle filter dripping oil, or exhaust motor grinding noise.',
      equipmentTag: 'Kitchen Chimney',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Cleaning',
      searchTokens: [
        'chimney', 'kitchen chimney', 'exhaust motor', 'baffle filter', 'suction weak', 'smoke not going',
        'chimney noise', 'chimney oil dripping', 'chimney not working', 'auto clean chimney',
        // Romanized Tanglish / Hinglish
        'chimney velaikala', 'puke izhukkala', 'chimney la sound varudhu', 'chimney dhooma vaanguthu illai',
        'chimney awaaz kar raha', 'chimney dhuan nahi khinch raha', 'chimney se tel tapak raha',
        // Native Tamil script
        'சிம்னி புகை இழுக்கல', 'சிம்னி சத்தம் போடுது',
        // Native Hindi
        'चिमनी धुआं नहीं खींच रही', 'चिमनी से आवाज़ आ रही', 'चिमनी से तेल टपक रहा',
        // Native Telugu
        'చిమ్నీ పొగ లాగడం లేదు', 'చిమ్నీ శబ్దం చేస్తోంది',
        // Native Malayalam
        'ചിമ്മിനി പുക വലിക്കുന്നില്ല', 'ചിമ്മിനിയിൽ ശബ്ദം',
      ],
      likelyCauses: [
        'Baffle/mesh filter fully choked with hardened grease reducing suction (Cleaning)',
        'Exhaust blower motor bearing worn or carbon brushes dead (Appliance)',
        'Non-return flap valve stuck or duct blocked with grease (Cleaning / Appliance)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'chimney_q1',
          questionText: 'What is the chimney doing when switched on?',
          options: [
            TriageOption(
              label: 'Motor runs but suction is very weak, filters visibly greasy',
              probableCategory: 'Cleaning',
              likelyCause: 'Baffle filter and duct choked with grease buildup',
            ),
            TriageOption(
              label: 'Loud grinding/rattling noise from the motor housing',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Worn blower motor bearing or bent fan blade',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Degreaser Solution', 'Multimeter', 'Motor Bearing Kit', 'Duct Brush'],
      isAmbiguous: true,
    ),

    // 22. Induction Cooktop / Electric Kettle Coil Failure (Appliance Repair vs Electrician)
    const SymptomItem(
      id: 'induction_kettle_coil_failure',
      title: 'Induction Cooktop Not Heating or Electric Kettle Tripping Switch',
      description: 'Induction stove shows error code and shuts off, or electric kettle heating coil trips the MCB / does not boil water.',
      equipmentTag: 'Induction Cooktop & Electric Kettle',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Electrician',
      searchTokens: [
        'induction', 'induction stove', 'induction cooktop', 'electric kettle', 'kettle', 'coil failure',
        'induction error', 'induction not heating', 'kettle not boiling', 'kettle tripping',
        // Romanized Tanglish / Hinglish
        'induction stove velaikala', 'induction heat aagala', 'kettle thanni koodalai', 'induction error varudhu',
        'induction chulha garam nahi ho raha', 'kettle mein paani nahi garam ho raha', 'kettle se MCB trip ho raha',
        // Native Tamil script
        'இண்டக்ஷன் அடுப்பு சூடாகல', 'கெட்டில் தண்ணீர் கொதிக்கல',
        // Native Hindi
        'इंडक्शन चूल्हा गर्म नहीं हो रहा', 'केतली में पानी नहीं उबल रहा', 'केतली से MCB ट्रिप हो रहा',
        // Native Telugu
        'ఇండక్షన్ స్టవ్ వేడెక్కడం లేదు', 'కెటిల్లో నీళ్ళు మరగడం లేదు',
        // Native Malayalam
        'ഇൻഡക്ഷൻ അടുപ്പ് ചൂടാകുന്നില്ല', 'കെറ്റിലിൽ വെള്ളം തിളക്കുന്നില്ല',
      ],
      likelyCauses: [
        'Induction cooktop IGBT power module or ceramic glass sensor failure (Appliance)',
        'Electric kettle heating element/coil burnt or open circuit (Appliance)',
        'Overloaded socket / undersized wiring tripping the MCB under kettle load (Electrical)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'induction_q1',
          questionText: 'What exactly is happening with the appliance?',
          options: [
            TriageOption(
              label: 'Induction stove displays an error code and shuts down mid-cooking',
              probableCategory: 'Appliance Repair',
              likelyCause: 'IGBT power module overheating or faulty pan-detection sensor',
            ),
            TriageOption(
              label: 'Kettle switches on but water never heats up',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Burnt heating coil/element inside the kettle base',
            ),
            TriageOption(
              label: 'MCB trips the moment the appliance is switched on',
              probableCategory: 'Electrician',
              likelyCause: 'Overloaded circuit or damaged socket wiring',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Multimeter', 'IGBT Tester', 'Insulated Screwdriver Set', 'Heating Element Tester'],
      isAmbiguous: true,
    ),

    // 23. Dishwasher Drainage & Spray Arm Issue (Appliance Repair vs Plumber)
    const SymptomItem(
      id: 'dishwasher_drainage_issue',
      title: 'Dishwasher Not Draining, Spray Arm Not Rotating, or Dishes Coming Out Dirty',
      description: 'Standing water pools at the bottom after a wash cycle, spray arm jets are blocked, or drain hose is siphoning back.',
      equipmentTag: 'Dishwasher',
      primaryCategory: 'Appliance Repair',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'dishwasher', 'dish washer', 'spray arm', 'dishwasher not draining', 'dishwasher water standing',
        'dishwasher dirty dishes', 'dishwasher error code', 'dishwasher leak',
        // Romanized Tanglish / Hinglish
        'dishwasher thanni pogala', 'dishwasher la thanni nikkudhu', 'dishwasher nahi drain ho raha',
        'dishwasher mein pani ruka hua hai', 'dishwasher se paani leak ho raha',
        // Native Tamil script
        'டிஷ்வாஷர் தண்ணீர் போகல', 'டிஷ்வாஷர் ஒழுகுது',
        // Native Hindi
        'डिशवॉशर से पानी नहीं निकल रहा', 'डिशवॉशर लीक हो रहा',
        // Native Telugu
        'డిష్వాషర్లో నీళ్ళు నిలిచిపోయాయి',
        // Native Malayalam
        'ഡിഷ്വാഷറിൽ വെള്ളം കെട്ടിക്കിടക്കുന്നു',
      ],
      likelyCauses: [
        'Drain pump filter or food-debris trap clogged (Appliance)',
        'Kinked or improperly looped drain hose causing siphoning back into the tub (Plumbing)',
        'Spray arm nozzle jets clogged with hard-water scale or food particles (Appliance)',
        'Under-sink drain connection or air-gap fitting blocked (Plumbing)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'dishwasher_q1',
          questionText: 'What is the dishwasher doing wrong?',
          options: [
            TriageOption(
              label: 'Water pools at the bottom after every cycle finishes',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Clogged drain pump filter or blocked drain hose',
            ),
            TriageOption(
              label: 'Dishes come out with food residue / not properly washed',
              probableCategory: 'Appliance Repair',
              likelyCause: 'Spray arm nozzles blocked or not rotating freely',
            ),
            TriageOption(
              label: 'Water backs up from the kitchen sink into the dishwasher tub',
              probableCategory: 'Plumber',
              likelyCause: 'Shared drain line blockage or missing air-gap fitting',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Drain Pump Pliers', 'Descaling Solution', 'Pipe Wrench', 'Multimeter'],
      isAmbiguous: true,
    ),

    // 24. Solar Water Heater / Heat Pump System (Electrician vs Plumber)
    const SymptomItem(
      id: 'solar_water_heater_issue',
      title: 'Solar Water Heater Not Heating, Heat Pump Tripping, or Panel Leaking',
      description: 'Rooftop solar water heater gives lukewarm water, backup heating element trips MCB, or glass tube/tank leaks.',
      equipmentTag: 'Solar Water Heater & Heat Pump',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'solar water heater', 'solar heater', 'heat pump', 'solar panel water', 'solar geyser not heating',
        'vacuum tube', 'solar backup heater', 'solar tank leak',
        // Romanized Tanglish / Hinglish
        'solar heater suudu thanni varala', 'solar water heater velaikala', 'heat pump trip aagudhu',
        'solar geyser garam paani nahi de raha', 'solar heater se paani leak ho raha',
        // Native Tamil script
        'சோலார் ஹீட்டர் சூடு தண்ணீர் தரல', 'சோலார் டேங்க் ஒழுகுது',
        // Native Hindi
        'सोलर हीटर गर्म पानी नहीं दे रहा', 'सोलर टैंक से पानी लीक हो रहा', 'हीट पंप ट्रिप हो रहा',
        // Native Telugu
        'సోలార్ హీటర్ వేడి నీళ్ళు ఇవ్వడం లేదు',
        // Native Malayalam
        'സോളാർ ഹീറ്റർ ചൂടുവെള്ളം തരുന്നില്ല',
      ],
      likelyCauses: [
        'Broken/cracked evacuated glass vacuum tube causing heat loss (Plumbing)',
        'Backup electric heating element or thermostat in the tank failed (Electrical)',
        'Heat pump compressor relay or circuit board fault tripping the MCB (Electrical)',
        'Tank-to-pipe union joint corroded and leaking at the rooftop (Plumbing)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'solar_q1',
          questionText: 'What symptom are you seeing with the solar/heat-pump system?',
          options: [
            TriageOption(
              label: 'Water stays lukewarm even after a full sunny day',
              probableCategory: 'Plumber',
              likelyCause: 'Cracked vacuum tube or scaled heat exchanger reducing efficiency',
            ),
            TriageOption(
              label: 'Backup electric heater trips the MCB or does not switch on',
              probableCategory: 'Electrician',
              likelyCause: 'Faulty backup heating element or thermostat',
            ),
            TriageOption(
              label: 'Water is dripping from the rooftop tank or pipe joints',
              probableCategory: 'Plumber',
              likelyCause: 'Corroded union joint or cracked tank seam',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Multimeter', 'Pipe Wrench', 'Vacuum Tube Replacement Kit', 'Thermostat Tester'],
      isAmbiguous: true,
    ),

    // 25. Smart Doorbell / CCTV / Intercom Power & Wiring Fault (Electrician)
    const SymptomItem(
      id: 'smart_doorbell_cctv_fault',
      title: 'Smart Doorbell, CCTV Camera, or Intercom Not Powering On',
      description: 'Video doorbell shows no power/offline, CCTV DVR camera feed goes blank, or intercom panel has no dial tone.',
      equipmentTag: 'Smart Doorbell, CCTV & Intercom',
      primaryCategory: 'Electrician',
      secondaryCategory: 'Appliance Repair',
      searchTokens: [
        'doorbell', 'video doorbell', 'smart doorbell', 'cctv', 'cctv camera', 'security camera',
        'intercom', 'dvr', 'nvr', 'camera not working', 'camera offline', 'doorbell not ringing',
        // Romanized Tanglish / Hinglish
        'doorbell velaikala', 'cctv camera velaikala', 'intercom sabdham varala',
        'doorbell kaam nahi kar raha', 'cctv camera band ho gaya', 'intercom mein awaaz nahi aa rahi',
        // Native Tamil script
        'டோர்பெல் வேலை செய்யல', 'சிசிடிவி காமிரா வேலை செய்யல',
        // Native Hindi
        'डोरबेल काम नहीं कर रही', 'सीसीटीवी कैमरा बंद हो गया', 'इंटरकॉम में आवाज़ नहीं आ रही',
        // Native Telugu
        'డోర్బెల్ పని చేయడం లేదు', 'సీసీటీవీ కెమెరా ఆఫ్లైన్',
        // Native Malayalam
        'ഡോർബെൽ പ്രവർത്തിക്കുന്നില്ല', 'സിസിടിവി ക്യാമറ ഓഫ്ലൈൻ',
      ],
      likelyCauses: [
        'Low-voltage transformer or PoE adapter for the doorbell/camera dead (Electrical)',
        'Loose or corroded wiring termination at the CCTV DVR/NVR power supply (Electrical)',
        'Intercom base station power adapter blown or fuse tripped (Electrical)'
      ],
      suggestedToolsNeeded: ['Multimeter', 'Cable Tester (RJ45/Coax)', 'PoE Injector Tester', 'Insulated Screwdriver Set'],
      isAmbiguous: false,
    ),

    // 26. Sliding Window Roller Jammed / Glass Crack (Carpenter vs Welder)
    const SymptomItem(
      id: 'sliding_window_roller_glass',
      title: 'Sliding Window Roller Jammed, Track Derailed, or Glass Pane Cracked',
      description: 'UPVC/aluminum sliding window is hard to slide, rollers have jumped the track, or glass pane is cracked/shattered.',
      equipmentTag: 'Sliding Windows & Glass',
      primaryCategory: 'Carpenter',
      secondaryCategory: 'Welder / Metal',
      searchTokens: [
        'sliding window', 'window roller', 'window track', 'glass crack', 'glass broken', 'window jammed',
        'upvc window', 'aluminum window', 'window not sliding', 'window pane cracked',
        // Romanized Tanglish / Hinglish
        'window jarudhu illai', 'kannadi udaindhuchu', 'window roller odayndhuchu',
        'khidki nahi khisak rahi', 'kanch tut gaya', 'khidki ka roller kharab',
        // Native Tamil script
        'ஜன்னல் நகரல', 'கண்ணாடி உடைந்தது', 'ஜன்னல் ரோலர் பழுது',
        // Native Hindi
        'खिड़की नहीं खिसक रही', 'खिड़की का कांच टूट गया', 'खिड़की का रोलर खराब',
        // Native Telugu
        'కిటికీ జారడం లేదు', 'కిటికీ అద్దం పగిలింది',
        // Native Malayalam
        'ജനൽ നീങ്ങുന്നില്ല', 'ജനൽ ചില്ല് പൊട്ടി',
      ],
      likelyCauses: [
        'Nylon/steel roller wheels worn out or derailed from aluminum track (Carpentry)',
        'Toughened or plain glass pane cracked from impact or thermal stress (Carpentry)',
        'Aluminum/UPVC frame corner joint bent or welded corner cleat failed (Welder / Metal)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'window_q1',
          questionText: 'What exactly is wrong with the sliding window?',
          options: [
            TriageOption(
              label: 'Window is stiff, jammed, or rollers have come off the track',
              probableCategory: 'Carpenter',
              likelyCause: 'Worn roller wheels needing replacement and track cleaning',
            ),
            TriageOption(
              label: 'Glass pane is cracked, chipped, or fully shattered',
              probableCategory: 'Carpenter',
              likelyCause: 'Glass pane needs re-cutting and reglazing into the frame',
            ),
            TriageOption(
              label: 'Metal frame corner is bent, loose, or the joint has separated',
              probableCategory: 'Welder / Metal',
              likelyCause: 'Corner cleat weld or crimp joint failure needing re-fabrication',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Roller Wheel Kit', 'Glass Cutter', 'Suction Cup Glass Lifter', 'Rivet Gun'],
      isAmbiguous: true,
    ),

    // 27. Bathroom Tile Grouting & Anti-Skid Seepage (Masonry vs Plumber)
    const SymptomItem(
      id: 'bathroom_tile_grouting_seepage',
      title: 'Bathroom Tile Grout Eroded, Anti-Skid Tiles Loose, or Shower Area Seepage',
      description: 'Grout lines between bathroom/anti-skid tiles crumbling and black-moldy, or seepage reappearing near the shower area.',
      equipmentTag: 'Bathroom Tile Grouting & Waterproofing',
      primaryCategory: 'Masonry',
      secondaryCategory: 'Plumber',
      searchTokens: [
        'tile grouting', 'grout', 'anti-skid tile', 'bathroom seepage', 'shower area leak', 'mold grout',
        'black fungus tile', 'regrouting', 'bathroom floor leak', 'epoxy grout',
        // Romanized Tanglish / Hinglish
        'bathroom tile grout udaindhuchu', 'kuligal la thanni oorudhu', 'bathroom la seepage varudhu',
        'bathroom mein grout ukhad gaya', 'shower area se seepage aa raha', 'tile grout kala pad gaya',
        // Native Tamil script
        'குளியலறை டைல் க்ரவுட் கழண்டது', 'குளியலறையில் ஈரப்பதம்',
        // Native Hindi
        'बाथरूम टाइल ग्राउट उखड़ गया', 'शावर एरिया में सीपेज',
        // Native Telugu
        'బాత్రూమ్ టైల్ గ్రౌట్ ఊడిపోయింది', 'షవర్ ఏరియాలో లీకేజీ',
        // Native Malayalam
        'ബാത്ത്റൂം ടൈൽ ഗ്രൗട്ട് ഇളകി', 'ഷവർ ഏരിയയിൽ ചോർച്ച',
      ],
      likelyCauses: [
        'Cement/epoxy grout eroded allowing water ingress into the tile bed (Masonry)',
        'Failed waterproofing membrane below the shower area screed (Masonry / Plumbing)',
        'Concealed shower mixer or connector pipe joint leaking beneath the tiles (Plumbing)'
      ],
      clarifyingQuestions: [
        TriageQuestion(
          id: 'grout_q1',
          questionText: 'What best describes the bathroom issue?',
          options: [
            TriageOption(
              label: 'Grout lines are crumbling, discolored, or growing black mold',
              probableCategory: 'Masonry',
              likelyCause: 'Grout erosion needs raking out and epoxy re-grouting',
            ),
            TriageOption(
              label: 'Seepage keeps reappearing on the wall or ceiling below the bathroom',
              probableCategory: 'Plumber',
              likelyCause: 'Concealed shower pipe or waterproofing membrane failure',
            ),
          ],
        ),
      ],
      suggestedToolsNeeded: ['Grout Removal Tool', 'Epoxy Grout Kit', 'Moisture Meter', 'Waterproofing Membrane'],
      isAmbiguous: true,
    ),

    // 28. Wood Termite Damage & Cavity Rot (Carpenter)
    const SymptomItem(
      id: 'wood_termite_damage',
      title: 'Wood Termite Infestation, Hollow Furniture, or Cavity Rot',
      description: 'Wooden door frame, wardrobe, or bed sounds hollow when tapped, mud tunnels visible, or wood crumbles to powder.',
      equipmentTag: 'Wood Termite & Cavity Rot',
      primaryCategory: 'Carpenter',
      secondaryCategory: 'Carpenter',
      searchTokens: [
        'termite', 'termites', 'wood borer', 'deemak', 'wood rot', 'hollow wood', 'wood powder',
        'mud tunnel', 'furniture eaten', 'white ants', 'wood decay',
        // Romanized Tanglish / Hinglish
        'thegu pூச்சி saapten', 'marathula thegu vandhurichi', 'lakdi mein deemak lag gaya',
        'furniture mein deemak', 'wood khaali ho gaya', 'lakdi choor ho rahi hai',
        // Native Tamil script
        'மரத்தில் கறையான்', 'மரம் பொடியாகுது', 'கதவு உள்ளே பொள்ளலாகுது',
        // Native Hindi
        'लकड़ी में दीमक लग गया', 'फर्नीचर में दीमक', 'लकड़ी अंदर से खोखली हो गई',
        // Native Telugu
        'కర్రలో చెద పట్టింది', 'ఫర్నిచర్లో చెదపురుగులు',
        // Native Malayalam
        'തടിയിൽ ചിതൽ കയറി', 'ഫർണിച്ചറിൽ ചിതൽ',
        // Native Kannada
        'ಮರದಲ್ಲಿ ಗೆದ್ದಲು ಹಿಡಿದಿದೆ',
      ],
      likelyCauses: [
        'Subterranean termite colony infestation through untreated wood-to-ground contact',
        'Moisture-induced wood rot fungus weakening the internal cavity',
        'Old furniture/frame never treated with anti-termite chemical during installation'
      ],
      suggestedToolsNeeded: ['Termite Detection Moisture Meter', 'Anti-Termite Injection Kit', 'Wood Filler', 'Chisel Set'],
      isAmbiguous: false,
    ),

    // 29. Balcony Clothes Drying Ceiling Pulley / Wire Snap (Carpenter vs Welder)
    const SymptomItem(
      id: 'balcony_pulley_wire_snap',
      title: 'Balcony Ceiling Cloth-Drying Pulley Jammed or Hanging Wire Snapped',
      description: 'Ceiling-mounted clothes drying hanger pulley does not rotate smoothly, or the steel wire/rope has snapped under load.',
      equipmentTag: 'Balcony Clothes Drying Pulley',
      primaryCategory: 'Carpenter',
      secondaryCategory: 'Welder / Metal',
      searchTokens: [
        'pulley', 'clothes drying pulley', 'ceiling pulley', 'drying stand', 'cloth hanger wire',
        'balcony pulley', 'pulley wire snapped', 'clothesline broken', 'hanger rope cut',
        // Romanized Tanglish / Hinglish
        'thugil pulley velaikala', 'kayiru arundhupochi', 'balcony pulley wire pottupochu',
        'kapda sukhane wali pulley kharab', 'balcony ki rassi toot gayi', 'pulley ka wire kat gaya',
        // Native Tamil script
        'துணி காயப்போடும் பொறி வேலை செய்யல', 'கயிறு அறுந்துபோச்சு',
        // Native Hindi
        'कपड़े सुखाने वाली पुली खराब हो गई', 'बालकनी की रस्सी टूट गई',
        // Native Telugu
        'బట్టలు ఆరవేసే పుల్లీ పాడైంది', 'తాడు తెగిపోయింది',
        // Native Malayalam
        'തുണി ഉണക്കുന്ന പുള്ളി കേടായി', 'കയർ പൊട്ടിപ്പോയി',
      ],
      likelyCauses: [
        'Pulley wheel bearing seized or ceiling bracket screws loosened (Carpentry)',
        'Galvanized steel hanging wire/rope frayed and snapped under repeated load (Carpentry)',
        'Ceiling mounting bracket bent or welded hook joint sheared off (Welder / Metal)'
      ],
      suggestedToolsNeeded: ['Pulley Replacement Kit', 'Galvanized Wire Rope', 'Cordless Drill', 'Wall Anchor Set'],
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

  // ---------------------------------------------------------------------
  // 22-Language Conversational Stopword Stripper
  // ---------------------------------------------------------------------
  // Spoken queries across India's Scheduled Languages are often wrapped in
  // filler words ("I need", "mujhe...chahiye", "enakku...vennu") that add
  // zero diagnostic signal and can dilute/starve the scoring engine, or
  // even trigger a false "Out of Scope" rejection. These are stripped
  // BEFORE tokenization/scoring so only the meaningful trade/symptom
  // tokens remain.
  static const Set<String> _conversationalFillers = {
    // --- South ---
    // Tamil
    'enakku', 'ippo', 'ippa', 'oru', 'vennu', 'venum', 'theva', 'aachu', 'poiduchu', 'varala',
    'veetuku', 'panna',
    // Telugu
    'naku', 'ippudu', 'oka', 'kavali', 'raavatledu', 'poindi', 'cheyali', 'ma', 'intiki', 'undi',
    // Kannada
    'nanage', 'eege', 'ondu', 'beku', 'bartilla', 'madabeku', 'namma', 'manege', 'agide',
    // Malayalam
    'enikku', 'ippol', 'venam', 'varunnilla', 'cheyyanam', 'veettil', 'und',

    // --- North & West ---
    // Hindi & Urdu
    'mujhe', 'ek', 'ki', 'zaroorat', 'hai', 'chahiye', 'bhej', 'do', 'karna', 'mere', 'ghar',
    'me', 'hoga', 'darmiyan',
    // Punjabi
    'mainu', 'ik', 'chahida', 'chahidi', 'kharab', 'ho', 'gaya', 'ghare', 'bhejo',
    // Gujarati
    'mane', 'joie', 'chhe', 'bagdi', 'gayu', 'gharma', 'moklo',
    // Marathi
    'mala', 'hava', 'ahe', 'yet', 'nahiye', 'pahije', 'karaycha', 'gharat',
    // Kashmiri / Dogri / Sindhi
    'mye', 'chhu', 'chhi', 'lori', 'khapyo',

    // --- East & Northeast ---
    // Bengali
    'amar', 'ekta', 'dorkar', 'lagbe', 'kharaap', 'asche', 'na', 'barite',
    // Assamese
    'mur', 'eta', 'lage', 'bhangise', 'ghorot', 'ahise',
    // Odia
    'mote', 'gote', 'darkar', 'kharap', 'heichi', 'gharare',
    // Maithili / Nepali / Santali / Bodo / Manipuri
    'hamra', 'chahi', 'chahiyo', 'bhayeko',

    // --- English conversational wrapper ---
    'i', 'need', 'want', 'looking', 'for', 'please', 'call', 'book', 'send', 'urgent',
    'quick', 'right', 'now',
  };

  /// Strips conversational filler/wrapper words (across all 22 Scheduled
  /// Languages + English) from a lowercased query so that only the
  /// meaningful trade/symptom tokens remain for scoring. Falls back to the
  /// original query if stripping would remove every single token (so we
  /// never operate on an empty string unnecessarily).
  static String _stripConversationalFillers(String loweredQuery) {
    final words = loweredQuery.split(RegExp(r'[\s,.-]+')).where((w) => w.isNotEmpty);
    final kept = words.where((w) => !_conversationalFillers.contains(w)).toList();
    if (kept.isEmpty) return loweredQuery;
    return kept.join(' ');
  }

  // Primary equipment identifiers mapped to item IDs
  static const Map<String, List<String>> _equipmentTokens = {
    'fan_repair_issue': ['fan', 'ceiling fan', 'table fan', 'exhaust fan', 'pedestal fan', 'wall fan', 'fan regulator', 'pankha', 'kaathadi', 'visiri'],
    'refrigerator_cooling_issue': ['fridge', 'refrigerator', 'freeze', 'freezer', 'frost', 'defrost', 'kuliralla', 'fridge leaking', 'fridge water'],
    'mixer_grinder_repair': ['mixer', 'grinder', 'mixie', 'blender', 'mixi', 'coupler'],
    'microwave_oven_issue': ['microwave', 'oven', 'magnetron', 'grill oven'],
    'drain_block_sewerage': ['drain', 'clog', 'clogged', 'blocked', 'blockage', 'sink', 'basin', 'sewage', 'choke', 'toilet block', 'gully trap', 'adaipu'],
    'door_lock_woodwork': ['door', 'lock', 'latch', 'hinge', 'key', 'wood', 'carpenter', 'wardrobe', 'cupboard', 'drawer', 'kathavu', 'pootu', 'darwaza'],
    'wall_dampness_painting': ['paint', 'painting', 'putty', 'primer', 'peel', 'peeling', 'waterproofing', 'vannam', 'safedi'],
    'deep_cleaning_sanitization': ['clean', 'cleaning', 'deep clean', 'sanitize', 'descaling', 'chimney clean', 'sofa clean', 'acid wash', 'safai', 'suththam'],
    'metal_gate_welding': ['weld', 'welding', 'gate', 'grill', 'metal', 'iron', 'railing', 'shutter', 'irumbu', 'loha'],
    'masonry_tile_plaster_repair': ['masonry', 'mason', 'tile', 'tiles', 'cement', 'plaster', 'brick', 'granite', 'marble', 'grout', 'kothanar', 'mistri'],
    'gas_stove_hob_repair': ['gas stove', 'hob', 'burner', 'gas leak', 'cylinder pipe', 'gas aduppu', 'chulha'],
    'water_motor_failure': ['motor', 'pump', 'submersible', 'borewell', 'water motor', 'sump pump', 'monoblock'],
    'inverter_backup_failure': ['inverter', 'battery', 'ups', 'home battery'],
    'geyser_heating_issue': ['geyser', 'water heater', 'instant geyser', 'solar geyser'],
    'ac_cooling_failure': ['ac', 'air conditioner', 'split ac', 'inverter ac', 'window ac', 'cassette ac', 'ac dripping', 'ac leaking'],
    'mcb_tripping_spark': ['mcb', 'fuse', 'switchboard', 'switch board', 'circuit breaker', 'socket', 'switch'],
    'pipe_leakage_dampness': ['pipe', 'tap', 'faucet', 'flush', 'toilet', 'cistern', 'seepage', 'pipeline', 'plumbing'],
    'ro_purifier_issue': ['ro', 'water purifier', 'purifier', 'kent', 'aquaguard', 'pureit', 'membrane filter'],
    'washing_machine_fault': ['washing machine', 'washer', 'dryer', 'front load', 'top load'],
    'overhead_tank_overflow': ['overhead tank', 'sump', 'float valve', 'ball valve', 'water tank', 'sump pump', 'level sensor', 'auto starter'],
    'chimney_exhaust_failure': ['chimney', 'kitchen chimney', 'baffle filter', 'exhaust motor', 'chimney filter'],
    'induction_kettle_coil_failure': ['induction', 'induction stove', 'induction cooktop', 'kettle', 'electric kettle'],
    'dishwasher_drainage_issue': ['dishwasher', 'dish washer', 'spray arm'],
    'solar_water_heater_issue': ['solar water heater', 'solar heater', 'heat pump', 'solar geyser', 'vacuum tube'],
    'smart_doorbell_cctv_fault': ['doorbell', 'video doorbell', 'smart doorbell', 'cctv', 'cctv camera', 'security camera', 'intercom', 'dvr', 'nvr'],
    'sliding_window_roller_glass': ['sliding window', 'window roller', 'window track', 'upvc window', 'aluminum window', 'glass pane'],
    'bathroom_tile_grouting_seepage': ['tile grouting', 'grout', 'anti-skid tile', 'regrouting', 'epoxy grout', 'shower area'],
    'wood_termite_damage': ['termite', 'termites', 'wood borer', 'deemak', 'white ants'],
    'balcony_pulley_wire_snap': ['pulley', 'clothes drying pulley', 'ceiling pulley', 'drying stand', 'balcony pulley'],
  };

  // Comprehensive guardrail against non-household requests (negative test cases)
  static const Set<String> _outOfScopeTokens = {
    // Stationery & Office Supplies
    'pen', 'ball pen', 'ballpoint', 'gel pen', 'fountain pen', 'pencil', 'eraser', 'sharpener',
    'notebook', 'stapler', 'marker', 'compass', 'ink', 'ruler', 'fevicol', 'glue', 'paper',
    'book', 'calculator', 'diary', 'stationery', 'rubber', 'whitener', 'chart paper', 'crayon',

    // Personal Gadgets, Mobile & Consumer IT
    'phone', 'mobile', 'iphone', 'android', 'smartphone', 'laptop', 'tablet', 'ipad', 'mouse',
    'keyboard', 'charger', 'headphone', 'earphone', 'airpods', 'smartwatch', 'printer', 'scanner',
    'cpu', 'monitor', 'wifi password', 'virus', 'software', 'sim card', 'bluetooth', 'pendrive',
    'hard disk', 'ram', 'motherboard', 'playstation', 'xbox', 'console', 'earbud', 'webcam',

    // Automobile, Vehicles & Transportation
    'car', 'bike', 'motorcycle', 'scooter', 'activa', 'tyre', 'tire', 'puncture', 'engine oil',
    'car battery', 'vehicle', 'clutch', 'brake pad', 'gearbox', 'car wash', 'bullet', 'scooty',
    'auto', 'bicycle', 'cycle', 'helmet', 'petrol', 'diesel', 'radiator', 'car ac',

    // Food, Groceries & Restaurant Delivery
    'pizza', 'biryani', 'grocery', 'vegetables', 'milk', 'restaurant', 'swiggy', 'zomato', 'snack',
    'burger', 'lunch', 'dinner', 'tea', 'chai', 'coffee', 'ice cream', 'fruits', 'bread',
    'water bottle', 'sweets', 'hotel food',

    // Healthcare, Pharmacy & Medical
    'medicine', 'doctor', 'fever', 'headache', 'cough', 'hospital', 'clinic', 'prescription',
    'nurse', 'dentist', 'bandage', 'injection', 'blood test', 'ambulance', 'syrup', 'pharmacy',

    // Clothing, Footwear & Tailoring
    'shirt', 'pants', 't-shirt', 'jeans', 'saree', 'shoes', 'slippers', 'chappal', 'wallet',
    'dress', 'tailor', 'stitch', 'zipper', 'button', 'dry cleaning', 'ironing', 'laundry', 'cobbler',

    // Salon, Cosmetics & Personal Grooming
    'haircut', 'salon', 'makeup', 'lipstick', 'perfume', 'facial', 'shave', 'waxing', 'massage',
    'spa', 'manicure', 'pedicure', 'mehendi',

    // Pets & Veterinary Care
    'dog', 'cat', 'puppy', 'kitten', 'pet food', 'veterinary', 'vet',

    // Education, Tutoring & Academics
    'homework', 'exam', 'tutor', 'tuition', 'assignment', 'schooling',

    // Financial, Banking & Legal
    'loan', 'credit card', 'bank', 'crypto', 'bitcoin', 'stock', 'trading', 'insurance', 'atm',

    // Travel & Ticketing
    'flight', 'flight ticket', 'train ticket', 'bus ticket', 'hotel room', 'passport', 'visa',

    // Weapons & Absurd
    'gun', 'weapon', 'spaceship', 'rocket', 'alien',
  };

  // ---------------------------------------------------------------------
  // Phonetic & Fuzzy STT Normalization
  // ---------------------------------------------------------------------
  static const Map<String, String> _phoneticSubstitutions = {
    'motar': 'motor',
    'motur': 'motor',
    'plamber': 'plumber',
    'plammar': 'plumber',
    'plamer': 'plumber',
    'nalwala': 'plumber',
    'geysar': 'geyser',
    'jyser': 'geyser',
    'giser': 'geyser',
    'geger': 'geyser',
    'frige': 'fridge',
    'freez': 'fridge',
    'frize': 'fridge',
    'mixi': 'mixie',
    'miksy': 'mixie',
    'mixy': 'mixie',
    'karant': 'current',
    'karand': 'current',
    'panka': 'fan',
    'pankha': 'fan',
    'carpantar': 'carpenter',
    'mistari': 'carpenter',
    'wirin': 'wiring',
    'wireing': 'wiring',
    'swich': 'switch',
    'swichboard': 'switchboard',
    'leeking': 'leak',
    'lik': 'leak',
    // Additional regional phonetic / STT dialect slips
    'istove': 'stove',
    'isteve': 'stove',
    'iswitch': 'switch',
    'iswitchboard': 'switchboard',
    'fyan': 'fan',
    'phyan': 'fan',
    'kol': 'tap',
    'karentu': 'current',
    'karrent': 'current',
    'plambaru': 'plumber',
    'palambar': 'plumber',
    'indukshun': 'induction',
    'indakshun': 'induction',
    'kittli': 'kettle',
    'ketli': 'kettle',
    'chimni': 'chimney',
    'chimney': 'chimney',
    'dishwaser': 'dishwasher',
    'dishwasar': 'dishwasher',
    'dorbel': 'doorbell',
    'dorebell': 'doorbell',
    'cictv': 'cctv',
    'sisitivi': 'cctv',
    'termait': 'termite',
    'turmite': 'termite',
    'pulli': 'pulley',
    'puli': 'pulley',
    'solaar': 'solar',
    'saump': 'sump',
    'isump': 'sump',
    'iflot': 'float',
    'iglass': 'glass',
    'girout': 'grout',
    'igrout': 'grout',
  };

  /// Computes bounded Levenshtein distance between [s] and [t].
  static int _levenshtein(String s, String t, {int maxDistance = 2}) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    if ((s.length - t.length).abs() > maxDistance) return maxDistance + 1;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      int minRowVal = v1[0];

      for (int j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v0[j + 1] + 1, min(v1[j] + 1, v0[j] + cost));
        if (v1[j + 1] < minRowVal) {
          minRowVal = v1[j + 1];
        }
      }

      if (minRowVal > maxDistance) {
        return maxDistance + 1;
      }

      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[t.length];
  }

  /// Checks if any word in [text] is within fuzzy edit distance of [token].
  /// Enforces token.length >= 5 and strict distance bounds to prevent false matches.
  static bool _fuzzyMatchesToken(String text, String token) {
    final t = token.trim().toLowerCase();
    if (t.length < 5 || t.contains(' ')) return false;

    final maxDist = t.length >= 8 ? 2 : 1;
    final words = text.split(RegExp(r'[\s,.-]+')).where((w) => w.length >= 4);

    for (final w in words) {
      if ((w.length - t.length).abs() > maxDist) continue;
      if (_levenshtein(w, t, maxDistance: maxDist) <= maxDist) {
        return true;
      }
    }
    return false;
  }

  /// Check whether a word or phrase matches inside text with exact word boundaries,
  /// with phonetic substitution and bounded fuzzy matching fallback.
  /// Prevents "ac" from matching "machine", "is" from matching "display", etc.
  static bool _matchesWordOrPhrase(String text, String token, {bool allowFuzzy = false}) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (t.contains(' ')) {
      return text.contains(t);
    }
    final reg = RegExp(r'\b' + RegExp.escape(t) + r'\b', caseSensitive: false);
    if (reg.hasMatch(text)) return true;

    // Check phonetic dictionary: if any word in text maps to token
    final words = text.split(RegExp(r'[\s,.-]+')).where((w) => w.isNotEmpty);
    for (final w in words) {
      if (_phoneticSubstitutions[w] == t) {
        return true;
      }
    }

    if (allowFuzzy && t.length >= 5) {
      return _fuzzyMatchesToken(text, t);
    }
    return false;
  }

  /// Root-stem matcher: matches a word STARTING with [stem], with a left
  /// word boundary but no right word boundary, with phonetic & fuzzy tolerance.
  static bool _matchesStem(String text, String stem, {bool allowFuzzy = false}) {
    final s = stem.trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s.contains(' ')) {
      return text.contains(s);
    }
    final reg = RegExp(r'\b' + RegExp.escape(s), caseSensitive: false);
    if (reg.hasMatch(text)) return true;

    final words = text.split(RegExp(r'[\s,.-]+')).where((w) => w.isNotEmpty);
    for (final w in words) {
      final canon = _phoneticSubstitutions[w];
      if (canon != null && canon.startsWith(s)) {
        return true;
      }
    }

    if (allowFuzzy && s.length >= 5) {
      for (final w in words) {
        if (w.length >= s.length - 1) {
          final prefix = w.length >= s.length ? w.substring(0, s.length) : w;
          if (_levenshtein(prefix, s, maxDistance: 1) <= 1) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Dual-text phrase matcher: checks a token/phrase against BOTH the
  /// filler-stripped query and the original raw (lowercased) query.
  static bool _matchesAny(String cleanedText, String rawText, String token, {bool allowFuzzy = false}) {
    return _matchesWordOrPhrase(cleanedText, token, allowFuzzy: allowFuzzy) ||
           _matchesWordOrPhrase(rawText, token, allowFuzzy: allowFuzzy);
  }

  /// Same dual-text guarantee as [_matchesAny], but for root-stem matching.
  static bool _matchesStemAny(String cleanedText, String rawText, String stem, {bool allowFuzzy = false}) {
    return _matchesStem(cleanedText, stem, allowFuzzy: allowFuzzy) ||
           _matchesStem(rawText, stem, allowFuzzy: allowFuzzy);
  }

  // ---------------------------------------------------------------------
  // Top-Level Direct Artisan Intent Gate
  // ---------------------------------------------------------------------
  // If the (filler-stripped) query directly names a trade artisan — in
  // English root form, or via common Hindi/regional trade nouns — we skip
  // the full symptom-scoring cascade entirely and return that trade
  // immediately with high (0.95) confidence. This is what lets queries
  // like "Enakku ippa oru painter vennu" or "mujhe ek painter ki zaroorat
  // hai" resolve straight to Painter regardless of language.
  static const List<Map<String, Object>> _directArtisanGate = [
    {
      'trade': 'Painter',
      'secondary': 'Plumber',
      'equipmentTag': 'Painting & Waterproofing',
      'stems': ['paint'],
      'phrases': ['rangwala', 'safediwala', 'rangari', 'chitrakaar', 'vanna poosu', 'rang lagana'],
    },
    {
      'trade': 'Plumber',
      'secondary': 'Electrician',
      'equipmentTag': 'Water & Plumbing System',
      'stems': ['plumb'],
      'phrases': ['nalwala', 'pipe mechanic', 'tap fitter', 'water mechanic'],
    },
    {
      'trade': 'Electrician',
      'secondary': 'Appliance Repair',
      'equipmentTag': 'Electrical Fixture',
      'stems': ['electr'],
      'phrases': ['bijliwala', 'wireman', 'line mechanic', 'current man'],
    },
    {
      'trade': 'Carpenter',
      'secondary': 'Welder / Metal',
      'equipmentTag': 'Doors, Locks & Woodwork',
      'stems': ['carpent'],
      'phrases': ['badhai', 'sutar', 'maramari', 'thachchan', 'wood worker', 'furniture maker'],
    },
    {
      'trade': 'Cleaning',
      'secondary': 'Plumber',
      'equipmentTag': 'Deep Cleaning & Descaling',
      'stems': ['clean'],
      'phrases': ['safaiwala', 'housekeeping', 'cleaning crew', 'kachra saf'],
    },
    {
      'trade': 'Masonry',
      'secondary': 'Plumber',
      'equipmentTag': 'Masonry & Tile Works',
      'stems': ['mason'],
      'phrases': ['mistri', 'rajmistri', 'kothanar', 'brick layer', 'plasterer'],
    },
    {
      'trade': 'Welder / Metal',
      'secondary': 'Carpenter',
      'equipmentTag': 'Metal Fabrication & Welding',
      'stems': ['weld'],
      'phrases': ['lohar', 'fabricator', 'patrai', 'iron worker'],
    },
  ];

  /// Returns a high-confidence direct-artisan match if the cleaned OR raw
  /// query explicitly names a trade professional, otherwise returns null so
  /// the caller can fall through to the normal symptom-scoring cascade.
  /// [cleanedQuery] is the filler-stripped, lowercased query; [rawLower] is
  /// the untouched, lowercased original — checked together so a filler word
  /// that coincidentally overlaps with a symptom/trade fragment (see
  /// [_matchesAny]) never causes a missed match.
  static DiagnosticResult? _checkDirectArtisanIntent(String cleanedQuery, String rawLower, String rawQuery) {
    for (final entry in _directArtisanGate) {
      final trade = entry['trade'] as String;
      final secondary = entry['secondary'] as String;
      final equipmentTag = entry['equipmentTag'] as String;
      final stems = entry['stems'] as List<String>;
      final phrases = entry['phrases'] as List<String>;

      var matched = false;
      for (final stem in stems) {
        if (_matchesStemAny(cleanedQuery, rawLower, stem, allowFuzzy: true)) {
          matched = true;
          break;
        }
      }
      if (!matched) {
        for (final phrase in phrases) {
          if (_matchesAny(cleanedQuery, rawLower, phrase, allowFuzzy: true)) {
            matched = true;
            break;
          }
        }
      }

      if (matched) {
        return DiagnosticResult(
          symptomQuery: rawQuery,
          primaryCategory: trade,
          secondaryCategory: secondary,
          confidence: 0.95,
          equipmentTag: equipmentTag,
          summary: 'Direct request identified for a $trade. Matched artisan trade professional with high confidence.',
          likelyCauses: const ['Customer directly requested this trade professional by name.'],
          suggestedToolsNeeded: const [],
          requiresSmartDiagnosticVisit: false,
          diagnosticFee: 99.0,
        );
      }
    }
    return null;
  }

  /// Token-based local triage matching algorithm for instantaneous offline response.
  /// Supports optional [contextEquipmentHint] to disambiguate identical symptoms (e.g. water leak from AC vs plumbing).
  static DiagnosticResult matchSymptom(
    String rawQuery, {
    String? contextEquipmentHint,
  }) {
    final lowered = rawQuery.trim().toLowerCase();
    if (lowered.isEmpty) {
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

    // Strip conversational wrapper/filler words across all 22 Scheduled
    // Languages + English BEFORE scoring, so phrases like "I need send
    // someone urgent in my house" or "mujhe ek painter ki zaroorat hai"
    // don't dilute scores or trigger a false Out-of-Scope rejection.
    // NOTE: `lowered` (the untouched raw text) is kept alongside `query`
    // (the stripped text) and both are checked together via [_matchesAny] /
    // [_matchesStemAny] throughout, because a handful of regional filler
    // words coincidentally double as fragments of legitimate multi-word
    // vernacular symptom phrases (e.g. Tamil "varala" inside "thani
    // varala" = "water not coming"). Stripping alone would silently break
    // those phrases; checking both texts guarantees they still match.
    final query = _stripConversationalFillers(lowered);

    // 0. Negative Guardrail: Reject Out-of-Scope Requests (e.g., "my pen broken", "car puncture", "laptop screen")
    for (final outToken in _outOfScopeTokens) {
      if (_matchesAny(query, lowered, outToken)) {
        return DiagnosticResult(
          symptomQuery: rawQuery,
          primaryCategory: 'Out of Scope',
          confidence: 0.0,
          equipmentTag: 'Non-Household Service',
          summary: 'This request ("$rawQuery") is outside the scope of WorkGo. WorkGo exclusively connects verified local artisans for Electrical, Plumbing, Appliance Repair, Carpentry, Painting, Cleaning, Welding, and Masonry.',
          likelyCauses: const [
            'The requested item does not belong to home utility craft trades (e.g. stationery, mobile devices, automobiles, medical, or food delivery).',
            'Supported residential trades: Electrician, Plumber, Appliance Repair, Carpenter, Painter, Deep Cleaning, Welder, and Masonry.'
          ],
          suggestedToolsNeeded: const [],
          requiresSmartDiagnosticVisit: false,
          diagnosticFee: 0.0,
          isOutOfScope: true,
        );
      }
    }

    // 0.5 Top-Level Direct Artisan Intent Gate (0.95 confidence short-circuit)
    final directMatch = _checkDirectArtisanIntent(query, lowered, rawQuery);
    if (directMatch != null) {
      return directMatch;
    }

    final allWords = query.split(RegExp(r'[\s,.-]+')).where((w) => w.length > 1).toList();
    final contentWords = allWords.where((w) => !_stopWords.contains(w)).toList();

    SymptomItem? bestItem;
    int bestScore = 0;

    for (final item in items) {
      int score = 0;

      // Context Equipment Hint Disambiguation (+15 points)
      if (contextEquipmentHint != null && contextEquipmentHint.isNotEmpty) {
        final hint = contextEquipmentHint.toLowerCase().trim();
        if (item.equipmentTag.toLowerCase().contains(hint) ||
            hint.contains(item.equipmentTag.toLowerCase()) ||
            item.title.toLowerCase().contains(hint)) {
          score += 15;
        }
      }

      // 1. Primary Equipment Name Match (+20 points)
      // If customer explicitly mentions the equipment (e.g. "ac", "geyser", "motor"),
      // that equipment MUST take priority over unrelated appliances.
      final equipTokens = _equipmentTokens[item.id] ?? [];
      for (final eqTok in equipTokens) {
        if (_matchesAny(query, lowered, eqTok, allowFuzzy: true)) {
          score += 20;
          break; // Count once per item
        }
      }

      // 2. Specialized Symptom / Fault Descriptor Tokens
      for (final token in item.searchTokens) {
        if (_matchesAny(query, lowered, token, allowFuzzy: true)) {
          score += (token.length > 5 ? 5 : 3);
        }
      }

      // 3. Content Word Overlap (Stopwords strictly excluded)
      for (final word in contentWords) {
        if (_matchesWordOrPhrase(item.title.toLowerCase(), word, allowFuzzy: true)) {
          score += 4;
        }
        if (_matchesWordOrPhrase(item.description.toLowerCase(), word, allowFuzzy: true)) {
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
      final bool isDualDiscipline = bestItem.isAmbiguous &&
          bestItem.secondaryCategory.isNotEmpty &&
          bestItem.secondaryCategory != bestItem.primaryCategory;

      final summary = isDualDiscipline
          ? 'Cross-disciplinary issue: Primary dispatch routed to ${bestItem.primaryCategory}, with cross-trade ${bestItem.secondaryCategory} verification on-site.'
          : 'Specialist match identified: ${bestItem.primaryCategory}.';

      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: bestItem.primaryCategory,
        secondaryCategory: isDualDiscipline
            ? bestItem.secondaryCategory
            : (bestItem.secondaryCategory != bestItem.primaryCategory ? bestItem.secondaryCategory : null),
        confidence: confidence,
        equipmentTag: bestItem.equipmentTag,
        summary: summary,
        likelyCauses: bestItem.likelyCauses,
        clarifyingQuestions: bestItem.clarifyingQuestions,
        suggestedKeywords: bestItem.searchTokens.take(4).toList(),
        suggestedToolsNeeded: bestItem.suggestedToolsNeeded,
        requiresSmartDiagnosticVisit: bestItem.isAmbiguous || isDualDiscipline,
        diagnosticFee: isDualDiscipline ? 149.0 : 99.0,
        isAiGenerated: false,
      );
    }

    // Comprehensive Heuristic Fallbacks based on Blue Collar Trade Taxonomy
    // 1. Carpenter Fallback
    if (_matchesStemAny(query, lowered, 'carpent') ||
        _matchesAny(query, lowered, 'door') ||
        _matchesAny(query, lowered, 'lock') ||
        _matchesAny(query, lowered, 'latch') ||
        _matchesAny(query, lowered, 'hinge') ||
        _matchesAny(query, lowered, 'key') ||
        _matchesAny(query, lowered, 'wood') ||
        _matchesAny(query, lowered, 'wardrobe') ||
        _matchesAny(query, lowered, 'cupboard') ||
        _matchesAny(query, lowered, 'drawer') ||
        _matchesAny(query, lowered, 'bed') ||
        _matchesAny(query, lowered, 'sofa') ||
        _matchesAny(query, lowered, 'furniture') ||
        _matchesAny(query, lowered, 'kathavu') ||
        _matchesAny(query, lowered, 'pootu') ||
        _matchesAny(query, lowered, 'saavi') ||
        _matchesAny(query, lowered, 'darwaza') ||
        _matchesAny(query, lowered, 'lakdi')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Carpenter',
        secondaryCategory: 'Welder / Metal',
        confidence: 0.85,
        equipmentTag: 'Doors, Locks & Woodwork',
        summary: 'Woodwork, lock mechanism, or door hinge issue. Carpenter will inspect alignment, cylinder, and fittings.',
        likelyCauses: ['Lock cylinder stuck or misaligned', 'Wood expansion or sagging hinges', 'Channel slider detached'],
        suggestedToolsNeeded: ['Wood Planer', 'Chisel Set', 'Cordless Drill', 'Lock Installation Kit'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // 2. Painter & Waterproofing Fallback
    if (_matchesStemAny(query, lowered, 'paint') ||
        _matchesAny(query, lowered, 'putty') ||
        _matchesAny(query, lowered, 'primer') ||
        _matchesAny(query, lowered, 'peel') ||
        _matchesAny(query, lowered, 'peeling') ||
        _matchesAny(query, lowered, 'waterproofing') ||
        _matchesAny(query, lowered, 'exterior paint') ||
        _matchesAny(query, lowered, 'interior paint') ||
        _matchesAny(query, lowered, 'vannam') ||
        _matchesAny(query, lowered, 'safedi') ||
        _matchesAny(query, lowered, 'rang') ||
        _matchesAny(query, lowered, 'color adikka') ||
        _matchesAny(query, lowered, 'rangwala') ||
        _matchesAny(query, lowered, 'rangari') ||
        _matchesAny(query, lowered, 'chitrakaar')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Painter',
        secondaryCategory: 'Plumber',
        confidence: 0.85,
        equipmentTag: 'Painting & Waterproofing',
        summary: 'Wall painting or surface dampness issue. Artisan will check moisture levels and plaster condition.',
        likelyCauses: ['Efflorescence from moisture', 'Flaking old paint layer', 'Hairline plaster cracks'],
        suggestedToolsNeeded: ['Moisture Meter', 'Scraper Blade', 'Putty Blade', 'Sanding Block'],
        requiresSmartDiagnosticVisit: true,
        diagnosticFee: 99.0,
      );
    }

    // 3. Deep Cleaning & Sanitization Fallback
    if (_matchesStemAny(query, lowered, 'clean') ||
        _matchesAny(query, lowered, 'deep clean') ||
        _matchesAny(query, lowered, 'sanitize') ||
        _matchesAny(query, lowered, 'descaling') ||
        _matchesAny(query, lowered, 'chimney clean') ||
        _matchesAny(query, lowered, 'sofa clean') ||
        _matchesAny(query, lowered, 'acid wash') ||
        _matchesAny(query, lowered, 'stain') ||
        _matchesAny(query, lowered, 'safai') ||
        _matchesAny(query, lowered, 'safaiwala') ||
        _matchesAny(query, lowered, 'housekeeping') ||
        _matchesAny(query, lowered, 'suththam') ||
        _matchesAny(query, lowered, 'kazhuva')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Cleaning',
        secondaryCategory: 'Plumber',
        confidence: 0.85,
        equipmentTag: 'Deep Cleaning & Descaling',
        summary: 'Deep cleaning or descaling service required. Cleaning crew will deploy specialized machinery and solutions.',
        likelyCauses: ['Hard-water calcium scale on tiles', 'Grease accumulation in chimney filters', 'Upholstery stain/dust'],
        suggestedToolsNeeded: ['High Pressure Steam Cleaner', 'Rotary Scrubber', 'Alkaline Degreaser', 'HEPA Vacuum'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // 4. Welder / Metal Fabrication Fallback
    if (_matchesStemAny(query, lowered, 'weld') ||
        _matchesAny(query, lowered, 'gate') ||
        _matchesAny(query, lowered, 'grill') ||
        _matchesAny(query, lowered, 'metal') ||
        _matchesAny(query, lowered, 'iron') ||
        _matchesAny(query, lowered, 'railing') ||
        _matchesAny(query, lowered, 'shutter') ||
        _matchesAny(query, lowered, 'irumbu') ||
        _matchesAny(query, lowered, 'patrai') ||
        _matchesAny(query, lowered, 'lohar') ||
        _matchesAny(query, lowered, 'fabricator') ||
        _matchesAny(query, lowered, 'loha')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Welder / Metal',
        secondaryCategory: 'Carpenter',
        confidence: 0.85,
        equipmentTag: 'Metal Fabrication & Welding',
        summary: 'Metal structure or gate hinge failure. Welder will perform on-site arc cutting and re-welding.',
        likelyCauses: ['Rusted hinge weld failure', 'Gate post anchor sag', 'Cracked safety grill joints'],
        suggestedToolsNeeded: ['Portable Arc Welder', 'Angle Grinder', 'Welding Helmet', 'Chipping Hammer'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // 5. Masonry & Civil Works Fallback
    if (_matchesStemAny(query, lowered, 'mason') ||
        _matchesAny(query, lowered, 'tile') ||
        _matchesAny(query, lowered, 'tiles') ||
        _matchesAny(query, lowered, 'cement') ||
        _matchesAny(query, lowered, 'plaster') ||
        _matchesAny(query, lowered, 'brick') ||
        _matchesAny(query, lowered, 'granite') ||
        _matchesAny(query, lowered, 'marble') ||
        _matchesAny(query, lowered, 'grout') ||
        _matchesAny(query, lowered, 'kothanar') ||
        _matchesAny(query, lowered, 'mistri') ||
        _matchesAny(query, lowered, 'rajmistri') ||
        _matchesAny(query, lowered, 'chuna') ||
        _matchesAny(query, lowered, 'patthar')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Masonry',
        secondaryCategory: 'Plumber',
        confidence: 0.85,
        equipmentTag: 'Masonry & Tile Works',
        summary: 'Civil masonry, tile repair, or cement plastering issue. Mason will inspect slab, grout lines, and structural soundness.',
        likelyCauses: ['Hollow or debonded tiles due to mortar shrinkage', 'Hairline plaster cracks in wall bed', 'Deteriorated waterproof tile grout'],
        suggestedToolsNeeded: ['Notched Trowel', 'Tile Cutter', 'Rubber Mallet', 'Spirit Level'],
        requiresSmartDiagnosticVisit: true,
        diagnosticFee: 99.0,
      );
    }

    // 6. Kitchen Gas Stove & Hob Fallback
    if (_matchesAny(query, lowered, 'gas stove') ||
        _matchesAny(query, lowered, 'hob') ||
        _matchesAny(query, lowered, 'burner') ||
        _matchesAny(query, lowered, 'gas leak') ||
        _matchesAny(query, lowered, 'cylinder pipe') ||
        _matchesAny(query, lowered, 'gas aduppu') ||
        _matchesAny(query, lowered, 'chulha')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Appliance Repair',
        secondaryCategory: 'Plumber',
        confidence: 0.88,
        equipmentTag: 'Kitchen Gas Stove & Hob',
        summary: 'Gas stove or built-in hob issue. Technician will check brass burner orifices, flame color, and gas hose integrity.',
        likelyCauses: ['Carbon soot clogging brass burner jets', 'Faulty spark pulse generator or thermocouple', 'Damaged regulator hose'],
        suggestedToolsNeeded: ['Nozzle Jet Pin Cleaner', 'Gas Pressure Manometer', 'Leak Detection Spray'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // 7. Appliance Repair Fallback
    if (_matchesAny(query, lowered, 'fridge') ||
        _matchesAny(query, lowered, 'refrigerator') ||
        _matchesAny(query, lowered, 'ac') ||
        _matchesAny(query, lowered, 'air conditioner') ||
        _matchesAny(query, lowered, 'washing machine') ||
        _matchesAny(query, lowered, 'geyser') ||
        _matchesAny(query, lowered, 'heater') ||
        _matchesAny(query, lowered, 'ro') ||
        _matchesAny(query, lowered, 'purifier') ||
        _matchesAny(query, lowered, 'microwave') ||
        _matchesAny(query, lowered, 'oven') ||
        _matchesAny(query, lowered, 'mixer') ||
        _matchesAny(query, lowered, 'grinder') ||
        _matchesAny(query, lowered, 'blender') ||
        _matchesAny(query, lowered, 'mixie') ||
        _matchesAny(query, lowered, 'tv') ||
        _matchesAny(query, lowered, 'television') ||
        _matchesAny(query, lowered, 'appliance')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Appliance Repair',
        secondaryCategory: 'Electrician',
        confidence: 0.85,
        equipmentTag: 'Home Appliance',
        summary: 'Household appliance malfunction. Technician will test internal components, PCB, and motor coils.',
        likelyCauses: ['Power component failure', 'Wear and tear in drive parts', 'Thermostat / sensor fault'],
        suggestedToolsNeeded: ['Digital Multimeter', 'Insulated Tool Set', 'Component Tester'],
        requiresSmartDiagnosticVisit: true,
        diagnosticFee: 99.0,
      );
    }

    // 8. Plumber Fallback
    if (_matchesStemAny(query, lowered, 'plumb') ||
        _matchesAny(query, lowered, 'water') ||
        _matchesAny(query, lowered, 'pipe') ||
        _matchesAny(query, lowered, 'tap') ||
        _matchesAny(query, lowered, 'faucet') ||
        _matchesAny(query, lowered, 'leak') ||
        _matchesAny(query, lowered, 'drain') ||
        _matchesAny(query, lowered, 'flush') ||
        _matchesAny(query, lowered, 'sink') ||
        _matchesAny(query, lowered, 'basin') ||
        _matchesAny(query, lowered, 'toilet') ||
        _matchesAny(query, lowered, 'sewer') ||
        _matchesAny(query, lowered, 'sewage') ||
        _matchesAny(query, lowered, 'clog') ||
        _matchesAny(query, lowered, 'shower') ||
        _matchesAny(query, lowered, 'motor') ||
        _matchesAny(query, lowered, 'valve') ||
        _matchesAny(query, lowered, 'tank') ||
        _matchesAny(query, lowered, 'nalwala') ||
        _matchesAny(query, lowered, 'thanni') ||
        _matchesAny(query, lowered, 'paani') ||
        _matchesAny(query, lowered, 'adaipu')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Plumber',
        secondaryCategory: 'Electrician',
        confidence: 0.80,
        equipmentTag: 'Water & Plumbing System',
        summary: 'Likely plumbing fixture or water flow issue. A diagnostic inspection will verify concealed lines.',
        likelyCauses: ['Pipe joint leakage', 'Valve wear', 'Blockage in drain line'],
        suggestedToolsNeeded: ['Pipe Wrench', 'Thread Seal Tape', 'Basin Wrench', 'Hacksaw'],
        requiresSmartDiagnosticVisit: true,
        diagnosticFee: 99.0,
      );
    }

    // 9. Electrician Fallback
    if (_matchesStemAny(query, lowered, 'electr') ||
        _matchesAny(query, lowered, 'light') ||
        _matchesAny(query, lowered, 'wire') ||
        _matchesAny(query, lowered, 'wiring') ||
        _matchesAny(query, lowered, 'switch') ||
        _matchesAny(query, lowered, 'fan') ||
        _matchesAny(query, lowered, 'power') ||
        _matchesAny(query, lowered, 'shock') ||
        _matchesAny(query, lowered, 'trip') ||
        _matchesAny(query, lowered, 'mcb') ||
        _matchesAny(query, lowered, 'fuse') ||
        _matchesAny(query, lowered, 'inverter') ||
        _matchesAny(query, lowered, 'current') ||
        _matchesAny(query, lowered, 'spark') ||
        _matchesAny(query, lowered, 'socket') ||
        _matchesAny(query, lowered, 'plug') ||
        _matchesAny(query, lowered, 'bulb') ||
        _matchesAny(query, lowered, 'earthing') ||
        _matchesAny(query, lowered, 'short circuit') ||
        _matchesAny(query, lowered, 'bijliwala') ||
        _matchesAny(query, lowered, 'wireman') ||
        _matchesAny(query, lowered, 'bijli')) {
      return DiagnosticResult(
        symptomQuery: rawQuery,
        primaryCategory: 'Electrician',
        secondaryCategory: 'Appliance Repair',
        confidence: 0.80,
        equipmentTag: 'Electrical Fixture',
        summary: 'Electrical distribution or fixture failure. Technician will verify voltage, continuity, and grounding.',
        likelyCauses: ['Wiring short circuit', 'Loose terminal connection', 'Switch/fuse malfunction'],
        suggestedToolsNeeded: ['Digital Multimeter', 'Insulated Screwdriver Set', 'Wire Strippers', 'Neon Tester'],
        requiresSmartDiagnosticVisit: false,
        diagnosticFee: 99.0,
      );
    }

    // 10. Strictly Reject Unrecognized Queries as Out of Scope.
    // NEVER blindly guess a trade fallback when zero household repair signals exist!
    return DiagnosticResult(
      symptomQuery: rawQuery,
      primaryCategory: 'Out of Scope',
      secondaryCategory: null,
      confidence: 0.0,
      equipmentTag: 'Unrecognized / Non-Household Service',
      summary: 'We could not recognize a supported household repair issue in "$rawQuery". WorkGo connects verified local artisans exclusively for residential trade crafts: Electrician, Plumber, Appliance Repair, Carpenter, Painter, Cleaning, Welder, and Masonry.',
      likelyCauses: const [
        'The query does not describe a supported household utility or appliance failure.',
        'Please describe your home issue (e.g., fan not working, pipe leaking, AC not cooling, door lock stuck, or tile cracked).',
      ],
      suggestedToolsNeeded: const [],
      requiresSmartDiagnosticVisit: false,
      diagnosticFee: 0.0,
      isOutOfScope: true,
    );
  }
}