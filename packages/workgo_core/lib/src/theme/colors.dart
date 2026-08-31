import 'package:flutter/material.dart';

class WorkGoColors {
  WorkGoColors._();

  // Primary — Electric Violet
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA855F7);
  static const Color primaryDark = Color(0xFF581C87);
  static const Color violetNeon = Color(0xFFA855F7);
  static const Color violetSoft = Color(0xFFC084FC);

  // Accent — Solar Yellow & Amber
  static const Color accent = Color(0xFFFFD600);
  static const Color accentLight = Color(0xFFFFE600);
  static const Color accentDark = Color(0xFFF59E0B);
  static const Color gold = Color(0xFFFFD600);
  static const Color amber = Color(0xFFFBBF24);

  // Surfaces — Obsidian Dark Theme
  static const Color surfaceDark = Color(0xFF080612);
  static const Color cardDark = Color(0xFF130E26);
  static const Color elevatedDark = Color(0xFF1C1536);
  static const Color dividerDark = Color(0xFF2E244E);

  // Surfaces — Light Theme
  static const Color surfaceLight = Color(0xFFF5F3FF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dividerLight = Color(0xFFEDE9FE);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFF43F5E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF38BDF8);

  // Text
  static const Color textPrimary = Color(0xFFFAF5FF);
  static const Color textSecondary = Color(0xFFB8A9D9);
  static const Color textDisabled = Color(0xFF6E608F);

  // Gradients
  static const LinearGradient violetGoldGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFFFD600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient electricVioletGradient = LinearGradient(
    colors: [Color(0xFF581C87), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient solarGoldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFFD600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
