import 'package:flutter/foundation.dart';

/// Categories of immediate physical household hazards detected by Tier 0.
enum HazardType {
  /// Electrical shock from metal body, taps, geysers, switchboards, or bare wire.
  electricalShock,

  /// Wire sparking, burning smell, smoke, or fire hazard from electrical circuits.
  fireSpark,

  /// LPG gas leak, cylinder leak, or gas stove pipe leakage.
  gasLeak,
}

/// Structured flag representing an identified household safety hazard.
@immutable
class HazardFlag {
  /// The specific category of the hazard.
  final HazardType type;

  /// The exact or normalized phrase in the query that triggered the hazard.
  final String matchedPhrase;

  /// Human-readable safety alert instruction for the customer.
  final String safetyInstruction;

  /// Recommended trade artisan to handle the emergency repair.
  final String emergencyTrade;

  /// Whether the customer must immediately cut off the utility (main MCB or gas regulator).
  final bool requiresImmediateIsolation;

  /// National emergency utility helpline number in India (1912 for electricity, 1906 for LPG).
  final String helplineNumber;

  /// Display label for the emergency helpline.
  final String helplineLabel;

  const HazardFlag({
    required this.type,
    required this.matchedPhrase,
    required this.safetyInstruction,
    required this.emergencyTrade,
    this.requiresImmediateIsolation = true,
    required this.helplineNumber,
    required this.helplineLabel,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'matchedPhrase': matchedPhrase,
        'safetyInstruction': safetyInstruction,
        'emergencyTrade': emergencyTrade,
        'requiresImmediateIsolation': requiresImmediateIsolation,
        'helplineNumber': helplineNumber,
        'helplineLabel': helplineLabel,
      };

  factory HazardFlag.fromMap(Map<String, dynamic> map) => HazardFlag(
        type: HazardType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => HazardType.electricalShock,
        ),
        matchedPhrase: map['matchedPhrase'] as String? ?? '',
        safetyInstruction: map['safetyInstruction'] as String? ?? '',
        emergencyTrade: map['emergencyTrade'] as String? ?? 'Electrician',
        requiresImmediateIsolation: map['requiresImmediateIsolation'] as bool? ?? true,
        helplineNumber: map['helplineNumber'] as String? ?? '1912',
        helplineLabel: map['helplineLabel'] as String? ?? 'National Emergency (1912)',
      );

  @override
  String toString() => 'HazardFlag(type: $type, matchedPhrase: "$matchedPhrase")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HazardFlag &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          matchedPhrase == other.matchedPhrase;

  @override
  int get hashCode => type.hashCode ^ matchedPhrase.hashCode;
}

/// Tier 0 Deterministic Hazard Scanner (Raw String, Zero ML, 100% Offline).
///
/// Runs directly on the raw, untouched input string before any ML model,
/// catalog scorer, or network request can execute.
///
/// Design Guarantees:
/// 1. Zero ML dependency: Cannot fail due to model corruption, OOM, or inference timeouts.
/// 2. Deterministic execution: < 0.1 ms execution budget on raw text.
/// 3. Multilingual coverage: Detects safety keywords in English, Tamil, Hindi,
///    Telugu, Kannada, Malayalam, Bengali, Marathi, Gujarati, and Romanized Tanglish/Hinglish variants.
/// 4. Negation awareness: Accurately filters out negated queries (e.g. "no shock",
///    "shock onnum illa", "gas leak nahi hai") to eliminate false emergency alarms.
class HazardScanner {
  HazardScanner._();

  // ── Electrical Shock Patterns ─────────────────────────────────────────────
  static final RegExp _shockRegex = RegExp(
    r'(\b(shocku?|shoku?|shack|electric\s*shocku?|current\s*shocku?|earthing\s*shocku?|wire\s*shocku?|tap\s*shocku?)\b|'
    r'current\s*(a[dt]i[kgh]+u[td]hu|a[dt]ichu[td]hu|lag\s*rah[aie]|mar\s*rah[aie]|maratha|koduthu|kodutondi|hodyutide|basla)|'
    r'shocku?\s*(a[dt]i[kgh]+u[td]hu|a[dt]ichu[td]hu|lag\s*rah[aie]|kodutondi|hodyutide|lagla)|'
    r'bijli\s*ka\s*jhatka|jhatka\s*lag|'
    r'earthing\s*(problem|issue|leak|leakage|aa\s*rah[aie]|varudhu)|'
    // Native Indian Scripts:
    r'[\u0B9A-\u0BD7]*ஷாக்[\u0B9A-\u0BD7]*|' // Tamil: ஷாக் / ஷாக்கு
    r'கரண்ட்\s*ஷாக்|'
    r'करंट\s*लग|बिजली\s*का\s*झटका|झटका\s*लग|' // Hindi
    r'షోక్|కరెంట్\s*కొడుతుంది|' // Telugu
    r'ಶಾಕ್|ಕರೆಂಟ್\s*ಹೊಡೆಯುತ್ತಿದೆ|' // Kannada
    r'ഷോക്ക്|കറണ്ട്\s*അടിക്കുന്നു|' // Malayalam
    r'ইলেকট্রিক\s*শক|কারেন্ট\s*লাগা|শক\s*লাগা|' // Bengali
    r'शॉक\s*लागला|करंट\s*बसला|' // Marathi
    r'કરંટ\s*લાગ્યો)', // Gujarati
    caseSensitive: false,
  );

  // ── Fire / Sparking / Burning Wire Patterns ───────────────────────────────
  static final RegExp _fireSparkRegex = RegExp(
    r'(\b(spark|sparking|sparks|short\s*circuit|burning\s*wire|melted\s*wire|wire\s*burning)\b|'
    r'(burning|burnt|burn)\s*(smell|odour|odor)|'
    r'smoke\s*(from|varudhu|aa\s*rah[aie]|nikal\s*rah[aie])|'
    r'smoke\b.*\b(switch|board|wire|mcb|socket|meter|panel)|'
    r'spark\s*(varudhu|varuthu|aa\s*rah[aie]|nikal\s*rah[aie]|vastundi)|'
    r'jalne\s*ki\s*(badbu|smell|gandh)|dhuan\s*(nikal|aa\s*rah[aie])|'
    r'eriyara\s*vaasam|thee\s*(pori|vaasam)|theepori|erinjupochu|'
    // Native Indian Scripts:
    r'தீப்பொறி|புகை\s*வருது|எரியும்\s*வாசனை|' // Tamil
    r'शॉर्ट\s*सर्किट|जलने\s*की\s*(बदबू|महक)|धुआं\s*निकल|' // Hindi
    r'మంటలు|పొగ\s*వస్తుంది|' // Telugu
    r'ಬೆಂಕಿ|ಹೊಗೆ|ಸುಟ್ಟ\s*ವಾಸನೆ|' // Kannada
    r'തീപ്പൊരി|പുക\s*വരുന്നു|കത്തുന്ന\s*മണം|' // Malayalam
    r'আগুন|ধোঁয়া|পোড়া\s*গন্ধ|শর্ট\s*সার্কিট|' // Bengali
    r'आग|धूर|जळण्याचा\s*वास|' // Marathi
    r'આગ|ધૂમાડો|બળવાની\s*વાસ)', // Gujarati
    caseSensitive: false,
  );

  // ── Gas Leak Patterns ─────────────────────────────────────────────────────
  static final RegExp _gasLeakRegex = RegExp(
    r'(\b(gas\s*leak|gas\s*leaking|cylinder\s*leak|cylinder\s*leaking|lpg\s*leak|lpg\s*leaking|gas\s*smell|lpg\s*smell)\b|'
    r'(smell|odour|odor)\s*of\s*(gas|lpg)|'
    r'gas\s*(ki\s*badbu|ki\s*smell|leak\s*ho\s*rah[aie]|vaasam|leak\s*aagudhu)|'
    r'cylinder\s*(se\s*gas|leak\s*ho\s*rah[aie]|leak|leaking)|'
    // Native Indian Scripts:
    r'கேஸ்\s*(லீக்|வாசனை)|' // Tamil
    r'गैस\s*(लीक|की\s*बदबू)|सिलेंडर\s*लीक|' // Hindi
    r'[\u0C00-\u0C7F]*గ్యాస్[\u0C00-\u0C7F]*\s*లీక్|' // Telugu
    r'[\u0C80-\u0CFF]*ಗ್ಯಾಸ್[\u0C80-\u0CFF]*\s*(ಸೋರಿಕೆ|ವಾಸನೆ|ಲೀಕ್)|' // Kannada
    r'[\u0D00-\u0D7F]*ഗ്യാസ്[\u0D00-\u0D7F]*\s*(ചോർച്ച|മണം|ലീക്ക്)|' // Malayalam
    r'[\u0980-\u09FF]*গ্যাস[\u0980-\u09FF]*\s*(লিক|গন্ধ|চুয়ে\s*পড়া)|' // Bengali
    r'[\u0900-\u097F]*गॅस[\u0900-\u097F]*\s*(गळती|वास|लीक)|' // Marathi
    r'[\u0A80-\u0AFF]*ગેસ[\u0A80-\u0AFF]*\s*(લીક|ગંધ))', // Gujarati
    caseSensitive: false,
  );

  // ── Negation Windows & Patterns ───────────────────────────────────────────
  // Preceding Negations: words directly before the hazard phrase (e.g. "no shock", "nahi lag raha shock")
  static final RegExp _precedingNegationRegex = RegExp(
    r'(\b(no|not|without|never|zero|free\s*from)\b|'
    r'\b(nahi|nahin|na|mat)\b|'
    r'\b(illa|illai|kedayathu)\b|'
    r'\b(ledu|kadu)\b|'
    r'[\u0900-\u097F]*(नहीं|ना|मत)[\u0900-\u097F]*|' // Hindi
    r'[\u0B80-\u0BFF]*(இல்லை|இல்ல)[\u0B80-\u0BFF]*|' // Tamil
    r'[\u0C00-\u0C7F]*(లేదు|కాదు)[\u0C00-\u0C7F]*|' // Telugu
    r'[\u0C80-\u0CFF]*(ಇಲ್ಲ)[\u0C80-\u0CFF]*|' // Kannada
    r'[\u0D00-\u0D7F]*(ഇല്ല|അല്ല)[\u0D00-\u0D7F]*|' // Malayalam
    r'[\u0980-\u09FF]*(না|নেই)[\u0980-\u09FF]*)', // Bengali
    caseSensitive: false,
  );

  // Following Negations: words directly following the hazard phrase (e.g. "shock illa", "shock onnum illa", "gas leak nahi hai")
  static final RegExp _followingNegationRegex = RegExp(
    r'(\b(not\s*present|not\s*there|absent|is\s*not|are\s*not|never)\b|'
    r'\b(illa|illai|varala|adikila|adikala|aagala|onnum\s*illa|kedayathu)\b|'
    r'\b(nahi|nahin|nahi\s*hai|nahi\s*lag\s*raha|nahi\s*ho\s*raha|kuch\s*nahi)\b|'
    r'\b(ledu|kadu|ravatledu|kodatledu)\b|'
    r'\b(hodyutilla|barutilla)\b|'
    r'\b(varunnilla)\b|'
    r'\b(hocche\s*na|nei)\b|'
    r'[\u0900-\u097F]*(नहीं|नहीं\s*है|नहीं\s*लग\s*रहा)[\u0900-\u097F]*|' // Hindi
    r'[\u0B80-\u0BFF]*(இல்லை|இல்ல|வரல|ஆவல|அடிக்கல)[\u0B80-\u0BFF]*|' // Tamil
    r'[\u0C00-\u0C7F]*(లేదు|రావట్లేదు|కొట్టట్లేదు)[\u0C00-\u0C7F]*|' // Telugu
    r'[\u0C80-\u0CFF]*(ಇಲ್ಲ)[\u0C80-\u0CFF]*|' // Kannada
    r'[\u0D00-\u0D7F]*(ഇല്ല)[\u0D00-\u0D7F]*|' // Malayalam
    r'[\u0980-\u09FF]*(না|নেই)[\u0980-\u09FF]*)', // Bengali
    caseSensitive: false,
  );

  /// Checks whether a specific regex match is negated by neighboring tokens.
  static bool _isMatchNegated(String fullText, Match match) {
    // 1. Check preceding window (up to 32 chars before match)
    final preStart = (match.start - 32).clamp(0, fullText.length);
    final preWindow = fullText.substring(preStart, match.start).trim();
    if (preWindow.isNotEmpty) {
      final preWords = preWindow.split(RegExp(r'\s+'));
      // Check the last 1 or 2 words right before the match
      final lastWords = preWords.skip(preWords.length > 2 ? preWords.length - 2 : 0).join(' ');
      if (_precedingNegationRegex.hasMatch(lastWords)) {
        return true;
      }
    }

    // 2. Check following window (up to 36 chars after match)
    final postEnd = (match.end + 36).clamp(0, fullText.length);
    final postWindow = fullText.substring(match.end, postEnd).trim();
    if (postWindow.isNotEmpty) {
      final postWords = postWindow.split(RegExp(r'\s+'));
      // Check the first 1 to 3 words right after the match
      final nextWords = postWords.take(3).join(' ');
      if (_followingNegationRegex.hasMatch(nextWords)) {
        return true;
      }
    }

    return false;
  }

  /// Scans [rawQuery] and returns a [HazardFlag] if a physical safety hazard
  /// is detected. Returns `null` if the query is safe for regular repair triage.
  static HazardFlag? scan(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return null;

    // 1. Gas Leak Check (Highest immediate explosion risk)
    final gasMatches = _gasLeakRegex.allMatches(query);
    for (final match in gasMatches) {
      if (!_isMatchNegated(query, match)) {
        return HazardFlag(
          type: HazardType.gasLeak,
          matchedPhrase: match.group(0) ?? 'gas leak',
          safetyInstruction:
              'SAFETY WARNING: Potential gas leak detected! Immediately turn off the regulator knob, do not operate electrical switches or light flames, open all windows, and vacate the area.',
          emergencyTrade: 'Appliance Repair',
          requiresImmediateIsolation: true,
          helplineNumber: '1906',
          helplineLabel: '24x7 LPG Emergency Helpline (1906)',
        );
      }
    }

    // 2. Fire / Sparking / Smoke Check (Short-circuit / wire fire risk)
    final fireMatches = _fireSparkRegex.allMatches(query);
    for (final match in fireMatches) {
      if (!_isMatchNegated(query, match)) {
        return HazardFlag(
          type: HazardType.fireSpark,
          matchedPhrase: match.group(0) ?? 'spark / burning smell',
          safetyInstruction:
              'SAFETY WARNING: Sparking or burning wire hazard detected! Immediately turn off the main circuit breaker (MCB) to prevent electrical fire.',
          emergencyTrade: 'Electrician',
          requiresImmediateIsolation: true,
          helplineNumber: '1912',
          helplineLabel: 'National Electricity Emergency (1912)',
        );
      }
    }

    // 3. Electrical Shock Check (Electrocution risk)
    final shockMatches = _shockRegex.allMatches(query);
    for (final match in shockMatches) {
      if (!_isMatchNegated(query, match)) {
        return HazardFlag(
          type: HazardType.electricalShock,
          matchedPhrase: match.group(0) ?? 'electrical shock',
          safetyInstruction:
              'SAFETY WARNING: Electrical shock / earthing leakage hazard! Do NOT touch the appliance, wet walls, or metallic pipes with bare hands. Turn off power at the main switchboard.',
          emergencyTrade: 'Electrician',
          requiresImmediateIsolation: true,
          helplineNumber: '1912',
          helplineLabel: 'National Electricity Emergency (1912)',
        );
      }
    }

    return null;
  }
}

