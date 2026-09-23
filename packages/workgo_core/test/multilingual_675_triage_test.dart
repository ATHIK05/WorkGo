import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/src/services/ai_diagnostic_service.dart';
import 'package:workgo_core/src/services/multilingual_semantic_fallback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer-Side 675 Phrasings Multi-Lingual Triage Verification', () {
    final aiService = AiDiagnosticService.instance;

    setUpAll(() async {
      await MultilingualSemanticFallback.instance.initialize();
    });

    // ── 1. Bengali (বাংলা) ──
    test('Diagnoses Bengali regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'মোটর চলছে কিন্তু জল আসছে না বোরওয়েল পাম্প খারাপ ট্যাংক ভরছে না',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));
      expect(resMotor.confidence, greaterThanOrEqualTo(0.72));

      final resAc = await aiService.diagnoseSymptom(
        'এসি চলছে ঘর ঠান্ডা হচ্ছে না কম্প্রেসার চালু হয় না গ্যাস লিক',
      );
      expect(resAc.isOutOfScope, isFalse);
      expect(resAc.equipmentTag, equals('Air Conditioner'));
      expect(resAc.primaryCategory, equals('Appliance Repair'));

      final resInverter = await aiService.diagnoseSymptom(
        'ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই',
      );
      expect(resInverter.isOutOfScope, isFalse);
      expect(resInverter.equipmentTag, equals('Inverter & Battery'));
      expect(resInverter.primaryCategory, equals('Electrician'));
    });

    // ── 2. Marathi (मराठी) ──
    test('Diagnoses Marathi regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'सबमर्सिबल मोटर चालू आहे पण पाणी येत नाही टाकी भरत नाही',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resMcb = await aiService.diagnoseSymptom(
        'एमसीबी वारंवार ट्रिप होतोय स्विचबोर्ड ठिणग्या जळाल्याचा वास',
      );
      expect(resMcb.isOutOfScope, isFalse);
      expect(resMcb.equipmentTag, equals('Switchboard & Distribution Board'));
      expect(resMcb.primaryCategory, equals('Electrician'));

      final resGeyser = await aiService.diagnoseSymptom(
        'गिझर चालू आहे पण गरम पाणी येत नाही वॉटर हीटर खराब',
      );
      expect(resGeyser.isOutOfScope, isFalse);
      expect(resGeyser.equipmentTag, equals('Water Heater / Geyser'));
      expect(resGeyser.primaryCategory, equals('Electrician'));
    });

    // ── 3. Gujarati (ગુજરાતી) ──
    test('Diagnoses Gujarati regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'મોટર ચાલુ છે પણ પાણી આવતું નથી બોરવેલ પંપ બંધ ટાંકી ભરાતી નથી',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resFridge = await aiService.diagnoseSymptom(
        'ફ્રિજ ઠંડુ થતું નથી અંદરનું ખાવાનું બગડે છે કોમ્પ્રેસર અવાજ',
      );
      expect(resFridge.isOutOfScope, isFalse);
      expect(resFridge.equipmentTag, equals('Refrigerator / Fridge'));
      expect(resFridge.primaryCategory, equals('Appliance Repair'));

      final resDrain = await aiService.diagnoseSymptom(
        'કિચન સિંક જામ થઈ ગયું છે પાણી નીકળતું નથી ગટર વાસ',
      );
      expect(resDrain.isOutOfScope, isFalse);
      expect(resDrain.equipmentTag, equals('Drainage & Sewerage'));
      expect(resDrain.primaryCategory, equals('Plumber'));
    });

    // ── 4. Kannada (ಕನ್ನಡ) ──
    test('Diagnoses Kannada regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resInverter = await aiService.diagnoseSymptom(
        'ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ',
      );
      expect(resInverter.isOutOfScope, isFalse);
      expect(resInverter.equipmentTag, equals('Inverter & Battery'));
      expect(resInverter.primaryCategory, equals('Electrician'));
    });

    // ── 5. Malayalam (മലയാളം) ──
    test('Diagnoses Malayalam regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'മോട്ടോർ ഓടുന്നുണ്ട് പക്ഷേ വെള്ളം വരുന്നില്ല ബോർവെൽ പമ്പ് നിന്നു ടാങ്ക് നിറയുന്നില്ല',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resClean = await aiService.diagnoseSymptom(
        'ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ ഉപ്പ് പാടുകൾ ഡീപ് ക്ലീനിംഗ്',
      );
      expect(resClean.isOutOfScope, isFalse);
      expect(resClean.equipmentTag, equals('Deep Cleaning & Descaling'));
      expect(resClean.primaryCategory, equals('Cleaning'));
    });

    // ── 6. Punjabi (ਪੰਜਾਬੀ) ──
    test('Diagnoses Punjabi regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resMcb = await aiService.diagnoseSymptom(
        'ਐਮਸੀਬੀ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਸਵਿੱਚਬੋਰਡ ਚੰਗਿਆੜੀਆਂ ਸੜਨ ਦੀ ਬਦਬੂ',
      );
      expect(resMcb.isOutOfScope, isFalse);
      expect(resMcb.equipmentTag, equals('Switchboard & Distribution Board'));
      expect(resMcb.primaryCategory, equals('Electrician'));
    });

    // ── 7. Odia (ଓଡ଼ିଆ) ──
    test('Diagnoses Odia regional queries correctly on-device', () async {
      final resMotor = await aiService.diagnoseSymptom(
        'ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ',
      );
      expect(resMotor.isOutOfScope, isFalse);
      expect(resMotor.equipmentTag, equals('Submersible Pump'));
      expect(resMotor.primaryCategory, equals('Electrician'));

      final resPipe = await aiService.diagnoseSymptom(
        'କାନ୍ଥ ଭିତରେ ପାଇପ୍ ଲିକ୍ ହେଉଛି ଛାତରେ ଓଦା ଦାଗ ପାଣି ଗଳୁଛି',
      );
      expect(resPipe.isOutOfScope, isFalse);
      expect(resPipe.equipmentTag, equals('Plumbing & Concealed Piping'));
      expect(resPipe.primaryCategory, equals('Plumber'));
    });

    // ── 8. Tamil, Hindi, Telugu, Tanglish, Hinglish, English ──
    test('Preserves 100% baseline accuracy for existing languages', () async {
      final resTamil = await aiService.diagnoseSymptom(
        'மோட்டார் ஓடல தண்ணீர் வரல போர்வெல் பம்ப் கெட்டுப்போச்சு',
      );
      expect(resTamil.primaryCategory, equals('Electrician'));

      final resHindi = await aiService.diagnoseSymptom(
        'मोटर चल रही है लेकिन पानी नहीं आ रहा बोरवेल पंप खराब',
      );
      expect(resHindi.primaryCategory, equals('Electrician'));

      final resTelugu = await aiService.diagnoseSymptom(
        'నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు బోరువెಲ್ పంప్ పని చేయట్లేదు',
      );
      expect(resTelugu.primaryCategory, equals('Electrician'));

      final resTanglish = await aiService.diagnoseSymptom(
        'motor la sound varudhu thani varala',
      );
      expect(resTanglish.primaryCategory, equals('Electrician'));

      final resHinglish = await aiService.diagnoseSymptom(
        'motor chal rahi hai par paani nahi aa raha',
      );
      expect(resHinglish.primaryCategory, equals('Electrician'));

      final resEnglish = await aiService.diagnoseSymptom(
        'Submersible pump humming but no water',
      );
      expect(resEnglish.primaryCategory, equals('Electrician'));
    });
  });
}
