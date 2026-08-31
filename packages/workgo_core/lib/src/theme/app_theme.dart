import "package:flutter/material.dart";
// ignore: unnecessary_import
import "package:flutter/cupertino.dart";
import "colors.dart";
import "spacing.dart";
import "motion.dart";
import "typography.dart";

class WorkGoTheme {
  WorkGoTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: WorkGoColors.primary,
        onPrimary: Colors.white,
        secondary: WorkGoColors.accent,
        onSecondary: Colors.black,
        surface: WorkGoColors.surfaceDark,
        onSurface: WorkGoColors.textPrimary,
        error: WorkGoColors.error,
      ),
      scaffoldBackgroundColor: WorkGoColors.surfaceDark,
      cardColor: WorkGoColors.cardDark,
      dividerColor: WorkGoColors.dividerDark,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WorkGoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, WorkGoSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkGoSpacing.radiusMd),
          ),
          animationDuration: WorkGoMotion.normal,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: WorkGoFonts.textTheme(WorkGoColors.textPrimary),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: WorkGoColors.primary,
        onPrimary: Colors.white,
        secondary: WorkGoColors.accent,
        onSecondary: Colors.black,
        surface: WorkGoColors.surfaceLight,
        onSurface: Color(0xFF1C1B2E),
        error: WorkGoColors.error,
      ),
      scaffoldBackgroundColor: WorkGoColors.surfaceLight,
      cardColor: WorkGoColors.cardLight,
      dividerColor: WorkGoColors.dividerLight,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WorkGoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, WorkGoSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkGoSpacing.radiusMd),
          ),
        ),
      ),
      fontFamily: "Inter",
    );
  }
}
