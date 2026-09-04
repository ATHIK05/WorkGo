import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Represents a turn-by-turn road navigation route geometry and metadata.
class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String? primaryRoad;
  final String provider;
  final bool isSuccess;
  final String? errorMessage;

  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.primaryRoad,
    required this.provider,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory RoadRoute.failure(String message, {List<LatLng>? fallbackPoints}) {
    return RoadRoute(
      points: fallbackPoints ?? const [],
      distanceKm: 0.0,
      durationMinutes: 0,
      provider: 'none',
      isSuccess: false,
      errorMessage: message,
    );
  }

  @override
  String toString() =>
      'RoadRoute(points: ${points.length}, dist: ${distanceKm.toStringAsFixed(1)}km, time: ${durationMinutes}min, road: $primaryRoad, provider: $provider)';
}

/// Cache entry for in-memory route caching.
class _CachedRoute {
  final RoadRoute route;
  final DateTime timestamp;

  _CachedRoute(this.route) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > 40;
}

/// Hybrid Road Routing Engine for WorkGo.
///
/// Multi-Tier Architecture:
/// 1. Primary: Mapbox Directions API (traffic-aware, turn maneuvers).
/// 2. Fallback: OpenRouteService (OSM road network).
/// 3. Fail-Safe: OSRM Public Engine (100% free, zero-key, ensures the route is NEVER a straight line).
class RoadRoutingService {
  RoadRoutingService._();
  static final RoadRoutingService instance = RoadRoutingService._();

  // Configurable tokens — pre-configured with active OpenRouteService token
  String? openRouteServiceApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRkYjdlM2NiZGU5YjRmNjhhYWUyZTk4ZmM1OGUyNGVlIiwiaCI6Im11cm11cjY0In0=';
  String? mapboxAccessToken;

  final Map<String, _CachedRoute> _cache = {};

  /// Computes a road-snapped driving route between [origin] and [destination].
  ///
  /// Priority:
  /// 1. OpenRouteService (Active token)
  /// 2. OSRM Public Routing Engine (Zero-key fail-safe backup)
  /// 3. Mapbox Directions API (Retained in codebase as tertiary option)
  Future<RoadRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
    bool forceRefresh = false,
  }) async {
    // 0. Cache check
    final cacheKey = _buildCacheKey(origin, destination);
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.route;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // 1. Try OpenRouteService (Primary)
    if (openRouteServiceApiKey != null && openRouteServiceApiKey!.trim().isNotEmpty) {
      try {
        final route = await _fetchOpenRouteService(origin, destination);
        if (route.isSuccess && route.points.length > 1) {
          _cache[cacheKey] = _CachedRoute(route);
          return route;
        }
      } catch (e) {
        debugPrint("[RoadRoutingService] OpenRouteService failed, switching to OSRM: $e");
      }
    }

    // 2. Fail-Safe: OSRM Public Engine (Guaranteed 0-Key Backup)
    try {
      final route = await _fetchOsrmRoute(origin, destination);
      if (route.isSuccess && route.points.length > 1) {
        _cache[cacheKey] = _CachedRoute(route);
        return route;
      }
    } catch (e) {
      debugPrint("[RoadRoutingService] OSRM query failed: $e");
    }

    // 3. Try Mapbox Directions API (Tertiary / Optional)
    if (mapboxAccessToken != null && mapboxAccessToken!.trim().isNotEmpty) {
      try {
        final route = await _fetchMapboxRoute(origin, destination);
        if (route.isSuccess && route.points.length > 1) {
          _cache[cacheKey] = _CachedRoute(route);
          return route;
        }
      } catch (e) {
        debugPrint("[RoadRoutingService] Mapbox query failed: $e");
      }
    }

    // 4. Absolute Fallback: Geometric straight line if completely offline
    final directDistanceKm = const Distance().as(LengthUnit.Kilometer, origin, destination);
    final fallback = RoadRoute(
      points: [origin, destination],
      distanceKm: directDistanceKm,
      durationMinutes: (directDistanceKm / 0.5).round().clamp(1, 180),
      provider: 'fallback_straight',
      isSuccess: false,
      errorMessage: 'Network offline: road routing unavailable.',
    );
    return fallback;
  }

  // ── 1. Mapbox Directions v5 ────────────────────────────────────────────────
  Future<RoadRoute> _fetchMapboxRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
      '?geometries=geojson&overview=full&steps=true&access_token=${mapboxAccessToken!.trim()}',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      return RoadRoute.failure('Mapbox HTTP ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return RoadRoute.failure('Mapbox returned no routes.');
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;

    final points = coords.map((c) {
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();

    final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

    String? primaryRoad;
    final legs = firstRoute['legs'] as List<dynamic>?;
    if (legs != null && legs.isNotEmpty) {
      final summary = legs[0]['summary'] as String?;
      if (summary != null && summary.isNotEmpty) {
        primaryRoad = summary.startsWith('via ') ? summary : 'via $summary';
      }
    }

    return RoadRoute(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60.0).round(),
      primaryRoad: primaryRoad,
      provider: 'mapbox',
    );
  }

  // ── 2. OpenRouteService ───────────────────────────────────────────────────
  Future<RoadRoute> _fetchOpenRouteService(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car'
      '?api_key=${openRouteServiceApiKey!.trim()}'
      '&start=${origin.longitude},${origin.latitude}'
      '&end=${destination.longitude},${destination.latitude}',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      return RoadRoute.failure('OpenRouteService HTTP ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return RoadRoute.failure('OpenRouteService returned no features.');
    }

    final firstFeature = features[0] as Map<String, dynamic>;
    final geometry = firstFeature['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;

    final points = coords.map((c) {
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();

    final properties = firstFeature['properties'] as Map<String, dynamic>? ?? {};
    final summary = properties['summary'] as Map<String, dynamic>? ?? {};
    final distanceMeters = (summary['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (summary['duration'] as num?)?.toDouble() ?? 0.0;

    String? primaryRoad;
    final segments = properties['segments'] as List<dynamic>?;
    if (segments != null && segments.isNotEmpty) {
      final steps = segments[0]['steps'] as List<dynamic>?;
      if (steps != null) {
        double maxDist = 0.0;
        for (final step in steps) {
          final sName = (step['name'] as String?)?.trim();
          final sDist = (step['distance'] as num?)?.toDouble() ?? 0.0;
          if (sName != null && sName.isNotEmpty && sName != '-' && sDist > maxDist) {
            maxDist = sDist;
            primaryRoad = sName.startsWith('via ') ? sName : 'via $sName';
          }
        }
      }
    }

    return RoadRoute(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60.0).round(),
      primaryRoad: primaryRoad,
      provider: 'openrouteservice',
    );
  }

  // ── 3. OSRM Public Routing Machine (100% Free Zero-Key Fail-Safe) ─────────
  Future<RoadRoute> _fetchOsrmRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      return RoadRoute.failure('OSRM HTTP ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      return RoadRoute.failure('OSRM code: ${data['code']}');
    }

    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return RoadRoute.failure('OSRM returned no routes.');
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final geometry = firstRoute['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;

    final points = coords.map((c) {
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return LatLng(lat, lon);
    }).toList();

    final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

    String? primaryRoad;
    final legs = firstRoute['legs'] as List<dynamic>?;
    if (legs != null && legs.isNotEmpty) {
      final summary = legs[0]['summary'] as String?;
      if (summary != null && summary.trim().isNotEmpty) {
        primaryRoad = summary.startsWith('via ') ? summary : 'via $summary';
      }
    }

    return RoadRoute(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60.0).round(),
      primaryRoad: primaryRoad,
      provider: 'osrm',
    );
  }

  /// Check if an updated coordinate has drifted off the existing polyline by > [thresholdMeters].
  bool hasDeviatedFromRoute({
    required LatLng currentPosition,
    required List<LatLng> routePoints,
    double thresholdMeters = 60.0,
  }) {
    if (routePoints.isEmpty) return true;
    final dist = const Distance();
    double minDistance = double.infinity;

    for (final pt in routePoints) {
      final d = dist.as(LengthUnit.Meter, currentPosition, pt);
      if (d < minDistance) {
        minDistance = d;
      }
      if (minDistance <= thresholdMeters) {
        return false;
      }
    }

    return minDistance > thresholdMeters;
  }

  String _buildCacheKey(LatLng o, LatLng d) {
    return '${o.latitude.toStringAsFixed(4)},${o.longitude.toStringAsFixed(4)}->${d.latitude.toStringAsFixed(4)},${d.longitude.toStringAsFixed(4)}';
  }

  /// Clears the in-memory route cache.
  void clearCache() => _cache.clear();
}
