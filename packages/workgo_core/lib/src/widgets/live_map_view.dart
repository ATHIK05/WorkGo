// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/worker.dart';
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
    this.nearbyWorkers,
    // Customer's own real-time device GPS for "My Location" blue dot
    this.myLocationLatitude,
    this.myLocationLongitude,
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
  final List<Worker>? nearbyWorkers;

  // ── Customer's own device location for Rapido-style blue dot ─────────────
  final double? myLocationLatitude;
  final double? myLocationLongitude;

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;
  late AnimationController _myLocationCtrl;

  // Defaults: Perundurai / Tamil Nadu coordinates when no live GPS yet
  static const LatLng _defaultPickup = LatLng(11.2743, 77.5866); // MBA Block, Perundurai
  static const LatLng _defaultPartner = LatLng(11.2680, 77.5750);

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
    _myLocationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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

    final workersChanged = oldWidget.nearbyWorkers != widget.nearbyWorkers ||
        oldWidget.nearbyWorkerLocations != widget.nearbyWorkerLocations;
    if (workersChanged && widget.mode == MapMode.broadcastScanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBroadcastBounds());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    _myLocationCtrl.dispose();
    super.dispose();
  }

  bool get _hasRealCoords =>
      widget.partnerLatitude != null &&
      widget.partnerLongitude != null &&
      widget.pickupLatitude != null &&
      widget.pickupLongitude != null;

  bool get _hasMyLocation =>
      widget.myLocationLatitude != null && widget.myLocationLongitude != null;

  LatLng get _partnerLatLng => _hasRealCoords
      ? LatLng(widget.partnerLatitude!, widget.partnerLongitude!)
      : _estimatedPartnerFromProgress;

  LatLng get _pickupLatLng =>
      (widget.pickupLatitude != null && widget.pickupLongitude != null)
          ? LatLng(widget.pickupLatitude!, widget.pickupLongitude!)
          : _defaultPickup;

  LatLng? get _myLocationLatLng => _hasMyLocation
      ? LatLng(widget.myLocationLatitude!, widget.myLocationLongitude!)
      : null;

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
      final allPoints = <LatLng>[_partnerLatLng, _pickupLatLng];
      if (_myLocationLatLng != null) allPoints.add(_myLocationLatLng!);
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 90, 60, 90),
        ),
      );
    } catch (_) {}
  }

  void _fitBroadcastBounds() {
    if (!mounted) return;
    try {
      final points = <LatLng>[_pickupLatLng];
      if (_myLocationLatLng != null) points.add(_myLocationLatLng!);
      if (widget.nearbyWorkers != null) {
        for (final w in widget.nearbyWorkers!) {
          if (w.latitude != null && w.longitude != null) {
            points.add(LatLng(w.latitude!, w.longitude!));
          }
        }
      }
      if (widget.nearbyWorkerLocations != null) {
        points.addAll(widget.nearbyWorkerLocations!);
      }
      if (points.length > 1) {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(50, 80, 50, 80),
          ),
        );
      } else {
        _mapController.move(_pickupLatLng, 14.0);
      }
    } catch (_) {}
  }

  (Color, Color, IconData, String) _getTradeAsset(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('plumb')) {
      return (const Color(0xFF0284C7), const Color(0xFF0369A1), Icons.plumbing_rounded, 'Plumbing');
    }
    if (cat.contains('electr')) {
      return (const Color(0xFFD97706), const Color(0xFFB45309), Icons.bolt_rounded, 'Electrician');
    }
    if (cat.contains('carpent')) {
      return (const Color(0xFFEA580C), const Color(0xFFC2410C), Icons.carpenter_rounded, 'Carpentry');
    }
    if (cat.contains('paint')) {
      return (const Color(0xFFE11D48), const Color(0xFFBE123C), Icons.format_paint_rounded, 'Painting');
    }
    if (cat.contains('ac') || cat.contains('appliance') || cat.contains('cool')) {
      return (const Color(0xFF0284C7), const Color(0xFF0369A1), Icons.ac_unit_rounded, 'Cooling');
    }
    return (const Color(0xFF059669), const Color(0xFF047857), Icons.handyman_rounded, 'Handyman');
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
            _buildRealMap(tradeColor, tradeDarkColor, tradeIcon),

            // ── Top Address Pill ────────────────────────────────────────────
            _buildAddressPill(tradeColor, tradeDarkColor),

            // ── Bottom Status HUD ───────────────────────────────────────────
            _buildBottomHud(tradeColor, tradeVehicleLabel),

            // ── My Location FAB (recenter button) ───────────────────────────
            if (_hasMyLocation)
              Positioned(
                bottom: 56,
                right: 12,
                child: GestureDetector(
                  onTap: _fitBounds,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealMap(
    Color tradeColor,
    Color tradeDarkColor,
    IconData tradeIcon,
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
        initialZoom: isRoute ? 14.0 : 13.0,
        onMapReady: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isRoute) {
              _fitBounds();
            } else {
              _fitBroadcastBounds();
            }
          });
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        // ── Tile Layer (OSM Standard — warm, slightly desaturated Rapido feel) ──
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.workgo.cooperative',
          maxZoom: 19,
          tileBuilder: (context, tileWidget, tile) => ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0.96, 0.04, 0.00, 0, 5,
              0.00, 0.96, 0.04, 0, 5,
              0.00, 0.00, 1.00, 0, 3,
              0.00, 0.00, 0.00, 1, 0,
            ]),
            child: tileWidget,
          ),
        ),

        if (isRoute) ...[
          // ── Route Polyline (partner → pickup) ──────────────────────────────
          PolylineLayer(
            polylines: [
              // Shadow glow beneath route
              Polyline(
                points: [partner, pickup],
                strokeWidth: 11.0,
                color: tradeColor.withOpacity(0.18),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Travelled section (grey-blue) — behind partner
              Polyline(
                points: _buildTravelledSegment(partner, pickup),
                strokeWidth: 5.0,
                color: const Color(0xFF94A3B8),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Remaining route — trade color
              Polyline(
                points: [partner, pickup],
                strokeWidth: 5.5,
                gradientColors: [tradeColor, tradeColor.withOpacity(0.7)],
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Inner white guidance line on top of route
              Polyline(
                points: [partner, pickup],
                strokeWidth: 2.0,
                color: Colors.white.withOpacity(0.85),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        ] else ...[
          // ── Broadcast mode: concentric radius rings (animated) ────────────
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, _) {
              final pulse = _radarCtrl.value;
              return CircleLayer(
                circles: [
                  // Expanding animated ring
                  CircleMarker(
                    point: pickup,
                    radius: (2000 + pulse * 8500).clamp(2000, 10500),
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity((1.0 - pulse) * 0.04),
                    borderColor: tradeColor.withOpacity((1.0 - pulse) * 0.30),
                    borderStrokeWidth: 1.5,
                  ),
                  // Static rings: 3.5km / 7km / 10km
                  CircleMarker(
                    point: pickup,
                    radius: 3500,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(0.05),
                    borderColor: tradeColor.withOpacity(0.20),
                    borderStrokeWidth: 1.2,
                  ),
                  CircleMarker(
                    point: pickup,
                    radius: 7000,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(0.03),
                    borderColor: tradeColor.withOpacity(0.12),
                    borderStrokeWidth: 1.0,
                  ),
                  CircleMarker(
                    point: pickup,
                    radius: 10000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: tradeColor.withOpacity(0.08),
                    borderStrokeWidth: 0.8,
                  ),
                ],
              );
            },
          ),
        ],

        // ── All Markers ─────────────────────────────────────────────────────
        MarkerLayer(
          rotate: false,
          markers: [
            // ── My Location — Rapido-style pulsing blue GPS dot ──────────────
            if (_myLocationLatLng != null)
              Marker(
                point: _myLocationLatLng!,
                width: 72,
                height: 72,
                child: _buildMyLocationDot(),
              ),

            // ── Pickup / Customer Home Marker ─────────────────────────────────
            Marker(
              point: pickup,
              width: 56,
              height: 72,
              alignment: Alignment.topCenter,
              child: _buildPickupMarker(isRoute),
            ),

            // ── Partner / Artisan Live Marker (navigation mode only) ──────────
            if (isRoute)
              Marker(
                point: partner,
                width: 68,
                height: 88,
                alignment: Alignment.topCenter,
                child: _buildPartnerMarker(tradeColor, tradeDarkColor, tradeIcon),
              ),

            // ── Real online workers from Firestore (broadcast mode) ───────────
            if (!isRoute && widget.nearbyWorkers != null && widget.nearbyWorkers!.isNotEmpty)
              for (int i = 0; i < widget.nearbyWorkers!.length; i++)
                _buildRealWorkerMarker(widget.nearbyWorkers![i], i, tradeColor, tradeIcon, pickup),

            // ── Real coordinates fallback (if nearbyWorkers is null) ──────────
            if (!isRoute &&
                (widget.nearbyWorkers == null || widget.nearbyWorkers!.isEmpty) &&
                widget.nearbyWorkerLocations != null)
              for (int i = 0; i < widget.nearbyWorkerLocations!.length; i++)
                Marker(
                  point: widget.nearbyWorkerLocations![i],
                  width: 44,
                  height: 44,
                  child: _buildNearbyWorkerDot(
                    i == 0 ? tradeColor : _altColor(i),
                    tradeIcon,
                  ),
                ),

            // ── Simulated workers fallback (when no Firestore workers exist) ──
            if (!isRoute &&
                (widget.nearbyWorkers == null || widget.nearbyWorkers!.isEmpty) &&
                (widget.nearbyWorkerLocations == null || widget.nearbyWorkerLocations!.isEmpty))
              ..._simulatedNearbyWorkers(pickup, tradeColor, tradeIcon),
          ],
        ),
      ],
    );
  }

  /// Marker for a real online artisan from Firestore
  Marker _buildRealWorkerMarker(
    Worker worker,
    int index,
    Color defaultColor,
    IconData defaultIcon,
    LatLng centerFallback,
  ) {
    // If worker coordinates exist, use them.
    // If worker is at MBA Block / Perundurai or has null coordinates, offset slightly around Perundurai center
    final lat = worker.latitude ?? (centerFallback.latitude + (index == 0 ? 0.0035 : -0.0040 * index));
    final lng = worker.longitude ?? (centerFallback.longitude + (index == 0 ? 0.0040 : 0.0035 * index));
    final pt = LatLng(lat, lng);

    final (color, _, icon, _) = _getTradeAsset(
      worker.skills.isNotEmpty ? worker.skills.first : widget.serviceCategory,
    );

    return Marker(
      point: pt,
      width: 80,
      height: 64,
      alignment: Alignment.topCenter,
      child: _buildNearbyWorkerDot(
        color,
        icon,
        name: worker.name,
      ),
    );
  }

  /// Build the already-travelled segment behind the partner marker
  List<LatLng> _buildTravelledSegment(LatLng partner, LatLng pickup) {
    final dLat = (pickup.latitude - partner.latitude) * 0.35;
    final dLng = (pickup.longitude - partner.longitude) * 0.35;
    final pastPoint = LatLng(partner.latitude - dLat, partner.longitude - dLng);
    return [pastPoint, partner];
  }

  /// Simulated nearby workers for broadcast fallback (no Firestore data yet)
  List<Marker> _simulatedNearbyWorkers(LatLng center, Color color, IconData icon) {
    // Offsets calibrated around Perundurai / MBA Block area
    const offsets = [
      (0.010, 0.015),
      (-0.018, 0.006),
      (0.004, -0.020),
      (-0.012, -0.010),
      (0.022, -0.005),
    ];
    return List.generate(offsets.length, (i) {
      final pt = LatLng(center.latitude + offsets[i].$1, center.longitude + offsets[i].$2);
      return Marker(
        point: pt,
        width: 40,
        height: 40,
        child: _buildNearbyWorkerDot(i == 0 ? color : _altColor(i), icon),
      );
    });
  }

  Color _altColor(int i) {
    const colors = [
      Color(0xFF10B981),
      Color(0xFFFBBF24),
      Color(0xFF6366F1),
      Color(0xFFEC4899),
      Color(0xFFEA580C),
    ];
    return colors[i % colors.length];
  }

  // ── Marker Builders ──────────────────────────────────────────────────────

  /// Rapido-style pulsing blue "My Location" dot with accuracy halo and heading
  Widget _buildMyLocationDot() {
    return AnimatedBuilder(
      animation: _myLocationCtrl,
      builder: (context, _) {
        final pulse = _myLocationCtrl.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'YOU ARE HERE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ripple
                Container(
                  width: 30 + pulse * 22,
                  height: 30 + pulse * 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2563EB).withOpacity((1.0 - pulse) * 0.28),
                  ),
                ),
                // Accuracy boundary
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withOpacity(0.18),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      width: 1.2,
                    ),
                  ),
                ),
                // Solid core
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1D4ED8),
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickupMarker(bool isNavigation) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isNavigation ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: (isNavigation ? const Color(0xFFE11D48) : const Color(0xFF0F172A))
                    .withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            isNavigation ? 'YOUR HOME' : 'PICKUP SPOT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Pin icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isNavigation ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (isNavigation ? const Color(0xFFE11D48) : const Color(0xFF0F172A))
                    .withOpacity(0.45),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isNavigation ? Icons.home_rounded : Icons.location_on_rounded,
            color: Colors.white,
            size: 19,
          ),
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
            // Artisan name chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tradeColor.withOpacity(0.35), width: 1),
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            // Trade icon circle with pulsing glow
            Container(
              width: 52,
              height: 52,
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
                    color: tradeColor.withOpacity(glow * 0.65),
                    blurRadius: 14 + glow * 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(tradeIcon, color: Colors.white, size: 26),
            ),
            // Direction arrow pointing to pickup
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18),
          ],
        );
      },
    );
  }

  Widget _buildNearbyWorkerDot(Color color, IconData icon, {String? name}) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name != null && name.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withOpacity(0.5), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 58),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width: 34 + _pulseCtrl.value * 5,
                  height: 34 + _pulseCtrl.value * 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity((1 - _pulseCtrl.value) * 0.22),
                  ),
                ),
                // Solid dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
              ],
            ),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          'PICKUP',
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
                  Icon(Icons.edit_rounded, size: 13, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),

          // ETA Badge — only in navigation mode
          if (isRoute) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
    final statusColor = isRoute ? const Color(0xFF10B981) : tradeColor;
    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Pulsing dot + status text — wrapped in Expanded to prevent overflow
            Expanded(
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4 + _pulseCtrl.value * 0.4),
                            blurRadius: 6 + _pulseCtrl.value * 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      isRoute
                          ? 'Artisan En Route · $tradeVehicleLabel'
                          : 'Broadcasting · 10 km live radius',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge — fixed width, won't cause overflow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isRoute ? 'LIVE GPS' : 'SCANNING',
                style: TextStyle(
                  color: statusColor,
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
