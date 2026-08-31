import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MapMode { broadcastScanning, routeNavigation }

class InteractiveRapidoMap extends StatefulWidget {
  const InteractiveRapidoMap({
    super.key,
    required this.serviceCategory,
    this.mode = MapMode.broadcastScanning,
    this.artisanName,
    this.etaMinutes = 4,
    this.distanceKm = 1.6,
    this.workerProgress = 0.0, // 0.0 to 1.0 along the route
    this.pickupAddress = "1148 E Main St, Thanjavur",
    this.height = 360,
    this.onTap,
  });

  final String serviceCategory;
  final MapMode mode;
  final String? artisanName;
  final int etaMinutes;
  final double distanceKm;
  final double workerProgress;
  final String pickupAddress;
  final double height;
  final VoidCallback? onTap;

  @override
  State<InteractiveRapidoMap> createState() => _InteractiveRapidoMapState();
}

class _InteractiveRapidoMapState extends State<InteractiveRapidoMap>
    with TickerProviderStateMixin {
  late AnimationController _radarCtrl;
  late AnimationController _roamCtrl;
  late AnimationController _routeDashCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _roamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();

    _routeDashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _roamCtrl.dispose();
    _routeDashCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  (Color, Color, IconData, String) _getTradeAsset(String category) {
    final cat = category.toLowerCase();
    if (cat.contains("plumb")) {
      return (
        const Color(0xFF00E5FF),
        const Color(0xFF0070F3),
        Icons.plumbing_rounded,
        "Plumbing Unit",
      );
    }
    if (cat.contains("electr")) {
      return (
        const Color(0xFFFBBF24),
        const Color(0xFFD97706),
        Icons.bolt_rounded,
        "Volt Service Bike",
      );
    }
    if (cat.contains("carpent")) {
      return (
        const Color(0xFFFB923C),
        const Color(0xFFC2410C),
        Icons.carpenter_rounded,
        "Woodcraft Mobile",
      );
    }
    if (cat.contains("paint")) {
      return (
        const Color(0xFFF43F5E),
        const Color(0xFFBE123C),
        Icons.format_paint_rounded,
        "Color Express",
      );
    }
    if (cat.contains("ac") || cat.contains("appliance") || cat.contains("cool")) {
      return (
        const Color(0xFF38BDF8),
        const Color(0xFF0284C7),
        Icons.ac_unit_rounded,
        "Cooling Tech Express",
      );
    }
    return (
      const Color(0xFF10B981),
      const Color(0xFF047857),
      Icons.handyman_rounded,
      "Co-op Rapid Cruiser",
    );
  }

  @override
  Widget build(BuildContext context) {
    final (tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel) =
        _getTradeAsset(widget.serviceCategory);

    return Container(
      height: widget.height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF080612),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tradeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tradeColor.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Vector Map Canvas (Streets, Arteries, Blocks, Route)
          AnimatedBuilder(
            animation: Listenable.merge([_radarCtrl, _roamCtrl, _routeDashCtrl, _pulseCtrl]),
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RapidoMapPainter(
                  mode: widget.mode,
                  radarProgress: _radarCtrl.value,
                  roamProgress: _roamCtrl.value,
                  routeDashOffset: _routeDashCtrl.value,
                  pulseProgress: _pulseCtrl.value,
                  workerProgress: widget.workerProgress,
                  primaryColor: tradeColor,
                  secondaryColor: tradeDarkColor,
                ),
              );
            },
          ),

          // 2. Custom Vehicle Asset Over Map
          if (widget.mode == MapMode.routeNavigation)
            _buildNavigatingVehicle(tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel)
          else
            _buildScanningOverlay(tradeColor, tradeIcon, tradeVehicleLabel),

          // 3. Top Floating Location Pill
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0B24).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF43F5E),
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "PICKUP ADDRESS",
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                widget.pickupAddress,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.mode == MapMode.routeNavigation) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tradeColor, tradeDarkColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: tradeColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${widget.etaMinutes} MIN",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "${widget.distanceKm} km",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. Map Bottom Live Radar HUD
          Positioned(
            bottom: 12,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF090716).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tradeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.mode == MapMode.routeNavigation
                              ? const Color(0xFF10B981)
                              : tradeColor,
                          boxShadow: [
                            BoxShadow(
                              color: (widget.mode == MapMode.routeNavigation
                                      ? const Color(0xFF10B981)
                                      : tradeColor)
                                  .withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.mode == MapMode.routeNavigation
                            ? "Artisan En Route via GPS ($tradeVehicleLabel)"
                            : "Broadcasting within 10 km live radius",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.mode == MapMode.routeNavigation ? "LIVE GPS" : "ACTIVE RADAR",
                    style: TextStyle(
                      color: tradeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

  Widget _buildNavigatingVehicle(
    Color tradeColor,
    Color tradeDarkColor,
    IconData tradeIcon,
    String tradeVehicleLabel,
  ) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Compute vehicle position along a smooth Bezier S-curve road
            final startX = constraints.maxWidth * 0.18;
            final startY = constraints.maxHeight * 0.78;
            final endX = constraints.maxWidth * 0.72;
            final endY = constraints.maxHeight * 0.36;

            final t = widget.workerProgress.clamp(0.0, 1.0);
            final curX = startX + (endX - startX) * t;
            final curY = startY + (endY - startY) * t - (math.sin(t * math.pi) * 35);

            return Stack(
              children: [
                // Destination (Customer Home Pin)
                Positioned(
                  left: endX - 18,
                  top: endY - 36,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "YOU",
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF43F5E),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),

                // Moving Trade Vehicle Pin
                Positioned(
                  left: curX - 22,
                  top: curY - 22,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [tradeColor, tradeDarkColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tradeColor.withValues(alpha: 0.7),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(tradeIcon, color: Colors.black, size: 22),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0B24),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tradeColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          widget.artisanName ?? "Artisan Partner",
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScanningOverlay(
    Color tradeColor,
    IconData tradeIcon,
    String tradeVehicleLabel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth * 0.5;
        final centerY = constraints.maxHeight * 0.5;

        return Stack(
          children: [
            // Center Customer Pin
            Positioned(
              left: centerX - 18,
              top: centerY - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF43F5E),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.8),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
              ),
            ),

            // Roaming trade vehicles (Simulated nearby captains)
            AnimatedBuilder(
              animation: _roamCtrl,
              builder: (context, _) {
                final angle = _roamCtrl.value * 2 * math.pi;
                final r1 = constraints.maxWidth * 0.28;
                final r2 = constraints.maxWidth * 0.38;

                final x1 = centerX + r1 * math.cos(angle);
                final y1 = centerY + r1 * math.sin(angle) * 0.6;

                final x2 = centerX + r2 * math.cos(angle + math.pi * 0.8);
                final y2 = centerY + r2 * math.sin(angle + math.pi * 0.8) * 0.6;

                final x3 = centerX + r1 * 1.2 * math.cos(angle + math.pi * 1.5);
                final y3 = centerY + r1 * 1.2 * math.sin(angle + math.pi * 1.5) * 0.6;

                return Stack(
                  children: [
                    _buildMiniVehiclePin(x1, y1, tradeColor, tradeIcon),
                    _buildMiniVehiclePin(x2, y2, const Color(0xFF10B981), Icons.handyman_rounded),
                    _buildMiniVehiclePin(x3, y3, const Color(0xFFFBBF24), Icons.bolt_rounded),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniVehiclePin(double x, double y, Color color, IconData icon) {
    return Positioned(
      left: x - 15,
      top: y - 15,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 15),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  MAP VECTOR CANVAS PAINTER
// ──────────────────────────────────────────────────────────────
class _RapidoMapPainter extends CustomPainter {
  _RapidoMapPainter({
    required this.mode,
    required this.radarProgress,
    required this.roamProgress,
    required this.routeDashOffset,
    required this.pulseProgress,
    required this.workerProgress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final MapMode mode;
  final double radarProgress;
  final double roamProgress;
  final double routeDashOffset;
  final double pulseProgress;
  final double workerProgress;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF080612);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Draw Street Grid & Urban Blocks
    final streetPaint = Paint()
      ..color = const Color(0xFF1B1736)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final minorStreetPaint = Paint()
      ..color = const Color(0xFF130E26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final blockPaint = Paint()..color = const Color(0xFF0D0A1C);

    // Urban City Blocks
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20, 20, size.width * 0.35, size.height * 0.3), const Radius.circular(8)), blockPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, 20, size.width * 0.38, size.height * 0.25), const Radius.circular(8)), blockPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20, size.height * 0.6, size.width * 0.4, size.height * 0.3), const Radius.circular(8)), blockPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, size.height * 0.55, size.width * 0.4, size.height * 0.35), const Radius.circular(8)), blockPaint);

    // Horizontal & Vertical Grid Streets
    final path = Path();
    path.moveTo(0, size.height * 0.28);
    path.lineTo(size.width, size.height * 0.28);
    path.moveTo(0, size.height * 0.52);
    path.lineTo(size.width, size.height * 0.52);
    path.moveTo(0, size.height * 0.76);
    path.lineTo(size.width, size.height * 0.76);

    path.moveTo(size.width * 0.25, 0);
    path.lineTo(size.width * 0.25, size.height);
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.5, size.height);
    path.moveTo(size.width * 0.78, 0);
    path.lineTo(size.width * 0.78, size.height);

    canvas.drawPath(path, minorStreetPaint);

    // Main Artery Curved Boulevard
    final artery = Path();
    artery.moveTo(0, size.height * 0.85);
    artery.cubicTo(size.width * 0.3, size.height * 0.7, size.width * 0.6, size.height * 0.3, size.width, size.height * 0.2);
    canvas.drawPath(artery, streetPaint);

    // 2. Mode Specific Drawing
    if (mode == MapMode.broadcastScanning) {
      _paintRadarScan(canvas, size);
    } else {
      _paintRouteNavigation(canvas, size);
    }
  }

  void _paintRadarScan(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Glowing Distance Rings (2 km, 5 km, 10 km)
    for (int i = 1; i <= 3; i++) {
      final radius = (size.width * 0.16 * i);
      final ringPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.12 * (4 - i) / 3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius, ringPaint);
    }

    // Expanding Radar Sonar Waves
    final waveRadius = (size.width * 0.45) * radarProgress;
    final wavePaint = Paint()
      ..color = primaryColor.withValues(alpha: (1.0 - radarProgress) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, waveRadius, wavePaint);

    // Rotating Radar Sweep Cone
    final sweepAngle = radarProgress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 3,
        colors: [
          primaryColor.withValues(alpha: 0.35),
          primaryColor.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.45));

    canvas.drawCircle(center, size.width * 0.45, sweepPaint);
  }

  void _paintRouteNavigation(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.18, size.height * 0.78);
    final end = Offset(size.width * 0.72, size.height * 0.36);

    final routePath = Path();
    routePath.moveTo(start.dx, start.dy);
    routePath.cubicTo(
      size.width * 0.35,
      size.height * 0.85,
      size.width * 0.45,
      size.height * 0.25,
      end.dx,
      end.dy,
    );

    // Base Road Glow
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, glowPaint);

    // Solid Route Line
    final linePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, linePaint);

    // Inner White Direction Dash
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant _RapidoMapPainter oldDelegate) => true;
}
