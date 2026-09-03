import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/user_address.dart';

class DecodedLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String streetArea;
  final String city;
  final String state;
  final String pincode;
  final String country;

  const DecodedLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.streetArea,
    required this.city,
    required this.state,
    required this.pincode,
    this.country = "India",
  });

  UserAddress toUserAddress({
    AddressLabel label = AddressLabel.home,
    String flatBuilding = "",
    String customLabel = "",
    bool isDefault = false,
  }) {
    return UserAddress(
      id: "addr_${DateTime.now().millisecondsSinceEpoch}",
      label: label,
      customLabel: customLabel,
      flatBuilding: flatBuilding,
      streetArea: streetArea,
      city: city,
      state: state,
      pincode: pincode,
      formattedAddress: formattedAddress,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );
  }
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;
  LocationService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStreamSub;

  /// Start continuous background GPS streaming to Firestore.
  /// Configures native Android/iOS background location settings with wake lock and foreground notification
  /// so updates stream continuously even when the app is outside/minimized or device is locked.
  Future<void> startRealtimeBroadcast({
    required Future<void> Function(double lat, double lng) onLocationUpdate,
  }) async {
    await stopRealtimeBroadcast();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("LocationService: Device location service disabled.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      late final LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "WorkGo Dispatch Radar Active",
            notificationText: "Transmitting live GPS position to incoming customer requests...",
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        );
      }

      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) async {
          try {
            await onLocationUpdate(pos.latitude, pos.longitude);
          } catch (e) {
            debugPrint("LocationService broadcast stream callback error: $e");
          }
        },
        onError: (err) {
          debugPrint("LocationService getPositionStream error: $err");
        },
      );
    } catch (e) {
      debugPrint("LocationService startRealtimeBroadcast exception: $e");
    }
  }

  /// Stop real-time background position streaming.
  Future<void> stopRealtimeBroadcast() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  // ── Coordinates & Geocoding ────────────────────────────────────────────────

  /// Retrieve current real-time GPS coordinates via device hardware GPS.
  Future<Map<String, double>> getCurrentCoordinates() async {
    try {
      // 1. Check if device location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("LocationService: Device location service disabled.");
      }

      // 2. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Quick check: Last known position is immediate (<50ms)
        Position? fastPos;
        try {
          fastPos = await Geolocator.getLastKnownPosition();
          if (fastPos != null) {
            debugPrint("LocationService: Fast GPS position available: ${fastPos.latitude}, ${fastPos.longitude}");
          }
        } catch (_) {}

        // Try fresh high-precision fix with 4s timeout
        try {
          final freshPosition = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: const Duration(seconds: 4),
            ),
          );
          debugPrint("LocationService: Fresh GPS acquired: ${freshPosition.latitude}, ${freshPosition.longitude}");
          return {
            "latitude": freshPosition.latitude,
            "longitude": freshPosition.longitude,
          };
        } catch (freshErr) {
          debugPrint("LocationService: Fresh fix note: $freshErr");
          if (fastPos != null) {
            return {
              "latitude": fastPos.latitude,
              "longitude": fastPos.longitude,
            };
          }
        }
      }
    } catch (e) {
      debugPrint("LocationService: Hardware GPS exception: $e");
    }

    // Default Perundurai / Erode Tamil Nadu central coordinates (No IP lookup to avoid Mumbai cellular gateway errors)
    return {"latitude": 11.2743, "longitude": 77.5866};
  }

  /// Forward geocode any address string into real-world (lat, lon) coordinates via OpenStreetMap Nominatim.
  Future<Map<String, double>?> forwardGeocode(String addressText) async {
    final query = addressText.trim();
    if (query.isEmpty) return null;

    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse("https://nominatim.openstreetmap.org/search?format=json&q=$encoded&addressdetails=1&limit=1");
      final res = await http.get(url, headers: {
        "User-Agent": "WorkGoCooperativeApp/1.0 (support@workgo.in)",
        "Accept": "application/json",
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          final item = list.first;
          final lat = double.tryParse(item["lat"]?.toString() ?? "");
          final lon = double.tryParse(item["lon"]?.toString() ?? "");
          if (lat != null && lon != null) {
            return {"latitude": lat, "longitude": lon};
          }
        }
      }
    } catch (e) {
      debugPrint("LocationService: dynamic forwardGeocode exception: $e");
    }
    return null;
  }

  /// Decode (reverse-geocode) latitude and longitude into human-readable address components.
  Future<DecodedLocation> reverseGeocode(double lat, double lon) async {
    try {
      // 1. Primary: OpenStreetMap Nominatim Reverse API (zoom=18 for building/street-level detail)
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&addressdetails=1&zoom=18",
      );
      final res = await http.get(url, headers: {
        "User-Agent": "WorkGoCooperativeApp/1.0 (support@workgo.in)",
        "Accept": "application/json",
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data["address"] as Map<String, dynamic>? ?? {};

        final houseNo = (address["house_number"] ?? address["building"] ?? address["house"] ?? "").toString().trim();
        final road = (address["road"] ?? address["pedestrian"] ?? address["street"] ?? address["lane"] ?? "").toString().trim();
        final suburb = (address["suburb"] ??
            address["neighbourhood"] ??
            address["residential"] ??
            address["quarter"] ??
            address["subdistrict"] ??
            address["village"] ??
            address["hamlet"] ??
            "").toString().trim();
        final city = (address["city"] ??
            address["town"] ??
            address["municipality"] ??
            address["city_district"] ??
            address["county"] ??
            address["state_district"] ??
            "Erode").toString().trim();
        final state = (address["state"] ?? "Tamil Nadu").toString().trim();
        final pincode = (address["postcode"] ?? address["postal_code"] ?? "").toString().trim();
        final country = (address["country"] ?? "India").toString().trim();

        final streetAreaParts = <String>[];
        if (houseNo.isNotEmpty) streetAreaParts.add(houseNo);
        if (road.isNotEmpty) streetAreaParts.add(road);
        if (suburb.isNotEmpty && suburb != road && suburb != city) streetAreaParts.add(suburb);

        final streetArea = streetAreaParts.isNotEmpty
            ? streetAreaParts.join(", ")
            : (suburb.isNotEmpty ? suburb : "$city Central");

        // Granular detailed formatted string: e.g. "20, Mosikeeranar Street, Indira Nagar, Erode 638001, Tamil Nadu"
        final formattedAddressParts = <String>[];
        if (streetArea.isNotEmpty) formattedAddressParts.add(streetArea);
        if (city.isNotEmpty) {
          formattedAddressParts.add(pincode.isNotEmpty ? "$city $pincode" : city);
        }
        if (state.isNotEmpty) formattedAddressParts.add(state);

        final formatted = formattedAddressParts.isNotEmpty
            ? formattedAddressParts.join(", ")
            : (data["display_name"] ?? "$streetArea, $city $pincode");

        return DecodedLocation(
          latitude: lat,
          longitude: lon,
          formattedAddress: formatted,
          streetArea: streetArea,
          city: city,
          state: state,
          pincode: pincode,
          country: country,
        );
      }
    } catch (e) {
      debugPrint("LocationService: Nominatim reverse geocode error: $e");
    }

    // 2. Secondary Fallback: BigDataCloud Client Reverse Geocode
    try {
      final bdcUrl = Uri.parse(
        "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en",
      );
      final res = await http.get(bdcUrl).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final locality = (data["locality"] ?? data["principalSubdivisionCode"] ?? "Local Area").toString().trim();
        final city = (data["city"] ?? data["principalSubdivision"] ?? "Erode").toString().trim();
        final state = (data["principalSubdivision"] ?? "Tamil Nadu").toString().trim();
        final pincode = (data["postcode"] ?? "").toString().trim();

        final formatted = "$locality, $city $pincode, $state";

        return DecodedLocation(
          latitude: lat,
          longitude: lon,
          formattedAddress: formatted,
          streetArea: locality,
          city: city,
          state: state,
          pincode: pincode,
        );
      }
    } catch (_) {}

    // 3. Dynamic GPS Coordinates Fallback
    final latStr = lat.toStringAsFixed(4);
    final lonStr = lon.toStringAsFixed(4);
    return DecodedLocation(
      latitude: lat,
      longitude: lon,
      formattedAddress: "Current Location ($latStr, $lonStr), Tamil Nadu",
      streetArea: "GPS ($latStr, $lonStr)",
      city: "Current Location",
      state: "Tamil Nadu",
      pincode: "",
    );
  }

  // ── Haversine Distance Calculator ──────────────────────────────────────────

  /// Calculate spherical distance between two GPS coordinates in kilometers.
  double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusKm * c;
    return double.parse(distance.toStringAsFixed(1));
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // ── Multi-Address Firestore Management (Swiggy / Zomato Pattern) ───────────

  /// Stream all saved addresses for a user or worker in real time.
  Stream<List<UserAddress>> streamUserAddresses(
    String userId, {
    String collection = "users",
  }) {
    return _db
        .collection(collection)
        .doc(userId)
        .collection("addresses")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => UserAddress.fromMap(d.data())).toList();
    });
  }

  /// Save or update an address. If [address.isDefault] is true, resets others.
  Future<void> saveAddress(
    String userId,
    UserAddress address, {
    String collection = "users",
  }) async {
    final userDocRef = _db.collection(collection).doc(userId);
    final addressRef = userDocRef.collection("addresses").doc(address.id);

    final batch = _db.batch();

    if (address.isDefault) {
      // Clear existing default flags
      final allAddresses = await userDocRef.collection("addresses").get();
      for (final doc in allAddresses.docs) {
        if (doc.id != address.id && (doc.data()["isDefault"] == true)) {
          batch.update(doc.reference, {"isDefault": false});
        }
      }
    }

    batch.set(addressRef, address.toMap(), SetOptions(merge: true));

    // Also update current active location on user doc for rapid search query
    batch.set(
      userDocRef,
      {
        "latitude": address.latitude,
        "longitude": address.longitude,
        "currentAddress": address.toMap(),
        "primaryArea": address.shortSummary,
        "baseAddress": address.shortSummary,
        "serviceLocation": address.shortSummary,
        "hasConfiguredLocation": true,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Delete a saved address.
  Future<void> deleteAddress(
    String userId,
    String addressId, {
    String collection = "users",
  }) async {
    await _db
        .collection(collection)
        .doc(userId)
        .collection("addresses")
        .doc(addressId)
        .delete();
  }

  /// Set an address as the default active address.
  Future<void> setDefaultAddress(
    String userId,
    String addressId, {
    String collection = "users",
  }) async {
    final userDocRef = _db.collection(collection).doc(userId);
    final addressesSnap = await userDocRef.collection("addresses").get();

    final batch = _db.batch();
    UserAddress? selectedDefault;

    for (final doc in addressesSnap.docs) {
      final isTarget = doc.id == addressId;
      batch.update(doc.reference, {"isDefault": isTarget});
      if (isTarget) {
        selectedDefault = UserAddress.fromMap(doc.data()).copyWith(isDefault: true);
      }
    }

    if (selectedDefault != null) {
      batch.update(userDocRef, {
        "latitude": selectedDefault.latitude,
        "longitude": selectedDefault.longitude,
        "currentAddress": selectedDefault.toMap(),
        "primaryArea": selectedDefault.shortSummary,
      });
    }

    await batch.commit();
  }
}
