import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('EmergencySosService Unit Tests', () {
    final sosService = EmergencySosService.instance;

    test('PoliceStationInfo serialization & deserialization works accurately', () {
      const station = PoliceStationInfo(
        name: 'Perundurai Police Station',
        distanceKm: 2.4,
        deskPhone: '04294-220233',
        emergencyNumber: '112',
      );

      final map = station.toMap();
      expect(map['name'], 'Perundurai Police Station');
      expect(map['distanceKm'], 2.4);
      expect(map['deskPhone'], '04294-220233');
      expect(map['emergencyNumber'], '112');

      final deserialized = PoliceStationInfo.fromMap(map);
      expect(deserialized.name, 'Perundurai Police Station');
      expect(deserialized.distanceKm, 2.4);
      expect(deserialized.deskPhone, '04294-220233');
      expect(deserialized.emergencyNumber, '112');
    });

    test('getNearestPoliceStation returns safe fallback when lat/lng is null', () {
      final station = sosService.getNearestPoliceStation(null, null);
      expect(station.emergencyNumber, '112');
      expect(station.deskPhone, '112');
      expect(station.distanceKm, 0.0);
    });

    test('getNearestPoliceStation computes nearest station for Perundurai coordinates', () {
      // Perundurai: 11.2778, 77.5835
      final station = sosService.getNearestPoliceStation(11.2780, 77.5830);
      expect(station.name, contains('Perundurai Police Station'));
      expect(station.emergencyNumber, '112');
      expect(station.distanceKm, lessThan(2.0));
    });

    test('getNearestPoliceStation computes nearest station for Chennai coordinates', () {
      // T. Nagar: 13.0418, 80.2341
      final station = sosService.getNearestPoliceStation(13.0420, 80.2340);
      expect(station.name, contains('T. Nagar Police Station'));
      expect(station.emergencyNumber, '112');
      expect(station.distanceKm, lessThan(1.5));
    });

    test('PoliceStationInfo handles null map safely', () {
      final station = PoliceStationInfo.fromMap(null);
      expect(station.emergencyNumber, '112');
      expect(station.distanceKm, 0.0);
    });
  });
}
