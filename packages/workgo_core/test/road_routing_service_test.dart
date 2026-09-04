import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('RoadRoutingService Tests', () {
    // Real Coordinates: Perundurai (MBA Block) to Erode Central
    const perundurai = LatLng(11.2743, 77.5866);
    const erode = LatLng(11.3410, 77.7172);

    test('should fetch road-snapped polyline between Perundurai and Erode with genuine road geometry', () async {
      final route = await RoadRoutingService.instance.getRoute(
        origin: perundurai,
        destination: erode,
        forceRefresh: true,
      );

      // Verify that the route succeeded
      expect(route.isSuccess, isTrue);
      // Verify that it is NOT a 2-point straight line, but has dozens of road coordinates tracing the highway curves!
      expect(route.points.length, greaterThan(15));

      // Driving distance between Perundurai & Erode via NH544 is ~17-22 km (longer than Euclidean 16 km)
      expect(route.distanceKm, greaterThan(15.0));
      expect(route.distanceKm, lessThan(30.0));

      // Real driving duration is at least 15-45 minutes
      expect(route.durationMinutes, greaterThan(10));
      expect(route.durationMinutes, lessThan(60));

      // Verify provider is one of the valid routing engines
      expect(['mapbox', 'openrouteservice', 'osrm'], contains(route.provider));
    });

    test('should utilize in-memory cache on repeat calls without network query', () async {
      // First call (populates cache)
      final route1 = await RoadRoutingService.instance.getRoute(
        origin: perundurai,
        destination: erode,
      );

      // Second call (hits cache)
      final route2 = await RoadRoutingService.instance.getRoute(
        origin: perundurai,
        destination: erode,
      );

      expect(identical(route1, route2), isTrue);
    });

    test('should verify OpenRouteService is active primary provider and extracts primary road name', () async {
      final route = await RoadRoutingService.instance.getRoute(
        origin: perundurai,
        destination: erode,
        forceRefresh: true,
      );

      expect(route.isSuccess, isTrue);
      expect(route.provider, equals('openrouteservice'));
      expect(route.primaryRoad, contains('SH173'));
    });

    test('should detect deviation when vehicle strays away from polyline', () {
      final polyline = [
        const LatLng(11.2743, 77.5866),
        const LatLng(11.2800, 77.6000),
        const LatLng(11.3000, 77.6500),
        const LatLng(11.3410, 77.7172),
      ];

      // A point right on the first waypoint -> NOT deviated
      final onTrack = RoadRoutingService.instance.hasDeviatedFromRoute(
        currentPosition: const LatLng(11.2743, 77.5866),
        routePoints: polyline,
        thresholdMeters: 60.0,
      );
      expect(onTrack, isFalse);

      // A point 5 km away (e.g. 11.4000, 77.5866) -> DEVIATED
      final offTrack = RoadRoutingService.instance.hasDeviatedFromRoute(
        currentPosition: const LatLng(11.4000, 77.5866),
        routePoints: polyline,
        thresholdMeters: 60.0,
      );
      expect(offTrack, isTrue);
    });

    test('should gracefully handle identical start and end points', () async {
      final route = await RoadRoutingService.instance.getRoute(
        origin: perundurai,
        destination: perundurai,
        forceRefresh: true,
      );

      expect(route.isSuccess, isTrue);
      expect(route.distanceKm, lessThan(0.5));
    });
  });
}
