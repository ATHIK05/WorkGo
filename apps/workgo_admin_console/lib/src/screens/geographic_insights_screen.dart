import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:workgo_core/workgo_core.dart';
import '../admin_theme.dart';

// --- Models ---
class RegionData {
  final String id;
  final String name;
  final String parentId;
  final int workers;
  final int customers;
  final List<List<LatLng>> polygons;
  final LatLngBounds bounds;

  RegionData({
    required this.id,
    required this.name,
    required this.parentId,
    required this.workers,
    required this.customers,
    required this.polygons,
    required this.bounds,
  });
}

// --- Background Parser (runs in isolate via compute()) ---
Map<String, List<RegionData>> parseGeoJsonMap(Map<String, dynamic> args) {
  final stateJsonStr = args['stateJson'] as String;
  final districtJsonStr = args['districtJson'] as String;
  final stateWorkerCount = args['stateWorkerCount'] as Map<String, int>;
  final stateCustomerCount = args['stateCustomerCount'] as Map<String, int>;
  final distWorkerCount = args['distWorkerCount'] as Map<String, int>;
  final distCustomerCount = args['distCustomerCount'] as Map<String, int>;

  List<RegionData> parseFeatures(String jsonStr, bool isState) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List<dynamic> features = data['features'] ?? [];
    List<RegionData> regions = [];

    for (var feature in features) {
      final properties = feature['properties'] ?? {};
      final geometry = feature['geometry'];
      if (geometry == null) continue;

      final type = geometry['type'];
      final coords = geometry['coordinates'];

      String name = properties['NAME_1'] ?? properties['st_nm'] ?? 'Unknown State';
      String parentId = '';
      if (!isState) {
        name = properties['NAME_2'] ?? properties['district'] ?? 'Unknown District';
        parentId = properties['NAME_1'] ?? properties['st_nm'] ?? 'Unknown State';
      }

      List<List<LatLng>> polygons = [];
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

      void processRing(List ring) {
        List<LatLng> points = [];
        for (var pt in ring) {
          double lng = (pt[0] as num).toDouble();
          double lat = (pt[1] as num).toDouble();
          points.add(LatLng(lat, lng));
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
        }
        if (points.isNotEmpty) polygons.add(points);
      }

      if (type == 'Polygon') {
        for (var ring in coords) { processRing(ring); }
      } else if (type == 'MultiPolygon') {
        for (var polygon in coords) {
          for (var ring in polygon) { processRing(ring); }
        }
      }

      if (polygons.isNotEmpty) {
        final wCount = isState ? stateWorkerCount : distWorkerCount;
        final cCount = isState ? stateCustomerCount : distCustomerCount;
        final searchName = name.toLowerCase().replaceAll(' ', '');

        int realWorkers = 0;
        int realCustomers = 0;

        for (var key in wCount.keys) {
          final k = key.toLowerCase().replaceAll(' ', '');
          if (k.isNotEmpty && (k == searchName || searchName.contains(k) || k.contains(searchName))) {
            realWorkers += wCount[key]!;
          }
        }
        for (var key in cCount.keys) {
          final k = key.toLowerCase().replaceAll(' ', '');
          if (k.isNotEmpty && (k == searchName || searchName.contains(k) || k.contains(searchName))) {
            realCustomers += cCount[key]!;
          }
        }

        regions.add(RegionData(
          id: name, name: name, parentId: parentId,
          workers: realWorkers, customers: realCustomers,
          polygons: polygons,
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        ));
      }
    }
    return regions;
  }

  final districts = parseFeatures(districtJsonStr, false);

  Map<String, int> aggregatedStateWorkers = {};
  Map<String, int> aggregatedStateCustomers = {};
  for (var dist in districts) {
    aggregatedStateWorkers[dist.parentId] = (aggregatedStateWorkers[dist.parentId] ?? 0) + dist.workers;
    aggregatedStateCustomers[dist.parentId] = (aggregatedStateCustomers[dist.parentId] ?? 0) + dist.customers;
  }

  List<RegionData> states = parseFeatures(stateJsonStr, true);
  for (int i = 0; i < states.length; i++) {
    final s = states[i];
    states[i] = RegionData(
      id: s.id, name: s.name, parentId: s.parentId,
      workers: s.workers + (aggregatedStateWorkers[s.name] ?? 0),
      customers: s.customers + (aggregatedStateCustomers[s.name] ?? 0),
      polygons: s.polygons, bounds: s.bounds,
    );
  }

  return {'states': states, 'districts': districts};
}

// ============================================================
// MAIN SCREEN — owns data & navigation state only
// ============================================================
class GeographicInsightsScreen extends StatefulWidget {
  const GeographicInsightsScreen({super.key});

  @override
  State<GeographicInsightsScreen> createState() => _GeographicInsightsScreenState();
}

class _GeographicInsightsScreenState extends State<GeographicInsightsScreen> {
  bool _isLoading = true;
  List<RegionData> _states = [];
  List<RegionData> _districts = [];

  bool _showingDistricts = false;
  String _selectedStateId = '';
  bool _showingWorkers = true;

  final MapController _mapController = MapController();

  final LatLngBounds _indiaBounds = LatLngBounds(
    const LatLng(6.5, 68.1),
    const LatLng(35.5, 97.4),
  );

  @override
  void initState() {
    super.initState();
    _loadGeoData();
  }

  Future<void> _loadGeoData() async {
    try {
      final stateJson = await rootBundle.loadString('assets/geo/india_state_opt.json');
      final districtJson = await rootBundle.loadString('assets/geo/india_district_opt.json');

      Map<String, int> stateWorkerCount = {};
      Map<String, int> stateCustomerCount = {};
      Map<String, int> distWorkerCount = {};
      Map<String, int> distCustomerCount = {};

      try {
        final usersSnap = await FirebaseFirestore.instance.collection('users').get();
        final workersSnap = await FirebaseFirestore.instance.collection('workers').get();

        List<AppUser> allUsers = [];
        Set<String> processedUids = {};

        for (var doc in usersSnap.docs) {
          final data = doc.data();
          data['uid'] = doc.id;
          final u = AppUser.fromMap(data);
          allUsers.add(u);
          processedUids.add(u.uid);
        }
        for (var doc in workersSnap.docs) {
          final data = doc.data();
          data['uid'] = doc.id;
          if (data['role'] == null) data['role'] = 'worker';
          final u = AppUser.fromMap(data);
          if (!processedUids.contains(u.uid)) {
            allUsers.add(u);
            processedUids.add(u.uid);
          }
        }

        for (var u in allUsers) {
          String state = u.region;
          if (state.isEmpty || state == 'null') state = 'Tamil Nadu';

          String dist = u.primaryArea ?? u.currentAddress?.city ?? '';
          if (dist.isEmpty || dist == 'null') {
            final fmt = u.currentAddress?.formattedAddress ?? '';
            if (fmt.toLowerCase().contains('erode')) dist = 'Erode';
            if (fmt.toLowerCase().contains('chennai')) dist = 'Chennai';
          }
          if (dist.isEmpty) dist = 'Erode';

          if (u.role == UserRole.worker) {
            if (dist.isNotEmpty) {
              distWorkerCount[dist] = (distWorkerCount[dist] ?? 0) + 1;
            } else if (state.isNotEmpty) {
              stateWorkerCount[state] = (stateWorkerCount[state] ?? 0) + 1;
            }
          } else {
            if (dist.isNotEmpty) {
              distCustomerCount[dist] = (distCustomerCount[dist] ?? 0) + 1;
            } else if (state.isNotEmpty) {
              stateCustomerCount[state] = (stateCustomerCount[state] ?? 0) + 1;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching real data: $e');
      }

      final result = await compute(parseGeoJsonMap, {
        'stateJson': stateJson,
        'districtJson': districtJson,
        'stateWorkerCount': stateWorkerCount,
        'stateCustomerCount': stateCustomerCount,
        'distWorkerCount': distWorkerCount,
        'distCustomerCount': distCustomerCount,
      });

      if (mounted) {
        setState(() {
          _states = result['states']!;
          _districts = result['districts']!;
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          _mapController.fitCamera(CameraFit.bounds(bounds: _indiaBounds, padding: const EdgeInsets.all(32)));
        });
      }
    } catch (e) {
      debugPrint('Error loading geodata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _drillIntoState(RegionData state) {
    setState(() {
      _showingDistricts = true;
      _selectedStateId = state.id;
    });
    _mapController.fitCamera(CameraFit.bounds(bounds: state.bounds, padding: const EdgeInsets.all(64)));
  }

  void _zoomOutToNational() {
    setState(() {
      _showingDistricts = false;
      _selectedStateId = '';
    });
    _mapController.fitCamera(CameraFit.bounds(bounds: _indiaBounds, padding: const EdgeInsets.all(32)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AX.bgCosmic,
        body: Center(child: CircularProgressIndicator(color: AX.emerald)),
      );
    }

    final activeRegions = _showingDistricts
        ? _districts.where((d) => d.parentId == _selectedStateId).toList()
        : _states;

    return Scaffold(
      backgroundColor: AX.bgCosmic,
      body: _MapView(
        regions: activeRegions,
        showingWorkers: _showingWorkers,
        showingDistricts: _showingDistricts,
        selectedStateId: _selectedStateId,
        mapController: _mapController,
        onRegionTapped: (r) {
          if (!_showingDistricts) _drillIntoState(r);
        },
        onBack: _zoomOutToNational,
        onToggleWorkers: (v) => setState(() => _showingWorkers = v),
      ),
    );
  }
}

// ============================================================
// MAP VIEW — owns ONLY hover state. Parent never rebuilds on hover.
// ============================================================
class _MapView extends StatefulWidget {
  final List<RegionData> regions;
  final bool showingWorkers;
  final bool showingDistricts;
  final String selectedStateId;
  final MapController mapController;
  final ValueChanged<RegionData> onRegionTapped;
  final VoidCallback onBack;
  final ValueChanged<bool> onToggleWorkers;

  const _MapView({
    required this.regions,
    required this.showingWorkers,
    required this.showingDistricts,
    required this.selectedStateId,
    required this.mapController,
    required this.onRegionTapped,
    required this.onBack,
    required this.onToggleWorkers,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  RegionData? _hoveredRegion;
  final LayerHitNotifier<RegionData> _hitNotifier = ValueNotifier(null);

  // Pre-built polygon cache — only rebuilt when data/mode changes
  late List<Polygon<RegionData>> _polygons;
  late int _maxVal;

  @override
  void initState() {
    super.initState();
    _rebuildPolygons();
    _hitNotifier.addListener(_onHitChanged);
  }

  @override
  void didUpdateWidget(_MapView old) {
    super.didUpdateWidget(old);
    // Rebuild polygons only when data or mode changes — NOT on every hover
    if (old.regions != widget.regions ||
        old.showingWorkers != widget.showingWorkers ||
        old.showingDistricts != widget.showingDistricts) {
      _rebuildPolygons();
      setState(() => _hoveredRegion = null);
    }
  }

  @override
  void dispose() {
    _hitNotifier.removeListener(_onHitChanged);
    _hitNotifier.dispose();
    super.dispose();
  }

  void _onHitChanged() {
    final hits = _hitNotifier.value?.hitValues;
    final newRegion = (hits != null && hits.isNotEmpty) ? hits.first : null;
    // Guard: only setState if the hovered region actually changed identity
    if (newRegion?.id != _hoveredRegion?.id) {
      setState(() => _hoveredRegion = newRegion);
    }
  }

  void _rebuildPolygons() {
    _maxVal = 1;
    if (widget.regions.isNotEmpty) {
      _maxVal = widget.regions
          .map((e) => widget.showingWorkers ? e.workers : e.customers)
          .reduce(math.max);
      if (_maxVal == 0) _maxVal = 1;
    }

    _polygons = [];
    final strokeWidth = widget.showingDistricts ? 0.5 : 1.0;

    for (var region in widget.regions) {
      final value = widget.showingWorkers ? region.workers : region.customers;
      final color = _colorForValue(value);

      for (var points in region.polygons) {
        _polygons.add(Polygon<RegionData>(
          hitValue: region,
          points: points,
          holePointsList: const [],
          color: color,
          borderColor: Colors.black12,
          borderStrokeWidth: strokeWidth,
        ));
      }
    }
  }

  Color _colorForValue(int value) {
    if (value == 0) return Colors.black.withValues(alpha: 0.04);
    final ratio = (value / _maxVal).clamp(0.0, 1.0);
    final base = widget.showingWorkers ? AX.emerald : AX.violet;
    return Color.lerp(AX.bgSurface, base, ratio) ?? Colors.grey;
  }

  List<Polygon<RegionData>> get _hoverPolygons {
    if (_hoveredRegion == null) return const [];
    return [
      for (var pts in _hoveredRegion!.polygons)
        Polygon<RegionData>(
          points: pts,
          holePointsList: const [],
          color: Colors.transparent,
          borderColor: Colors.black87,
          borderStrokeWidth: 2.5,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds(const LatLng(6.5, 68.1), const LatLng(35.5, 97.4)),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) {
              if (_hoveredRegion != null) widget.onRegionTapped(_hoveredRegion!);
            },
          ),
          children: [
            // Layer 1: Static base polygons — cached, never changes on hover
            PolygonLayer<RegionData>(
              hitNotifier: _hitNotifier,
              polygons: _polygons,
            ),
            // Layer 2: Hover outline — tiny, cheap, only the active region
            if (_hoveredRegion != null)
              PolygonLayer<RegionData>(polygons: _hoverPolygons),
          ],
        ),
        _buildControls(),
        if (_hoveredRegion != null) _buildInfoCard(),
      ],
    );
  }

  Widget _buildInfoCard() {
    final r = _hoveredRegion!;
    return Positioned(
      bottom: 24, right: 24,
      child: IgnorePointer(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AX.bgSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AX.divider),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.name.toLocalizedRegion(context.locale.languageCode), style: AX.display(fontSize: 20)),
              const SizedBox(height: 4),
              Text(widget.showingDistricts ? 'admin_geo_district_type'.trSafe('District') : 'admin_geo_state_type'.trSafe('State'),
                  style: AX.mono(fontSize: 12, color: AX.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('admin_geo_workers'.trSafe('Workers'), style: AX.body(fontSize: 12, color: AX.textSecondary)),
                    Text('${r.workers}', style: AX.display(fontSize: 18, color: AX.emerald)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('admin_geo_customers'.trSafe('Customers'), style: AX.body(fontSize: 12, color: AX.textSecondary)),
                    Text('${r.customers}', style: AX.display(fontSize: 18, color: AX.violet)),
                  ]),
                ],
              ),
              if (!widget.showingDistricts) ...[
                const SizedBox(height: 16),
                Text('admin_geo_tap_districts'.trSafe('Tap to see districts'), style: AX.mono(fontSize: 10, color: AX.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      top: 24, left: 24, right: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            if (widget.showingDistricts)
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AX.bgSurface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AX.divider),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AX.textPrimary),
                  onPressed: widget.onBack,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AX.bgSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AX.divider),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Text(
                widget.showingDistricts
                    ? 'admin_geo_district_breakdown'.trSafe('District Breakdown: ${widget.selectedStateId.toLocalizedRegion(context.locale.languageCode)}', [widget.selectedStateId.toLocalizedRegion(context.locale.languageCode)])
                    : 'admin_geo_national_map'.trSafe('National Supply Map'),
                style: AX.display(fontSize: 18),
              ),
            ),
          ]),
          Container(
            decoration: BoxDecoration(
              color: AX.bgSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AX.divider),
            ),
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              _buildToggleBtn('admin_geo_workers'.trSafe('Workers'), true, AX.emerald),
              const SizedBox(width: 8),
              _buildToggleBtn('admin_geo_customers'.trSafe('Customers'), false, AX.violet),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isWorkers, Color activeColor) {
    final active = widget.showingWorkers == isWorkers;
    return GestureDetector(
      onTap: () => widget.onToggleWorkers(isWorkers),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : AX.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'SpaceGrotesk',
          ),
        ),
      ),
    );
  }
}
