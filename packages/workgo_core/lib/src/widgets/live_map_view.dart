// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'interactive_rapido_map.dart' show MapMode;

// ──────────────────────────────────────────────────────────────────────────────
// LiveMapView — Drop-in replacement for InteractiveRapidoMap.
//
// Uses real OpenStreetMap tiles (light Rapido-style) with live worker markers.
// When real GPS coords are unavailable, falls back to a simulated illustrated
// position using workerProgress (zero regression vs. old widget).
//
// Data source: booking.workerLatitude / workerLongitude from Firestore
// streamed via BookingService.streamBooking() — no new data source.
// ──────────────────────────────────────────────────────────────────────────────

class LiveMapView extends StatefulWidget {
  const LiveMapView({
    super.key,
    required this.serviceCategory,
    this.mode = MapMode.routeNavigation,
    this.artisanName,
    this.etaMinutes = 4,
    this.distanceKm = 1.6,
    this.workerProgress = 0.0,
    this.pickupAddress = "1148 E Main St, Thanjavur",
    this.height = 260,
    this.onTap,
    // Real GPS bindings — optional (falls back to illustrated if null)
    this.partnerLatitude,
    this.partnerLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.nearbyWorkerLocations,
  });

  // ── Shared interface (identical to InteractiveRapidoMap) ──────────────────
  final String serviceCategory;
  final MapMode mode;
  final String? artisanName;
  final int etaMinutes;
  final double distanceKm;
  final double workerProgress;
  final String pickupAddress;
  final double height;
  final VoidCallback? onTap;

  // ── Real GPS bindings (new, optional) ────────────────────────────────────
  final double? partnerLatitude;
  final double? partnerLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final List<LatLng>? nearbyWorkerLocations;

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;

  // Defaults: Erode / Tamil Nadu coordinates when no live GPS yet
  static const LatLng _defaultPickup = LatLng(11.3410, 77.7172);
  static const LatLng _defaultPartner = LatLng(11.3310, 77.7050);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void didUpdateWidget(LiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When partner location updates, smoothly re-fit camera
    final partnerChanged = oldWidget.partnerLatitude != widget.partnerLatitude ||
        oldWidget.partnerLongitude != widget.partnerLongitude;
    if (partnerChanged && _hasRealCoords) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    super.dispose();
  }

  bool get _hasRealCoords =>
      widget.partnerLatitude != null &&
      widget.partnerLongitude != null &&
      widget.pickupLatitude != null &&
      widget.pickupLongitude != null;

  LatLng get _partnerLatLng => _hasRealCoords
      ? LatLng(widget.partnerLatitude!, widget.partnerLongitude!)
      : _estimatedPartnerFromProgress;

  LatLng get _pickupLatLng =>
      (widget.pickupLatitude != null && widget.pickupLongitude != null)
          ? LatLng(widget.pickupLatitude!, widget.pickupLongitude!)
          : _defaultPickup;

  /// When no real GPS: estimate partner position from workerProgress (0.0–1.0)
  LatLng get _estimatedPartnerFromProgress {
    final t = widget.workerProgress.clamp(0.0, 1.0);
    final lat = _defaultPickup.latitude +
        (_defaultPartner.latitude - _defaultPickup.latitude) * (1.0 - t);
    final lng = _defaultPickup.longitude +
        (_defaultPartner.longitude - _defaultPickup.longitude) * (1.0 - t);
    return LatLng(lat, lng);
  }

  void _fitBounds() {
    if (!mounted) return;
    try {
      final bounds = LatLngBounds.fromPoints([_partnerLatLng, _pickupLatLng]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 80, 60, 80),
        ),
      );
    } catch (_) {}
  }

  (Color, Color, IconData, String) _getTradeAsset(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('plumb')) {
      return (const Color(0xFF0284C7), const Color(0xFF0369A1), Icons.plumbing_rounded, 'Plumbing Unit');
    }
    if (cat.contains('electr')) {
      return (const Color(0xFFD97706), const Color(0xFFB45309), Icons.bolt_rounded, 'Volt Service Bike');
    }
    if (cat.contains('carpent')) {
      return (const Color(0xFFEA580C), const Color(0xFFC2410C), Icons.carpenter_rounded, 'Woodcraft Mobile');
    }
    if (cat.contains('paint')) {
      return (const Color(0xFFE11D48), const Color(0xFFBE123C), Icons.format_paint_rounded, 'Color Express');
    }
    if (cat.contains('ac') || cat.contains('appliance') || cat.contains('cool')) {
      return (const Color(0xFF0284C7), const Color(0xFF0369A1), Icons.ac_unit_rounded, 'Cooling Tech Express');
    }
    return (const Color(0xFF059669), const Color(0xFF047857), Icons.handyman_rounded, 'Co-op Rapid Cruiser');
  }

  @override
  Widget build(BuildContext context) {
    final (tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel) =
        _getTradeAsset(widget.serviceCategory);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Real OSM Map Tiles ──────────────────────────────────────────
            _buildRealMap(tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel),

            // ── Top Address Pill ────────────────────────────────────────────
            _buildAddressPill(tradeColor, tradeDarkColor),

            // ── Bottom Status HUD ───────────────────────────────────────────
            _buildBottomHud(tradeColor, tradeVehicleLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildRealMap(
    Color tradeColor,
    Color tradeDarkColor,
    IconData tradeIcon,
    String tradeVehicleLabel,
  ) {
    final isRoute = widget.mode == MapMode.routeNavigation;
    final partner = _partnerLatLng;
    final pickup = _pickupLatLng;

    // Initial center: midpoint between partner and pickup
    final centerLat = (partner.latitude + pickup.latitude) / 2;
    final centerLng = (partner.longitude + pickup.longitude) / 2;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: 14.0,
        onMapReady: () => WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds()),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        // ── Tile Layer (OpenStreetMap Standard — light, clean, Rapido-style) ──
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.workgo.cooperative',
          maxZoom: 19,
          tileBuilder: (context, tileWidget, tile) => ColorFiltered(
            // Slight desaturation + brightness for softer Rapido aesthetic
            colorFilter: ColorFilter.matrix([
              0.95, 0.05, 0.00, 0, 8,
              0.00, 0.95, 0.05, 0, 8,
              0.00, 0.00, 1.00, 0, 5,
              0.00, 0.00, 0.00, 1, 0,
            ]),
            child: tileWidget,
          ),
        ),

        if (isRoute) ...[
          // ── Route Polyline (partner → pickup) ──────────────────────────────
          PolylineLayer(
            polylines: [
              // Travelled section (blue) — from partner backwards to estimated 30% start
              Polyline(
                points: _buildTravelledSegment(partner, pickup),
                strokeWidth: 5.0,
                color: const Color(0xFF2563EB),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Remaining section (orange/yellow) — from partner forward to pickup
              Polyline(
                points: [partner, pickup],
                strokeWidth: 5.0,
                gradientColors: [tradeColor, const Color(0xFFFBBF24)],
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        ] else ...[
          // ── Broadcast mode: 10 km radius circle ──────────────────────────
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, _) {
              return CircleLayer(
                circles: [
                  CircleMarker(
                    point: pickup,
                    radius: 3500, // ~3.5 km visual ring (scales with zoom)
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(0.06),
                    borderColor: tradeColor.withOpacity(0.25),
                    borderStrokeWidth: 1.5,
                  ),
                  CircleMarker(
                    point: pickup,
                    radius: 7000,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(0.04),
                    borderColor: tradeColor.withOpacity(0.15),
                    borderStrokeWidth: 1.2,
                  ),
                  CircleMarker(
                    point: pickup,
                    radius: 10500,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: tradeColor.withOpacity(0.10),
                    borderStrokeWidth: 1.0,
                  ),
                ],
              );
            },
          ),
        ],

        // ── Markers ─────────────────────────────────────────────────────────
        MarkerLayer(
          markers: [
            // Pickup / Customer Home Marker
            Marker(
              point: pickup,
              width: 56,
              height: 68,
              alignment: Alignment.topCenter,
              child: _buildPickupMarker(isRoute),
            ),

            // Partner / Artisan Marker (only in route navigation mode)
            if (isRoute)
              Marker(
                point: partner,
                width: 64,
                height: 80,
                alignment: Alignment.topCenter,
                child: _buildPartnerMarker(tradeColor, tradeDarkColor, tradeIcon),
              ),

            // Nearby workers in broadcast mode
            if (!isRoute && widget.nearbyWorkerLocations != null)
              ...widget.nearbyWorkerLocations!.map((loc) => Marker(
                    point: loc,
                    width: 36,
                    height: 36,
                    child: _buildNearbyWorkerDot(tradeColor),
                  )),

            // Simulated nearby workers in broadcast mode (when no real coords)
            if (!isRoute && (widget.nearbyWorkerLocations == null || widget.nearbyWorkerLocations!.isEmpty))
              ..._simulatedNearbyWorkers(pickup, tradeColor, tradeIcon),
          ],
        ),
      ],
    );
  }

  /// Build a rough "already-travelled" arc that starts behind the partner
  List<LatLng> _buildTravelledSegment(LatLng partner, LatLng pickup) {
    // Simulate the already-travelled portion as a slight offset path
    final dLat = (pickup.latitude - partner.latitude) * 0.3;
    final dLng = (pickup.longitude - partner.longitude) * 0.3;
    final pastPoint = LatLng(partner.latitude - dLat, partner.longitude - dLng);
    return [pastPoint, partner];
  }

  /// Simulated nearby workers for broadcast mode (when no Firestore data)
  List<Marker> _simulatedNearbyWorkers(LatLng center, Color color, IconData icon) {
    const offsets = [
      (0.012, 0.018),
      (-0.020, 0.008),
      (0.005, -0.022),
      (-0.015, -0.012),
    ];
    return List.generate(offsets.length, (i) {
      final pt = LatLng(center.latitude + offsets[i].$1, center.longitude + offsets[i].$2);
      return Marker(
        point: pt,
        width: 34,
        height: 34,
        child: _buildNearbyWorkerDot(i == 0 ? color : _altColor(i)),
      );
    });
  }

  Color _altColor(int i) {
    const colors = [Color(0xFF10B981), Color(0xFFFBBF24), Color(0xFF6366F1), Color(0xFFEC4899)];
    return colors[i % colors.length];
  }

  Widget _buildPickupMarker(bool showYouBadge) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showYouBadge) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'YOU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 3),
        ],
        Container(
          width: showYouBadge ? 38 : 44,
          height: showYouBadge ? 38 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildPartnerMarker(Color tradeColor, Color tradeDarkColor, IconData tradeIcon) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final glow = 0.5 + _pulseCtrl.value * 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tradeColor, tradeDarkColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: tradeColor.withOpacity(glow * 0.6),
                    blurRadius: 16 + glow * 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(tradeIcon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tradeColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.artisanName ?? 'Artisan Partner',
                style: TextStyle(
                  color: tradeDarkColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNearbyWorkerDot(Color color) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4 + _pulseCtrl.value * 0.3),
                blurRadius: 8 + _pulseCtrl.value * 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.directions_bike_rounded, color: Colors.white, size: 16),
        );
      },
    );
  }

  Widget _buildAddressPill(Color tradeColor, Color tradeDarkColor) {
    final isRoute = widget.mode == MapMode.routeNavigation;
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE11D48),
                    ),
                    child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PICKUP ADDRESS',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          widget.pickupAddress,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Edit pencil icon (Rapido-style)
                  Icon(Icons.edit_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),

          // ETA Badge — only in navigation mode
          if (isRoute) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tradeColor, tradeDarkColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: tradeColor.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.etaMinutes} MIN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${widget.distanceKm} km',
                    style: const TextStyle(
                      color: Colors.white70,
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
    );
  }

  Widget _buildBottomHud(Color tradeColor, String tradeVehicleLabel) {
    final isRoute = widget.mode == MapMode.routeNavigation;
    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRoute ? const Color(0xFF10B981) : tradeColor,
                      boxShadow: [
                        BoxShadow(
                          color: (isRoute ? const Color(0xFF10B981) : tradeColor)
                              .withOpacity(0.4 + _pulseCtrl.value * 0.4),
                          blurRadius: 6 + _pulseCtrl.value * 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isRoute
                      ? 'Artisan En Route via GPS ($tradeVehicleLabel)'
                      : 'Broadcasting within 10 km live radius',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isRoute
                    ? const Color(0xFF10B981).withOpacity(0.10)
                    : tradeColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isRoute ? 'LIVE GPS' : 'ACTIVE RADAR',
                style: TextStyle(
                  color: isRoute ? const Color(0xFF059669) : tradeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
