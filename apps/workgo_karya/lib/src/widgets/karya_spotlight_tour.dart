import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../karya_theme.dart';

class SpotlightTarget {
  final GlobalKey key;
  final int navIndex;
  final String pageTitle;
  final String stepNumber;
  final String title;
  final String description;
  final String badgeText;
  final IconData icon;
  final ShapeBorder shape;
  final EdgeInsets padding;
  final List<String> bulletPoints;

  const SpotlightTarget({
    required this.key,
    this.navIndex = 0,
    required this.pageTitle,
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.icon,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    this.padding = const EdgeInsets.all(6),
    this.bulletPoints = const [],
  });
}

class KaryaSpotlightTourOverlay extends StatefulWidget {
  final List<SpotlightTarget> targets;
  final ScrollController? scrollController;
  final ValueChanged<int>? onPageChange;
  final VoidCallback onComplete;

  const KaryaSpotlightTourOverlay({
    super.key,
    required this.targets,
    this.scrollController,
    this.onPageChange,
    required this.onComplete,
  });

  static const String prefKey = "has_completed_spotlight_tour_v4";

  /// Checks SharedPreferences and triggers the real multi-page spotlight coachmark tour.
  /// If [isManual] is true, launches regardless of prior completion.
  static Future<void> startTour({
    required BuildContext context,
    required List<SpotlightTarget> targets,
    ScrollController? scrollController,
    ValueChanged<int>? onPageChange,
    bool isManual = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;

    if (!isManual && hasSeen) return;

    if (context.mounted) {
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (ctx) => KaryaSpotlightTourOverlay(
          targets: targets,
          scrollController: scrollController,
          onPageChange: onPageChange,
          onComplete: () {
            try {
              entry.remove();
            } catch (_) {}
            prefs.setBool(prefKey, true);
          },
        ),
      );

      overlay.insert(entry);
    }
  }

  @override
  State<KaryaSpotlightTourOverlay> createState() => _KaryaSpotlightTourOverlayState();
}

class _KaryaSpotlightTourOverlayState extends State<KaryaSpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  Rect? _targetRect;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateTarget(0);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _activateTarget(int index) async {
    if (!mounted || widget.targets.isEmpty) return;

    final currentNav = widget.targets[_currentIndex].navIndex;
    final nextNav = widget.targets[index].navIndex;

    if (nextNav != currentNav && widget.onPageChange != null) {
      if (mounted) {
        setState(() {
          _targetRect = null;
        });
      }
      widget.onPageChange!(nextNav);
      // Give AnimatedSwitcher time to render the new tab
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;

    setState(() {
      _currentIndex = index;
      _targetRect = null;
      _retryCount = 0;
    });

    _calculateCurrentTargetPosition();
  }

  Future<void> _calculateCurrentTargetPosition() async {
    if (!mounted || widget.targets.isEmpty) return;

    final target = widget.targets[_currentIndex];
    final renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null && renderBox.hasSize && renderBox.attached) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final rect = Rect.fromLTWH(
        position.dx - target.padding.left,
        position.dy - target.padding.top,
        size.width + target.padding.horizontal,
        size.height + target.padding.vertical,
      );

      // Auto-scroll if target is outside of screen viewport
      final screenHeight = MediaQuery.of(context).size.height;
      if (widget.scrollController != null && (rect.top < 70 || rect.bottom > screenHeight - 110)) {
        try {
          await Scrollable.ensureVisible(
            target.key.currentContext!,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: 0.35,
          );
          final updatedBox = target.key.currentContext?.findRenderObject() as RenderBox?;
          if (updatedBox != null && updatedBox.hasSize && updatedBox.attached) {
            final updatedPos = updatedBox.localToGlobal(Offset.zero);
            if (mounted) {
              setState(() {
                _targetRect = Rect.fromLTWH(
                  updatedPos.dx - target.padding.left,
                  updatedPos.dy - target.padding.top,
                  updatedBox.size.width + target.padding.horizontal,
                  updatedBox.size.height + target.padding.vertical,
                );
              });
            }
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _targetRect = rect);
      }
    } else {
      if (_retryCount < 15) {
        _retryCount++;
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) _calculateCurrentTargetPosition();
      } else {
        // Widget still not rendered — auto-skip to avoid blank overlay
        if (mounted && _currentIndex < widget.targets.length - 1) {
          _activateTarget(_currentIndex + 1);
        } else if (mounted) {
          _finishTour();
        }
      }
    }
  }

  void _nextTarget() {
    HapticFeedback.mediumImpact();
    if (_currentIndex < widget.targets.length - 1) {
      _activateTarget(_currentIndex + 1);
    } else {
      _finishTour();
    }
  }

  void _previousTarget() {
    HapticFeedback.lightImpact();
    if (_currentIndex > 0) {
      _activateTarget(_currentIndex - 1);
    }
  }

  void _finishTour() {
    HapticFeedback.heavyImpact();
    widget.onPageChange?.call(0);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targets[_currentIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLast = _currentIndex == widget.targets.length - 1;

    final targetCenterY = _targetRect != null ? _targetRect!.center.dy : screenHeight * 0.4;
    final showTooltipBelow = targetCenterY < screenHeight * 0.52;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Cutout Spotlight Dark Backdrop
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(screenWidth, screenHeight),
                painter: _SpotlightPainter(
                  targetRect: _targetRect,
                  pulseScale: _pulseController.value,
                ),
              );
            },
          ),

          // 2. Interactive Dismiss / Next Area
          Positioned.fill(
            child: GestureDetector(
              onTap: _nextTarget,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // 3. Top Skip & Page Indicator Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140D2E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KX.gold.withValues(alpha: 0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_rounded, color: KX.gold, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "${target.pageTitle.toUpperCase()} · STEP ${_currentIndex + 1}/${widget.targets.length}",
                        style: const TextStyle(
                          color: KX.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _finishTour,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Skip Tour",
                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Interactive Floating Coachmark Card (ALWAYS rendered so it NEVER disappears)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            top: _targetRect != null
                ? (showTooltipBelow
                    ? (_targetRect!.bottom + 14).clamp(70.0, screenHeight - 340.0)
                    : null)
                : null,
            bottom: _targetRect != null
                ? (!showTooltipBelow
                    ? (screenHeight - _targetRect!.top + 14).clamp(70.0, screenHeight - 340.0)
                    : null)
                : 28.0, // Fallback bottom anchor if measuring
            child: GestureDetector(
              onTap: () {}, // Prevent card tap from dismissing
              child: _buildCoachmarkCard(target, isLast),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachmarkCard(SpotlightTarget target, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF140D2E).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KX.gold.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: KX.gold.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: KX.luminaVioletGold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: KX.gold.withValues(alpha: 0.4), blurRadius: 10),
                  ],
                ),
                child: Icon(target.icon, color: const Color(0xFF1E1035), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: KX.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${target.pageTitle.toUpperCase()} · ${target.badgeText}",
                        style: const TextStyle(
                          color: KX.gold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description Text
          Text(
            target.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),

          // Bullet Points
          if (target.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              children: target.bulletPoints.map((point) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),

          // Navigation Controls Row
          Row(
            children: [
              if (_currentIndex > 0) ...[
                OutlinedButton(
                  onPressed: _previousTarget,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("back_btn".tr(), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextTarget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? const Color(0xFF10B981) : KX.gold,
                    foregroundColor: const Color(0xFF1E1035),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? "complete_full_tour_btn".tr() : "next_page_feature_btn".tr(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Icon(isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseScale;

  _SpotlightPainter({this.targetRect, required this.pulseScale});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xEA080415);

    if (targetRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      return;
    }

    // 1. Draw backdrop with cutout hole
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(targetRect!, const Radius.circular(18)));

    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, backgroundPaint);

    // 2. Draw glowing pulsing border around targeted widget
    final pulseExtra = pulseScale * 6.0;
    final pulseRect = Rect.fromLTRB(
      targetRect!.left - pulseExtra,
      targetRect!.top - pulseExtra,
      targetRect!.right + pulseExtra,
      targetRect!.bottom + pulseExtra,
    );

    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6 - (pulseScale * 0.3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(RRect.fromRectAndRadius(pulseRect, Radius.circular(18 + pulseExtra)), glowPaint);

    final sharpBorderPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(RRect.fromRectAndRadius(targetRect!, const Radius.circular(18)), sharpBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.pulseScale != pulseScale;
  }
}
