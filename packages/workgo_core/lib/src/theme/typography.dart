import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Typography Engine for WorkGo.
/// Pairs Plus Jakarta Sans (ultra-clean, modern geometric) with
/// Outfit (dynamic, character-rich headings) and
/// Space Grotesk (fintech-grade numeric & badge clarity).
class WorkGoFonts {
  WorkGoFonts._();

  /// Hero & Screen Titles (Character-rich, high impact)
  static TextStyle display({
    double fontSize = 28.0,
    FontWeight fontWeight = FontWeight.w900,
    Color color = Colors.white,
    double letterSpacing = -0.8,
    double height = 1.15,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Section & Card Headings (Modern geometric)
  static TextStyle heading({
    double fontSize = 18.0,
    FontWeight fontWeight = FontWeight.w800,
    Color color = Colors.white,
    double letterSpacing = -0.4,
    double height = 1.25,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Currency, Pricing, Counters & Metrics (Distinctive neo-fintech)
  static TextStyle numeric({
    double fontSize = 22.0,
    FontWeight fontWeight = FontWeight.w900,
    Color color = Colors.white,
    double letterSpacing = -0.6,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Standard readable body & descriptions
  static TextStyle body({
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w500,
    Color color = const Color(0xFF94A3B8),
    double letterSpacing = -0.1,
    double height = 1.4,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Micro tags, buttons, badges
  static TextStyle badge({
    double fontSize = 10.0,
    FontWeight fontWeight = FontWeight.w800,
    Color color = Colors.white,
    double letterSpacing = 0.6,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Complete TextTheme for ThemeData integration
  static TextTheme textTheme([Color defaultColor = Colors.white]) {
    return GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: defaultColor,
      displayColor: defaultColor,
    );
  }
}
