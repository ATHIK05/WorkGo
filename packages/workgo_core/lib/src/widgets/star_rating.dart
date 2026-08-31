import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'safe_text.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.starSize = 18.0,
    this.showLabel = true,
    this.isInteractive = false,
    this.onRatingChanged,
  });

  final double rating;
  final int maxRating;
  final double starSize;
  final bool showLabel;
  final bool isInteractive;
  final ValueChanged<double>? onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(maxRating, (index) {
          final starValue = index + 1.0;
          final isFull = rating >= starValue;
          final isHalf = !isFull && rating >= starValue - 0.5;

          final icon = isFull
              ? Icons.star_rounded
              : (isHalf ? Icons.star_half_rounded : Icons.star_outline_rounded);

          final star = Icon(
            icon,
            size: starSize,
            color: (isFull || isHalf)
                ? WorkGoColors.accent
                : Colors.white.withValues(alpha: 0.25),
          );

          if (isInteractive) {
            return GestureDetector(
              onTap: () => onRatingChanged?.call(starValue),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: star,
              ),
            );
          }
          return star;
        }),
        if (showLabel) ...[
          const SizedBox(width: WorkGoSpacing.xs + 2),
          SafeText(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: starSize * 0.75,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}
