import "dart:math" as math;
import "package:flutter/material.dart";

/// Tinder-style circular verification & profile completion ring.
/// Wraps around [WorkGoAvatar] with an animated progress arc and floating micro-pill.
class ProfileAvatarTrustRing extends StatelessWidget {
  const ProfileAvatarTrustRing({
    super.key,
    required this.child,
    required this.score,
    this.avatarRadius = 38,
    this.ringGap = 4.0,
    this.strokeWidth = 3.5,
    this.showBadge = true,
    this.onTap,
  });

  final Widget child;
  final int score;
  final double avatarRadius;
  final double ringGap;
  final double strokeWidth;
  final bool showBadge;
  final VoidCallback? onTap;

  Color _getProgressColor(double progress) {
    if (progress >= 0.99) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (progress >= 0.5) {
      return const Color(0xFF3B82F6); // Blue
    } else {
      return const Color(0xFFF59E0B); // Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100);
    final targetProgress = clampedScore / 100.0;
    final totalRadius = avatarRadius + ringGap + strokeWidth;
    final totalDiameter = totalRadius * 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Animated Progress Halo
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetProgress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              final activeColor = _getProgressColor(progress);

              return SizedBox(
                width: totalDiameter,
                height: totalDiameter,
                child: CustomPaint(
                  painter: _TrustRingPainter(
                    progress: progress,
                    strokeWidth: strokeWidth,
                    color: activeColor,
                    trackColor: const Color(0xFFE5E7EB),
                  ),
                ),
              );
            },
          ),

          // Avatar Child inside the ring
          child,

          // Tinder-Style Micro Floating Badge at bottom
          if (showBadge)
            Positioned(
              bottom: -6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getProgressColor(targetProgress).withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      clampedScore == 100 ? Icons.verified_rounded : Icons.shield_rounded,
                      color: _getProgressColor(targetProgress),
                      size: 11,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      "$clampedScore%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrustRingPainter extends CustomPainter {
  _TrustRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress Arc Paint
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = progress * 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrustRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor;
  }
}
