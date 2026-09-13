import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:workgo_core/workgo_core.dart';

/// On-device and resilient multi-tier translation service for dynamic Firebase
/// content, AI-generated diagnoses, worker skills, and customer locations.
///
/// Multi-Tier Pipeline:
///   1. Synchronous Session Cache (0ms instant return)
///   2. Smart Regional & Diagnostic Dictionary (0ms instant address & triage translation)
///   3. On-Device Google ML Kit Translator (offline, zero-latency inference)
///   4. Resilient Cloud Translation Fallback (when on-device model is pending download or fails)
/// Convenient type alias for casing tolerance
typedef MLTranslationService = MlTranslationService;

class MlTranslationService {
  MlTranslationService._();
  static final MlTranslationService instance = MlTranslationService._();

  final _modelManager = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators = {};
  final Map<String, String> _cache = {};

  static const _supportedTargets = {
    'hi': TranslateLanguage.hindi,
    'ta': TranslateLanguage.tamil,
    'te': TranslateLanguage.telugu,
    'kn': TranslateLanguage.kannada,
    'mr': TranslateLanguage.marathi,
    'bn': TranslateLanguage.bengali,
    'gu': TranslateLanguage.gujarati,
    'ur': TranslateLanguage.urdu,
  };

  // ──────────────────────────────────────────────────────────────────────────
  //  SMART REGIONAL & DIAGNOSTIC DICTIONARY
  // ──────────────────────────────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _phraseDictionary = {
    'hi': {
      // Address & Location terms
      'home': 'घर',
      'office': 'कार्यालय',
      'work': 'कार्यस्थल',
      'near': 'के पास',
      'near to': 'के पास',
      'nearby': 'आसपास',
      'opposite': 'के सामने',
      'opp': 'के सामने',
      'behind': 'के पीछे',
      'road': 'मार्ग',
      'rd': 'मार्ग',
      'street': 'गली',
      'st': 'गली',
      'main road': 'मुख्य मार्ग',
      'cross': 'क्रॉस',
      'nagar': 'नगर',
      'colony': 'कॉलोनी',
      'apartment': 'अपार्टमेंट',
      'apt': 'अपार्टमेंट',
      'layout': 'लेआउट',
      'sector': 'सेक्टर',
      'block': 'ब्लॉक',
      'floor': 'मंजिल',
      'tamil nadu': 'तमिलनाडु',
      'tamilnadu': 'तमिलनाडु',
      'erode': 'इरोड',
      'chennai': 'चेन्नई',
      'coimbatore': 'कोयंबटूर',
      'salem': 'सेलम',
      'madurai': 'मदुरै',
      'tirupur': 'तिरुपुर',
      'bangalore': 'बेंगलुरु',
      'bengaluru': 'बेंगलुरु',
      'mumbai': 'मुंबई',
      'delhi': 'दिल्ली',
      'hyderabad': 'हैदराबाद',
      'pune': 'पुणे',
      'kolkata': 'कोलकाता',
      'kerala': 'केरल',
      'karnataka': 'कर्नाटक',
      'maharashtra': 'महाराष्ट्र',
      'thanjavur': 'तंजावुर',
      'trichy': 'त्रिची',
      'tiruchirappalli': 'तिरुचिरापल्ली',
      'vellore': 'वेल्लोर',
      'hosur': 'होसुर',
      'e main st': 'ईस्ट मेन स्ट्रीट',
      'main st': 'मेन स्ट्रीट',
      'east': 'पूर्व',
      'west': 'पश्चिम',
      'north': 'उत्तर',
      'south': 'दक्षिण',
      'current live location': 'वर्तमान लाइव स्थान',
      'direct service dispatch to verified customer': 'सत्यापित ग्राहक को सीधी सेवा डिस्पैच',

      // AI Symptom Triage common terms
      'ceiling fan / home appliance': 'सीलिंग फैन / घरेलू उपकरण',
      'ceiling fan': 'सीलिंग फैन',
      'fan': 'पंखा',
      'home appliance': 'घरेलू उपकरण',
      'refrigerator / fridge': 'रेफ्रिजरेटर / फ्रिज',
      'fridge': 'फ्रिज',
      'mixer grinder / home appliance': 'मिक्सर ग्राइंडर / घरेलू उपकरण',
      'mixer grinder': 'मिक्सर ग्राइंडर',
      'mixie': 'मिक्सर',
      'microwave oven': 'माइक्रोवेव ओवन',
      'drainage & sewerage': 'जल निकासी और सीवरेज',
      'doors, locks & woodwork': 'दरवाजे, ताले और लकड़ी का काम',
      'painting & waterproofing': 'पेंटिंग और वॉटरप्रूफिंग',
      'deep cleaning & descaling': 'डीप क्लीनिंग और डीस्केलिंग',
      'metal fabrication & welding': 'धातु निर्माण और वेल्डिंग',
      'masonry & tile works': 'चिनाई और टाइल का काम',
      'masonry': 'चिनाई (राजमिस्त्री)',
      'kitchen gas stove & hob': 'रसोई गैस चूल्हा और हॉब',
      'out of scope': 'सेवा कार्यक्षेत्र से बाहर',
      'non-household service': 'गैर-घरेलू सेवा',
      'electrical fixture': 'विद्युत उपकरण',
      'electrical distribution or fixture failure. technician will verify voltage and continuity.':
          'विद्युत वितरण या उपकरण की खराबी। तकनीशियन वोल्टेज और निरंतरता का सत्यापन करेगा।',
      'wiring short circuit': 'वायरिंग शॉर्ट सर्किट',
      'loose connection': 'ढीला कनेक्शन',
      'switch/fuse malfunction': 'स्विच/फ्यूज खराबी',
      'water motor humming sound or ac blowing room air':
          'पानी की मोटर से गुनगुनाहट या एसी से सामान्य हवा आना',
      'water dripping from bottom right corner, unusual humming, or trips breaker':
          'नीचे दाएं कोने से पानी टपकना, असामान्य आवाज, या ब्रेकर ट्रिप होना',
      'is the circuit breaker tripping?': 'क्या सर्किट ब्रेकर ट्रिप हो रहा है?',
      'is there a burning smell or sparking?': 'क्या जलने की गंध या चिंगारी आ रही है?',
      'does the problem happen continuously or intermittently?':
          'क्या समस्या लगातार होती है या रुक-रुक कर?',
      'yes, breaker trips': 'हाँ, ब्रेकर ट्रिप होता है',
      'no tripping': 'ट्रिपिंग नहीं होती',
      'only under heavy load': 'केवल भारी लोड पर',
      'yes, burning smell': 'हाँ, जलने की गंध आ रही है',
      'continuous': 'लगातार',
      'intermittent': 'रुक-रुक कर',

      // Roles
      'artisan': 'कारीगर',
      'coop artisan': 'सहकारी कारीगर',
      'artisan partner': 'कारीगर पार्टनर',
    },
    'ta': {
      // Address & Location terms
      'home': 'வீடு',
      'office': 'அலுவலகம்',
      'work': 'வேலை இடம்',
      'near': 'அருகில்',
      'near to': 'அருகில்',
      'nearby': 'அருகில்',
      'opposite': 'எதிரில்',
      'opp': 'எதிரில்',
      'behind': 'பின்புறம்',
      'road': 'சாலை',
      'rd': 'சாலை',
      'street': 'தெரு',
      'st': 'தெரு',
      'main road': 'பிரதான சாலை',
      'cross': 'குறுக்குத் தெரு',
      'nagar': 'நகர்',
      'colony': 'காலனி',
      'apartment': 'அபார்ட்மெண்ட்',
      'apt': 'அபார்ட்மெண்ட்',
      'layout': 'லேஅவுட்',
      'sector': 'செக்டார்',
      'block': 'பிளாக்',
      'floor': 'தளம்',
      'tamil nadu': 'தமிழ்நாடு',
      'tamilnadu': 'தமிழ்நாடு',
      'erode': 'ஈரோடு',
      'chennai': 'சென்னை',
      'coimbatore': 'கோயம்புத்தூர்',
      'salem': 'சேலம்',
      'madurai': 'மதுரை',
      'tirupur': 'திருப்பூர்',
      'bangalore': 'பெங்களூரு',
      'bengaluru': 'பெங்களூரு',
      'mumbai': 'மும்பை',
      'delhi': 'டெல்லி',
      'hyderabad': 'ஹைதராபாத்',
      'pune': 'புனே',
      'kolkata': 'கொல்கத்தா',
      'kerala': 'கேரளா',
      'karnataka': 'கர்நாடகா',
      'maharashtra': 'மகாராஷ்டிரா',
      'thanjavur': 'தஞ்சாவூர்',
      'trichy': 'திருச்சி',
      'tiruchirappalli': 'திருச்சிராப்பள்ளி',
      'vellore': 'வேலூர்',
      'hosur': 'ஓசூர்',
      'e main st': 'கிழக்கு பிரதான சாலை',
      'main st': 'பிரதான சாலை',
      'east': 'கிழக்கு',
      'west': 'மேற்கு',
      'north': 'வடக்கு',
      'south': 'தெற்கு',
      'current live location': 'தற்போதைய நேரடி இருப்பிடம்',
      'direct service dispatch to verified customer': 'சரிபார்க்கப்பட்ட வாடிக்கையாளருக்கு நேரடி சேவை அனுப்புதல்',

      // AI Symptom Triage common terms
      'ceiling fan / home appliance': 'சீலிங் ஃபேன் / வீட்டு உபகரணம்',
      'ceiling fan': 'சீலிங் ஃபேன்',
      'fan': 'ஃபேன்',
      'home appliance': 'வீட்டு உபகரணம்',
      'refrigerator / fridge': 'குளிர்சாதனப் பெட்டி / ஃப்ரிட்ஜ்',
      'fridge': 'ஃப்ரிட்ஜ்',
      'mixer grinder / home appliance': 'மிக்ஸி கிரைண்டர் / வீட்டு உபகரணம்',
      'mixer grinder': 'மிக்ஸி கிரைண்டர்',
      'mixie': 'மிக்ஸி',
      'microwave oven': 'மைக்ரோவேவ் ஓவன்',
      'drainage & sewerage': 'வடிகால் மற்றும் கழிவுநீர் பழுது',
      'doors, locks & woodwork': 'கதவுகள், பூட்டுகள் மற்றும் மரவேலை',
      'painting & waterproofing': 'பெயிண்டிங் மற்றும் நீர்ப்புகாப்பு',
      'deep cleaning & descaling': 'ஆழ்ந்த தூய்மைப்பணி மற்றும் கறை நீக்கம்',
      'metal fabrication & welding': 'உலோக தயாரிப்பு மற்றும் வெல்டிங்',
      'masonry & tile works': 'கட்டிட வேலை மற்றும் டைல்ஸ் பழுது',
      'masonry': 'கொத்தனார் வேலை',
      'kitchen gas stove & hob': 'சமையலறை கேஸ் அடுப்பு பழுது',
      'out of scope': 'சேவை வரம்பிற்கு வெளியே',
      'non-household service': 'வீட்டு உபயோகமல்லாத சேவை',
      'electrical fixture': 'மின் சாதனங்கள்',
      'electrical distribution or fixture failure. technician will verify voltage and continuity.':
          'மின் விநியோகம் அல்லது சாதனம் பழுது. தொழில்நுட்ப வல்லுநர் மின்னழுத்தம் மற்றும் தொடர்ச்சியை சரிபார்ப்பார்.',
      'wiring short circuit': 'வயரிங் ஷார்ட் சர்க்யூட்',
      'loose connection': 'தளர்வான இணைப்பு',
      'switch/fuse malfunction': 'சுவிட்ச்/ஃபியூஸ் கோளாறு',
      'water motor humming sound or ac blowing room air':
          'வாட்டர் மோட்டார் இரைச்சல் அல்லது ஏசி அறை வெப்பக் காற்று வீசுதல்',
      'water dripping from bottom right corner, unusual humming, or trips breaker':
          'கீழ் வலது மூலையில் இருந்து தண்ணீர் சொட்டுவது, விசித்திரமான சத்தம் அல்லது பிரேக்கர் டிரிப் ஆவது',
      'is the circuit breaker tripping?': 'சர்க்யூட் பிரேக்கர் டிரிப் ஆகிறதா?',
      'is there a burning smell or sparking?': 'எரியும் வாசனை அல்லது தீப்பொறி வருகிறதா?',
      'does the problem happen continuously or intermittently?':
          'பிரச்சனை தொடர்ச்சியாக உள்ளதா அல்லது விட்டு விட்டு வருகிறதா?',
      'yes, breaker trips': 'ஆம், பிரேக்கர் டிரிப் ஆகிறது',
      'no tripping': 'டிரிப்பிங் இல்லை',
      'only under heavy load': 'அதிக சுமைகளின் போது மட்டுமே',
      'yes, burning smell': 'ஆம், எரியும் வாசனை உள்ளது',
      'continuous': 'தொடர்ச்சியானது',
      'intermittent': 'விட்டு விட்டு',

      // Roles
      'artisan': 'கைவினைஞர்',
      'coop artisan': 'கூட்டுறவு கைவினைஞர்',
      'artisan partner': 'கைவினைஞர் பங்குதாரர்',
    },
  };

  // ──────────────────────────────────────────────────────────────────────────
  //  CORE TRANSLATION METHODS
  // ──────────────────────────────────────────────────────────────────────────

  String _extractLocale(dynamic contextOrLocale) {
    if (contextOrLocale is BuildContext) {
      return contextOrLocale.locale.languageCode;
    } else if (contextOrLocale is Locale) {
      return contextOrLocale.languageCode;
    } else if (contextOrLocale is String && contextOrLocale.isNotEmpty) {
      return contextOrLocale;
    }
    return 'en';
  }

  /// Instant synchronous translation lookup (Cache -> Catalog Trade -> Dictionary -> Fallback to original text).
  /// Perfect for initial build frame to prevent UI flicker.
  String translateSync(String text, dynamic contextOrLocale, {bool isAddress = false}) {
    if (text.trim().isEmpty) return text;
    final locale = _extractLocale(contextOrLocale);
    if (locale == 'en') return text;

    // If text already contains target language script, it is already localized
    if (locale == 'ta' && RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return text;
    if (locale == 'hi' && RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;
    if (locale == 'te' && RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return text;
    if (locale == 'kn' && RegExp(r'[\u0C80-\u0CFF]').hasMatch(text)) return text;
    if (locale == 'ml' && RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) return text;
    if (locale == 'bn' && RegExp(r'[\u0980-\u09FF]').hasMatch(text)) return text;
    if (locale == 'gu' && RegExp(r'[\u0A80-\u0AFF]').hasMatch(text)) return text;
    if (locale == 'mr' && RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;

    final cacheKey = '$locale:$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // 0. Instant trade catalog check
    if (!isAddress) {
      final trade = text.toLocalizedTrade();
      if (trade != text) {
        _cache[cacheKey] = trade;
        return trade;
      }
    }

    if (isAddress) {
      return translateAddressSync(text, locale);
    }

    final dict = _phraseDictionary[locale];
    if (dict != null) {
      final normalized = text.trim().toLowerCase();
      if (dict.containsKey(normalized)) {
        return dict[normalized]!;
      }
    }

    return text;
  }

  /// Translates address strings synchronously using dictionary tokens.
  String translateAddressSync(String address, dynamic contextOrLocale) {
    if (address.trim().isEmpty) return address;
    final locale = _extractLocale(contextOrLocale);
    if (locale == 'en') return address;

    final dict = _phraseDictionary[locale];
    if (dict == null) return address;

    String result = address;
    // Replace multi-word and single-word landmark tokens
    dict.forEach((key, val) {
      final regex = RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false);
      result = result.replaceAllMapped(regex, (m) => val);
    });
    return result;
  }

  /// Translate [text] from English into the target locale.
  /// Uses multi-tier strategy: Cache -> Catalog Trade -> Smart Dict -> On-Device ML Kit -> Cloud Fallback.
  Future<String> translate(
    String text,
    dynamic contextOrLocale, {
    bool isAddress = false,
  }) async {
    if (text.trim().isEmpty) return text;
    final locale = _extractLocale(contextOrLocale);
    if (locale == 'en') return text;

    // If text already contains target language script, it is already localized
    if (locale == 'ta' && RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return text;
    if (locale == 'hi' && RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;
    if (locale == 'te' && RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return text;
    if (locale == 'kn' && RegExp(r'[\u0C80-\u0CFF]').hasMatch(text)) return text;
    if (locale == 'ml' && RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) return text;
    if (locale == 'bn' && RegExp(r'[\u0980-\u09FF]').hasMatch(text)) return text;
    if (locale == 'gu' && RegExp(r'[\u0A80-\u0AFF]').hasMatch(text)) return text;
    if (locale == 'mr' && RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;

    final cacheKey = '$locale:$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // 0. Instant trade catalog check
    if (!isAddress) {
      final trade = text.toLocalizedTrade();
      if (trade != text) {
        _cache[cacheKey] = trade;
        return trade;
      }
    }

    // 1. Check Smart Dictionary
    final dict = _phraseDictionary[locale];
    if (dict != null) {
      final normalized = text.trim().toLowerCase();
      if (dict.containsKey(normalized)) {
        final translated = dict[normalized]!;
        _cache[cacheKey] = translated;
        return translated;
      }
    }

    // If it's an address, try token-based translation first
    String candidateText = text;
    if (isAddress) {
      candidateText = translateAddressSync(text, locale);
      if (candidateText != text) {
        _cache[cacheKey] = candidateText;
      }
    }

    // 2. Try On-Device Google ML Kit (for supported languages)
    final targetLang = _supportedTargets[locale];
    if (targetLang != null) {
      try {
        final modelReady = await _ensureModel(targetLang);
        if (modelReady) {
          final translator = _translators[locale] ??= OnDeviceTranslator(
            sourceLanguage: TranslateLanguage.english,
            targetLanguage: targetLang,
          );
          final translated = await translator.translateText(candidateText);
          if (translated.trim().isNotEmpty && translated != candidateText) {
            _cache[cacheKey] = translated;
            return translated;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Lightweight Cloud Google Translate API
    try {
      final cloudResult = await _fetchCloudTranslation(candidateText, locale);
      if (cloudResult != null && cloudResult.isNotEmpty) {
        _cache[cacheKey] = cloudResult;
        return cloudResult;
      }
    } catch (_) {}

    // 4. Return candidate from dictionary or original text
    return candidateText;
  }

  /// Specialized address translation combining dictionary and async translation.
  Future<String> translateAddress(String address, dynamic contextOrLocale) async {
    return translate(address, contextOrLocale, isAddress: true);
  }

  Future<bool> _ensureModel(TranslateLanguage lang) async {
    try {
      final code = lang.bcpCode;
      final ready = await _modelManager.isModelDownloaded(code);
      if (ready) return true;
      return await _modelManager.downloadModel(
        code,
        isWifiRequired: false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Cloud Google Translate public endpoint fallback (zero dependency via dart:io)
  Future<String?> _fetchCloudTranslation(String text, String targetLang) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final url = Uri.parse(
        'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=$targetLang&q=${Uri.encodeComponent(text)}',
      );
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(responseBody);
        if (decoded is List && decoded.isNotEmpty && decoded[0] != null) {
          final res = decoded[0].toString().trim();
          if (res.isNotEmpty) return res;
        } else if (decoded is String && decoded.trim().isNotEmpty) {
          return decoded.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Pre-warm models for the given locale.
  Future<void> prewarmModel(String languageCode) async {
    final targetLang = _supportedTargets[languageCode];
    if (targetLang == null) return;
    await _ensureModel(targetLang);
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
    _cache.clear();
  }
}
