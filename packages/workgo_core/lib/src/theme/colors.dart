import 'package:flutter/material.dart';

/// WorkGo Unified Design Token System — Light + Yellow Edition
/// Single source of truth for all color, shadow, and gradient values
/// across workgo_admin_console, workgo_customer, and workgo_karya.
class WorkGoColors {
  WorkGoColors._();

  // ── Primary Accent — Confident Amber Yellow ────────────────────────────────
  static const Color primary = Color(0xFFFFB800);       // Main CTA, active states
  static const Color primaryLight = Color(0xFFFFCD4A);  // Hover / focus
  static const Color primaryDark = Color(0xFFE8A500);   // Pressed / shadow tint
  static const Color violetNeon = Color(0xFFFFCD4A);    // Compat alias (remapped)
  static const Color violetSoft = Color(0xFFFFE4A0);    // Compat alias (remapped)

  // ── Accent (same role, kept for explicit accent calls) ─────────────────────
  static const Color accent = Color(0xFFFFB800);
  static const Color accentLight = Color(0xFFFFCD4A);
  static const Color accentDark = Color(0xFFE8A500);
  static const Color gold = Color(0xFFFFB800);
  static const Color amber = Color(0xFFF59E0B);

  // ── Background Surfaces ────────────────────────────────────────────────────
  static const Color surfaceDark = Color(0xFFFFFBF2);   // Warm off-white background
  static const Color cardDark = Color(0xFFFFFFFF);      // Card surface
  static const Color elevatedDark = Color(0xFFFFF3D6);  // Elevated / yellow-tint card
  static const Color dividerDark = Color(0xFFF0EDE6);   // Subtle warm divider

  static const Color surfaceLight = Color(0xFFFFFBF2);  // Same warm background
  static const Color cardLight = Color(0xFFFFFFFF);     // Cards
  static const Color dividerLight = Color(0xFFF0EDE6);  // Light dividers

  // ── Tint Fills ─────────────────────────────────────────────────────────────
  static const Color accentTint = Color(0xFFFFF3D6);    // Soft yellow tint (card bg)
  static const Color accentTint2 = Color(0xFFFFE3C2);   // Soft peach/orange tag tint
  static const Color darkCard = Color(0xFF1C1C1E);      // Dark hero card variant

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFF43F5E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);     // Near-black headers
  static const Color textSecondary = Color(0xFF6B6B6B);   // Medium gray body
  static const Color textDisabled = Color(0xFFB0B0B0);    // Disabled / muted

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient violetGoldGradient = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFFE4A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient electricVioletGradient = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFB800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient solarGoldGradient = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFB800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero dark card gradient — dark charcoal with amber glow
  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [Color(0xFF1C1C1E), Color(0xFF2D2207)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Centralized shadow presets — warm-tinted, diffuse, premium feel.
/// Use these instead of raw BoxShadow definitions for consistency.
class WorkGoShadows {
  WorkGoShadows._();

  /// Standard card elevation — subtle lift off warm background
  static const BoxShadow card = BoxShadow(
    color: Color(0x11000000), // rgba(0,0,0,0.07)
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  /// Warm accent shadow — for active/focused cards and yellow CTAs
  static const BoxShadow warm = BoxShadow(
    color: Color(0x24FFB800), // rgba(255,184,0,0.14)
    blurRadius: 20,
    spreadRadius: -2,
    offset: Offset(0, 6),
  );

  /// Floating nav bar shadow — heavier lift from screen floor
  static const BoxShadow nav = BoxShadow(
    color: Color(0x1A000000), // rgba(0,0,0,0.10)
    blurRadius: 28,
    spreadRadius: 0,
    offset: Offset(0, -4),
  );

  /// Hero/CTA button shadow with amber tint
  static const BoxShadow button = BoxShadow(
    color: Color(0x33E8A500), // rgba(232,165,0,0.20)
    blurRadius: 16,
    spreadRadius: -2,
    offset: Offset(0, 4),
  );

  /// Combine card + warm for premium floating card effect
  static List<BoxShadow> get floatingCard => [card, warm];
}
