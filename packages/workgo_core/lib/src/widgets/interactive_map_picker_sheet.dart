import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../localization/trade_localization.dart';
import '../models/user_address.dart';
import '../services/location_service.dart';

/// Opens the interactive, full-featured map location picker sheet.
/// Allows consumers to pan the map, drag/adjust the center pin onto their doorstep,
/// search landmarks, and confirm their exact service coordinates.
Future<UserAddress?> showInteractiveMapPickerSheet(
  BuildContext context, {
  double? initialLatitude,
  double? initialLongitude,
  String? initialAddress,
}) async {
  return showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: false,
    builder: (ctx) => InteractiveMapPickerSheet(
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      initialAddress: initialAddress,
    ),
  );
}

class InteractiveMapPickerSheet extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const InteractiveMapPickerSheet({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<InteractiveMapPickerSheet> createState() => _InteractiveMapPickerSheetState();
}

class _InteractiveMapPickerSheetState extends State<InteractiveMapPickerSheet> {
  late final MapController _mapController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _flatCtrl = TextEditingController();
  final TextEditingController _landmarkCtrl = TextEditingController();

  late LatLng _currentCenter;
  String _currentAddressText = "";
  String _currentCity = "";
  String _currentPincode = "";
  bool _isMapMoving = false;
  bool _isReverseGeocoding = false;
  bool _isSearching = false;
  bool _isLocatingGps = false;
  Timer? _debounceTimer;

  static const LatLng _defaultFallback = LatLng(11.2743, 77.5866); // Perundurai / Erode Central

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final validLat = widget.initialLatitude != null && widget.initialLatitude! > 1.0;
    final validLng = widget.initialLongitude != null && widget.initialLongitude! > 1.0;

    _currentCenter = (validLat && validLng)
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _defaultFallback;

    _currentAddressText = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!
        : "Detecting location...";

    if (widget.initialLatitude == null || widget.initialLatitude! <= 1.0) {
      _fetchDeviceGpsInitial();
    } else {
      _reverseGeocodeCoordinate(_currentCenter.latitude, _currentCenter.longitude);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _flatCtrl.dispose();
    _landmarkCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceGpsInitial() async {
    try {
      final coords = await LocationService.instance.getCurrentCoordinates();
      final lat = coords["latitude"] ?? _defaultFallback.latitude;
      final lng = coords["longitude"] ?? _defaultFallback.longitude;
      if (mounted && lat > 1.0) {
        final newCenter = LatLng(lat, lng);
        setState(() {
          _currentCenter = newCenter;
        });
        _mapController.move(newCenter, 16.5);
        _reverseGeocodeCoordinate(lat, lng);
      }
    } catch (_) {}
  }

  Future<void> _onGpsButtonTapped() async {
    HapticFeedback.selectionClick();
    setState(() => _isLocatingGps = true);
    try {
      final coords = await LocationService.instance.getCurrentCoordinates();
      final lat = coords["latitude"] ?? _currentCenter.latitude;
      final lng = coords["longitude"] ?? _currentCenter.longitude;
      if (mounted && lat > 1.0) {
        final newCenter = LatLng(lat, lng);
        setState(() {
          _currentCenter = newCenter;
          _isLocatingGps = false;
        });
        _mapController.move(newCenter, 17.0);
        _reverseGeocodeCoordinate(lat, lng);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!mounted) return;
    if (!_isMapMoving) {
      setState(() => _isMapMoving = true);
    }
    _currentCenter = camera.center;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        setState(() => _isMapMoving = false);
        _reverseGeocodeCoordinate(_currentCenter.latitude, _currentCenter.longitude);
      }
    });
  }

  Future<void> _reverseGeocodeCoordinate(double lat, double lon) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final decoded = await LocationService.instance.reverseGeocode(lat, lon);
      if (mounted) {
        setState(() {
          _currentAddressText = decoded.formattedAddress;
          _currentCity = decoded.city;
          _currentPincode = decoded.pincode;
          _isReverseGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddressText = "${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}";
          _isReverseGeocoding = false;
        });
      }
    }
  }

  Future<void> _onSearchSubmitted(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    try {
      final res = await LocationService.instance.forwardGeocode(q);
      if (res != null && res["latitude"] != null && res["latitude"]! > 1.0) {
        final target = LatLng(res["latitude"]!, res["longitude"]!);
        if (mounted) {
          setState(() {
            _currentCenter = target;
            _isSearching = false;
          });
          _mapController.move(target, 16.5);
          _reverseGeocodeCoordinate(target.latitude, target.longitude);
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not locate '$q'. Pan the map directly to your area.",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF1E1035),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmLocation() {
    HapticFeedback.mediumImpact();
    final flat = _flatCtrl.text.trim();
    final landmark = _landmarkCtrl.text.trim();

    String fullFormatted = _currentAddressText;
    if (flat.isNotEmpty) {
      fullFormatted = "$flat, $fullFormatted";
    }
    if (landmark.isNotEmpty) {
      fullFormatted = "$fullFormatted (Near $landmark)";
    }

    final confirmed = UserAddress(
      id: "picked_${DateTime.now().millisecondsSinceEpoch}",
      label: AddressLabel.home,
      flatBuilding: flat,
      streetArea: _currentAddressText,
      landmark: landmark,
      city: _currentCity.isNotEmpty ? _currentCity : "Local Area",
      state: "Tamil Nadu",
      pincode: _currentPincode,
      formattedAddress: fullFormatted,
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.90;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            // ── 1. Full-Height Interactive Map Canvas ─────────────────────
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: 16.5,
                  minZoom: 5.0,
                  maxZoom: 18.5,
                  onPositionChanged: _onMapPositionChanged,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'in.workgo.cooperative',
                    maxZoom: 19,
                  ),
                ],
              ),
            ),

            // ── 2. Fixed Animated Center Pin & Pulsing Shadow ─────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Pin
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      transform: Matrix4.translationValues(0, _isMapMoving ? -14 : 0, 0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1035),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFB800), width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x35000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFFFB800),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Shadow dot on map surface
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _isMapMoving ? 8 : 14,
                      height: _isMapMoving ? 3 : 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isMapMoving ? 0.2 : 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Top Floating Search Bar & Close Button ─────────────────
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back / Close circular button
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x18000000), blurRadius: 10, offset: Offset(0, 3)),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E1035), size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Search text input
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3)),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _onSearchSubmitted,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: "search_area_hint".trSafe("Search street, landmark, area..."),
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB800)),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFD97706), size: 18),
                                      onPressed: () => _onSearchSubmitted(_searchCtrl.text),
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtle Instruction Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1035).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pan_tool_alt_rounded, color: Color(0xFFFFB800), size: 13),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "drag_pin_hint".trSafe("Pan map to position pin on your doorstep"),
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. Floating Action Controls (GPS & Zoom) ───────────────────
            Positioned(
              right: 16,
              bottom: 270,
              child: Column(
                children: [
                  // Live GPS Center Button
                  FloatingActionButton.small(
                    heroTag: "map_picker_gps_fab",
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0284C7),
                    elevation: 3,
                    onPressed: _isLocatingGps ? null : _onGpsButtonTapped,
                    child: _isLocatingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                  ),
                  const SizedBox(height: 10),

                  // Zoom In
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 20),
                      onPressed: () {
                        final z = _mapController.camera.zoom + 1.0;
                        _mapController.move(_currentCenter, z.clamp(5.0, 18.5));
                      },
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Zoom Out
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A), size: 20),
                      onPressed: () {
                        final z = _mapController.camera.zoom - 1.0;
                        _mapController.move(_currentCenter, z.clamp(5.0, 18.5));
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── 5. Bottom Detailed Address Confirmation Card ──────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location Header & Coordinates Chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.pin_drop_rounded, color: Color(0xFFD97706), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "doorstep_location".trSafe("Service Doorstep"),
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}",
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                if (_isReverseGeocoding)
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFD97706)),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Updating address...",
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    _currentAddressText.toLocalizedAddress(context.locale.languageCode),
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Optional Flat / House No & Landmark Input Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: _flatCtrl,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: "flat_house_hint".trSafe("Flat / House No. (Opt)"),
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: _landmarkCtrl,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: "landmark_hint".trSafe("Landmark (Opt)"),
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Confirm Location Button
                      ElevatedButton(
                        onPressed: _isMapMoving ? null : _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: const Color(0xFF1E1035),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF1E1035), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "confirm_location_btn".trSafe("Confirm Service Location"),
                                style: const TextStyle(
                                  color: Color(0xFF1E1035),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
