// karya_tts_service.dart
// Multilingual voice announcement service for Karya artisans.
// Announces new jobs, job acceptance, service start, and completion in English, Hindi, or Tamil.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:workgo_core/workgo_core.dart';
import 'ml_translation_service.dart';

class KaryaTtsService {
  KaryaTtsService._();
  static final KaryaTtsService instance = KaryaTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true; // can be toggled by user
  String _currentLocale = 'en';

  String get currentLocale => _currentLocale;

  // ── Initialise once per app session ─────────────────────────
  Future<void> init({String languageCode = 'en'}) async {
    _currentLocale = languageCode;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _tts.setVolume(0.9);
        await _tts.setSpeechRate(0.50); // clear comfortable pace
        await _tts.setPitch(1.0);
        await _setLanguage(languageCode);
        _initialized = true;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    _currentLocale = code;
    await _setLanguage(code);
  }

  Future<void> _setLanguage(String code) async {
    try {
      final lang = switch (code) {
        'ta' => 'ta-IN',
        'hi' => 'hi-IN',
        _ => 'en-IN',
      };
      final available = await _tts.isLanguageAvailable(lang);
      await _tts.setLanguage((available == true) ? lang : 'en-IN');
    } catch (_) {}
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

  // ── Specific announcement helpers with Tamil, Hindi & English ────────────────────────────

  /// Called when a new job request enters the radar.
  Future<void> announceNewJob(
    dynamic jobOrServiceType, {
    double? amount,
    double? distanceKm,
  }) async {
    final pay = (jobOrServiceType is Booking ? jobOrServiceType.amount : amount ?? 0).toStringAsFixed(0);
    final rawTrade = (jobOrServiceType is Booking ? jobOrServiceType.serviceType : jobOrServiceType?.toString() ?? 'Service');
    final trade = rawTrade.toLocalizedTrade();

    String rawAddr = '';
    if (jobOrServiceType is Booking && jobOrServiceType.customerAddressText?.isNotEmpty == true) {
      rawAddr = jobOrServiceType.customerAddressText!;
    }
    final localizedAddr = rawAddr.isNotEmpty
        ? MlTranslationService.instance.translateAddressSync(rawAddr, _currentLocale)
        : '';

    switch (_currentLocale) {
      case 'hi':
        final loc = localizedAddr.isNotEmpty ? '$localizedAddr में ' : '';
        await announce('$loc नया $trade कार्य। भुगतान: $pay रुपये। अभी स्वीकार करें।');
        break;
      case 'ta':
        final loc = localizedAddr.isNotEmpty ? '$localizedAddr-ல் ' : '';
        await announce('$loc புதிய $trade பணி. கட்டணம்: $pay ரூபாய். இப்போதே ஏற்கவும்.');
        break;
      default:
        final loc = rawAddr.isNotEmpty ? 'at $rawAddr. ' : 'nearby. ';
        await announce('New $trade job $loc Payout: $pay rupees. Accept now.');
        break;
    }
  }

  /// Called when the artisan goes online.
  Future<void> announceOnline() async {
    switch (_currentLocale) {
      case 'hi':
        await announce('आप अब रडार पर ऑनलाइन हैं। नए कार्यों की प्रतीक्षा की जा रही है।');
        break;
      case 'ta':
        await announce('நீங்கள் இப்போது ரேடாரில் நேரலையில் உள்ளீர்கள். அருகிலுள்ள பணிகளைத் தேடுகிறது.');
        break;
      default:
        await announce('You are now live on radar. Listening for nearby jobs.');
        break;
    }
  }

  /// Called when the artisan goes offline.
  Future<void> announceOffline() async {
    switch (_currentLocale) {
      case 'hi':
        await announce('आप अब ऑफलाइन हैं। आज का कार्य बहुत बढ़िया रहा।');
        break;
      case 'ta':
        await announce('நீங்கள் இப்போது ஆஃப்லைனில் உள்ளீர்கள். இன்றைய பணி அருமை.');
        break;
      default:
        await announce('You are now offline. Great work today.');
        break;
    }
  }

  /// Called after job is accepted.
  Future<void> announceJobAccepted(dynamic jobOrServiceType, [String? address]) async {
    final rawTrade = (jobOrServiceType is Booking ? jobOrServiceType.serviceType : jobOrServiceType?.toString() ?? 'Service');
    final trade = rawTrade.toLocalizedTrade();
    final rawAddr = (jobOrServiceType is Booking ? jobOrServiceType.customerAddressText : address) ?? '';
    final localizedAddr = rawAddr.isNotEmpty
        ? MlTranslationService.instance.translateAddressSync(rawAddr, _currentLocale)
        : '';

    switch (_currentLocale) {
      case 'hi':
        final nav = localizedAddr.isNotEmpty ? '$localizedAddr पर जाएं।' : 'कार्य का विवरण देखें।';
        await announce('$trade कार्य स्वीकार किया गया। $nav');
        break;
      case 'ta':
        final nav = localizedAddr.isNotEmpty ? '$localizedAddr முகவரிக்குச் செல்லவும்.' : 'பணி விவரங்களைச் சரிபார்க்கவும்.';
        await announce('$trade பணி ஏற்றுக்கொள்ளப்பட்டது. $nav');
        break;
      default:
        final nav = rawAddr.isNotEmpty ? 'Navigate to $rawAddr.' : 'Check the job details.';
        await announce('$trade job accepted. $nav');
        break;
    }
  }

  /// Called after OTP verified and service starts.
  Future<void> announceServiceStarted() async {
    switch (_currentLocale) {
      case 'hi':
        await announce('सेवा शुरू हो गई है। टाइमर चालू है। ध्यान से काम करें।');
        break;
      case 'ta':
        await announce('பணி தொடங்கியது. டைமர் இயங்குகிறது. சிறப்பாகச் செய்யுங்கள்.');
        break;
      default:
        await announce('Service started. Timer is running. Do your best.');
        break;
    }
  }

  /// Called after job is completed.
  Future<void> announceJobComplete(double amount) async {
    final pay = amount.toStringAsFixed(0);
    switch (_currentLocale) {
      case 'hi':
        await announce('कार्य पूरा हुआ! $pay रुपये आपके खाते में जमा कर दिए गए हैं।');
        break;
      case 'ta':
        await announce('பணி நிறைவடைந்தது! $pay ரூபாய் உங்கள் கணக்கில் வரவு வைக்கப்பட்டது.');
        break;
      default:
        await announce('Mission complete! $pay rupees credited to your account.');
        break;
    }
  }

  /// Called when SOS is activated.
  Future<void> announceSos() async {
    switch (_currentLocale) {
      case 'hi':
        await announce('आपातकालीन सूचना भेज दी गई है। मदद रास्ते में है। सुरक्षित रहें।');
        break;
      case 'ta':
        await announce('அவசர எச்சரிக்கை அனுப்பப்பட்டது. உதவி வருகிறது. பாதுகாப்பாக இருங்கள்.');
        break;
      default:
        await announce('Emergency alert sent. Help is on the way. Stay safe.');
        break;
    }
  }

  /// Called when a peer artisan activates SOS nearby.
  Future<void> announcePeerSos(String name) async {
    switch (_currentLocale) {
      case 'hi':
        await announce('आपातकालीन चेतावनी: साथी कारीगर $name ने पास में मदद मांगी है।');
        break;
      case 'ta':
        await announce('அவசர எச்சரிக்கை: சக கைவினைஞர் $name அருகில் உதவி கோரியுள்ளார்.');
        break;
      default:
        await announce('Emergency alert: Fellow artisan $name requested assistance nearby.');
        break;
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
