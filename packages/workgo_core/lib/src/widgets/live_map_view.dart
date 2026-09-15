// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../localization/trade_localization.dart';
import '../models/worker.dart';
import '../services/location_service.dart';
import '../services/road_routing_service.dart';
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

enum MapLayerType {
  dark,
  street,
  satellite,
}

class LiveMapView extends StatefulWidget {
  const LiveMapView({
    super.key,
    required this.serviceCategory,
    this.mode = MapMode.routeNavigation,
    this.artisanName,
    this.etaMinutes = 4,
    this.distanceKm = 1.6,
    this.workerProgress = 0.0,
    this.pickupAddress = "Current Location",
    this.height = 380,
    this.onTap,
    // Real GPS bindings — optional (falls back to illustrated if null)
    this.partnerLatitude,
    this.partnerLongitude,
    this.partnerHeading,
    this.pickupLatitude,
    this.pickupLongitude,
    this.nearbyWorkerLocations,
    this.nearbyWorkers,
    // Customer's own real-time device GPS for "My Location" blue dot
    this.myLocationLatitude,
    this.myLocationLongitude,
    // Optional initial map layer (defaults to dark for broadcast scanning, street for route)
    this.initialLayerType,
    // Broadcast scanning radius in km & callback to cycle/expand
    this.broadcastRadiusKm = 10.0,
    this.onRadiusChanged,
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
  final double? partnerHeading;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final List<LatLng>? nearbyWorkerLocations;
  final List<Worker>? nearbyWorkers;

  // ── Customer's own device location for Rapido-style blue dot ─────────────
  final double? myLocationLatitude;
  final double? myLocationLongitude;

  // ── Initial Map Layer ────────────────────────────────────────────────────
  final MapLayerType? initialLayerType;

  // ── Broadcast Radius & Expansion Callback ────────────────────────────────
  final double broadcastRadiusKm;
  final ValueChanged<double>? onRadiusChanged;

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView>
    with TickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;
  late AnimationController _myLocationCtrl;
  bool _hasUserInteracted = false;
  late MapLayerType _currentLayer;
  String? _liveAddress;
  bool _isResolvingAddress = false;

  void _resolveLiveAddress() async {
    if (_isResolvingAddress) return;
    final latLng = _customerLatLng;
    if (latLng.latitude <= 1.0 || latLng.longitude <= 1.0) return;
    _isResolvingAddress = true;
    try {
      final decoded = await LocationService.instance.reverseGeocode(
        latLng.latitude,
        latLng.longitude,
      );
      if (mounted) {
        final text = decoded.streetArea.isNotEmpty
            ? '${decoded.streetArea}, ${decoded.city}'
            : decoded.formattedAddress;
        if (text.isNotEmpty && !text.toLowerCase().contains('mumbai')) {
          setState(() {
            _liveAddress = text;
          });
        }
      }
    } catch (_) {
    } finally {
      _isResolvingAddress = false;
    }
  }

  // Defaults: Perundurai / Tamil Nadu coordinates when no live GPS yet
  static const LatLng _defaultPickup =
      LatLng(11.2743, 77.5866); // MBA Block, Perundurai
  static const LatLng _defaultPartner = LatLng(11.2680, 77.5750);

  RoadRoute? _roadRoute;

  bool get _isAtSameSpot {
    if (widget.mode != MapMode.routeNavigation) return false;
    final p1 = _partnerLatLng;
    final p2 = _customerLatLng;
    return const Distance().as(LengthUnit.Meter, p1, p2) < 200;
  }

  double get _computedDistanceKm {
    if (_isAtSameSpot) return 0.0;
    if (_roadRoute != null &&
        _roadRoute!.isSuccess &&
        _roadRoute!.distanceKm > 0.0) {
      return _roadRoute!.distanceKm;
    }
    if (_hasRealCoords && (_hasMyLocation || widget.pickupLatitude != null)) {
      final p1 = _partnerLatLng;
      final p2 = _customerLatLng;
      final km = const Distance().as(LengthUnit.Kilometer, p1, p2);
      if (km >= 0.0 && km < 100.0) return km;
    }
    if (widget.distanceKm > 0.0) return widget.distanceKm;
    return 1.4;
  }

  int get _computedEtaMinutes {
    if (_isAtSameSpot) return 0;
    if (_roadRoute != null &&
        _roadRoute!.isSuccess &&
        _roadRoute!.durationMinutes > 0) {
      return _roadRoute!.durationMinutes;
    }
    final km = _computedDistanceKm;
    if (km <= 0.04) return 0;
    if (widget.etaMinutes > 0 && !_hasRealCoords) return widget.etaMinutes;
    return ((km * 2.5) + 1.0).round().clamp(1, 45);
  }

  void _fetchRoadRoute({bool forceRefresh = false}) async {
    if (widget.mode != MapMode.routeNavigation) return;
    final p1 = _partnerLatLng;
    final p2 = _customerLatLng;

    // Check if at same spot
    if (_isAtSameSpot) {
      if (mounted && _roadRoute != null) {
        setState(() => _roadRoute = null);
      }
      return;
    }

    // Check if route already exists and vehicle hasn't deviated by >60m
    if (!forceRefresh && _roadRoute != null && _roadRoute!.points.isNotEmpty) {
      final deviated = RoadRoutingService.instance.hasDeviatedFromRoute(
        currentPosition: p1,
        routePoints: _roadRoute!.points,
        thresholdMeters: 60.0,
      );
      if (!deviated) return;
    }

    try {
      final route = await RoadRoutingService.instance.getRoute(
        origin: p1,
        destination: p2,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _roadRoute = route;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentLayer = widget.initialLayerType ??
        (widget.mode == MapMode.broadcastScanning
            ? MapLayerType.dark
            : MapLayerType.street);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoadRoute();
      _resolveLiveAddress();
    });
  }

  @override
  void didUpdateWidget(LiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When partner location updates, smoothly re-fit camera if user hasn't manually panned
    final partnerChanged =
        oldWidget.partnerLatitude != widget.partnerLatitude ||
            oldWidget.partnerLongitude != widget.partnerLongitude;
    if (partnerChanged && _hasRealCoords && !_hasUserInteracted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }

    final coordsChanged = partnerChanged ||
        oldWidget.pickupLatitude != widget.pickupLatitude ||
        oldWidget.pickupLongitude != widget.pickupLongitude ||
        oldWidget.myLocationLatitude != widget.myLocationLatitude ||
        oldWidget.myLocationLongitude != widget.myLocationLongitude;
    if (coordsChanged && widget.mode == MapMode.routeNavigation) {
      _fetchRoadRoute();
    }

    final customerCoordsChanged =
        oldWidget.pickupLatitude != widget.pickupLatitude ||
        oldWidget.pickupLongitude != widget.pickupLongitude ||
        oldWidget.myLocationLatitude != widget.myLocationLatitude ||
        oldWidget.myLocationLongitude != widget.myLocationLongitude;
    if (customerCoordsChanged) {
      _resolveLiveAddress();
    }

    final radiusChanged =
        oldWidget.broadcastRadiusKm != widget.broadcastRadiusKm;
    final workersChanged = oldWidget.nearbyWorkers != widget.nearbyWorkers ||
        oldWidget.nearbyWorkerLocations != widget.nearbyWorkerLocations ||
        radiusChanged;
    if (workersChanged &&
        widget.mode == MapMode.broadcastScanning &&
        !_hasUserInteracted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _fitBroadcastBounds(force: radiusChanged));
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
      widget.partnerLatitude! > 1.0 &&
      widget.partnerLongitude! > 1.0;

  bool get _hasMyLocation =>
      widget.myLocationLatitude != null &&
      widget.myLocationLongitude != null &&
      widget.myLocationLatitude! > 1.0 &&
      widget.myLocationLongitude! > 1.0;

  LatLng get _partnerLatLng => _hasRealCoords
      ? LatLng(widget.partnerLatitude!, widget.partnerLongitude!)
      : _estimatedPartnerFromProgress;

  LatLng get _customerLatLng {
    // 1. Customer's live hardware GPS (highest priority - guarantees local Perundurai / current phone location)
    if (_hasMyLocation) {
      return LatLng(widget.myLocationLatitude!, widget.myLocationLongitude!);
    }
    // 2. Saved pickup coordinates
    if (widget.pickupLatitude != null &&
        widget.pickupLongitude != null &&
        widget.pickupLatitude! > 1.0) {
      return LatLng(widget.pickupLatitude!, widget.pickupLongitude!);
    }
    // 3. Fallback to default
    return const LatLng(10.7870, 79.1378);
  }

  /// When no real GPS: estimate partner position from workerProgress (0.0–1.0)
  LatLng get _estimatedPartnerFromProgress {
    final t = widget.workerProgress.clamp(0.0, 1.0);
    final lat = _customerLatLng.latitude +
        (_defaultPartner.latitude - _defaultPickup.latitude) * (1.0 - t);
    final lng = _customerLatLng.longitude +
        (_defaultPartner.longitude - _defaultPickup.longitude) * (1.0 - t);
    return LatLng(lat, lng);
  }

  void _fitBounds({bool force = false}) {
    if (!mounted) return;
    if (_hasUserInteracted && !force) return;
    try {
      final p1 = _partnerLatLng;
      final p2 = _customerLatLng;
      final meters = const Distance().as(LengthUnit.Meter, p1, p2);

      if (meters < 200) {
        // Both are at the same spot! Center smoothly at a comfortable street-level zoom (15.2)
        final center = LatLng(
          (p1.latitude + p2.latitude) / 2,
          (p1.longitude + p2.longitude) / 2,
        );
        _mapController.move(center, 15.2);
        return;
      }

      final allPoints = (_roadRoute != null && _roadRoute!.points.isNotEmpty)
          ? _roadRoute!.points
          : <LatLng>[p1, p2];
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 90, 60, 90),
          maxZoom: 15.8,
        ),
      );
    } catch (_) {}
  }

  void _fitBroadcastBounds({bool force = false}) {
    if (!mounted) return;
    if (_hasUserInteracted && !force) return;
    try {
      final points = <LatLng>[_customerLatLng];
      final maxCoverDist = math.max(25.0, widget.broadcastRadiusKm);
      if (widget.nearbyWorkers != null) {
        for (final w in widget.nearbyWorkers!) {
          if (w.latitude != null && w.longitude != null && w.latitude! > 1.0) {
            final pt = LatLng(w.latitude!, w.longitude!);
            final d =
                const Distance().as(LengthUnit.Kilometer, _customerLatLng, pt);
            // ONLY include workers within coverage of the customer! Remote workers won't distort bounds.
            if (d <= maxCoverDist) {
              points.add(pt);
            }
          }
        }
      }
      if (widget.nearbyWorkerLocations != null) {
        for (final loc in widget.nearbyWorkerLocations!) {
          if (loc.latitude > 1.0) {
            final d =
                const Distance().as(LengthUnit.Kilometer, _customerLatLng, loc);
            if (d <= maxCoverDist) {
              points.add(loc);
            }
          }
        }
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
        _mapController.move(_customerLatLng, 14.5);
      }
    } catch (_) {}
  }

  (Color, Color, IconData, String) _getTradeAsset(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('plumb')) {
      return (
        const Color(0xFF0284C7),
        const Color(0xFF0369A1),
        Icons.plumbing_rounded,
        'Plumber'
      );
    }
    if (cat.contains('electr')) {
      return (
        const Color(0xFFD97706),
        const Color(0xFFB45309),
        Icons.bolt_rounded,
        'Electrician'
      );
    }
    if (cat.contains('carpent')) {
      return (
        const Color(0xFFEA580C),
        const Color(0xFFC2410C),
        Icons.carpenter_rounded,
        'Carpenter'
      );
    }
    if (cat.contains('paint')) {
      return (
        const Color(0xFFE11D48),
        const Color(0xFFBE123C),
        Icons.format_paint_rounded,
        'Painter'
      );
    }
    if (cat.contains('ac') || cat.contains('cool')) {
      return (
        const Color(0xFF06B6D4),
        const Color(0xFF0891B2),
        Icons.ac_unit_rounded,
        'AC Specialist'
      );
    }
    if (cat.contains('repair') ||
        cat.contains('appliance') ||
        cat.contains('mechanic')) {
      return (
        const Color(0xFF7C3AED),
        const Color(0xFF6D28D9),
        Icons.build_circle_rounded,
        'Repair Pro'
      );
    }
    if (cat.contains('clean')) {
      return (
        const Color(0xFF059669),
        const Color(0xFF047857),
        Icons.cleaning_services_rounded,
        'Cleaning Pro'
      );
    }
    return (
      const Color(0xFF2563EB),
      const Color(0xFF1D4ED8),
      Icons.handyman_rounded,
      'Specialist'
    );
  }

  @override
  Widget build(BuildContext context) {
    final (tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel) =
        _getTradeAsset(widget.serviceCategory);
    final isDark = _currentLayer == MapLayerType.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? tradeColor.withOpacity(0.35) : Colors.grey.shade200,
            width: isDark ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? tradeColor.withOpacity(0.18)
                  : Colors.black.withOpacity(0.10),
              blurRadius: 22,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Real Map Tiles (Layer Selectable) ──────────────────────────
            _buildRealMap(
                tradeColor, tradeDarkColor, tradeIcon, tradeVehicleLabel),

            // ── Smooth Vignette Edge Dissolve (blends map with surrounding layout) ──
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (isDark ? Colors.black : Colors.white)
                            .withOpacity(0.28),
                        Colors.transparent,
                        Colors.transparent,
                        (isDark ? Colors.black : Colors.white)
                            .withOpacity(0.35),
                      ],
                      stops: const [0.0, 0.12, 0.88, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top Address Pill ────────────────────────────────────────────
            _buildAddressPill(tradeColor, tradeDarkColor),

            // ── Live On-Site Arrived Floating Alert (when both are close at same spot) ──
            if (_isAtSameSpot)
              Positioned(
                top: 70,
                left: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0xFF34D399), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'pro_at_your_location'
                                  .trSafe('PRO AT YOUR LOCATION'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'specialist_at_same_spot'.trSafe(
                                  'Specialist & you are at the exact same spot'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'on_site'.trSafe('ON-SITE'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Bottom Status HUD ───────────────────────────────────────────
            _buildBottomHud(tradeColor, tradeVehicleLabel),

            // ── Floating Zoom & Recenter Controls (Rapido Style) ────────────
            Positioned(
              bottom: 56,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map Layer Switcher Button (Dark / Street / Satellite)
                  GestureDetector(
                    onTap: _showLayerSelectionSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xE60F172A) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.25 : 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _currentLayer == MapLayerType.satellite
                            ? Icons.satellite_alt_rounded
                            : (_currentLayer == MapLayerType.dark
                                ? Icons.radar_rounded
                                : Icons.layers_rounded),
                        size: 20,
                        color: _currentLayer == MapLayerType.satellite
                            ? const Color(0xFF059669)
                            : (_currentLayer == MapLayerType.dark
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Zoom In (+) Button
                  GestureDetector(
                    onTap: () {
                      _hasUserInteracted = true;
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        (currentZoom + 1.0).clamp(3.0, 19.0),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xE60F172A) : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.25 : 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  // Divider
                  Container(
                    width: 36,
                    height: 1,
                    color:
                        isDark ? const Color(0x33FFFFFF) : Colors.grey.shade200,
                  ),
                  // Zoom Out (-) Button
                  GestureDetector(
                    onTap: () {
                      _hasUserInteracted = true;
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        (currentZoom - 1.0).clamp(3.0, 19.0),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xE60F172A) : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.25 : 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Recenter GPS Button
                  GestureDetector(
                    onTap: () {
                      setState(() => _hasUserInteracted = false);
                      if (widget.mode == MapMode.routeNavigation) {
                        _fitBounds(force: true);
                      } else {
                        _fitBroadcastBounds(force: true);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xE60F172A) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.25 : 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
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
    String tradeVehicleLabel,
  ) {
    final isRoute = widget.mode == MapMode.routeNavigation;
    final partner = _partnerLatLng;
    final customer = _customerLatLng;

    // When both are at the exact same spot (< 200m), offset partner marker slightly (~20m)
    // so both the customer's pulsing blue dot and artisan's vehicle marker are visible side-by-side
    final displayPartner = _isAtSameSpot
        ? LatLng(partner.latitude + 0.00018, partner.longitude + 0.00018)
        : partner;

    // Initial center
    final centerLat = isRoute
        ? (displayPartner.latitude + customer.latitude) / 2
        : customer.latitude;
    final centerLng = isRoute
        ? (displayPartner.longitude + customer.longitude) / 2
        : customer.longitude;
    final initialZoom = isRoute ? (_isAtSameSpot ? 15.2 : 14.5) : 14.0;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(centerLat, centerLng),
        initialZoom: initialZoom,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            _hasUserInteracted = true;
          }
        },
        onMapReady: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isRoute) {
              _fitBounds(force: true);
            } else {
              _fitBroadcastBounds(force: true);
            }
          });
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
        ),
      ),
      children: [
        // ── Dynamic Tile Layer (Selectable: Street, Satellite) ───────────────
        _buildTileLayer(),

        if (isRoute) ...[
          // ── Road-Snapped Polyline (partner → customer) ──────────────────────
          Builder(
            builder: (context) {
              final rawPoints =
                  (_roadRoute != null && _roadRoute!.points.isNotEmpty)
                      ? _roadRoute!.points
                      : <LatLng>[partner, customer];
              final (travelled, remaining) =
                  _splitRoadRoute(rawPoints, partner);

              return PolylineLayer(
                polylines: [
                  // When at the same spot, render a glowing emerald arrival tether between them
                  if (_isAtSameSpot)
                    Polyline(
                      points: [displayPartner, customer],
                      strokeWidth: 4.0,
                      color: const Color(0xFF10B981),
                      strokeCap: StrokeCap.round,
                    )
                  else ...[
                    // 1. Shadow glow beneath remaining route
                    Polyline(
                      points: remaining,
                      strokeWidth: 11.0,
                      color: tradeColor.withOpacity(0.20),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // 2. Travelled section (grey-blue) — behind partner
                    if (travelled.length > 1)
                      Polyline(
                        points: travelled,
                        strokeWidth: 4.5,
                        color: const Color(0xFF94A3B8),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    // 3. Remaining road-snapped route — trade color
                    Polyline(
                      points: remaining,
                      strokeWidth: 5.5,
                      gradientColors: [tradeColor, tradeColor.withOpacity(0.8)],
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // 4. Inner white guidance line on top of route
                    Polyline(
                      points: remaining,
                      strokeWidth: 2.0,
                      color: Colors.white.withOpacity(0.9),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ],
              );
            },
          ),
        ] else ...[
          // ── Broadcast mode: concentric radius rings (animated around customer) ──
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, _) {
              final pulse = _radarCtrl.value;
              final isDark = _currentLayer == MapLayerType.dark;
              final maxMeters = (widget.broadcastRadiusKm > 0
                      ? widget.broadcastRadiusKm
                      : 10.0) *
                  1000.0;
              return CircleLayer(
                circles: [
                  // Expanding animated sonar wave ring
                  CircleMarker(
                    point: customer,
                    radius: (maxMeters * 0.15 + pulse * maxMeters * 0.85)
                        .clamp(maxMeters * 0.15, maxMeters),
                    useRadiusInMeter: true,
                    color: tradeColor
                        .withOpacity((1.0 - pulse) * (isDark ? 0.08 : 0.04)),
                    borderColor: tradeColor
                        .withOpacity((1.0 - pulse) * (isDark ? 0.45 : 0.28)),
                    borderStrokeWidth: 1.8,
                  ),
                  // Dynamic concentric broadcast rings: 25% / 50% / 75% / 100% of radius
                  CircleMarker(
                    point: customer,
                    radius: maxMeters * 0.25,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(isDark ? 0.04 : 0.025),
                    borderColor: tradeColor.withOpacity(isDark ? 0.28 : 0.18),
                    borderStrokeWidth: 1.0,
                  ),
                  CircleMarker(
                    point: customer,
                    radius: maxMeters * 0.50,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(isDark ? 0.03 : 0.02),
                    borderColor: tradeColor.withOpacity(isDark ? 0.22 : 0.14),
                    borderStrokeWidth: 1.0,
                  ),
                  CircleMarker(
                    point: customer,
                    radius: maxMeters * 0.75,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(isDark ? 0.02 : 0.015),
                    borderColor: tradeColor.withOpacity(isDark ? 0.16 : 0.10),
                    borderStrokeWidth: 1.0,
                  ),
                  CircleMarker(
                    point: customer,
                    radius: maxMeters,
                    useRadiusInMeter: true,
                    color: tradeColor.withOpacity(isDark ? 0.015 : 0.01),
                    borderColor: tradeColor.withOpacity(isDark ? 0.35 : 0.20),
                    borderStrokeWidth: 1.5,
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
            // ── In Broadcast mode: 360° rotating radar sweep cone & ultrasonic pulse ──
            if (!isRoute)
              Marker(
                point: customer,
                width: 320,
                height: 320,
                alignment: Alignment.center,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _radarCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(320, 320),
                        painter: _BroadcastRadarSweepPainter(
                          sweepAngle: _radarCtrl.value * 2 * math.pi,
                          pulse: _radarCtrl.value,
                          color: tradeColor,
                          isDark: _currentLayer == MapLayerType.dark,
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Customer Live Location Marker (Rapido pulsing blue GPS dot) ──
            Marker(
              point: customer,
              width: 80,
              height: 80,
              alignment: Alignment.topCenter,
              child: _buildMyLocationDot(),
            ),

            // ── Partner / Artisan Live Marker (navigation mode only) ──────────
            if (isRoute)
              Marker(
                point: displayPartner,
                width: 112,
                height: 104,
                alignment: Alignment.topCenter,
                child: _buildPartnerMarker(
                  tradeColor,
                  tradeDarkColor,
                  tradeIcon,
                  tradeVehicleLabel,
                  vehicleAngle: _calculateVehicleHeading(
                    _roadRoute != null
                        ? _roadRoute!.points
                        : [partner, customer],
                    partner,
                  ),
                ),
              ),

            // ── Real online workers from Firestore (broadcast mode) ───────────
            if (!isRoute &&
                widget.nearbyWorkers != null &&
                widget.nearbyWorkers!.isNotEmpty)
              for (int i = 0; i < widget.nearbyWorkers!.length; i++)
                if (widget.nearbyWorkers![i].latitude != null &&
                    widget.nearbyWorkers![i].longitude != null)
                  _buildRealWorkerMarker(widget.nearbyWorkers![i], i,
                      tradeColor, tradeIcon, customer),

            // ── Real coordinates fallback (if nearbyWorkerLocations provided) ──
            if (!isRoute &&
                (widget.nearbyWorkers == null ||
                    widget.nearbyWorkers!.isEmpty) &&
                widget.nearbyWorkerLocations != null)
              for (int i = 0; i < widget.nearbyWorkerLocations!.length; i++)
                Marker(
                  point: widget.nearbyWorkerLocations![i],
                  width: 96,
                  height: 72,
                  alignment: Alignment.topCenter,
                  child: _buildNearbyWorkerDot(
                    i == 0 ? tradeColor : _altColor(i),
                    tradeIcon,
                    customerPoint: customer,
                  ),
                ),
          ],
        ),
      ],
    );
  }

  /// Marker for a real online artisan from Firestore with exact GPS coordinates
  Marker _buildRealWorkerMarker(
    Worker worker,
    int index,
    Color defaultColor,
    IconData defaultIcon,
    LatLng customerPoint,
  ) {
    final pt = LatLng(worker.latitude!, worker.longitude!);
    final (color, _, icon, _) = _getTradeAsset(
      worker.skills.isNotEmpty ? worker.skills.first : widget.serviceCategory,
    );

    return Marker(
      point: pt,
      width: 110,
      height: 74,
      alignment: Alignment.topCenter,
      child: _buildNearbyWorkerDot(
        color,
        icon,
        name: worker.name,
        worker: worker,
        customerPoint: customerPoint,
      ),
    );
  }

  /// Splits a road polyline into the travelled segment behind the partner and the remaining route ahead.
  (List<LatLng>, List<LatLng>) _splitRoadRoute(
      List<LatLng> roadPoints, LatLng partner) {
    if (roadPoints.length <= 2) {
      return (<LatLng>[partner], roadPoints);
    }
    int closestIdx = 0;
    double minDist = double.infinity;
    const dist = Distance();
    for (int i = 0; i < roadPoints.length; i++) {
      final d = dist.as(LengthUnit.Meter, partner, roadPoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    final travelled = roadPoints.sublist(0, closestIdx + 1);
    final remaining = [partner, ...roadPoints.sublist(closestIdx + 1)];
    return (travelled, remaining);
  }

  /// Calculates the vehicle compass rotation heading in radians along the road geometry.
  double _calculateVehicleHeading(List<LatLng> roadPoints, LatLng partner) {
    if (widget.partnerHeading != null && widget.partnerHeading! >= 0) {
      return widget.partnerHeading! * (math.pi / 180.0);
    }
    if (roadPoints.length < 2) return 0.0;

    int closestIdx = 0;
    double minDist = double.infinity;
    const dist = Distance();
    for (int i = 0; i < roadPoints.length; i++) {
      final d = dist.as(LengthUnit.Meter, partner, roadPoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    final nextIdx =
        (closestIdx + 1 < roadPoints.length) ? closestIdx + 1 : closestIdx;
    if (nextIdx == closestIdx) return 0.0;

    final p1 = roadPoints[closestIdx];
    final p2 = roadPoints[nextIdx];

    final bearingDeg = Geolocator.bearingBetween(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude);
    return bearingDeg * (math.pi / 180.0);
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
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Column(
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
                child: Text(
                  'you_are_here'.trSafe('YOU ARE HERE'),
                  style: const TextStyle(
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
                      color: const Color(0xFF2563EB)
                          .withOpacity((1.0 - pulse) * 0.28),
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
          ),
        );
      },
    );
  }

  Widget _buildPartnerMarker(
    Color tradeColor,
    Color tradeDarkColor,
    IconData tradeIcon,
    String tradeLabel, {
    double vehicleAngle = 0.0,
  }) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final glow = 0.5 + _pulseCtrl.value * 0.5;

        // Clean name to prevent awkward "Artisan" generic text
        String cleanName = (widget.artisanName ?? "").trim();
        cleanName = cleanName
            .replaceAll(RegExp(r'^Artisan\s+', caseSensitive: false), '')
            .trim();
        final lower = cleanName.toLowerCase();
        if (cleanName.isEmpty ||
            lower == 'artisan' ||
            lower == 'partner' ||
            lower == 'artisan partner' ||
            lower == 'verified artisan' ||
            lower == 'specialist' ||
            lower == 'worker') {
          cleanName = tradeLabel;
        }

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rapido / Uber Style Sleek Artisan Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: tradeColor.withValues(alpha: 0.4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tradeIcon, size: 11, color: tradeDarkColor),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 86),
                      child: Text(
                        cleanName,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Rotatable Trade Icon circle with pulsing glow (faces direction of travel)
              Transform.rotate(
                angle: vehicleAngle,
                child: Container(
                  width: 50,
                  height: 50,
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
                        color: tradeColor.withValues(alpha: glow * 0.65),
                        blurRadius: 14 + glow * 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(tradeIcon, color: Colors.white, size: 25),
                ),
              ),
              // Direction pointer arrow
              Transform.rotate(
                angle: vehicleAngle,
                child: const Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNearbyWorkerDot(
    Color color,
    IconData icon, {
    String? name,
    Worker? worker,
    LatLng? customerPoint,
  }) {
    // Calculate live distance if coordinates are present
    String? distText;
    if (worker?.latitude != null &&
        worker?.longitude != null &&
        customerPoint != null) {
      final dM = const Distance().as(
        LengthUnit.Meter,
        LatLng(worker!.latitude!, worker.longitude!),
        customerPoint,
      );
      distText =
          dM < 1000 ? '${dM.toInt()}m' : '${(dM / 1000).toStringAsFixed(1)} km';
    }

    final isDark = _currentLayer == MapLayerType.dark;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = _pulseCtrl.value;

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Proximity Telemetry Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xE60F172A)
                      : Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? color.withOpacity(0.6)
                        : color.withOpacity(0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? color.withOpacity(0.3)
                          : Colors.black.withOpacity(0.12),
                      blurRadius: isDark ? 6 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 82),
                      child: Text(
                        (name != null && name.trim().isNotEmpty)
                            ? name.trim()
                            : 'artisan_pro'.trSafe('Artisan'),
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distText != null) ...[
                      const SizedBox(width: 3.5),
                      Text(
                        '• $distText',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF38BDF8) : color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Breathing glowing marker with trade icon
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer breathing aura ring
                  Container(
                    width: 36 + pulse * 8,
                    height: 36 + pulse * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color
                          .withOpacity((1.0 - pulse) * (isDark ? 0.35 : 0.20)),
                      border: Border.all(
                        color: color
                            .withOpacity((1.0 - pulse) * (isDark ? 0.6 : 0.35)),
                        width: 1.0,
                      ),
                    ),
                  ),
                  // Solid icon avatar
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressPill(Color tradeColor, Color tradeDarkColor) {
    final isRoute = widget.mode == MapMode.routeNavigation;
    final isDark = _currentLayer == MapLayerType.dark;
    String displayAddress = (_liveAddress ?? widget.pickupAddress).trim();
    if (displayAddress.toLowerCase().contains('mumbai') ||
        displayAddress.toLowerCase().contains('bombay') ||
        displayAddress.isEmpty) {
      displayAddress = 'current_live_location'.trSafe('Current Live Location');
    }

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
                color: isDark
                    ? const Color(0xE60F172A)
                    : Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? const Color(0x33FFFFFF) : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
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
                      color: Color(0xFF2563EB),
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: Colors.white, size: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'your_location_caps'.trSafe('YOUR LOCATION'),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          displayAddress,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color:
                        isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400,
                  ),
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
                  colors: _isAtSameSpot
                      ? [const Color(0xFF059669), const Color(0xFF047857)]
                      : [tradeColor, tradeDarkColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isAtSameSpot ? const Color(0xFF059669) : tradeColor)
                            .withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isAtSameSpot
                        ? 'arrived'.trSafe('ARRIVED')
                        : '$_computedEtaMinutes MIN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _isAtSameSpot
                        ? 'on_site_small'.trSafe('On Site')
                        : '${_computedDistanceKm.toStringAsFixed(1)} km${_roadRoute?.primaryRoad != null ? " · ${_roadRoute!.primaryRoad}" : ""}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
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
    final isDark = _currentLayer == MapLayerType.dark;
    final currentRad = (widget.broadcastRadiusKm > 0
            ? widget.broadcastRadiusKm
            : 10.0)
        .toInt();
    final statusColor = _isAtSameSpot
        ? const Color(0xFF059669)
        : (isRoute ? const Color(0xFF10B981) : tradeColor);
    final statusText = _isAtSameSpot
        ? 'specialist_arrived_doorstep'
            .trSafe('Specialist Arrived · At Your Doorstep')
        : (isRoute
            ? 'artisan_en_route_arg'.trSafe(
                'Artisan En Route · {}', [tradeVehicleLabel.toLocalizedTrade()])
            : 'searching_within_radius'
                .trSafe('Scanning {} km live radius', [currentRad.toString()]));
    final badgeText = _isAtSameSpot
        ? 'on_site'.trSafe('ON SITE')
        : (isRoute
            ? 'live_gps'.trSafe('LIVE GPS')
            : (widget.onRadiusChanged != null
                ? '$currentRad KM ▾'
                : 'scanning'.trSafe('SCANNING')));

    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isDark ? const Color(0xE60F172A) : Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0x33FFFFFF) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
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
                            color: statusColor
                                .withOpacity(0.4 + _pulseCtrl.value * 0.4),
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
                      statusText,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF334155),
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
            // Badge — if broadcast mode & callback provided, interactive chip to cycle radius!
            GestureDetector(
              onTap: (!isRoute && widget.onRadiusChanged != null)
                  ? () {
                      HapticFeedback.lightImpact();
                      final options = [10.0, 15.0, 20.0, 25.0, 35.0];
                      int idx = options.indexOf(widget.broadcastRadiusKm);
                      double next = (idx >= 0 && idx < options.length - 1)
                          ? options[idx + 1]
                          : options.first;
                      widget.onRadiusChanged!(next);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: (!isRoute && widget.onRadiusChanged != null)
                      ? Border.all(
                          color: statusColor.withOpacity(0.35), width: 0.8)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (!isRoute && widget.onRadiusChanged != null) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.unfold_more_rounded,
                          size: 11, color: statusColor),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map Layer Switcher Implementation ──────────────────────────────────────

  Widget _buildTileLayer() {
    switch (_currentLayer) {
      case MapLayerType.dark:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.workgo.cooperative',
          maxZoom: 19,
          tileBuilder: (context, tileWidget, tile) {
            return ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                -0.85, 0, 0, 0, 220,
                0, -0.85, 0, 0, 222,
                0, 0, -0.82, 0, 235,
                0, 0, 0, 1, 0,
              ]),
              child: tileWidget,
            );
          },
        );
      case MapLayerType.street:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'in.workgo.cooperative',
          maxZoom: 19,
        );
      case MapLayerType.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'in.workgo.cooperative',
          maxZoom: 18,
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        );
    }
  }

  void _showLayerSelectionSheet() {
    final isDarkSheet = _currentLayer == MapLayerType.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          decoration: BoxDecoration(
            color: isDarkSheet ? const Color(0xFF1E1035) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDarkSheet
                ? Border.all(color: const Color(0x33FFFFFF), width: 1)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkSheet ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.layers_rounded,
                      color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'map_layers_title'.trSafe('Map View & Layers'),
                    style: TextStyle(
                      color:
                          isDarkSheet ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildLayerOptionCard(
                    layer: MapLayerType.dark,
                    title: 'layer_radar_dark'.trSafe('Radar / Dark'),
                    subtitle: 'layer_radar_dark_sub'
                        .trSafe('Sleek high-contrast radar'),
                    icon: Icons.radar_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDarkSheet: isDarkSheet,
                  ),
                  const SizedBox(width: 8),
                  _buildLayerOptionCard(
                    layer: MapLayerType.street,
                    title: 'layer_street_title'.trSafe('Street View'),
                    subtitle: 'layer_street_sub'
                        .trSafe('Crisp Carto roads & landmarks'),
                    icon: Icons.map_rounded,
                    color: const Color(0xFF0284C7),
                    isDarkSheet: isDarkSheet,
                  ),
                  const SizedBox(width: 8),
                  _buildLayerOptionCard(
                    layer: MapLayerType.satellite,
                    title: 'layer_satellite_title'.trSafe('Satellite View'),
                    subtitle:
                        'layer_satellite_sub'.trSafe('Real aerial imagery'),
                    icon: Icons.satellite_alt_rounded,
                    color: const Color(0xFF059669),
                    isDarkSheet: isDarkSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerOptionCard({
    required MapLayerType layer,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isDarkSheet = false,
  }) {
    final isSelected = _currentLayer == layer;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentLayer = layer);
          Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDarkSheet ? 0.25 : 0.08)
                : (isDarkSheet
                    ? const Color(0xFF281545)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDarkSheet
                      ? const Color(0x26FFFFFF)
                      : Colors.grey.shade200),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : (isDarkSheet ? const Color(0xFF3B1E63) : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon,
                    size: 17, color: isSelected ? Colors.white : color),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isDarkSheet ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDarkSheet
                      ? const Color(0xFFCBD5E1)
                      : Colors.grey.shade600,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle_rounded, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic 360° rotating radar sweep cone & ultrasonic pulse waves for broadcast scanning
class _BroadcastRadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final double pulse;
  final Color color;
  final bool isDark;

  _BroadcastRadarSweepPainter({
    required this.sweepAngle,
    required this.pulse,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Soft radial ambient glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(isDark ? 0.16 : 0.08),
          color.withOpacity(isDark ? 0.05 : 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    // 2. Concentric tactical grid rings
    final gridPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.14 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.35, gridPaint);
    canvas.drawCircle(center, radius * 0.65, gridPaint);
    canvas.drawCircle(center, radius * 0.95, gridPaint);

    // 3. Expanding acoustic ultrasonic wave ripples
    final wavePulse1 = pulse;
    final wavePulse2 = (pulse + 0.5) % 1.0;

    void drawWave(double p) {
      final r = radius * (0.2 + p * 0.78);
      final alpha = (1.0 - p) * (isDark ? 0.42 : 0.26);
      final wavePaint = Paint()
        ..color = color.withOpacity(alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(center, r, wavePaint);
    }

    drawWave(wavePulse1);
    drawWave(wavePulse2);

    // 4. Rotating 360° radar sweep cone
    const sweepSpan = math.pi * 0.38; // ~68 degree sweep cone
    final sweepRect = Rect.fromCircle(center: center, radius: radius * 0.95);
    final conePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - sweepSpan,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          color.withOpacity(isDark ? 0.04 : 0.02),
          color.withOpacity(isDark ? 0.24 : 0.14),
        ],
        stops: const [0.0, 0.4, 1.0],
        transform: GradientRotation(0),
      ).createShader(sweepRect);

    canvas.drawArc(
      sweepRect,
      sweepAngle - sweepSpan,
      sweepSpan,
      true,
      conePaint,
    );

    // 5. Leading scanning needle
    final needleTip = Offset(
      center.dx + (radius * 0.95) * math.cos(sweepAngle),
      center.dy + (radius * 0.95) * math.sin(sweepAngle),
    );

    final needlePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.55),
          Colors.white,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromPoints(center, needleTip))
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, needleTip, needlePaint);

    // Needle tip blip
    final tipGlow = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needleTip, 2.5, tipGlow);
  }

  @override
  bool shouldRepaint(covariant _BroadcastRadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
