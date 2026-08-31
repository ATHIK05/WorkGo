import 'package:flutter/material.dart';

/// easy_localization setup for workgo_core.
///
/// Each app must wrap its root widget with EasyLocalization:
///
/// ```dart
/// EasyLocalization(
///   supportedLocales: WorkGoLocale.supported,
///   path: WorkGoLocale.assetPath,
///   fallbackLocale: WorkGoLocale.fallback,
///   child: const MyApp(),
/// )
/// ```
///
/// In any widget, translate strings with the .tr() extension:
/// ```dart
/// SafeText('book_now'.tr())
/// ```
///
/// Switch locale at runtime (persisted automatically):
/// ```dart
/// await context.setLocale(const Locale('ta'));
/// ```
class WorkGoLocale {
  WorkGoLocale._();

  static const List<Locale> supported = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
  ];

  /// Asset path for the JSON translation files in workgo_core.
  /// Must also be declared in each app's pubspec.yaml flutter > assets section:
  ///   - packages/workgo_core/assets/lang/
  static const String assetPath = 'packages/workgo_core/assets/lang';

  static const Locale fallback = Locale('en');
}
