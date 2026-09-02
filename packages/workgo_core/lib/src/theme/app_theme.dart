import "package:flutter/material.dart";
// ignore: unnecessary_import
import "package:flutter/cupertino.dart";
import "colors.dart";
import "spacing.dart";
import "motion.dart";
import "typography.dart";

class WorkGoTheme {
  WorkGoTheme._();

  /// PRIMARY THEME — Light + Yellow premium consumer design
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: WorkGoColors.primary,        // #FFB800 amber yellow
        onPrimary: Color(0xFF1A1A1A),         // dark text on yellow
        secondary: WorkGoColors.accent,
        onSecondary: Color(0xFF1A1A1A),
        surface: WorkGoColors.surfaceLight,   // #FFFBF2 warm off-white
        onSurface: WorkGoColors.textPrimary,  // #1A1A1A
        surfaceContainerHighest: WorkGoColors.accentTint,
        error: WorkGoColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: WorkGoColors.surfaceLight,
      cardColor: WorkGoColors.cardLight,
      dividerColor: WorkGoColors.dividerLight,
      // AppBar — white surface, dark text, no elevation shadow line
      appBarTheme: AppBarTheme(
        backgroundColor: WorkGoColors.cardLight,
        foregroundColor: WorkGoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(color: WorkGoColors.textPrimary),
        titleTextStyle: WorkGoFonts.display(fontSize: 20),
      ),
      // Elevated Button — solid yellow, dark text, full-radius pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WorkGoColors.primary,
          foregroundColor: const Color(0xFF1A1A1A),
          minimumSize: const Size(0, WorkGoSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkGoSpacing.radiusFull),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          animationDuration: WorkGoMotion.normal,
        ),
      ),
      // Outlined Button — warm border, dark text
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WorkGoColors.textPrimary,
          side: const BorderSide(color: WorkGoColors.dividerLight, width: 1.5),
          minimumSize: const Size(0, WorkGoSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkGoSpacing.radiusFull),
          ),
        ),
      ),
      // Text Button — amber color
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WorkGoColors.primary,
        ),
      ),
      // Input fields — pill shaped, warm fill, no harsh border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9F6EE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WorkGoSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WorkGoSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WorkGoSpacing.radiusMd),
          borderSide: const BorderSide(color: WorkGoColors.primary, width: 1.5),
        ),
        hintStyle: WorkGoFonts.body(color: WorkGoColors.textDisabled),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Chip — yellow active, ghost inactive
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0EDE6),
        selectedColor: WorkGoColors.primary,
        labelStyle: WorkGoFonts.badge(color: WorkGoColors.textSecondary),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      // Bottom nav — transparent (we use custom floating nav)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: WorkGoColors.primary,
        unselectedItemColor: WorkGoColors.textDisabled,
      ),
      // Progress indicator — amber
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WorkGoColors.primary,
        linearTrackColor: WorkGoColors.accentTint,
      ),
      // Divider — warm subtle
      dividerTheme: const DividerThemeData(
        color: WorkGoColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      // Smooth page transitions
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

  /// DARK THEME — kept for reference / admin future use
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: WorkGoColors.primary,
        onPrimary: Color(0xFF1A1A1A),
        secondary: WorkGoColors.accent,
        onSecondary: Color(0xFF1A1A1A),
        surface: Color(0xFF080612),
        onSurface: Colors.white,
        error: WorkGoColors.error,
      ),
      scaffoldBackgroundColor: const Color(0xFF080612),
      cardColor: const Color(0xFF130E26),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WorkGoColors.primary,
          foregroundColor: const Color(0xFF1A1A1A),
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
      textTheme: WorkGoFonts.textTheme(Colors.white),
    );
  }
}
