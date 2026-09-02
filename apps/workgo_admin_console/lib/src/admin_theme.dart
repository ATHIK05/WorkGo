import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WorkGo Admin Console Design System — Light + Yellow Edition
/// All token names preserved for zero call-site breakage across 6 screens.
class AX {
  AX._();

  // ── Surfaces — Warm Off-White ──────────────────────────────────────────────
  static const Color bgCosmic = Color(0xFFFFFBF2);     // App background
  static const Color bgSurface = Color(0xFFFFFFFF);    // Sidebar / AppBar surface
  static const Color bgCard = Color(0xFFFFFFFF);       // Standard card
  static const Color bgCardHover = Color(0xFFFFF8E8);  // Card hover state
  static const Color bgGlass = Color(0xFFFFF3D6);      // Yellow tint panel

  // ── Primary Accent — Amber Yellow ─────────────────────────────────────────
  static const Color emerald = Color(0xFFFFB800);          // Active state / CTA
  static const Color emeraldLight = Color(0xFFFFCD4A);     // Hover
  static const Color emeraldDark = Color(0xFFE8A500);      // Pressed

  // ── Supporting Palette (semantic, for charts & tags) ──────────────────────
  static const Color cyan = Color(0xFF3B82F6);             // Info / secondary chart
  static const Color cyanLight = Color(0xFF93C5FD);
  static const Color cyanDark = Color(0xFF1D4ED8);

  static const Color amber = Color(0xFFF59E0B);            // Warning
  static const Color amberLight = Color(0xFFFCD34D);
  static const Color amberDark = Color(0xFFD97706);

  static const Color violet = Color(0xFF8B5CF6);           // Welfare / tertiary
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color violetDark = Color(0xFF6D28D9);

  static const Color rose = Color(0xFFEF4444);             // Danger / emergency
  static const Color roseLight = Color(0xFFFCA5A5);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFB0B0B0);

  // ── Divider ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFF0EDE6);

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextStyle display({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.4,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle heading({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textSecondary,
    double height = 1.5,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textSecondary,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // ── Card Decorations ───────────────────────────────────────────────────────
  /// Standard light card — white surface with soft warm shadow.
  /// Signature identical to old glassBox() — zero call-site changes needed.
  static BoxDecoration glassBox({
    Color? borderColor,
    double borderWidth = 1.0,
    double radius = 16,
    Color? fillColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: fillColor ?? bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : Border.all(color: divider, width: 1),
      boxShadow: shadows ??
          [
            const BoxShadow(
              color: Color(0x0D000000),  // rgba(0,0,0,0.05)
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
            const BoxShadow(
              color: Color(0x10FFB800),  // subtle warm tint
              blurRadius: 20,
              spreadRadius: -3,
              offset: Offset(0, 6),
            ),
          ],
    );
  }

  /// Accent-colored card — for KPI/stats with a soft colored glow.
  /// Signature identical to old glowBox().
  static BoxDecoration glowBox({
    required Color glowColor,
    double radius = 16,
    double blurRadius = 20,
    double opacity = 0.10,
  }) {
    return BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glowColor.withValues(alpha: 0.20),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0D000000),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: glowColor.withValues(alpha: opacity),
          blurRadius: blurRadius,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

/// Breakpoint detection helper for web, desktop, and mobile
class AdminBreakpoints {
  AdminBreakpoints._();

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 700 && w < 1100;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;
}
