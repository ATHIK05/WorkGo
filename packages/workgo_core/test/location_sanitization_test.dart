import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Location Sanitization & Distance Calculation Tests", () {
    test("isEmulatorOrOutOfBounds detects Mountain View CA, zero coords, and negative longitudes", () {
      // Mountain View, CA (Android emulator default)
      expect(LocationService.isEmulatorOrOutOfBounds(37.4219983, -122.084), isTrue);
      // Zero coordinates
      expect(LocationService.isEmulatorOrOutOfBounds(0.0, 0.0), isTrue);
      // Negative longitude
      expect(LocationService.isEmulatorOrOutOfBounds(11.34, -77.71), isTrue);
      // Outside India (e.g. London)
      expect(LocationService.isEmulatorOrOutOfBounds(51.5074, -0.1278), isTrue);

      // Legitimate Indian coordinates: Erode, Tamil Nadu
      expect(LocationService.isEmulatorOrOutOfBounds(11.3410, 77.7172), isFalse);
      // Legitimate Indian coordinates: Perundurai
      expect(LocationService.isEmulatorOrOutOfBounds(11.2743, 77.5866), isFalse);
      // Legitimate Indian coordinates: Chennai
      expect(LocationService.isEmulatorOrOutOfBounds(13.0827, 80.2707), isFalse);
    });

    test("isMumbaiGatewayArtifact identifies ISP cellular APN proxy artifacts for non-Mumbai addresses", () {
      // Typical Mumbai APN gateway coordinates
      const mumbaiLat = 19.0760;
      const mumbaiLng = 72.8777;

      // Address is in Erode, Tamil Nadu -> MUST flag as Mumbai gateway artifact
      expect(
        LocationService.isMumbaiGatewayArtifact(mumbaiLat, mumbaiLng, "Home, Erode, Tamil Nadu 638003, Near J"),
        isTrue,
      );

      // Address is in Coimbatore -> MUST flag as Mumbai gateway artifact
      expect(
        LocationService.isMumbaiGatewayArtifact(mumbaiLat, mumbaiLng, "R.S. Puram, Coimbatore 641002"),
        isTrue,
      );

      // Address is genuinely in Mumbai / Maharashtra -> MUST NOT flag
      expect(
        LocationService.isMumbaiGatewayArtifact(mumbaiLat, mumbaiLng, "Bandra West, Mumbai, Maharashtra 400050"),
        isFalse,
      );
    });

    test("resolveSanitizedCoordinates correctly heals Mumbai artifact using Erode pincode fallback", () async {
      final service = LocationService.instance;

      // User address that originally had Mumbai IP coordinates:
      final healed = await service.resolveSanitizedCoordinates(
        addressText: "Home, Erode, Tamil Nadu 638003, Near J",
        latitude: 19.0760,
        longitude: 72.8777,
      );

      // Must be healed to Erode coordinates (approx 11.34, 77.71), NOT Mumbai (19.07, 72.87)
      expect(healed["latitude"], isNotNull);
      expect(healed["longitude"], isNotNull);
      expect(healed["latitude"]! > 11.0 && healed["latitude"]! < 12.0, isTrue);
      expect(healed["longitude"]! > 77.0 && healed["longitude"]! < 78.5, isTrue);
    });

    test("Erode customer to Erode worker distance calculation is under 2 km and never 1005 km or 14,211 km", () {
      // Customer at Erode (638003)
      const custLat = 11.3410;
      const custLng = 77.7172;

      // Worker in Erode / Perundurai area
      final worker = Worker(
        id: "w_erode_01",
        userId: "u_erode_01",
        name: "Muthu Kumaran",
        skills: ["Plumbing"],
        experienceYears: 5,
        verificationStatus: VerificationStatus.approved,
        latitude: 11.3430,
        longitude: 77.7190,
      );

      final distKm = worker.calculateDistanceKm(custLat, custLng);

      // Distance should be roughly 0.3 km
      expect(distKm, lessThan(2.0));
      expect(distKm, greaterThan(0.0));

      // Formatted distance should show accurate localized text, not 1005.0 km
      final distStr = worker.formattedDistanceString(custLat, custLng);
      expect(distStr.contains("1005"), isFalse);
      expect(distStr.contains("14211"), isFalse);
    });
  });
}
