import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'safe_text.dart';

enum WorkGoButtonVariant { primary, secondary, emergency, call, danger }

class WorkGoButton extends StatefulWidget {
  const WorkGoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WorkGoButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 52.0,
    this.width,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final WorkGoButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final bool isFullWidth;

  @override
  State<WorkGoButton> createState() => _WorkGoButtonState();
}

class _WorkGoButtonState extends State<WorkGoButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _scaleController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _scaleController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Visual config per variant ────────────────────────────────────────────
    final (gradient, textColor, border, shadowColor) = switch (widget.variant) {
      WorkGoButtonVariant.primary => (
          // Solid amber yellow — premium, confident CTA
          const LinearGradient(
            colors: [WorkGoColors.primary, WorkGoColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          const Color(0xFF1A1A1A),      // Dark text on yellow
          null,
          WorkGoColors.primaryDark.withValues(alpha: 0.30),
        ),
      WorkGoButtonVariant.secondary => (
          // Warm tint fill — soft, no harsh border
          LinearGradient(
            colors: [
              const Color(0xFFF9F6EE),
              const Color(0xFFF5F0E6),
            ],
          ),
          WorkGoColors.textPrimary,
          Border.all(color: WorkGoColors.dividerLight, width: 1.5),
          Colors.transparent,
        ),
      WorkGoButtonVariant.emergency => (
          const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Colors.white,
          null,
          const Color(0xFFDC2626).withValues(alpha: 0.35),
        ),
      WorkGoButtonVariant.call => (
          const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Colors.white,
          null,
          const Color(0xFF10B981).withValues(alpha: 0.30),
        ),
      WorkGoButtonVariant.danger => (
          const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Colors.white,
          null,
          const Color(0xFFEF4444).withValues(alpha: 0.30),
        ),
    };

    final content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: Container(
          height: widget.height,
          width: widget.isFullWidth ? (widget.width ?? double.infinity) : widget.width,
          padding: const EdgeInsets.symmetric(horizontal: WorkGoSpacing.md),
          decoration: BoxDecoration(
            gradient: widget.onPressed == null ? null : gradient,
            color: widget.onPressed == null
                ? WorkGoColors.dividerLight
                : null,
            borderRadius: BorderRadius.circular(WorkGoSpacing.radiusFull),
            border: border,
            boxShadow: [
              if (widget.onPressed != null && shadowColor != Colors.transparent)
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 19, color: textColor),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: SafeText(
                          widget.label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                          enableAutoShrink: true,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return content;
  }
}
