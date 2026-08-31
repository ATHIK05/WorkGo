import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import '../karya_theme.dart';

class SpotlightTarget {
  final GlobalKey key;
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
  final VoidCallback onComplete;

  const KaryaSpotlightTourOverlay({
    super.key,
    required this.targets,
    this.scrollController,
    required this.onComplete,
  });

  static const String prefKey = "has_completed_spotlight_tour_v2";

  /// Checks SharedPreferences and triggers the real spotlight coachmark tour.
  /// If [isManual] is true, launches regardless of prior completion.
  static Future<void> startTour({
    required BuildContext context,
    required List<SpotlightTarget> targets,
    ScrollController? scrollController,
    bool isManual = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;

    if (!isManual && hasSeen) return;

    if (context.mounted) {
      final overlay = Overlay.of(context);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (ctx) => KaryaSpotlightTourOverlay(
          targets: targets,
          scrollController: scrollController,
          onComplete: () {
            entry.remove();
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateCurrentTargetPosition();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _calculateCurrentTargetPosition() async {
    if (!mounted || widget.targets.isEmpty) return;

    final target = widget.targets[_currentIndex];
    final renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final rect = Rect.fromLTWH(
        position.dx - target.padding.left,
        position.dy - target.padding.top,
        size.width + target.padding.horizontal,
        size.height + target.padding.vertical,
      );

      // Auto-scroll if target is outside of comfortable screen viewport
      final screenHeight = MediaQuery.of(context).size.height;
      if (widget.scrollController != null && (rect.top < 80 || rect.bottom > screenHeight - 120)) {
        try {
          await Scrollable.ensureVisible(
            target.key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: 0.35,
          );
          // Recalculate after scroll
          final updatedBox = target.key.currentContext?.findRenderObject() as RenderBox?;
          if (updatedBox != null) {
            final updatedPos = updatedBox.localToGlobal(Offset.zero);
            setState(() {
              _targetRect = Rect.fromLTWH(
                updatedPos.dx - target.padding.left,
                updatedPos.dy - target.padding.top,
                updatedBox.size.width + target.padding.horizontal,
                updatedBox.size.height + target.padding.vertical,
              );
            });
            return;
          }
        } catch (_) {}
      }

      setState(() => _targetRect = rect);
    } else {
      // If widget context is not ready yet, retry in 80ms
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _calculateCurrentTargetPosition();
    }
  }

  void _nextTarget() {
    HapticFeedback.mediumImpact();
    if (_currentIndex < widget.targets.length - 1) {
      setState(() {
        _currentIndex++;
        _targetRect = null;
      });
      _calculateCurrentTargetPosition();
    } else {
      _finishTour();
    }
  }

  void _previousTarget() {
    HapticFeedback.lightImpact();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _targetRect = null;
      });
      _calculateCurrentTargetPosition();
    }
  }

  void _finishTour() {
    HapticFeedback.heavyImpact();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targets[_currentIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLast = _currentIndex == widget.targets.length - 1;

    // Determine whether to render tooltip card above or below target
    final targetCenterY = _targetRect != null ? _targetRect!.center.dy : screenHeight * 0.4;
    final showTooltipBelow = targetCenterY < screenHeight * 0.55;

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

          // 3. Top Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: _finishTour,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Skip Tour",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ),

          // 4. Interactive Floating Coachmark Card
          if (_targetRect != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              top: showTooltipBelow
                  ? (_targetRect!.bottom + 16).clamp(80.0, screenHeight - 340.0)
                  : null,
              bottom: !showTooltipBelow
                  ? (screenHeight - _targetRect!.top + 16).clamp(80.0, screenHeight - 340.0)
                  : null,
              child: GestureDetector(
                onTap: () {}, // Prevent card tap from propagating
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
        color: const Color(0xFF140D2E).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KX.gold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: KX.gold.withValues(alpha: 0.3),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: KX.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "STEP ${_currentIndex + 1} OF ${widget.targets.length} · ${target.badgeText}",
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
                  child: const Text("Back", style: TextStyle(fontSize: 12)),
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
                        isLast ? "Finish Tour & Start 🚀" : "Next Feature",
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
    final backgroundPaint = Paint()..color = const Color(0xE8080415);

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
