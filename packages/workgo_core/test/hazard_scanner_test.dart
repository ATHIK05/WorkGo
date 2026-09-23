import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/src/services/hazard_scanner.dart';

void main() {
  group('Tier 0 Deterministic Hazard Scanner Tests', () {
    group('Electrical Shock Hazard Detection', () {
      final shockQueries = [
        // English
        'geyser gives shock when touching water',
        'current shock from washing machine body',
        'metal pipe gives electric shock',
        'earthing problem in bathroom switch',
        // Tanglish
        'geyser la shock adikuthu',
        'tap thotta current adikkudhu thanni la',
        'motor touch panna shock adikudhu',
        'switch pota current shocku',
        // Tamil Script
        'கீசர்ல ஷாக் அடிக்குது',
        'கரண்ட் ஷாக் வருது',
        // Hinglish
        'tap me se current lag raha hai',
        'fridge se shock lag raha hai',
        'bijli ka jhatka laga switchboard se',
        'earthing aa rahi hai geyser me',
        // Hindi Script
        'नल में करंट लग रहा है',
        'बिजली का झटका लगा',
        // Telugu
        'shock kodutondi water tap lo',
        'కరెంట్ కొడుతుంది',
        // Kannada
        'ಶಾಕ್ ಹೊಡೆಯುತ್ತಿದೆ',
        // Malayalam
        'ഷോക്ക് അടിക്കുന്നു',
        // Bengali
        'ইলেকট্রিক শক লাগছে',
        // Marathi
        'शॉक लागला',
        // Gujarati
        'કરંટ લાગ્યો',
      ];

      for (final query in shockQueries) {
        test('Detects electrical shock in: "$query"', () {
          final flag = HazardScanner.scan(query);
          expect(flag, isNotNull, reason: 'Expected hazard for "$query"');
          expect(flag!.type, equals(HazardType.electricalShock));
          expect(flag.emergencyTrade, equals('Electrician'));
          expect(flag.requiresImmediateIsolation, isTrue);
          expect(flag.helplineNumber, equals('1912'));
          expect(flag.safetyInstruction, contains('Electrical shock'));
        });
      }
    });

    group('Fire / Spark / Burning Wire Hazard Detection', () {
      final fireSparkQueries = [
        // English
        'switchboard sparking and burning smell',
        'smoke from main mcb switch',
        'wire sparking in meter box',
        'short circuit in bedroom board',
        'burnt smell coming from fan',
        // Tanglish
        'switchboard la spark varudhu',
        'theepori varudhu wire la',
        'eriyara vaasam varudhu mcb la',
        'wire erinjupochu smoke varudhu',
        // Tamil Script
        'தீப்பொறி வருது போர்டுல',
        'புகை வருது',
        'எரியும் வாசனை இருக்கு',
        // Hinglish
        'wire se jalne ki badbu aa rahi hai',
        'switchboard me spark aa raha hai',
        'dhuan nikal raha hai meter se',
        'short circuit ho gaya',
        // Hindi Script
        'शॉर्ट सर्किट हो गया',
        'तार से जलने की बदबू आ रही है',
        'धुआं निकल रहा है',
        // Kannada Script
        'ಬೆಂಕಿ ಹೊಗೆ ಬರುತ್ತಿದೆ',
        // Malayalam Script
        'തീപ്പൊരി വരുന്നു',
        // Bengali Script
        'শর্ট সার্কিট আগুন লেগেছে',
        // Marathi Script
        'आग लागली वायरमधून धूर येत आहे',
      ];

      for (final query in fireSparkQueries) {
        test('Detects fire/spark in: "$query"', () {
          final flag = HazardScanner.scan(query);
          expect(flag, isNotNull, reason: 'Expected hazard for "$query"');
          expect(flag!.type, equals(HazardType.fireSpark));
          expect(flag.emergencyTrade, equals('Electrician'));
          expect(flag.requiresImmediateIsolation, isTrue);
          expect(flag.helplineNumber, equals('1912'));
          expect(flag.safetyInstruction, contains('MCB'));
        });
      }
    });

    group('LPG Gas Leak Hazard Detection', () {
      final gasLeakQueries = [
        // English
        'gas leak from kitchen cylinder pipe',
        'smell of lpg gas near stove',
        'cylinder leaking under kitchen counter',
        // Tanglish
        'gas leak aagudhu kitchen la',
        'cylinder gas vaasam adikuthu',
        // Tamil Script
        'கேஸ் லீக் ஆகுது',
        'கேஸ் வாசனை அடிக்குது',
        // Hinglish
        'cylinder se gas leak ho rahi hai',
        'kitchen me gas ki badbu aa rahi hai',
        // Hindi Script
        'गैस लीक हो रही है',
        'सिलेंडर लीक है',
        // Kannada Script
        'ಗ್ಯಾಸ್ ಸೋರಿಕೆ ಆಗ್ತಿದೆ',
        // Malayalam Script
        'ഗ്യാസ് ചോർച്ച ഉണ്ട്',
        // Bengali Script
        'গ্যাসের গন্ধ বের হচ্ছে',
        // Marathi Script
        'गॅस गळती होत आहे',
      ];

      for (final query in gasLeakQueries) {
        test('Detects gas leak in: "$query"', () {
          final flag = HazardScanner.scan(query);
          expect(flag, isNotNull, reason: 'Expected hazard for "$query"');
          expect(flag!.type, equals(HazardType.gasLeak));
          expect(flag.emergencyTrade, equals('Appliance Repair'));
          expect(flag.requiresImmediateIsolation, isTrue);
          expect(flag.helplineNumber, equals('1906'));
          expect(flag.safetyInstruction, contains('gas leak'));
        });
      }
    });

    group('Negation Awareness (Filters Out Negated Danger Keywords)', () {
      final negatedQueries = [
        'water motor is humming but no shock',
        'geyser is working fine no electric shock',
        'water motor la sound varudhu shock onnum illa',
        'tap thotta thanni varala shock illa',
        'tap water varudhu shock adikala',
        'switch loose aagi irukku spark illa',
        'wire checking pannanum no spark no smoke',
        'stove burner clean pannanum gas leak illa',
        'gas cylinder leak nahi hai just pipe loose hai',
        'gas ki badbu nahi hai burner kaam nahi kar raha',
        'motor aawaz kar raha hai current nahi lag raha',
        'no gas leak in kitchen',
      ];

      for (final query in negatedQueries) {
        test('Correctly ignores negated hazard in: "$query"', () {
          final flag = HazardScanner.scan(query);
          expect(flag, isNull, reason: 'Negated phrase should NOT trigger hazard for: "$query"');
        });
      }
    });

    group('Safe / Normal Non-Hazard Queries', () {
      final safeQueries = [
        'water motor humming but no water',
        'AC fan running but not cooling room',
        'kitchen sink drain is completely blocked',
        'main door lock key is stuck and cylinder jammed',
        'refrigerator not cooling and ice buildup',
        'wall paint peeling near bathroom',
        'floor tiles broken and cement hollow',
        'ceiling fan speed is very slow',
        'geyser not heating water at all',
        'motor la sound varudhu thani varala',
        'ac cool aagala',
      ];

      for (final query in safeQueries) {
        test('Returns null (no false positive) for: "$query"', () {
          final flag = HazardScanner.scan(query);
          expect(flag, isNull, reason: 'Expected no hazard flag for "$query"');
        });
      }
    });

    test('Handles empty and whitespace queries gracefully', () {
      expect(HazardScanner.scan(''), isNull);
      expect(HazardScanner.scan('   '), isNull);
    });
  });
}
