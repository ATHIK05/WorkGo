import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive, real-time Speedometer Gauge for the Karya Daily Challenge.
///
/// Sweeps an animated needle from 0% (pointing left at "0") to 100% (pointing right)
/// across a vibrant magenta -> orange -> emerald gradient speed track.
class KaryaSpeedometerGauge extends StatefulWidget {
  final double progress; // 0.0 to 1.0 (or greater)
  final double width;
  final double height;
  final String minLabel;
  final bool showCelebrationGlow;

  const KaryaSpeedometerGauge({
    super.key,
    required this.progress,
    this.width = 96,
    this.height = 62,
    this.minLabel = '0',
    this.showCelebrationGlow = true,
  });

  @override
  State<KaryaSpeedometerGauge> createState() => _KaryaSpeedometerGaugeState();
}

class _KaryaSpeedometerGaugeState extends State<KaryaSpeedometerGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.progress.clamp(0.0, 1.0);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: _currentProgress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KaryaSpeedometerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.progress - widget.progress).abs() > 0.001) {
      final target = widget.progress.clamp(0.0, 1.0);
      _animation = Tween<double>(
        begin: _animation.value,
        end: target,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _SpeedometerGaugePainter(
            progress: _animation.value,
            minLabel: widget.minLabel,
            isCompleted: widget.progress >= 1.0,
          ),
        );
      },
    );
  }
}

class _SpeedometerGaugePainter extends CustomPainter {
  final double progress;
  final String minLabel;
  final bool isCompleted;

  _SpeedometerGaugePainter({
    required this.progress,
    required this.minLabel,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.95);
    final radius = size.width * 0.46;
    final strokeWidth = size.width * 0.14;

    // 1. Base Dial Background Plate (Soft off-white / light lavender)
    final bgArcRect = Rect.fromCircle(center: center, radius: radius);
    final bgPaint = Paint()
      ..color = const Color(0xFFFAF9FF)
      ..style = PaintingStyle.fill;
    canvas.drawArc(bgArcRect, math.pi, math.pi, true, bgPaint);

    // 2. Dial Outer Border Stroke
    final outlinePaint = Paint()
      ..color = const Color(0xFF231B38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawArc(bgArcRect, math.pi, math.pi, false, outlinePaint);

    // Bottom horizontal baseline of dial
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      outlinePaint,
    );

    // 3. Colored Rainbow Gradient Speed Track
    // Sweep from Pink/Magenta -> Orange/Amber -> Emerald Green
    final trackRadius = radius - (strokeWidth / 2) - 1.0;
    final trackRect = Rect.fromCircle(center: center, radius: trackRadius);

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFFE879F9), // Soft Magenta / Pink
          Color(0xFFF43F5E), // Coral Rose
          Color(0xFFF97316), // Vivid Orange
          Color(0xFFFBBF24), // Amber Yellow
          Color(0xFF34D399), // Mint
          Color(0xFF10B981), // Emerald
        ],
        stops: [0.0, 0.2, 0.45, 0.7, 0.88, 1.0],
      ).createShader(trackRect);

    canvas.drawArc(trackRect, math.pi, math.pi, false, gradientPaint);

    // Inner outline separating color track from white face
    final innerRadius = radius - strokeWidth - 1.5;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final innerBorderPaint = Paint()
      ..color = const Color(0xFF231B38).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(innerRect, math.pi, math.pi, false, innerBorderPaint);

    // 4. Subtle Radial Tick Marks
    final tickPaint = Paint()
      ..color = const Color(0xFF231B38).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const tickFractions = [0.25, 0.5, 0.75];
    for (final frac in tickFractions) {
      final tickAngle = math.pi + (frac * math.pi);
      final rInner = radius - strokeWidth - 1.0;
      final rOuter = radius - 1.0;
      final p1 = Offset(
        center.dx + rInner * math.cos(tickAngle),
        center.dy + rInner * math.sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + rOuter * math.cos(tickAngle),
        center.dy + rOuter * math.sin(tickAngle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 5. Dial Numerals: "0" label near left bottom
    final textPainter = TextPainter(
      text: TextSpan(
        text: minLabel,
        style: const TextStyle(
          color: Color(0xFF231B38),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position "0" inside the white inner area near bottom-left
    final textOffset = Offset(
      center.dx - radius + strokeWidth + 4,
      center.dy - textPainter.height - 2,
    );
    textPainter.paint(canvas, textOffset);

    // 6. Dynamic Needle (Pivots from math.pi at 0.0 to 2*math.pi at 1.0)
    // When progress == 0, needle points left (angle = math.pi)
    // When progress == 0.5, needle points up (angle = 1.5 * math.pi)
    // When progress == 1.0, needle points right (angle = 2.0 * math.pi)
    final needleAngle = math.pi + (progress.clamp(0.0, 1.0) * math.pi);
    final needleLength = radius * 0.78;

    final needleTip = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    // Needle body path (tapered pointer)
    final perpAngle = needleAngle + (math.pi / 2);
    const needleBaseWidth = 3.5;
    final baseP1 = Offset(
      center.dx + needleBaseWidth * math.cos(perpAngle),
      center.dy + needleBaseWidth * math.sin(perpAngle),
    );
    final baseP2 = Offset(
      center.dx - needleBaseWidth * math.cos(perpAngle),
      center.dy - needleBaseWidth * math.sin(perpAngle),
    );

    final needlePath = Path()
      ..moveTo(baseP1.dx, baseP1.dy)
      ..lineTo(needleTip.dx, needleTip.dy)
      ..lineTo(baseP2.dx, baseP2.dy)
      ..close();

    // Needle drop shadow for 3D tactile feel
    canvas.drawShadow(
      needlePath,
      const Color(0x33000000),
      2.0,
      false,
    );

    final needlePaint = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.fill;
    canvas.drawPath(needlePath, needlePaint);

    // 7. Center Pivot Hub
    final hubBorderPaint = Paint()
      ..color = const Color(0xFF1E1035)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.5, hubBorderPaint);

    final hubInnerPaint = Paint()
      ..color = isCompleted ? const Color(0xFF10B981) : const Color(0xFFFAF9FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, hubInnerPaint);

    // 8. Celebration Shimmer (if 100% reached)
    if (isCompleted) {
      final glowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawArc(bgArcRect, math.pi, math.pi, false, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.minLabel != minLabel;
  }
}

/// Dynamic action speed lines radiating outward from behind the gauge.
class KaryaSpeedLines extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const KaryaSpeedLines({
    super.key,
    this.width = 44,
    this.height = 36,
    this.color = const Color(0x401E1035),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SpeedLinesPainter(color: color),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  final Color color;
  _SpeedLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // 4 diagonal motion streaks angled towards top-right
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.92),
      Offset(size.width * 0.88, size.height * 0.14),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.98),
      Offset(size.width * 0.98, size.height * 0.38),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.0, size.height * 0.65),
      Offset(size.width * 0.68, size.height * 0.0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.40),
      Offset(size.width * 0.45, size.height * 0.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}

