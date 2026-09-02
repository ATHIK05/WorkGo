import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Centralized Typography Engine for WorkGo — Light + Yellow Edition.
/// Font stack: Outfit (display) + Plus Jakarta Sans (body/heading) + Space Grotesk (numeric).
/// Default colors are now dark-on-light for the warm white background system.
class WorkGoFonts {
  WorkGoFonts._();

  /// Hero & Screen Titles — bold, character-rich, high impact
  static TextStyle display({
    double fontSize = 24.0,
    FontWeight fontWeight = FontWeight.w700,
    Color color = WorkGoColors.textPrimary,   // #1A1A1A — dark on light
    double letterSpacing = -0.5,
    double height = 1.2,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Section & Card Headings — modern geometric, clear hierarchy
  static TextStyle heading({
    double fontSize = 17.0,
    FontWeight fontWeight = FontWeight.w700,
    Color color = WorkGoColors.textPrimary,   // #1A1A1A
    double letterSpacing = -0.3,
    double height = 1.3,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Currency, Pricing, Counters & Metrics — tight letter-spacing = premium
  static TextStyle numeric({
    double fontSize = 24.0,
    FontWeight fontWeight = FontWeight.w800,
    Color color = WorkGoColors.textPrimary,
    double letterSpacing = -0.8,
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
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.w400,
    Color color = WorkGoColors.textSecondary, // #6B6B6B — medium gray
    double letterSpacing = -0.1,
    double height = 1.5,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Caption / meta — smallest readable tier
  static TextStyle caption({
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w400,
    Color color = WorkGoColors.textDisabled,  // #B0B0B0 — muted
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Micro tags, buttons, badges — tight tracking for label legibility
  static TextStyle badge({
    double fontSize = 11.0,
    FontWeight fontWeight = FontWeight.w700,
    Color color = WorkGoColors.textPrimary,
    double letterSpacing = 0.2,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Complete TextTheme for ThemeData integration
  static TextTheme textTheme([Color defaultColor = WorkGoColors.textPrimary]) {
    return GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: defaultColor,
      displayColor: defaultColor,
    );
  }
}
