import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workgo_core/workgo_core.dart';

// ══════════════════════════════════════════════════════════════
//  KARYA DESIGN SYSTEM — "Artisan Light + Amber"
//  Premium artisan cockpit: Warm White Canvas · Amber Gold · Dark Text
// ══════════════════════════════════════════════════════════════

class KaryaColors {
  KaryaColors._();
  static const Color backgroundLight = Color(0xFFFFFBF2);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color brandYellow = Color(0xFFFFB800);
  static const Color brandAmber = Color(0xFFE8A500);
  static const Color emerald = Color(0xFF10B981);
}

class KX {
  KX._();

  // Canvas & Surfaces — Warm Off-White
  static const Color canvas = Color(0xFFFFFBF2);       // App background
  static const Color canvasCard = Color(0xFFFFFFFF);   // Card surface
  static const Color canvasMid = Color(0xFFFFF8EE);    // Mid surface
  static const Color canvasElevated = Color(0xFFFFF3D6); // Accent tint panel
  static const Color dividerLight = Color(0xFFF0EDE6);   // Subtle divider

  // Primary — Amber Yellow (replaces violet/purple)
  static const Color purpleDeep = Color(0xFFE8A500);   // Pressed amber
  static const Color violet = Color(0xFFFFB800);       // Primary CTA amber
  static const Color violetVivid = Color(0xFFFFCD4A);  // Hover amber
  static const Color violetNeon = Color(0xFFFFE066);   // Bright amber
  static const Color violetLight = Color(0xFFFFF3D6);  // Soft amber tint
  static const Color violetGlow = Color(0xFFFFB800);   // Glow (softer on light)

  // Accent Gold — warm gold family
  static const Color gold = Color(0xFFFFB800);
  static const Color yellowNeon = Color(0xFFFFCD4A);
  static const Color amber = Color(0xFFF59E0B);        // Warning
  static const Color amberDark = Color(0xFFD97706);
  static const Color brandAmber = Color(0xFFE8A500);
  static const Color goldGlow = Color(0xFFFFB800);

  // Supporting Semantics
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color rose = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF3B82F6);
  static const Color cyanLight = Color(0xFF93C5FD);

  // Glass & Borders — Light-aware
  static Color glass(double opacity) => Colors.black.withValues(alpha: opacity * 0.04);
  static Color glassCard = const Color(0xFFFFF3D6).withValues(alpha: 0.5);
  static Color glassBorder = const Color(0xFFFFB800).withValues(alpha: 0.18);
  static Color glassBorderBright = const Color(0xFFFFB800).withValues(alpha: 0.40);

  // Text — Dark on warm white
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFB0B0B0);

  // Reference Template Pastel & Dock Tokens
  static const Color pastelAmber = Color(0xFFFFDE9C);     // Sunny amber tall plan card
  static const Color pastelAmberLight = Color(0xFFFFF1D6);
  static const Color pastelLavender = Color(0xFFE9E4FF);  // Soft lavender hero card
  static const Color pastelSky = Color(0xFFD6EBFF);       // Soft sky blue radar card
  static const Color pastelPink = Color(0xFFFFD6EC);      // Soft pink action capsule
  static const Color pastelMint = Color(0xFFD1FAE5);      // Soft mint verified pill
  static const Color dockBlack = Color(0xFF141416);       // Floating dark capsule dock
  static const Color pillSurface = Color(0xFFFFFFFF);     // Pure white capsule pill

  // Gradients — Amber/Yellow family
  static const LinearGradient luminaVioletGold = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFCD4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient luminaGoldViolet = LinearGradient(
    colors: [Color(0xFFFFCD4A), Color(0xFFE8A500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraVioletNeon = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFCD4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient solarGold = LinearGradient(
    colors: [Color(0xFFE8A500), Color(0xFFFFB800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraAccept = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraDecline = LinearGradient(
    colors: [Color(0xFF9F1239), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraOnline = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
  );

  static const LinearGradient auroraOffline = LinearGradient(
    colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)],  // warm gray offline
  );
}

// ──────────────────────────────────────────────────────────────
//  PHYSICAL ANIMATIONS & SPRING CURVES
// ──────────────────────────────────────────────────────────────
class KAnim {
  KAnim._();
  static const Duration snap = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  static const Curve spring = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve easeOut = Curves.easeOutCubic;
}

// ──────────────────────────────────────────────────────────────
//  KARYA LUMINA SCAFFOLD (Obsidian Canvas + Electric Nebulas)
// ──────────────────────────────────────────────────────────────
class KaryaScaffold extends StatelessWidget {
  const KaryaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KX.canvas,  // #FFFBF2 warm off-white
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          // Warm ambient blobs on light background
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB800).withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFE3C2).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  KARYA APP BAR (Clean, high contrast, zero-clutter)
// ──────────────────────────────────────────────────────────────
class KaryaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KaryaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: KX.canvasCard,  // white surface
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading ??
          (Navigator.canPop(context)
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EA), // warm gray tint
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF0EDE6)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14, color: KX.textPrimary),
                  ),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: WorkGoFonts.display(
                color: KX.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: WorkGoFonts.body(
                color: KX.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: actions,
      iconTheme: const IconThemeData(color: KX.textPrimary),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  KARYA GLASS CARD (Luminous Lumina Finish)
// ──────────────────────────────────────────────────────────────
class KaryaCard extends StatelessWidget {
  const KaryaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20.0,
    this.borderColor,
    this.glowColor,
    this.onTap,
    this.gradient,
    this.blurSigma = 16.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double blurSigma;  // API-compat, not used on light

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? KX.canvasCard : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.1)
            : const Border.fromBorderSide(
                BorderSide(color: Color(0xFFF0EDE6), width: 1)), // warm divider
        boxShadow: glow != null
            ? [
                const BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: glow.withValues(alpha: 0.14),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x0E000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x10FFB800),  // warm amber tint
                  blurRadius: 20,
                  spreadRadius: -3,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return _KaryaTappable(
        borderRadius: borderRadius,
        onTap: onTap!,
        child: content,
      );
    }

    return content;
  }
}

class _KaryaTappable extends StatefulWidget {
  const _KaryaTappable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<_KaryaTappable> createState() => _KaryaTappableState();
}

class _KaryaTappableState extends State<_KaryaTappable>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: KAnim.snap);
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
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

// ──────────────────────────────────────────────────────────────
//  KARYA TACTILE BUTTON
// ──────────────────────────────────────────────────────────────
class KaryaButton extends StatefulWidget {
  const KaryaButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient,
    this.glowColor,
    this.height = 48.0,
    this.isFullWidth = true,
    this.borderRadius = 16.0,
    this.fontSize = 14.0,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Color? glowColor;
  final double height;
  final bool isFullWidth;
  final double borderRadius;
  final double fontSize;
  final bool isLoading;

  @override
  State<KaryaButton> createState() => _KaryaButtonState();
}

class _KaryaButtonState extends State<KaryaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: KAnim.snap);
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? KX.luminaVioletGold;
    final glow = widget.glowColor ?? KX.violet;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        if (widget.onPressed != null && !widget.isLoading) widget.onPressed!();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: widget.height,
          width: widget.isFullWidth ? double.infinity : null,
          padding: widget.isFullWidth
              ? null
              : const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.40),
                blurRadius: 18,
                spreadRadius: -3,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: WorkGoFonts.heading(
                          color: Colors.white,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w900,
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

// ──────────────────────────────────────────────────────────────
//  KARYA SLIDE-TO-ACTION (Slide to Accept / Complete)
//  Market-defining dispatch slider with soundful physical drag!
// ──────────────────────────────────────────────────────────────
class KaryaSlideAction extends StatefulWidget {
  const KaryaSlideAction({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.gradient = KX.luminaVioletGold,
    this.glowColor = KX.gold,
    this.icon = Icons.arrow_forward_ios_rounded,
    this.height = 56.0,
    this.completedLabel = "Confirmed ✓",
  });

  final String label;
  final String completedLabel;
  final Future<void> Function() onConfirmed;
  final Gradient gradient;
  final Color glowColor;
  final IconData icon;
  final double height;

  @override
  State<KaryaSlideAction> createState() => _KaryaSlideActionState();
}

class _KaryaSlideActionState extends State<KaryaSlideAction>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  bool _isLoading = false;

  late AnimationController _springCtrl;
  late Animation<double> _springAnim;

  @override
  void initState() {
    super.initState();
    _springCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isCompleted || _isLoading) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  Future<void> _onDragEnd(DragEndDetails details, double maxDrag) async {
    if (_isCompleted || _isLoading) return;
    if (_dragPosition >= maxDrag * 0.75) {
      // Trigger confirmation!
      HapticFeedback.heavyImpact();
      setState(() {
        _dragPosition = maxDrag;
        _isLoading = true;
      });
      await widget.onConfirmed();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCompleted = true;
        });
      }
    } else {
      // Spring back
      HapticFeedback.lightImpact();
      _springAnim = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springCtrl, curve: Curves.easeOutBack),
      )..addListener(() {
          setState(() => _dragPosition = _springAnim.value);
        });
      _springCtrl.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbSize = widget.height - 8;
        final maxDrag = constraints.maxWidth - thumbSize - 8;
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: KX.canvasMid,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: Color.lerp(KX.glassBorder, widget.glowColor, progress)!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.25 * progress),
                blurRadius: 18 * progress,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Dynamic fill trail
              Container(
                width: _dragPosition + thumbSize + 4,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // Central Label
              Center(
                child: AnimatedOpacity(
                  duration: KAnim.fast,
                  opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCompleted ? widget.completedLabel : widget.label,
                        style: WorkGoFonts.heading(
                          color: KX.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.double_arrow_rounded,
                        color: KX.gold.withValues(alpha: 0.8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // Glowing Draggable Thumb
              Positioned(
                left: 4 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (d) => _onDragEnd(d, maxDrag),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.gradient,
                      boxShadow: [
                        BoxShadow(
                          color: widget.glowColor.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isCompleted
                                  ? Icons.check_rounded
                                  : widget.icon,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  KARYA ORB — gradient icon holder
// ──────────────────────────────────────────────────────────────
class KaryaOrb extends StatelessWidget {
  const KaryaOrb({
    super.key,
    required this.icon,
    required this.gradient,
    this.glowColor,
    this.size = 46,
    this.iconSize = 22,
  });

  final IconData icon;
  final LinearGradient gradient;
  final Color? glowColor;
  final double size;
  final double iconSize;

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
                  color: glowColor!.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  KARYA BADGE — Cyber Lumina Pill
// ──────────────────────────────────────────────────────────────
enum KaryaBadgeStyle { gold, violet, emerald, rose, teal, info }

class KaryaBadge extends StatelessWidget {
  const KaryaBadge({
    super.key,
    required this.label,
    this.style = KaryaBadgeStyle.gold,
    this.fontSize = 9.5,
  });

  final String label;
  final KaryaBadgeStyle style;
  final double fontSize;

  (Color, Color) get _colors => switch (style) {
        KaryaBadgeStyle.gold => (KX.gold.withValues(alpha: 0.20), KX.gold),
        KaryaBadgeStyle.violet => (KX.violetNeon.withValues(alpha: 0.20), KX.violetLight),
        KaryaBadgeStyle.emerald => (KX.emerald.withValues(alpha: 0.20), KX.emeraldLight),
        KaryaBadgeStyle.rose => (KX.rose.withValues(alpha: 0.20), KX.rose),
        KaryaBadgeStyle.teal => (KX.info.withValues(alpha: 0.20), KX.info),
        KaryaBadgeStyle.info => (KX.info.withValues(alpha: 0.20), KX.info),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        label,
        style: WorkGoFonts.badge(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  PULSING STATUS DOT
// ──────────────────────────────────────────────────────────────
class KPulsingDot extends StatefulWidget {
  const KPulsingDot({super.key, required this.color, this.size = 8.0});
  final Color color;
  final double size;

  @override
  State<KPulsingDot> createState() => _KPulsingDotState();
}

class _KPulsingDotState extends State<KPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
              color: widget.color.withValues(alpha: _pulse.value * 0.8),
              blurRadius: widget.size * 2.0,
              spreadRadius: widget.size * 0.4 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SLIDE-FADE ENTRY ANIMATOR
// ──────────────────────────────────────────────────────────────
class KSlideFadeIn extends StatefulWidget {
  const KSlideFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 16.0,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<KSlideFadeIn> createState() => _KSlideFadeInState();
}

class _KSlideFadeInState extends State<KSlideFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: KAnim.slow);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.0, 0.75, curve: Curves.easeOut)),
    );
    _slide = Tween<Offset>(
            begin: Offset(0, widget.offsetY / 100), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

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

// ──────────────────────────────────────────────────────────────
//  SHIMMER SKELETON
// ──────────────────────────────────────────────────────────────
class KaryaShimmer extends StatefulWidget {
  const KaryaShimmer({super.key, required this.height, this.borderRadius = 16.0, this.width});
  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<KaryaShimmer> createState() => _KaryaShimmerState();
}

class _KaryaShimmerState extends State<KaryaShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: [
              KX.canvasCard,
              KX.violet.withValues(alpha: 0.15),
              KX.canvasCard,
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  ANIMATED NUMBER COUNTER
// ──────────────────────────────────────────────────────────────
class KAnimatedCounter extends StatelessWidget {
  const KAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = "₹",
  });

  final double value;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: KAnim.verySlow,
      curve: Curves.easeOutCubic,
      builder: (_, val, __) => Text(
        "$prefix${val.toStringAsFixed(0)}",
        style: style ??
            WorkGoFonts.numeric(
              color: KX.gold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
      ),
    );
  }
}
