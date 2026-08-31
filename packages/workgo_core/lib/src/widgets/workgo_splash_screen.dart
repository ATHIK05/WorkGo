// workgo_splash_screen.dart
//
// An impressive animated splash screen for "WorkGo", rebuilt from a
// reference intro video: comet streak -> logo reveal -> orbit ring ->
// tagline -> ambient particles + corner sparkle.
//
// Palette: deep violet dark background, violet -> yellow gradients for the
// logomark and orbit ring, soft yellow glow accents.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ---- Brand palette -------------------------------------------------------
class WorkGoBrandColors {
  WorkGoBrandColors._();

  static const Color bgTop = Color(0xFF120B22); // near-black violet
  static const Color bgBottom = Color(0xFF07040E); // almost black
  static const Color violetDeep = Color(0xFF3A0CA3);
  static const Color violetCore = Color(0xFF7B2FF7);
  static const Color violetSoft = Color(0xFFB185F7);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color yellowSoft = Color(0xFFFFE873);
  static const Color textPrimary = Color(0xFFF5F1FF);
  static const Color textSecondary = Color(0xFFB9AEDD);
}

/// ---- Public entry widget --------------------------------------------------
class WorkGoSplashScreen extends StatefulWidget {
  const WorkGoSplashScreen({
    super.key,
    this.nextScreen,
    this.totalDuration = const Duration(milliseconds: 3600),
    this.appName = 'WorkGo',
    this.tagline = 'Book your service in minutes',
  });

  /// Screen to navigate to automatically once the splash finishes.
  /// If null, the splash just plays and stays on its final frame.
  final Widget? nextScreen;

  final Duration totalDuration;
  final String appName;
  final String tagline;

  @override
  State<WorkGoSplashScreen> createState() => _WorkGoSplashScreenState();
}

class _WorkGoSplashScreenState extends State<WorkGoSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController
      _loopController; // ambient loop (particles, sparkle, ring spin)

  // Staged animations mapped from the single main controller.
  late final Animation<double> _streakProgress; // 0 -> 1 comet draws in
  late final Animation<double> _streakFade; // fades the streak out
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _ringFade;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _streakProgress = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.34, curve: Curves.easeOutCubic),
    );

    _streakFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.30, 0.46, curve: Curves.easeIn),
    );

    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.28, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.28, 0.46, curve: Curves.easeOut),
    );

    _textFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.40, 0.62, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.40, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.58, 0.80, curve: Curves.easeOut),
    );

    _ringFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.34, 0.58, curve: Curves.easeOut),
    );

    _glowPulse = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );

    _mainController.forward();

    if (widget.nextScreen != null) {
      _mainController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 450), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 650),
                pageBuilder: (_, anim, __) => FadeTransition(
                  opacity: anim,
                  child: widget.nextScreen,
                ),
              ),
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: WorkGoBrandColors.bgBottom,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _loopController]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient + radial glow.
              _buildBackground(size),

              // Ambient floating particles.
              CustomPaint(
                painter: WorkGoParticlePainter(
                  loopValue: _loopController.value,
                  revealValue: _glowPulse.value,
                ),
                size: Size.infinite,
              ),

              // Center composition: streak -> logomark -> orbit ring.
              Center(
                child: SizedBox(
                  width: math.min(size.width * 0.9, 520),
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Orbit ring behind the logo.
                      Opacity(
                        opacity: _ringFade.value,
                        child: Transform.rotate(
                          angle: _loopController.value * 2 * math.pi,
                          child: CustomPaint(
                            painter: _OrbitRingPainter(),
                            size: const Size(300, 300),
                          ),
                        ),
                      ),

                      // Comet streak intro.
                      if (_streakFade.value < 1.0)
                        Opacity(
                          opacity: 1.0 - _streakFade.value,
                          child: CustomPaint(
                            painter: _StreakPainter(
                              progress: _streakProgress.value,
                            ),
                            size: const Size(220, 220),
                          ),
                        ),

                      // Logomark + wordmark + tagline.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: _logoScale.value,
                                child: Opacity(
                                  opacity: _logoFade.value.clamp(0.0, 1.0),
                                  child: const WorkGoMark(size: 74),
                                ),
                              ),
                              const SizedBox(width: 14),
                              ClipRect(
                                child: SlideTransition(
                                  position: _textSlide,
                                  child: Opacity(
                                    opacity: _textFade.value.clamp(0.0, 1.0),
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [
                                          WorkGoBrandColors.textPrimary,
                                          WorkGoBrandColors.yellowSoft,
                                        ],
                                      ).createShader(bounds),
                                      child: Text(
                                        widget.appName.replaceAll(' ', '\n'),
                                        style: const TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          height: 1.08,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Opacity(
                            opacity: _taglineFade.value.clamp(0.0, 1.0),
                            child: Text(
                              widget.tagline,
                              style: const TextStyle(
                                fontSize: 16,
                                color: WorkGoBrandColors.textSecondary,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground(Size size) {
    final glow = 0.55 + 0.25 * math.sin(_loopController.value * 2 * math.pi);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WorkGoBrandColors.bgTop, WorkGoBrandColors.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WorkGoBrandColors.violetCore.withValues(alpha: 0.28 * glow),
                    WorkGoBrandColors.violetDeep.withValues(alpha: 0.10 * glow),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.6, 0.5),
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WorkGoBrandColors.yellow.withValues(alpha: 0.06 * glow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---- Logomark: two interlocking ribbon shapes (violet -> yellow) --------
class WorkGoMark extends StatelessWidget {
  const WorkGoMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back ribbon (violet gradient) — a "V" swoosh.
    final backPath = Path()
      ..moveTo(w * 0.06, h * 0.08)
      ..lineTo(w * 0.34, h * 0.08)
      ..lineTo(w * 0.58, h * 0.62)
      ..lineTo(w * 0.44, h * 0.98)
      ..close();

    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [WorkGoBrandColors.violetSoft, WorkGoBrandColors.violetCore],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(backPath, backPaint);

    // Front ribbon (yellow gradient) — the "G/arrow" swoosh, offset & angled.
    final frontPath = Path()
      ..moveTo(w * 0.30, h * 0.32)
      ..lineTo(w * 0.62, h * 0.32)
      ..lineTo(w * 0.94, h * 0.98)
      ..lineTo(w * 0.66, h * 0.98)
      ..close();

    final frontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [WorkGoBrandColors.yellowSoft, WorkGoBrandColors.yellow],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    canvas.drawPath(frontPath,
        frontPaint..color = frontPaint.color.withValues(alpha: 0.94));
    canvas.restore();
    canvas.restore();

    // Soft glow behind the mark.
    final glowPaint = Paint()
      ..color = WorkGoBrandColors.violetCore.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.42, glowPaint);

    // Repaint the two ribbons on top of the glow so they stay crisp.
    canvas.drawPath(backPath, backPaint);
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ---- Comet streak intro (violet -> yellow trail that draws itself) ------
class _StreakPainter extends CustomPainter {
  _StreakPainter({required this.progress});
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.30,
        size.width * 0.58,
        size.height * 0.30,
      );

    final metrics = path.computeMetrics().first;
    final extractLength = metrics.length * progress;
    final drawPath = metrics.extractPath(0, extractLength);

    final gradient = const LinearGradient(
      colors: [WorkGoBrandColors.violetSoft, WorkGoBrandColors.yellow],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final trailPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawPath(drawPath, trailPaint);

    // Bright comet head at the tip.
    final tangent = metrics.getTangentForOffset(extractLength);
    if (tangent != null) {
      final headPaint = Paint()
        ..color = WorkGoBrandColors.yellowSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(tangent.position, 7, headPaint);
      canvas.drawCircle(
        tangent.position,
        3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ---- Orbit ring (spinning arc around the wordmark) -----------------------
class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          WorkGoBrandColors.violetSoft,
          WorkGoBrandColors.yellow,
          Colors.transparent,
        ],
        stops: [0.0, 0.35, 0.55, 0.75],
      ).createShader(rect);

    canvas.drawArc(
        rect.deflate(6), -math.pi * 0.35, math.pi * 1.1, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ---- Ambient floating particles ------------------------------------------
class WorkGoParticlePainter extends CustomPainter {
  WorkGoParticlePainter({required this.loopValue, required this.revealValue});
  final double loopValue;
  final double revealValue;

  static final List<_ParticleSeed> _seeds = List.generate(26, (i) {
    final rnd = math.Random(i * 97 + 3);
    return _ParticleSeed(
      dx: rnd.nextDouble(),
      dy: rnd.nextDouble(),
      radius: 0.8 + rnd.nextDouble() * 2.0,
      speed: 0.3 + rnd.nextDouble() * 0.7,
      phase: rnd.nextDouble(),
      isYellow: rnd.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (revealValue <= 0) return;
    for (final s in _seeds) {
      final t = (loopValue * s.speed + s.phase) % 1.0;
      final dy = (s.dy - t) % 1.0;
      final twinkle = (math.sin((loopValue + s.phase) * 2 * math.pi) + 1) / 2;
      final opacity = (0.15 + 0.55 * twinkle) * revealValue;

      final paint = Paint()
        ..color = (s.isYellow
                ? WorkGoBrandColors.yellow
                : WorkGoBrandColors.violetSoft)
            .withValues(alpha: opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

      canvas.drawCircle(
        Offset(s.dx * size.width, dy * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorkGoParticlePainter oldDelegate) =>
      oldDelegate.loopValue != loopValue ||
      oldDelegate.revealValue != revealValue;
}

class _ParticleSeed {
  _ParticleSeed({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.isYellow,
  });
  final double dx, dy, radius, speed, phase;
  final bool isYellow;
}
