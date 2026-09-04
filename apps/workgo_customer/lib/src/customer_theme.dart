import 'package:flutter/material.dart';
import 'package:workgo_core/workgo_core.dart';

// ─────────────────────────────────────────────
//  AURORA COLOR TOKENS — Light + Yellow Edition
// ─────────────────────────────────────────────
class CX {
  CX._();

  // Canvas — warm off-white light surfaces
  static const Color canvas = Color(0xFFFFFBF2); // App background
  static const Color canvasCard = Color(0xFFFFFFFF); // Card surface
  static const Color canvasMid = Color(0xFFFFF8EE); // Mid surface
  static const Color canvasElevated = Color(0xFFFFF3D6); // Accent tint surface
  static const Color dividerLight = Color(0xFFF0EDE6); // Subtle divider

  // Primary accent — confident amber yellow
  static const Color violet = Color(0xFFFFB800); // Remapped: amber as primary
  static const Color violetLight = Color(0xFFFFCD4A); // Lighter amber
  static const Color cyan = Color(0xFF3B82F6); // Secondary: blue for info
  static const Color cyanLight = Color(0xFF93C5FD);
  static const Color amber = Color(0xFFF59E0B); // Warning / warm orange
  static const Color amberDark = Color(0xFFD97706);
  static const Color emerald = Color(0xFF10B981); // Success green
  static const Color rose = Color(0xFFEF4444); // Danger / emergency
  static const Color indigo = Color(0xFF6366F1); // Tertiary accent

  // Tint fills
  static const Color accentTint = Color(0xFFFFF3D6); // Soft yellow tint
  static const Color accentTint2 = Color(0xFFFFE3C2); // Soft peach/orange tint
  static const Color darkCard = Color(0xFF1C1C1E); // Dark hero card

  // Glass / surface helpers (light-aware)
  static Color glass(double opacity) =>
      Colors.black.withValues(alpha: opacity * 0.04);
  static Color glassCard = const Color(0xFFFFF3D6).withValues(alpha: 0.6);
  static Color glassBorder = const Color(0xFFFFB800).withValues(alpha: 0.20);
  static Color glassBorderBright = const Color(
    0xFFFFB800,
  ).withValues(alpha: 0.40);

  // Text — dark on warm white
  static const Color textPrimary = Color(0xFF1A1A1A); // Near-black headers
  static const Color textSecondary = Color(0xFF6B6B6B); // Medium gray body
  static const Color textMuted = Color(0xFFB0B0B0); // Disabled / captions

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradients — amber/yellow family
  static const LinearGradient auroraVioletCyan = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFFCD4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraVioletAmber = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFB800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraFull = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFB800), Color(0xFFFFCD4A)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraEmergency = LinearGradient(
    colors: [Color(0xFF9B1C1C), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraSuccess = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraCanvas = LinearGradient(
    colors: [Color(0xFFFFFBF2), Color(0xFFFFF8E8), Color(0xFFFFFBF2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─────────────────────────────────────────────
//  ANIMATION DURATIONS
// ─────────────────────────────────────────────
class CAnim {
  CAnim._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration verySlow = Duration(milliseconds: 700);
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOutCubic;
}

// ─────────────────────────────────────────────
//  AURORA GLASS CARD — premium backdrop blur card
// ─────────────────────────────────────────────
class AuroraCard extends StatelessWidget {
  const AuroraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24.0,
    this.borderColor,
    this.glowColor,
    this.onTap,
    this.gradient,
    this.blurSigma = 20.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Light card: white surface with warm shadow
        gradient: gradient,
        color: gradient == null ? CX.canvasCard : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.2)
            : Border.all(
                color: const Color(0xFFF0EDE6),
                width: 1,
              ), // warm divider
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: const Color(0x0D000000),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: glow.withValues(alpha: 0.14),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x0E000000), // rgba(0,0,0,0.055)
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x10FFB800), // warm amber tint
                  blurRadius: 20,
                  spreadRadius: -3,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return _TappableCard(
        borderRadius: borderRadius,
        onTap: onTap!,
        child: content,
      );
    }

    return content;
  }
}

class _TappableCard extends StatefulWidget {
  const _TappableCard({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GLOW BUTTON — aurora gradient CTA
// ─────────────────────────────────────────────
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradient = CX.auroraVioletCyan,
    this.height = 52.0,
    this.isLoading = false,
    this.isFullWidth = true,
    this.borderRadius = 16.0,
    this.fontSize = 15.0,
    this.glowColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double height;
  final bool isLoading;
  final bool isFullWidth;
  final double borderRadius;
  final double fontSize;
  final Color? glowColor;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Default gradient = amber yellow — premium warm CTA
    final effectiveGradient = widget.gradient == CX.auroraVioletCyan
        ? CX
              .auroraVioletCyan // keep as-is (already remapped to amber)
        : widget.gradient;
    final glow = widget.glowColor ?? CX.amber;
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          if (!widget.isLoading) widget.onPressed?.call();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          height: widget.height,
          width: widget.isFullWidth ? double.infinity : null,
          padding: widget.isFullWidth
              ? null
              : const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            borderRadius: BorderRadius.circular(
              widget.borderRadius == 16.0 ? 999 : widget.borderRadius,
            ),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1A1A1A), // dark on yellow
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: const Color(0xFF1A1A1A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: WorkGoFonts.heading(
                          color: const Color(0xFF1A1A1A), // dark text on yellow
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PULSING DOT — animated live indicator
// ─────────────────────────────────────────────
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.color = const Color(0xFF22C55E),
    this.size = 10.0,
  });
  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _pulse.value * 0.7),
              blurRadius: widget.size * 1.6,
              spreadRadius: widget.size * 0.3 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AURORA ORB — colorful gradient circle icon holder
// ─────────────────────────────────────────────
class AuroraOrb extends StatelessWidget {
  const AuroraOrb({
    super.key,
    required this.icon,
    required this.gradient,
    this.size = 52.0,
    this.iconSize = 26.0,
    this.glowColor,
  });

  final IconData icon;
  final Gradient gradient;
  final double size;
  final double iconSize;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AURORA BADGE — styled status pill
// ─────────────────────────────────────────────
enum AuroraBadgeStyle { violet, cyan, amber, emerald, rose, info }

class AuroraBadge extends StatelessWidget {
  const AuroraBadge({
    super.key,
    required this.label,
    this.style = AuroraBadgeStyle.violet,
    this.fontSize = 10.0,
  });
  final String label;
  final AuroraBadgeStyle style;
  final double fontSize;

  // Light-theme badge colors — legible dark text on tinted backgrounds
  Color get _bg => switch (style) {
    AuroraBadgeStyle.violet => const Color(0xFFFFF3D6), // soft yellow
    AuroraBadgeStyle.cyan => const Color(0xFFDBEAFE), // soft blue
    AuroraBadgeStyle.amber => const Color(0xFFFEF3C7), // soft amber
    AuroraBadgeStyle.emerald => const Color(0xFFD1FAE5), // soft green
    AuroraBadgeStyle.rose => const Color(0xFFFEE2E2), // soft red
    AuroraBadgeStyle.info => const Color(0xFFDBEAFE), // soft blue
  };

  Color get _fg => switch (style) {
    AuroraBadgeStyle.violet => const Color(0xFF92400E), // dark amber text
    AuroraBadgeStyle.cyan => const Color(0xFF1E40AF), // dark blue text
    AuroraBadgeStyle.amber => const Color(0xFF92400E), // dark amber text
    AuroraBadgeStyle.emerald => const Color(0xFF065F46), // dark green text
    AuroraBadgeStyle.rose => const Color(0xFF991B1B), // dark red text
    AuroraBadgeStyle.info => const Color(0xFF1E40AF), // dark blue text
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: WorkGoFonts.badge(
          color: _fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHIMMER LOADER — animated skeleton shimmer
// ─────────────────────────────────────────────
class AuroraShimmer extends StatefulWidget {
  const AuroraShimmer({
    super.key,
    required this.height,
    this.borderRadius = 16.0,
    this.width,
  });
  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<AuroraShimmer> createState() => _AuroraShimmerState();
}

class _AuroraShimmerState extends State<AuroraShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [
                const Color(0xFFFFF3D6), // #FFF3D6 — warm yellow tint base
                const Color(0xFFFFF8E8), // shimmer highlight
                const Color(0xFFFFF3D6),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  AURORA SCAFFOLD — consistent background
// ─────────────────────────────────────────────
class AuroraScaffold extends StatelessWidget {
  const AuroraScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CX.canvas, // #FFFBF2 warm off-white
      extendBodyBehindAppBar: true,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Warm ambient blobs — subtle warm yellow/peach tints instead of neon
          Positioned(
            top: -80,
            left: -60,
            child: _AuroraBlob(
              color: const Color(0xFFFFB800).withValues(alpha: 0.06),
              size: 280,
            ),
          ),
          Positioned(
            top: 200,
            right: -80,
            child: _AuroraBlob(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
              size: 220,
            ),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: _AuroraBlob(
              color: const Color(0xFFFFE3C2).withValues(alpha: 0.10),
              size: 180,
            ),
          ),
          body,
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AURORA APPBAR
// ─────────────────────────────────────────────
class AuroraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuroraAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: CX.canvasCard, // white surface AppBar
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: Text(
        title,
        style: WorkGoFonts.display(
          color: CX.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      actions: actions,
      iconTheme: const IconThemeData(color: CX.textPrimary),
    );
  }
}

// ─────────────────────────────────────────────
//  SLIDE-FADE WIDGET — entry animation
// ─────────────────────────────────────────────
class SlideFadeIn extends StatefulWidget {
  const SlideFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 24.0,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<SlideFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CAnim.slow);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────
//  STAR ROW WIDGET — display-only
// ─────────────────────────────────────────────
class AuroraStarRow extends StatelessWidget {
  const AuroraStarRow({
    super.key,
    required this.rating,
    this.starSize = 14.0,
    this.showValue = true,
  });
  final double rating;
  final double starSize;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final fill = (rating - i).clamp(0.0, 1.0);
          return Icon(
            fill >= 0.75
                ? Icons.star_rounded
                : fill >= 0.25
                ? Icons.star_half_rounded
                : Icons.star_border_rounded,
            size: starSize,
            color: CX.amber,
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: CX.textSecondary,
              fontSize: starSize * 0.85,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED COUNTER — smooth number change
// ─────────────────────────────────────────────
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '₹',
    this.style,
  });
  final double value;
  final String prefix;
  final TextStyle? style;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CAnim.slow);
    _anim = Tween<double>(
      begin: widget.value,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
        begin: old.value,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '${widget.prefix}${_anim.value.toStringAsFixed(0)}',
        style:
            widget.style ??
            WorkGoFonts.numeric(
              color: CX.textPrimary, // dark text on light background
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CATEGORY COLOR & BENTO STYLE MAP
// ─────────────────────────────────────────────
class CategoryStyle {
  const CategoryStyle({
    required this.gradient,
    required this.glow,
    required this.icon,
    this.subtitle = "",
    this.startingPrice = "From ₹149",
    this.badge = "⚡ FAST",
    this.accentColor,
    this.quickSkills = const [],
  });
  final Gradient gradient;
  final Color glow;
  final IconData icon;
  final String subtitle;
  final String startingPrice;
  final String badge;
  final Color? accentColor;
  final List<String> quickSkills;
}

final Map<String, CategoryStyle> categoryStyleMap = {
  'Plumbing': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF0369A1), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFF06B6D4),
    icon: Icons.plumbing_rounded,
    subtitle: "Leaks, Taps & Drains",
    startingPrice: "From ₹149",
    badge: "⚡ 15 MIN",
    accentColor: Color(0xFF06B6D4),
    quickSkills: ["Tap Fix", "Pipe Leak", "Drain Clog"],
  ),
  'Electrical': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF92400E), Color(0xFFFBBF24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFFFBBF24),
    icon: Icons.bolt_rounded,
    subtitle: "Wiring, Switches & MCB",
    startingPrice: "From ₹149",
    badge: "POPULAR",
    accentColor: Color(0xFFFBBF24),
    quickSkills: ["Switchboard", "Short Circuit", "Fan/Light"],
  ),
  'Carpentry': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF9A3412), Color(0xFFF97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFFF97316),
    icon: Icons.handyman_rounded,
    subtitle: "Furniture, Doors & Locks",
    startingPrice: "From ₹199",
    badge: "EXPERT",
    accentColor: Color(0xFFFB923C),
    quickSkills: ["Door Lock", "Hinge Repair", "Custom Wood"],
  ),
  'Cleaning': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF065F46), Color(0xFF34D399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFF34D399),
    icon: Icons.cleaning_services_rounded,
    subtitle: "Deep Home & Kitchen Care",
    startingPrice: "From ₹299",
    badge: "DISCOUNT",
    accentColor: Color(0xFF34D399),
    quickSkills: ["Kitchen Deep", "Bathroom", "Sofa Care"],
  ),
  'Painting': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF5B21B6), Color(0xFFA78BFA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFFA78BFA),
    icon: Icons.format_paint_rounded,
    subtitle: "Walls, Waterproofing & Polish",
    startingPrice: "From ₹399",
    badge: "PRO",
    accentColor: Color(0xFFA78BFA),
    quickSkills: ["Wall Touchup", "Waterproofing", "Full Repaint"],
  ),
  'Appliance Repair': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF9F1239), Color(0xFFF43F5E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFFF43F5E),
    icon: Icons.home_repair_service_rounded,
    subtitle: "AC, Fridge & Washing Machine",
    startingPrice: "From ₹249",
    badge: "90D WARRANTY",
    accentColor: Color(0xFFFB7185),
    quickSkills: ["AC Service", "Fridge Cooling", "Washing Tech"],
  ),
  'Masonry': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF1E3A5F), Color(0xFF64748B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFF94A3B8),
    icon: Icons.foundation_rounded,
    subtitle: "Tiles, Plaster & Civil Work",
    startingPrice: "From ₹349",
    badge: "CIVIL",
    accentColor: Color(0xFF94A3B8),
    quickSkills: ["Tile Fitting", "Wall Crack", "Cement Work"],
  ),
  'Gardening': const CategoryStyle(
    gradient: LinearGradient(
      colors: [Color(0xFF064E3B), Color(0xFF10B981)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glow: Color(0xFF10B981),
    icon: Icons.yard_rounded,
    subtitle: "Lawn Mowing & Plant Care",
    startingPrice: "From ₹199",
    badge: "ECO",
    accentColor: Color(0xFFA3E635),
    quickSkills: ["Lawn Trimming", "Plant Pruning", "Fertilizer"],
  ),
};

CategoryStyle categoryStyle(String name) =>
    categoryStyleMap[name] ??
    const CategoryStyle(
      gradient: LinearGradient(
        colors: [Color(0xFFE8A500), Color(0xFFFFB800)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: Color(0xFFFFB800),
      icon: Icons.handyman_rounded,
      subtitle: "Verified Co-op Service",
      startingPrice: "From ₹149",
      badge: "VERIFIED",
    );
