// workgo_splash_screen.dart
//
// Reimagined, ultra-premium splash screen for "WorkGo" — a cooperative
// blue-collar platform connecting people with skilled local artisans & gig workers
// (plumbing, electrical, carpentry, building, and repair services).
//
// Theme: Pure white + warm sunflower gold / amber luxury.
// Staged animations:
//   1. Comet streak arc ->
//   2. 3D golden squircle logomark reveal with spring bounce ->
//   3. Orbiting trade icons (plumbing, electrical, tools, repair) with counter-rotation ->
//   4. Bespoke Outfit wordmark + Plus Jakarta Sans tagline ->
//   5. Rising building-blocks skyline motif ->
//   6. Ambient golden dust particles & cooperative trust badge ->
//   7. Smooth route handover.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---- Brand palette: Pure White & Sunflower Gold Luxury ----
class WorkGoBrandColors {
  WorkGoBrandColors._();

  // Background surfaces: Crisp, luminous white transitioning into warm ivory champagne
  static const Color bgTop = Color(0xFFFFFFFF);
  static const Color bgBottom = Color(0xFFFFFDF5);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Golds & Ambers
  static const Color amberDark = Color(0xFFD97706); // Deep warm amber
  static const Color amberCore = Color(0xFFFFB800); // Signature WorkGo sunflower gold
  static const Color amberSoft = Color(0xFFFFD54A); // Luminous warm amber
  static const Color yellow = Color(0xFFFFE14D); // Solar radiant gold
  static const Color yellowSoft = Color(0xFFFFF7C2); // Brilliant highlight cream

  // High-contrast Inks & Accents (Never cheap pure black)
  static const Color ink = Color(0xFF0F172A); // Deep slate obsidian
  static const Color inkSoft = Color(0xFF475569); // Refined slate grey
  static const Color inkMuted = Color(0xFF94A3B8); // Muted slate accent
}

/// ---- Public entry widget --------------------------------------------------
class WorkGoSplashScreen extends StatefulWidget {
  const WorkGoSplashScreen({
    super.key,
    this.nextScreen,
    this.onFinish,
    this.totalDuration = const Duration(milliseconds: 3800),
    this.appName = 'WorkGo',
    this.tagline = 'Connecting people. Building together.',
  });

  final Widget? nextScreen;
  final VoidCallback? onFinish;

  final Duration totalDuration;
  final String appName;
  final String tagline;

  @override
  State<WorkGoSplashScreen> createState() => _WorkGoSplashScreenState();
}

class _WorkGoSplashScreenState extends State<WorkGoSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _loopController;

  // Staged timeline animations
  late final Animation<double> _streakProgress;
  late final Animation<double> _streakFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _ringFade;
  late final Animation<double> _toolsFade;
  late final Animation<double> _groundFade;
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
      duration: const Duration(seconds: 8),
    )..repeat();

    // 1. Comet streak entrance (0.00 -> 0.32)
    _streakProgress = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
    );

    _streakFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.28, 0.44, curve: Curves.easeIn),
    );

    // 2. Central Logomark spring scale & fade (0.26 -> 0.54)
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.26, 0.54, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.26, 0.46, curve: Curves.easeOut),
    );

    // 3. Orbit ring reveal (0.32 -> 0.58)
    _ringFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.32, 0.58, curve: Curves.easeOut),
    );

    // 4. Trade tools fade in (0.42 -> 0.68)
    _toolsFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.42, 0.68, curve: Curves.easeOut),
    );

    // 5. Brand typography slide & fade (0.40 -> 0.65)
    _textFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.40, 0.62, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.40, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // 6. Tagline reveal (0.56 -> 0.78)
    _taglineFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.56, 0.78, curve: Curves.easeOut),
    );

    // 7. Base building block skyline (0.55 -> 0.85)
    _groundFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    // 8. Ambient breathing glow
    _glowPulse = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );

    _mainController.forward();

    if (widget.nextScreen != null || widget.onFinish != null) {
      _mainController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 450), () {
            if (!mounted) return;
            widget.onFinish?.call();
            if (widget.nextScreen != null) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 650),
                  pageBuilder: (_, anim, __) => FadeTransition(
                    opacity: anim,
                    child: widget.nextScreen,
                  ),
                ),
              );
            }
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
      backgroundColor: WorkGoBrandColors.bgTop,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _loopController]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Warm Luminous Light Pools Background ──────────────────
              _buildBackground(size),

              // ── 2. Ambient Floating Golden Dust Particles ─────────────────
              CustomPaint(
                painter: WorkGoParticlePainter(
                  loopValue: _loopController.value,
                  revealValue: _glowPulse.value,
                ),
                size: Size.infinite,
              ),

              // ── 3. Subtle Building Blocks / Skyline Motif at Base ─────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: _groundFade.value.clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _SkylinePainter(reveal: _groundFade.value),
                    size: Size(size.width, size.height * 0.15),
                  ),
                ),
              ),

              // ── 4. Center Composition: Logo, Orbiting Trades & Wordmark ───
              Center(
                child: SizedBox(
                  width: math.min(size.width * 0.92, 540),
                  height: 380,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Golden Orbit Ring behind logo
                      Opacity(
                        opacity: _ringFade.value.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: _loopController.value * 2 * math.pi,
                          child: CustomPaint(
                            painter: _OrbitRingPainter(),
                            size: const Size(290, 290),
                          ),
                        ),
                      ),

                      // 4 Orbiting Cooperative Trade Icons (Plumbing, Electric, Carpentry, Care)
                      // Notice counter-rotation (-angle) so icons remain perfectly upright!
                      Opacity(
                        opacity: _toolsFade.value.clamp(0.0, 1.0),
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            children: [
                              _buildOrbitingChip(
                                icon: Icons.plumbing_rounded,
                                angleDeg: 0,
                                radius: 130,
                                boxSize: 280,
                              ),
                              _buildOrbitingChip(
                                icon: Icons.bolt_rounded,
                                angleDeg: 90,
                                radius: 130,
                                boxSize: 280,
                              ),
                              _buildOrbitingChip(
                                icon: Icons.build_rounded,
                                angleDeg: 180,
                                radius: 130,
                                boxSize: 280,
                              ),
                              _buildOrbitingChip(
                                icon: Icons.home_repair_service_rounded,
                                angleDeg: 270,
                                radius: 130,
                                boxSize: 280,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Comet streak trail intro
                      if (_streakFade.value < 1.0)
                        Opacity(
                          opacity: (1.0 - _streakFade.value).clamp(0.0, 1.0),
                          child: CustomPaint(
                            painter: _StreakPainter(
                              progress: _streakProgress.value,
                            ),
                            size: const Size(260, 260),
                          ),
                        ),

                      // Brand Mark + High-Fashion Typography + Tagline
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
                                  child: const WorkGoMark(size: 82),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ClipRect(
                                child: SlideTransition(
                                  position: _textSlide,
                                  child: Opacity(
                                    opacity: _textFade.value.clamp(0.0, 1.0),
                                    child: _buildBrandTitle(widget.appName),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Opacity(
                            opacity: _taglineFade.value.clamp(0.0, 1.0),
                            child: Text(
                              widget.tagline,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                color: WorkGoBrandColors.inkSoft,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 5. Bottom Cooperative Trust Badge & Sleek Progress Bar ────
              Positioned(
                bottom: 38,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _taglineFade.value.clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glassmorphism Cooperative Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: WorkGoBrandColors.amberCore.withValues(alpha: 0.40),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: WorkGoBrandColors.amberCore.withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                              const BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                color: WorkGoBrandColors.amberDark,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'A COOPERATIVE OF TRUSTED WORKERS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: WorkGoBrandColors.ink,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Sleek Ambient Progress Bar
                        SizedBox(
                          width: 120,
                          height: 3.5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _mainController.value,
                              backgroundColor: WorkGoBrandColors.amberCore.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                WorkGoBrandColors.amberDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the brand title with GoogleFonts.outfit and stylish micro-badge
  /// for app subtitles (e.g. "WorkGo Karya" or "WorkGo Console").
  Widget _buildBrandTitle(String rawName) {
    final parts = rawName.trim().split(' ');
    final primaryName = parts.isNotEmpty ? parts.first : 'WorkGo';
    final hasSuffix = parts.length > 1;
    final suffixName = hasSuffix ? parts.sublist(1).join(' ') : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Primary Wordmark with metallic dark-to-amber gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              WorkGoBrandColors.ink,
              Color(0xFF1E293B),
              WorkGoBrandColors.amberDark,
            ],
            stops: [0.0, 0.75, 1.0],
          ).createShader(bounds),
          child: Text(
            primaryName,
            style: GoogleFonts.outfit(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
        ),
        if (hasSuffix && suffixName != null) ...[
          const SizedBox(width: 8),
          // Suffix Badge (KARYA / CONSOLE) - Luminous Amber Light Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: WorkGoBrandColors.amberCore.withValues(alpha: 0.70),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: WorkGoBrandColors.amberCore.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              suffixName.toUpperCase(),
              style: GoogleFonts.outfit(
                color: const Color(0xFFB45309),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Places an orbiting trade icon chip with counter-rotation so it stays upright.
  Widget _buildOrbitingChip({
    required IconData icon,
    required double angleDeg,
    required double radius,
    required double boxSize,
  }) {
    final currentAngle = (_loopController.value * 2 * math.pi * 0.5) + (angleDeg * math.pi / 180);
    final cx = boxSize / 2 + radius * math.cos(currentAngle) - 17;
    final cy = boxSize / 2 + radius * math.sin(currentAngle) - 17;

    return Positioned(
      left: cx,
      top: cy,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: WorkGoBrandColors.amberCore.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: WorkGoBrandColors.amberCore.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16.5,
            color: WorkGoBrandColors.amberDark,
          ),
        ),
      ),
    );
  }

  /// Soft luminous background with breathing amber halos
  Widget _buildBackground(Size size) {
    final glow = 0.60 + 0.30 * math.sin(_loopController.value * 2 * math.pi);

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
          // Primary Center Amber Glow
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: size.width * 1.15,
              height: size.width * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WorkGoBrandColors.amberCore.withValues(alpha: 0.20 * glow),
                    WorkGoBrandColors.amberSoft.withValues(alpha: 0.08 * glow),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Secondary Soft Solar Glow
          Align(
            alignment: const Alignment(0.65, 0.45),
            child: Container(
              width: size.width * 0.70,
              height: size.width * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WorkGoBrandColors.yellow.withValues(alpha: 0.12 * glow),
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

/// ---- Logomark: Sunflower Gold Squircle with a builder emblem ----
class WorkGoMark extends StatelessWidget {
  const WorkGoMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WorkGoBrandColors.yellowSoft,
            WorkGoBrandColors.amberCore,
            WorkGoBrandColors.amberDark,
          ],
          stops: [0.0, 0.46, 1.0],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: WorkGoBrandColors.amberCore.withValues(alpha: 0.45),
            blurRadius: size * 0.42,
            spreadRadius: size * 0.04,
            offset: Offset(0, size * 0.12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.75),
            blurRadius: size * 0.16,
            offset: Offset(0, -size * 0.02),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.handyman_rounded,
          size: size * 0.52,
          color: const Color(0xFF78350F),
        ),
      ),
    );
  }
}

/// ---- Comet streak intro (amber -> solar gold trail) ------
class _StreakPainter extends CustomPainter {
  _StreakPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.28,
        size.width * 0.56,
        size.height * 0.28,
      );

    final metrics = path.computeMetrics().first;
    final extractLength = metrics.length * progress;
    final drawPath = metrics.extractPath(0, extractLength);

    final gradient = const LinearGradient(
      colors: [WorkGoBrandColors.amberSoft, WorkGoBrandColors.amberDark],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final trailPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawPath(drawPath, trailPaint);

    final tangent = metrics.getTangentForOffset(extractLength);
    if (tangent != null) {
      final headPaint = Paint()
        ..color = WorkGoBrandColors.amberCore
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(tangent.position, 7, headPaint);
      canvas.drawCircle(
        tangent.position,
        3.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ---- Orbit ring (spinning gold arc around the wordmark) -------------------
class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          WorkGoBrandColors.amberSoft,
          WorkGoBrandColors.amberCore,
          Colors.transparent,
        ],
        stops: [0.0, 0.35, 0.55, 0.75],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(6),
      -math.pi * 0.35,
      math.pi * 1.1,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ---- Ambient floating golden dust particles --------------------------------
class WorkGoParticlePainter extends CustomPainter {
  WorkGoParticlePainter({required this.loopValue, required this.revealValue});
  final double loopValue;
  final double revealValue;

  static final List<_ParticleSeed> _seeds = List.generate(28, (i) {
    final rnd = math.Random(i * 97 + 3);
    return _ParticleSeed(
      dx: rnd.nextDouble(),
      dy: rnd.nextDouble(),
      radius: 0.8 + rnd.nextDouble() * 2.2,
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
      final opacity = (0.12 + 0.38 * twinkle) * revealValue;

      final paint = Paint()
        ..color = (s.isYellow
                ? WorkGoBrandColors.amberCore
                : WorkGoBrandColors.amberSoft)
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

/// ---- Faint building-blocks "skyline" motif rising at the base -------------
/// A subtle nod to construction / building trades, drawn as rounded pillars of
/// varying heights that gently fade & rise in as the splash completes.
class _SkylinePainter extends CustomPainter {
  _SkylinePainter({required this.reveal});
  final double reveal;

  static const List<double> _heights = [
    0.28, 0.52, 0.38, 0.74, 0.48, 0.62, 0.34, 0.58, 0.44, 0.68, 0.36, 0.50
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final barCount = _heights.length;
    final barWidth = size.width / barCount;
    final paint = Paint()
      ..color = WorkGoBrandColors.amberCore.withValues(alpha: 0.08 * reveal);

    for (var i = 0; i < barCount; i++) {
      final h = size.height * _heights[i] * reveal;
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.12,
        size.height - h,
        barWidth * 0.76,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) =>
      oldDelegate.reveal != reveal;
}
