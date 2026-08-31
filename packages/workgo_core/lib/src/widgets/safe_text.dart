import "package:auto_size_text/auto_size_text.dart";
import "package:flutter/material.dart";

/// The ONLY text widget to use across all WorkGo apps.
/// Enforces overflow-safe behaviour for all three locales (en / hi / ta).
/// See PRD v2 Section 13.1.
class SafeText extends StatelessWidget {
  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.enableAutoShrink = false,
    this.textAlign,
    this.minFontSize = 10.0,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// If true, the text will gently shrink to [minFontSize] before truncating.
  /// Use for short UI labels (bottom-nav, chips, buttons). Use false for body copy.
  final bool enableAutoShrink;
  final TextAlign? textAlign;
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    if (enableAutoShrink) {
      return AutoSizeText(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        minFontSize: minFontSize,
        textAlign: textAlign,
      );
    }
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
