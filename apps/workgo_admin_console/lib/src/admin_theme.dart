import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 2026 Glassmorphic Design System Tokens for WorkGo Admin Governance Console
class AX {
  AX._();

  // ── Palette: Obsidian Deep Cosmic Canvas ────────────────────────────────────
  static const Color bgCosmic = Color(0xFF070510);
  static const Color bgSurface = Color(0xFF0D0A1C);
  static const Color bgCard = Color(0xFF130E26);
  static const Color bgCardHover = Color(0xFF1A1333);
  static const Color bgGlass = Color(0xCC110D24);

  // ── 2026 Neon Brand Accents ────────────────────────────────────────────────
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color emeraldDark = Color(0xFF047857);

  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanLight = Color(0xFF38BDF8);
  static const Color cyanDark = Color(0xFF0284C7);

  static const Color amber = Color(0xFFFBBF24);
  static const Color amberLight = Color(0xFFFDE047);
  static const Color amberDark = Color(0xFFD97706);

  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color violetDark = Color(0xFF6D28D9);

  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFB7185);

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextStyle display({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w900,
    Color color = Colors.white,
    double letterSpacing = -0.5,
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
    Color color = Colors.white,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = Colors.white70,
    double height = 1.4,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = cyan,
  }) {
    return GoogleFonts.firaCode(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // ── Glass Box Decorations ──────────────────────────────────────────────────
  static BoxDecoration glassBox({
    Color? borderColor,
    double borderWidth = 1.0,
    double radius = 16,
    Color? fillColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: fillColor ?? bgCard.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        width: borderWidth,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

  static BoxDecoration glowBox({
    required Color glowColor,
    double radius = 16,
    double blurRadius = 24,
    double opacity = 0.2,
  }) {
    return BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: opacity),
          blurRadius: blurRadius,
          spreadRadius: -2,
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
