import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Invoice Multilingual Localization & Keys Verification', () {
    late Map<String, dynamic> enJson;
    late Map<String, dynamic> taJson;
    late Map<String, dynamic> hiJson;

    setUpAll(() {
      final enFile = File('assets/lang/en.json');
      final taFile = File('assets/lang/ta.json');
      final hiFile = File('assets/lang/hi.json');

      enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      taJson = jsonDecode(taFile.readAsStringSync()) as Map<String, dynamic>;
      hiJson = jsonDecode(hiFile.readAsStringSync()) as Map<String, dynamic>;
    });

    final expectedInvoiceKeys = [
      'invoice_title',
      'invoice_to',
      'invoice_terms',
      'authorised_sign',
      'thank_you_business',
      'invoice_num',
      'invoice_date',
      'invoice_booking',
      'invoice_artisan',
      'invoice_paid',
      'invoice_sl',
      'invoice_item_desc',
      'invoice_price',
      'invoice_total',
      'invoice_subtotal',
      'invoice_platform_fee',
      'invoice_gst',
      'invoice_total_amount',
      'invoice_emergency_fee',
      'invoice_diagnostic_credit',
      'invoice_phone',
      'invoice_email',
      'invoice_website',
      'invoice_terms_heading',
      'invoice_coop_tagline',
      'invoice_welfare_contribution',
    ];

    test('All invoice keys exist and are populated across en.json, ta.json, and hi.json', () {
      for (final key in expectedInvoiceKeys) {
        expect(enJson[key], isNotNull, reason: 'Missing key "$key" in en.json');
        expect(enJson[key].toString().trim(), isNotEmpty, reason: 'Empty key "$key" in en.json');

        expect(taJson[key], isNotNull, reason: 'Missing key "$key" in ta.json');
        expect(taJson[key].toString().trim(), isNotEmpty, reason: 'Empty key "$key" in ta.json');

        expect(hiJson[key], isNotNull, reason: 'Missing key "$key" in hi.json');
        expect(hiJson[key].toString().trim(), isNotEmpty, reason: 'Empty key "$key" in hi.json');
      }
    });

    test('Tamil translations contain authentic Tamil characters', () {
      expect(IndicPdfShaper.hasIndicCharacters(taJson['invoice_title']), isTrue);
      expect(IndicPdfShaper.hasIndicCharacters(taJson['invoice_artisan']), isTrue);
      expect(IndicPdfShaper.hasIndicCharacters(taJson['thank_you_business']), isTrue);
    });

    test('Hindi translations contain authentic Devanagari characters', () {
      expect(IndicPdfShaper.hasIndicCharacters(hiJson['invoice_title']), isTrue);
      expect(IndicPdfShaper.hasIndicCharacters(hiJson['invoice_artisan']), isTrue);
      expect(IndicPdfShaper.hasIndicCharacters(hiJson['thank_you_business']), isTrue);
    });

    test('IndicPdfShaper detects Indic vs Latin scripts accurately', () {
      expect(IndicPdfShaper.hasIndicCharacters('INV-1788625675113'), isFalse);
      expect(IndicPdfShaper.hasIndicCharacters('₹180.00'), isFalse);
      expect(IndicPdfShaper.hasIndicCharacters('Mohamed Athik R'), isFalse);
      expect(IndicPdfShaper.hasIndicCharacters('வொர்க்கோ'), isTrue);
      expect(IndicPdfShaper.hasIndicCharacters('कारीगर'), isTrue);
    });

    test('IndicPdfShaper renders English text as native pw.Text vector widget', () async {
      final regularFont = pw.Font.courier();
      final widget = await IndicPdfShaper.render(
        text: 'Invoice # INV-12345',
        fontSize: 10,
        fallbackFont: regularFont,
        locale: 'en',
      );
      expect(widget, isA<pw.Text>());
    });

    test('IndicPdfShaper renders Tamil text with native HarfBuzz shaping as high-DPI pw.Image', () async {
      final widget = await IndicPdfShaper.render(
        text: 'வொர்க்கோ கூட்டுறவு கைவினைஞர்',
        fontSize: 14,
        isBold: true,
        locale: 'ta',
      );
      expect(widget, isA<pw.Image>());
    });

    test('IndicPdfShaper renders Hindi Devanagari text with native HarfBuzz shaping as high-DPI pw.Image', () async {
      final widget = await IndicPdfShaper.render(
        text: 'वर्कगो सहकारी कारीगर सेवाएं',
        fontSize: 14,
        isBold: true,
        locale: 'hi',
      );
      expect(widget, isA<pw.Image>());
    });

    test('IndicPdfShaper respects maxWidth constraint for long Tamil text', () async {
      final widget = await IndicPdfShaper.render(
        text: 'வொர்க்கோ கூட்டுறவு கைவினைஞர் சேவைகளை தேர்ந்தெடுத்ததற்கு நன்றி',
        fontSize: 9.0,
        maxWidth: 250.0,
        locale: 'ta',
      );
      expect(widget, isA<pw.Image>());
      final img = widget as pw.Image;
      expect(img.width != null && img.width! <= 250.0, isTrue);
    });

    test('IndicPdfShaper respects maxWidth constraint for long Hindi text', () async {
      final widget = await IndicPdfShaper.render(
        text: 'वर्कगो सहकारी कारीगर सेवाओं को चुनने के लिए धन्यवाद',
        fontSize: 9.0,
        maxWidth: 250.0,
        locale: 'hi',
      );
      expect(widget, isA<pw.Image>());
      final img = widget as pw.Image;
      expect(img.width != null && img.width! <= 250.0, isTrue);
    });
  });
}
