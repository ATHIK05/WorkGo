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
        const Color(0xFFD1FAE5),          // soft green tint
        const Color(0xFF6EE7B7),
        const Color(0xFF065F46),          // dark green text — legible on light
      ),
      BadgeType.warning => (
        const Color(0xFFFEF3C7),          // soft amber tint
        const Color(0xFFFCD34D),
        const Color(0xFF92400E),          // dark amber text
      ),
      BadgeType.error => (
        const Color(0xFFFEE2E2),          // soft red tint
        const Color(0xFFFCA5A5),
        const Color(0xFF991B1B),          // dark red text
      ),
      BadgeType.info => (
        const Color(0xFFDBEAFE),          // soft blue tint
        const Color(0xFF93C5FD),
        const Color(0xFF1E40AF),          // dark blue text
      ),
      BadgeType.neutral => (
        const Color(0xFFF3F0EA),          // warm gray tint
        const Color(0xFFE0D8C8),
        const Color(0xFF6B6B6B),          // medium gray text
      ),
      BadgeType.emergency => (
        const Color(0xFFFEE2E2),
        const Color(0xFFFCA5A5),
        const Color(0xFF7F1D1D),
      ),
      BadgeType.accent => (
        const Color(0xFFFFF3D6),          // soft yellow tint
        const Color(0xFFFFCD4A),
        const Color(0xFF92400E),          // dark amber text — readable
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
