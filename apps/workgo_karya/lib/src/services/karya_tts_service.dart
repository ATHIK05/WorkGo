// karya_tts_service.dart
// Multi-lingual voice announcement service for Karya artisans.
// Announces new jobs, job acceptance, service start, completion, and language preference switches.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:workgo_core/workgo_core.dart';

class KaryaTtsService {
  KaryaTtsService._();
  static final KaryaTtsService instance = KaryaTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true; // can be toggled by user
  String _currentLanguageCode = 'en';

  String get currentLanguageCode => _currentLanguageCode;

  // ── Initialise once per app session ─────────────────────────
  Future<void> init({String languageCode = 'en'}) async {
    _currentLanguageCode = languageCode;
    if (_initialized) {
      await updateLanguage(languageCode, announceChange: false);
      return;
    }
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _tts.setVolume(0.95);
        await _tts.setSpeechRate(0.50); // slightly slower for clear trade understanding
        await _tts.setPitch(1.0);
        await _setLanguage(languageCode);
        _initialized = true;
      }
    } catch (e) {
      debugPrint('[KaryaTtsService] Init error: $e');
    }
  }

  /// Dynamically updates the TTS engine language to match the artisan's locale preference.
  Future<void> updateLanguage(String languageCode, {bool announceChange = true}) async {
    _currentLanguageCode = languageCode;
    try {
      await _setLanguage(languageCode);
      if (announceChange) {
        await announceLanguageChanged(languageCode);
      }
    } catch (e) {
      debugPrint('[KaryaTtsService] Update language error: $e');
    }
  }

  Future<void> _setLanguage(String code) async {
    try {
      final lang = switch (code) {
        'ta' => 'ta-IN',
        'hi' => 'hi-IN',
        'te' => 'te-IN',
        'kn' => 'kn-IN',
        'ml' => 'ml-IN',
        'mr' => 'mr-IN',
        'bn' => 'bn-IN',
        'gu' => 'gu-IN',
        'pa' => 'pa-IN',
        'or' => 'or-IN',
        'ur' => 'ur-IN',
        'as' => 'as-IN',
        _ => 'en-IN',
      };
      final available = await _tts.isLanguageAvailable(lang);
      await _tts.setLanguage((available == true) ? lang : 'en-IN');
    } catch (e) {
      debugPrint('[KaryaTtsService] Set language code error: $e');
    }
  }

  void setEnabled(bool value) => _enabled = value;

  // ── Core announce ────────────────────────────────────────────
  Future<void> announce(String text) async {
    if (!_enabled || !_initialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  String _pickLocalized(Map<String, String> map, String fallbackEn) {
    return map[_currentLanguageCode] ?? map['en'] ?? fallbackEn;
  }

  // ── Specific announcement helpers ────────────────────────────

  /// Called when language preference is updated in the app.
  Future<void> announceLanguageChanged(String code) async {
    const phrases = {
      'en': 'Language set to English.',
      'hi': 'भाषा हिंदी पर सेट की गई है।',
      'ta': 'மொழி தமிழுக்கு மாற்றப்பட்டது.',
      'te': 'భాష తెలుగుకు మార్చబడింది.',
      'kn': 'ಭಾಷೆಯನ್ನು ಕನ್ನಡಕ್ಕೆ ಹೊಂದಿಸಲಾಗಿದೆ.',
      'ml': 'ഭാഷ മലയാളത്തിലേക്ക് മാറ്റി.',
      'bn': 'ভাষা বাংলায় পরিবর্তন করা হয়েছে।',
      'mr': 'भाषा मराठीवर सेट केली आहे.',
      'gu': 'ભાષા ગુજરાતી પર સેટ કરવામાં આવી છે.',
      'pa': 'ਭਾਸ਼ਾ ਪੰਜਾਬੀ ਵਿੱਚ ਬਦਲੀ ਗਈ ਹੈ।',
      'or': 'ଭାଷା ଓଡ଼ିଆରେ ପରିବର୍ତ୍ତିତ ହୋଇଛି।',
      'ur': 'زبان اردو پر سیٹ کر دی گئی ہے۔',
      'as': 'ভাষা অসমীয়ালৈ সলনি কৰা হৈছে।',
    };
    final msg = phrases[code] ?? phrases['en']!;
    await announce(msg);
  }

  /// Called when a new job request enters the radar.
  Future<void> announceNewJob(
    dynamic jobOrServiceType, {
    double? amount,
    double? distanceKm,
  }) async {
    final String service;
    final int payout;
    if (jobOrServiceType is Booking) {
      service = jobOrServiceType.serviceType;
      payout = jobOrServiceType.amount.toInt();
    } else {
      service = jobOrServiceType?.toString() ?? 'Service';
      payout = (amount ?? 0).toInt();
    }

    final phrases = {
      'en': 'New $service job. Payout: $payout rupees. Accept now.',
      'hi': 'नया $service कार्य आया है। भुगतान: $payout रुपये। तुरंत स्वीकार करें।',
      'ta': 'புதிய $service பணி வந்துள்ளது. வருமானம்: $payout ரூபாய். உடனே ஏற்கவும்.',
      'te': 'కొత్త $service పని వచ్చింది. రాబడి: $payout రూపాయలు. ఇప్పుడే అంగీకరించండి.',
      'kn': 'ಹೊಸ $service ಕೆಲಸ ಬಂದಿದೆ. ಗಳಿಕೆ: $payout ರೂಪಾಯಿಗಳು. ಈಗಲೇ ಸ್ವೀಕರಿಸಿ.',
      'ml': 'പുതിയ $service ജോലി വന്നിരിക്കുന്നു. പ്രതിഫലം: $payout രൂപ. ഇപ്പോൾ സ്വീകരിക്കുക.',
      'bn': 'নতুন $service কাজ এসেছে। পারিশ্রমিক: $payout টাকা। এখনই গ্রহণ করুন।',
      'mr': 'नवीन $service काम आले आहे. मोबदला: $payout रुपये. त्वरित स्वीकारा.',
      'gu': 'નવું $service કામ આવ્યું છે. ચુકવણી: $payout રૂપિયા. હમણાં જ સ્વીકારો.',
      'pa': 'ਨਵਾਂ $service ਕੰਮ ਆਇਆ ਹੈ। ਕਮਾਈ: $payout ਰੁਪਏ। ਹੁਣੇ ਸਵੀਕਾਰ ਕਰੋ।',
      'or': 'ନୂତନ $service କାର୍ଯ୍ୟ ଆସିଛି। ପାରିଶ୍ରମିକ: $payout ଟଙ୍କା। ଏବେ ସ୍ୱୀକାର କରନ୍ତୁ।',
      'ur': 'نیا $service کام آیا ہے۔ ادائیگی: $payout روپے۔ ابھی قبول کریں۔',
      'as': 'নতুন $service কাম আহিছে। মজুৰি: $payout টকা। এতিয়াই গ্ৰহণ কৰক।',
    };

    final msg = _pickLocalized(phrases, 'New $service job. Payout: $payout rupees. Accept now.');
    await announce(msg);
  }

  /// Called when the artisan goes online.
  Future<void> announceOnline() async {
    const phrases = {
      'en': 'You are now live on radar. Listening for nearby jobs.',
      'hi': 'आप अब रडार पर ऑनलाइन हैं। नए कार्यों की प्रतीक्षा की जा रही है।',
      'ta': 'நீங்கள் இப்போது ரேடாரில் நேரலையில் உள்ளீர்கள். புதிய பணிகளுக்காக காத்திருக்கிறது.',
      'te': 'మీరు ఇప్పుడు రాడార్‌లో లైవ్‌లో ఉన్నారు. సమీప పనుల కోసం వేచి చూస్తోంది.',
      'kn': 'ನೀವು ಈಗ ರೇಡಾರ್‌ನಲ್ಲಿ ಲೈವ್ ಆಗಿದ್ದೀರಿ. ಹತ್ತಿರದ ಕೆಲಸಗಳಿಗಾಗಿ ಕಾಯಲಾಗುತ್ತಿದೆ.',
      'ml': 'നിങ്ങൾ ഇപ്പോൾ റഡാറിൽ തത്സമയമാണ്. അടുത്തുള്ള ജോലികൾക്കായി കാത്തിരിക്കുന്നു.',
      'bn': 'আপনি এখন রাডারে লাইভ আছেন। নতুন কাজের জন্য অপেক্ষা করা হচ্ছে।',
      'mr': 'तुम्ही आता रडारवर ऑनलाइन आहात. नवीन कामांची वाट पाहत आहे.',
      'gu': 'તમે હવે રડાર પર લાઈવ છો. નજીકના કામોની રાહ જોવાઈ રહી છે.',
      'pa': 'ਤੁਸੀਂ ਹੁਣ ਰਾਡਾਰ \'ਤੇ ਲਾਈਵ ਹੋ। ਨੇੜਲੇ ਕੰਮਾਂ ਦੀ ਉਡੀਕ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ।',
      'or': 'ଆପଣ ଏବେ ରାଡାରରେ ଲାଇଭ୍ ଅଛନ୍ତି। ନୂତନ କାର୍ଯ୍ୟ ଅପେକ୍ଷା କରାଯାଉଛି।',
      'ur': 'آپ اب راڈار پر لائیو ہیں۔ قریبی ملازمتوں کا انتظار ہے۔',
      'as': 'আপুনি এতিয়া ৰাডাৰত লাইভ আছে। ওচৰৰ কামৰ বাবে অপেক্ষা কৰা হৈছে।',
    };
    await announce(_pickLocalized(phrases, 'You are now live on radar. Listening for nearby jobs.'));
  }

  /// Called when the artisan goes offline.
  Future<void> announceOffline() async {
    const phrases = {
      'en': 'You are now offline. Great work today.',
      'hi': 'आप अब ऑफलाइन हैं। आज का कार्य उत्तम रहा।',
      'ta': 'நீங்கள் இப்போது ஆஃப்லைனில் உள்ளீர்கள். இன்றைய சிறப்பான பணிக்கு நன்றி.',
      'te': 'మీరు ఇప్పుడు ఆఫ్‌లైన్‌లో ఉన్నారు. నేటి పని అద్భుతం.',
      'kn': 'ನೀವು ಈಗ ಆಫ್‌ಲೈನ್ ಆಗಿದ್ದೀರಿ. ಇಂದಿನ ಉತ್ತಮ ಕೆಲಸಕ್ಕೆ ಧನ್ಯವಾದಗಳು.',
      'ml': 'നിങ്ങൾ ഇപ്പോൾ ഓഫ്‌ലൈനിലാണ്. ഇന്നത്തെ മികച്ച ജോലിക്ക് നന്ദി.',
      'bn': 'আপনি এখন অফলাইনে আছেন। আজকের কাজের জন্য ধন্যবাদ।',
      'mr': 'तुम्ही आता ऑफलाइन आहात. आजचे काम उत्तम झाले.',
      'gu': 'તમે હવે ઑફલાઇન છો. આજના ઉત્તમ કામ બદલ આભાર.',
      'pa': 'ਤੁਸੀਂ ਹੁਣ ਔਫਲਾਈਨ ਹੋ। ਅੱਜ ਦਾ ਕੰਮ ਸ਼ਾਨਦਾਰ ਰਿਹਾ।',
      'or': 'ଆପଣ ଏବେ ଅଫଲାଇନ୍ ଅଛନ୍ତି। ଆଜିର ଉତ୍ତମ କାର୍ଯ୍ୟ ପାଇଁ ଧନ୍ୟବାଦ।',
      'ur': 'آپ اب آف لائن ہیں۔ آج کا کام بہترین رہا۔',
      'as': 'আপুনি এতিয়া অফলাইনত আছে। আজিৰ ভাল কামৰ বাবে ধন্যবাদ।',
    };
    await announce(_pickLocalized(phrases, 'You are now offline. Great work today.'));
  }

  /// Called after job is accepted.
  Future<void> announceJobAccepted(dynamic jobOrServiceType, [String? address]) async {
    final String service;
    if (jobOrServiceType is Booking) {
      service = jobOrServiceType.serviceType;
    } else {
      service = jobOrServiceType?.toString() ?? 'Service';
    }

    final phrases = {
      'en': '$service job accepted. Navigate to customer destination.',
      'hi': '$service कार्य स्वीकार किया गया। ग्राहक के स्थान की ओर नेविगेट करें।',
      'ta': '$service பணி ஏற்றுக்கொள்ளப்பட்டது. வாடிக்கையாளர் இடத்திற்கு வழிகாட்டவும்.',
      'te': '$service పని అంగీకరించబడింది. కస్టమర్ స్థానానికి నావిగేట్ చేయండి.',
      'kn': '$service ಕೆಲಸವನ್ನು ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಗ್ರಾಹಕರ ಸ್ಥಳಕ್ಕೆ ನ್ಯಾವಿಗೇಟ್ ಮಾಡಿ.',
      'ml': '$service ജോലി സ്വീകരിച്ചു. ഉപഭോക്താവിന്റെ സ്ഥലത്തേക്ക് നാവിഗേറ്റ് ചെയ്യുക.',
      'bn': '$service কাজ গ্রহণ করা হয়েছে। গ্রাহকের ঠিকানায় এগিয়ে যান।',
      'mr': '$service काम स्वीकारले आहे. ग्राहकाच्या पत्त्यावर नेव्हिगेट करा.',
      'gu': '$service કામ સ્વીકાર્યું છે. ગ્રાહકના સરનામે નેવિગેટ કરો.',
      'pa': '$service ਕੰਮ ਸਵੀਕਾਰ ਕੀਤਾ ਗਿਆ। ਗਾਹਕ ਦੇ ਸਥਾਨ \'ਤੇ ਨੈਵੀਗੇਟ ਕਰੋ।',
      'or': '$service କାର୍ଯ୍ୟ ସ୍ୱୀକୃତ ହେଲା। ଗ୍ରାହକଙ୍କ ସ୍ଥାନକୁ ଯାଆନ୍ତୁ।',
      'ur': '$service کام قبول کر لیا گیا۔ گاہک کی منزل پر پہنچیں۔',
      'as': '$service কাম গ্ৰহণ কৰা হৈছে। গ্ৰাহকৰ ঠিকনালৈ আগবাঢ়ক।',
    };

    await announce(_pickLocalized(phrases, '$service job accepted. Navigate to customer destination.'));
  }

  /// Called after OTP verified and service starts.
  Future<void> announceServiceStarted() async {
    const phrases = {
      'en': 'Service started. Timer is running. Do your best.',
      'hi': 'सेवा शुरू हो गई है। टाइमर चल रहा है। शुभकामनाएं।',
      'ta': 'பணி தொடங்கியது. நேரம் கணக்கிடப்படுகிறது. சிறப்பான பணியைத் தொடருங்கள்.',
      'te': 'సేవ ప్రారంభమైంది. టైమర్ నడుస్తోంది. ఆల్ ది బెస్ట్.',
      'kn': 'ಸೇವೆ ಪ್ರಾರಂಭವಾಗಿದೆ. ಸಮಯ ಆರಂಭವಾಗಿದೆ. ಶುಭವಾಗಲಿ.',
      'ml': 'സേവനം ആരംഭിച്ചു. സമയം ആരംഭിച്ചിരിക്കുന്നു. ആശംസകൾ.',
      'bn': 'কাজ শুরু হয়েছে। টাইমার চলছে। শুভকামনা।',
      'mr': 'काम सुरू झाले आहे. टायमर सुरू आहे. शुभेच्छा.',
      'gu': 'સેવા શરૂ થઈ ગઈ છે. ટાઈમર ચાલુ છે. શુભેચ્છાઓ.',
      'pa': 'ਸੇਵਾ ਸ਼ੁਰੂ ਹੋ ਗਈ ਹੈ। ਟਾਈਮਰ ਚੱਲ ਰਿਹਾ ਹੈ। ਸ਼ੁਭਕਾਮਨਾਵਾਂ।',
      'or': 'ସେବା ଆରମ୍ଭ ହୋଇଛି। ଟାଇମର୍ ଚାଲୁଛି। ଶୁଭକାମନା।',
      'ur': 'کام شروع ہو گیا ہے۔ ٹائمر چل رہا ہے۔ نیک تمنائیں!',
      'as': 'সেৱা আৰম্ভ হৈছে। টাইমাৰ চলি আছে। শুভকামনা।',
    };
    await announce(_pickLocalized(phrases, 'Service started. Timer is running. Do your best.'));
  }

  /// Called after job is completed.
  Future<void> announceJobComplete(double amount) async {
    final amt = amount.toInt();
    final phrases = {
      'en': 'Mission complete! $amt rupees credited to your account.',
      'hi': 'कार्य संपन्न हुआ! $amt रुपये आपके खाते में जमा कर दिए गए हैं।',
      'ta': 'பணி வெற்றிகரமாக முடிந்தது! $amt ரூபாய் உங்கள் கணக்கில் வரவு வைக்கப்பட்டது.',
      'te': 'పని పూర్తయింది! $amt రూపాయలు మీ ఖాతాలో జమ చేయబడ్డాయి.',
      'kn': 'ಕೆಲಸ ಪೂರ್ಣಗೊಂಡಿದೆ! $amt ರೂಪಾಯಿಗಳು ನಿಮ್ಮ ಖಾತೆಗೆ ಜಮೆಯಾಗಿದೆ.',
      'ml': 'ജോലി വിജയകരമായി പൂർത്തിയായി! $amt രൂപ നിങ്ങളുടെ അക്കൗണ്ടിലേക്ക് ചേർത്തു.',
      'bn': 'কাজ সফলভাবে সমাপ্ত হয়েছে! $amt টাকা আপনার অ্যাকাউন্টে জমা হয়েছে।',
      'mr': 'काम पूर्ण झाले! $amt रुपये तुमच्या खात्यात जमा झाले आहेत.',
      'gu': 'કામ સફળતાપૂર્વક પૂરું થયું! $amt રૂપિયા તમારા ખાતામાં જમા થઈ ગયા છે.',
      'pa': 'ਕੰਮ ਪੂਰਾ ਹੋ ਗਿਆ! $amt ਰੁਪਏ ਤੁਹਾਡੇ ਖਾਤੇ ਵਿੱਚ ਜਮ੍ਹਾ ਹੋ ਗਏ ਹਨ।',
      'or': 'କାର୍ଯ୍ୟ ସମ୍ପୂର୍ଣ୍ଣ ହେଲା! $amt ଟଙ୍କା ଆପଣଙ୍କ ଖାତାରେ ଜମା ହୋଇଛି।',
      'ur': 'مشن مکمل ہوا! $amt روپے آپ کے اکاؤنٹ میں جمع کر دیے گئے ہیں۔',
      'as': 'কাম সমাপ্ত হ\'ল! $amt টকা আপোনাৰ একাউণ্টত জমা কৰা হৈছে।',
    };
    await announce(_pickLocalized(phrases, 'Mission complete! $amt rupees credited to your account.'));
  }

  /// Called when SOS is activated.
  Future<void> announceSos() async {
    const phrases = {
      'en': 'Emergency alert sent. Help is on the way. Stay safe.',
      'hi': 'आपातकालीन चेतावनी प्रसारित की गई। सहायता आ रही है। सुरक्षित रहें।',
      'ta': 'அவசர எச்சரிக்கை அனுப்பப்பட்டது. உதவி வந்து கொண்டிருக்கிறது. பாதுகாப்பாக இருங்கள்.',
      'te': 'అత్యవసర హెచ్చరిక పంపబడింది. సహాయం వస్తోంది. సురక్షితంగా ఉండండి.',
      'kn': 'ತುರ್ತು ಎಚ್ಚರಿಕೆ ಕಳುಹಿಸಲಾಗಿದೆ. ನೆರವು ಬರುತ್ತಿದೆ. ಸುರಕ್ಷಿತವಾಗಿರಿ.',
      'ml': 'അടിയന്തര മുന്നറിയിപ്പ് അയച്ചു. സഹായം എത്തിക്കൊണ്ടിരിക്കുന്നു. സുരക്ഷിതമായിരിക്കുക.',
      'bn': 'জরুরি সতর্কতা পাঠানো হয়েছে। সাহায্য আসছে। নিরাপদে থাকুন।',
      'mr': 'तातडीचा इशारा पाठवला आहे. मदत येत आहे. सुरक्षित राहा.',
      'gu': 'ઇમરજન્સી એલર્ટ મોકલવામાં આવ્યું છે. મદદ આવી રહી છે. સુરક્ષિત રહો.',
      'pa': 'ਐਮਰਜੈਂਸੀ ਅਲਰਟ ਭੇਜਿਆ ਗਿਆ ਹੈ। ਮਦਦ ਆ ਰਹੀ ਹੈ। ਸੁਰੱਖਿਅਤ ਰਹੋ।',
      'or': 'ଜରୁରୀକାଳୀନ ସତର୍କତା ପ୍ରେରିତ ହୋଇଛି। ସାହାଯ୍ୟ ଆସୁଛି। ସୁରକ୍ଷିତ ରୁହନ୍ତୁ।',
      'ur': 'ایمرجنسی الرٹ بھیجا گیا ہے۔ مدد آ رہی ہے۔ محفوظ رہیں۔',
      'as': 'জৰুৰীকালীন সতৰ্কতা প্ৰেৰণ কৰা হৈছে। সহায় আহি আছে। সুৰক্ষিত থাকক।',
    };
    await announce(_pickLocalized(phrases, 'Emergency alert sent. Help is on the way. Stay safe.'));
  }

  /// Called when a peer artisan activates SOS nearby.
  Future<void> announcePeerSos(String name) async {
    const phrases = {
      'en': 'Emergency alert: Fellow artisan requested assistance nearby.',
      'hi': 'आपातकालीन चेतावनी: नजदीकी साथी कारीगर ने सहायता का अनुरोध किया है।',
      'ta': 'அவசர எச்சரிக்கை: அருகிலுள்ள சக பணியாளர் உதவி கோரியுள்ளார்.',
      'te': 'అత్యవసర హెచ్చరిక: సమీప సహోద్యోగి సహాయం కోరారు.',
      'kn': 'ತುರ್ತು ಎಚ್ಚರಿಕೆ: ಹತ್ತಿರದ ಸಹೋದ್ಯೋಗಿ ಸಹಾಯ ಕೋರಿದ್ದಾರೆ.',
      'ml': 'അടിയന്തര മുന്നറിയിപ്പ്: അടുത്തുള്ള സഹപ്രവർത്തകൻ സഹായം അഭ്യർത്ഥിച്ചു.',
      'bn': 'জরুরি সতর্কতা: নিকটবর্তী সহকর্মী কারিগর সাহায্য চেয়েছেন।',
      'mr': 'तातडीचा इशारा: जवळच्या सहकारी कारागिराने मदत मागितली आहे.',
      'gu': 'ઇમરજન્સી એલર્ટ: નજીકના સાથી કારીગરે મદદની વિનંતી કરી છે.',
      'pa': 'ਐਮਰਜੈਂਸੀ ਅਲਰਟ: ਨੇੜਲੇ ਸਾਥੀ ਕਾਰੀਗਰ ਨੇ ਮਦਦ ਦੀ ਬੇਨਤੀ ਕੀਤੀ ਹੈ।',
      'or': 'ଜରୁରୀକାଳୀନ ସତର୍କତା: ନିକଟସ୍ଥ ସହଯୋଗୀ କାରିଗର ସାହାଯ୍ୟ ମାଗିଛନ୍ତି।',
      'ur': 'ایمرجنسی الرٹ: قریبی ساتھی کاریگر نے مدد کی درخواست کی ہے۔',
      'as': 'জৰুৰীকালীন সতৰ্কতা: ওচৰৰ সহযোগী কাৰিকৰে সহায় বিচাৰিছে।',
    };
    await announce(_pickLocalized(phrases, 'Emergency alert: Fellow artisan requested assistance nearby.'));
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
