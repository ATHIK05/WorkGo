import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import 'safe_text.dart';

enum BadgeType { success, warning, error, info, neutral, emergency, accent }

class WorkGoBadge extends StatelessWidget {
  const WorkGoBadge({
    super.key,
    required this.label,
    this.type = BadgeType.neutral,
    this.icon,
    this.fontSize = 11.0,
  });

  final String label;
  final BadgeType type;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = switch (type) {
      BadgeType.success => (
        const Color(0xFF22C55E).withValues(alpha: 0.15),
        const Color(0xFF22C55E).withValues(alpha: 0.4),
        const Color(0xFF4ADE80),
      ),
      BadgeType.warning => (
        const Color(0xFFF59E0B).withValues(alpha: 0.15),
        const Color(0xFFF59E0B).withValues(alpha: 0.4),
        const Color(0xFFFBBF24),
      ),
      BadgeType.error => (
        const Color(0xFFEF4444).withValues(alpha: 0.15),
        const Color(0xFFEF4444).withValues(alpha: 0.4),
        const Color(0xFFF87171),
      ),
      BadgeType.info => (
        const Color(0xFF38BDF8).withValues(alpha: 0.15),
        const Color(0xFF38BDF8).withValues(alpha: 0.4),
        const Color(0xFF38BDF8),
      ),
      BadgeType.neutral => (
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.18),
        const Color(0xFFCBD5E1),
      ),
      BadgeType.emergency => (
        const Color(0xFFDC2626).withValues(alpha: 0.25),
        const Color(0xFFDC2626).withValues(alpha: 0.6),
        const Color(0xFFFFA4A4),
      ),
      BadgeType.accent => (
        const Color(0xFFFBBF24).withValues(alpha: 0.15),
        const Color(0xFFFBBF24).withValues(alpha: 0.4),
        const Color(0xFFFBBF24),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: WorkGoSpacing.xs),
          ],
          SafeText(
            label.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            enableAutoShrink: true,
          ),
        ],
      ),
    );
  }
}
