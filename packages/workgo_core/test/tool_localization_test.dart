import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('ToolLocalization Tests', () {
    setUp(() {
      WorkGoLocale.currentCode = 'en';
    });

    test('Translates canonical tools to Malayalam (ml)', () {
      WorkGoLocale.setLocaleCode('ml');

      expect('Digital Multimeter'.toLocalizedTool(), equals('ഡിജിറ്റൽ മൾട്ടിമീറ്റർ'));
      expect('Precision Screwdrivers Set'.toLocalizedTool(), equals('പ്രിസിഷൻ സ്ക്രൂഡ്രൈവർ സെറ്റ്'));
      expect('Nut Driver Set'.toLocalizedTool(), equals('നട്ട് ഡ്രൈവർ സെറ്റ്'));
      expect('Insulated Pliers'.toLocalizedTool(), equals('ഇൻസുലേറ്റഡ് പ്ലയർ'));
      expect('Adjustable Spanner'.toLocalizedTool(), equals('ക്രമീകരിക്കാവുന്ന സ്പാനർ'));
      expect('Electrical Tape'.toLocalizedTool(), equals('ഇലക്ട്രിക്കൽ ടേപ്പ്'));
      expect('Assorted Fuses'.toLocalizedTool(), equals('വിവിധയിനം ഫ്യൂസുകൾ'));
      expect('Wire Connectors'.toLocalizedTool(), equals('വയർ കണക്ടറുകൾ'));
      expect('Insulated Work Gloves'.toLocalizedTool(), equals('ഇൻസുലേറ്റഡ് ഗ്ലൗസുകൾ'));
      expect('Safety Glasses'.toLocalizedTool(), equals('സുരക്ഷാ ഗ്ലാസുകൾ'));
    });

    test('Translates tools to Hindi (hi)', () {
      WorkGoLocale.setLocaleCode('hi');

      expect('Digital Multimeter'.toLocalizedTool(), equals('डिजिटल मल्टीमीटर'));
      expect('Pipe Wrench'.toLocalizedTool(), equals('पाइप रिंच'));
      expect('Claw Hammer'.toLocalizedTool(), equals('हथौड़ा (क्लॉ हैमर)'));
    });

    test('Translates tools with technical specifications and preserves specs', () {
      WorkGoLocale.setLocaleCode('ml');

      expect('Digital Multimeter (CAT III)'.toLocalizedTool(), equals('ഡിജിറ്റൽ മൾട്ടിമീറ്റർ (CAT III)'));
      expect('Pipe Wrench (12" & 14")'.toLocalizedTool(), equals('പൈപ്പ് റെഞ്ച് (12" & 14")'));
    });

    test('Maintains canonical English when locale is en', () {
      WorkGoLocale.setLocaleCode('en');

      expect('Digital Multimeter'.toLocalizedTool(), equals('Digital Multimeter'));
      expect('Precision Screwdrivers Set'.toLocalizedTool(), equals('Precision Screwdrivers Set'));
    });

    test('Gracefully returns original custom tool if unknown', () {
      WorkGoLocale.setLocaleCode('ml');

      expect('Custom Brass Ball Valve 3/4 inch'.toLocalizedTool(), equals('Custom Brass Ball Valve 3/4 inch'));
    });
  });
}
