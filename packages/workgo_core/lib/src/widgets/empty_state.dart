import "package:flutter/material.dart";
import "../theme/colors.dart";
import "../theme/spacing.dart";
import "safe_text.dart";

/// A designed empty-state widget. Use on every screen that can have no data.
/// Never show a blank screen — that reads as broken.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.cta,
    this.onCtaPressed,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? cta;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WorkGoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: WorkGoColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: WorkGoSpacing.md),
            SafeText(title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: WorkGoSpacing.sm),
              SafeText(subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: WorkGoColors.textSecondary),
                  maxLines: 3,
                  textAlign: TextAlign.center),
            ],
            if (cta != null && onCtaPressed != null) ...[
              const SizedBox(height: WorkGoSpacing.lg),
              ElevatedButton(
                onPressed: onCtaPressed,
                child: SafeText(cta!, enableAutoShrink: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
