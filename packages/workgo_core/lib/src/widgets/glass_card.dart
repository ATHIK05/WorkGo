import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Premium light card widget — replaces GlassCard (dark glassmorphic).
/// Warm white surface with soft diffuse shadow. No backdrop blur needed on light.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WorkGoSpacing.md),
    this.borderRadius = WorkGoSpacing.radiusMd,
    this.blurSigma = 0.0,               // Not used on light — kept for API compat
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.elevation = 8.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;               // API-compat; ignored on light surfaces
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? WorkGoColors.cardLight,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: const Color(0x0D000000),  // rgba(0,0,0,0.05) — whisper
                  blurRadius: elevation * 1.8,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0x08FFB800),  // rgba(255,184,0,0.03) warm tint
                  blurRadius: elevation,
                  spreadRadius: -1,
                  offset: Offset(0, elevation / 3),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: WorkGoColors.primary.withValues(alpha: 0.08),
          highlightColor: WorkGoColors.primary.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    return content;
  }
}
