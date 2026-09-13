import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';
import 'firestore_asset_loader.dart';

/// Language descriptor with native script and regional BCP-47 identifiers.
class WorkGoLanguageInfo {
  final String code;
  final String englishName;
  final String nativeName;
  final String region;
  final String bcp47;

  const WorkGoLanguageInfo({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.region,
    required this.bcp47,
  });

  Locale get locale => Locale(code);
}

/// easy_localization setup and 22 Official Scheduled Indian Languages registry.
///
/// Each app wraps its root widget with EasyLocalization:
/// ```dart
/// EasyLocalization(
///   supportedLocales: WorkGoLocale.supported,
///   path: WorkGoLocale.assetPath,
///   fallbackLocale: WorkGoLocale.fallback,
///   assetLoader: const FirestoreAssetLoader(),
///   child: const MyApp(),
/// )
/// ```
class WorkGoLocale {
  WorkGoLocale._();

  /// Default asset loader using Firestore dynamic caching and asset fallback
  static const FirestoreAssetLoader loader = FirestoreAssetLoader();

  /// All 22 Officially Recognized Indian Languages + English
  static const List<WorkGoLanguageInfo> allLanguages = [
    WorkGoLanguageInfo(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
      region: 'Pan-India',
      bcp47: 'en-IN',
    ),
    // North & West
    WorkGoLanguageInfo(
      code: 'hi',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      region: 'North',
      bcp47: 'hi-IN',
    ),
    WorkGoLanguageInfo(
      code: 'pa',
      englishName: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      region: 'North',
      bcp47: 'pa-IN',
    ),
    WorkGoLanguageInfo(
      code: 'gu',
      englishName: 'Gujarati',
      nativeName: 'ગુજરાતી',
      region: 'West',
      bcp47: 'gu-IN',
    ),
    WorkGoLanguageInfo(
      code: 'mr',
      englishName: 'Marathi',
      nativeName: 'मराठी',
      region: 'West',
      bcp47: 'mr-IN',
    ),
    WorkGoLanguageInfo(
      code: 'ks',
      englishName: 'Kashmiri',
      nativeName: 'کٲشُر / कश्मीरी',
      region: 'North',
      bcp47: 'ks-IN',
    ),
    WorkGoLanguageInfo(
      code: 'doi',
      englishName: 'Dogri',
      nativeName: 'डोगरी',
      region: 'North',
      bcp47: 'doi-IN',
    ),
    WorkGoLanguageInfo(
      code: 'sd',
      englishName: 'Sindhi',
      nativeName: 'سنڌي / सिंधी',
      region: 'West',
      bcp47: 'sd-IN',
    ),
    // East & Northeast
    WorkGoLanguageInfo(
      code: 'bn',
      englishName: 'Bengali',
      nativeName: 'বাংলা',
      region: 'East',
      bcp47: 'bn-IN',
    ),
    WorkGoLanguageInfo(
      code: 'as',
      englishName: 'Assamese',
      nativeName: 'অসমীয়া',
      region: 'Northeast',
      bcp47: 'as-IN',
    ),
    WorkGoLanguageInfo(
      code: 'or',
      englishName: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      region: 'East',
      bcp47: 'or-IN',
    ),
    WorkGoLanguageInfo(
      code: 'mai',
      englishName: 'Maithili',
      nativeName: 'मैथिली',
      region: 'East',
      bcp47: 'mai-IN',
    ),
    WorkGoLanguageInfo(
      code: 'sat',
      englishName: 'Santali',
      nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ',
      region: 'East',
      bcp47: 'sat-IN',
    ),
    WorkGoLanguageInfo(
      code: 'brx',
      englishName: 'Bodo',
      nativeName: 'बर\'',
      region: 'Northeast',
      bcp47: 'brx-IN',
    ),
    WorkGoLanguageInfo(
      code: 'mni',
      englishName: 'Manipuri',
      nativeName: 'মৈতৈলোন্',
      region: 'Northeast',
      bcp47: 'mni-IN',
    ),
    WorkGoLanguageInfo(
      code: 'ne',
      englishName: 'Nepali',
      nativeName: 'नेपाली',
      region: 'East',
      bcp47: 'ne-IN',
    ),
    // South
    WorkGoLanguageInfo(
      code: 'te',
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
      region: 'South',
      bcp47: 'te-IN',
    ),
    WorkGoLanguageInfo(
      code: 'ta',
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
      region: 'South',
      bcp47: 'ta-IN',
    ),
    WorkGoLanguageInfo(
      code: 'kn',
      englishName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      region: 'South',
      bcp47: 'kn-IN',
    ),
    WorkGoLanguageInfo(
      code: 'ml',
      englishName: 'Malayalam',
      nativeName: 'മലയാളം',
      region: 'South',
      bcp47: 'ml-IN',
    ),
    // Classical & Others
    WorkGoLanguageInfo(
      code: 'sa',
      englishName: 'Sanskrit',
      nativeName: 'संस्कृतम्',
      region: 'Classical',
      bcp47: 'sa-IN',
    ),
    WorkGoLanguageInfo(
      code: 'ur',
      englishName: 'Urdu',
      nativeName: 'اردو',
      region: 'North & Deccan',
      bcp47: 'ur-IN',
    ),
    WorkGoLanguageInfo(
      code: 'kok',
      englishName: 'Konkani',
      nativeName: 'कोंकणी',
      region: 'West',
      bcp47: 'kok-IN',
    ),
  ];

  /// List of supported Locale instances for EasyLocalization
  static final List<Locale> supported = allLanguages.map((l) => l.locale).toList();

  /// Asset path for baseline JSON translation files in workgo_core.
  static const String assetPath = 'packages/workgo_core/assets/lang';

  static const Locale fallback = Locale('en');

  /// Fallback delegates ensuring Flutter Material and Cupertino widgets support all 22 Indian languages
  static const List<LocalizationsDelegate<dynamic>> fallbackDelegates = [
    WorkGoMaterialLocalizationsDelegate(),
    WorkGoCupertinoLocalizationsDelegate(),
  ];

  /// Composite localizations delegates including WorkGo regional fallbacks
  static List<LocalizationsDelegate<dynamic>> delegates(BuildContext context) {
    return [
      const WorkGoMaterialLocalizationsDelegate(),
      const WorkGoCupertinoLocalizationsDelegate(),
      ...context.localizationDelegates,
    ];
  }

  /// Pre-configures intl date symbols and patterns for all 22 Indian languages
  static Future<void> ensureInitialized() async {
    try {
      await initializeDateFormatting('en', null);
      final symbols = dateTimeSymbolMap();
      final enSymbols = symbols['en'];
      if (enSymbols is DateSymbols) {
        const unsupported = {'sa', 'kok', 'doi', 'ks', 'mai', 'sat', 'brx', 'mni', 'sd'};
        for (final code in unsupported) {
          final serialized = Map<String, dynamic>.from(enSymbols.serializeToMap());
          serialized['NAME'] = code;
          final customSymbols = DateSymbols.deserializeFromMap(serialized);
          initializeDateFormattingCustom(
            locale: code,
            symbols: customSymbols,
            patterns: const {'yMMMMd': 'y MMMM d'},
          );
        }
      }
    } catch (_) {}
  }

  /// Find language info by code
  static WorkGoLanguageInfo getInfo(String code) {
    return allLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => allLanguages.first,
    );
  }

  /// Check if a code is officially registered
  static bool isSupportedCode(String code) {
    return allLanguages.any((l) => l.code == code);
  }
}

/// Delegate ensuring Flutter's Material widgets gracefully support all 22 Indian regional languages
class WorkGoMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const WorkGoMaterialLocalizationsDelegate();

  static const unsupportedByFlutter = {'sa', 'kok', 'doi', 'ks', 'mai', 'sat', 'brx', 'mni', 'sd'};

  @override
  bool isSupported(Locale locale) => unsupportedByFlutter.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    const devanagariLangs = {'sa', 'mai', 'doi', 'kok', 'ks'};
    final target = devanagariLangs.contains(locale.languageCode) ? const Locale('hi') : const Locale('en');
    return await GlobalMaterialLocalizations.delegate.load(target);
  }

  @override
  bool shouldReload(WorkGoMaterialLocalizationsDelegate old) => false;
}

/// Delegate ensuring Cupertino widgets gracefully support all 22 Indian regional languages
class WorkGoCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const WorkGoCupertinoLocalizationsDelegate();

  static const unsupportedByFlutter = {'sa', 'kok', 'doi', 'ks', 'mai', 'sat', 'brx', 'mni', 'sd'};

  @override
  bool isSupported(Locale locale) => unsupportedByFlutter.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    const devanagariLangs = {'sa', 'mai', 'doi', 'kok', 'ks'};
    final target = devanagariLangs.contains(locale.languageCode) ? const Locale('hi') : const Locale('en');
    return await GlobalCupertinoLocalizations.delegate.load(target);
  }

  @override
  bool shouldReload(WorkGoCupertinoLocalizationsDelegate old) => false;
}

