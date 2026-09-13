import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/src/services/trade_tool_catalog.dart';

void main() {
  group('TradeToolCatalog Tests', () {
    test('Plumbing: Leakage triggers pipe wrench & Teflon tape', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Plumbing',
        issueText: 'Water pipe joint leak in kitchen sink',
      );
      expect(kit.primaryTools, anyElement(contains('Pipe Wrench')));
      expect(kit.consumables, anyElement(contains('PTFE Thread Seal Tape')));
      expect(kit.safetyGear, anyElement(contains('Waterproof Work Gloves')));
    });

    test('Plumbing: Drain blockage triggers drain auger & plunger', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Plumbing',
        issueText: 'Bathroom toilet drain is clogged and overflowing',
      );
      expect(kit.primaryTools, anyElement(contains('Drain Auger')));
      expect(kit.primaryTools, anyElement(contains('Heavy-Duty Plunger')));
    });

    test('Electrical: Short circuit triggers 1000V insulated screwdrivers & MCB', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Electrical',
        issueText: 'Short circuit causing main power tripping',
      );
      expect(kit.primaryTools, anyElement(contains('1000V Insulated Screwdrivers')));
      expect(kit.primaryTools, anyElement(contains('Multimeter')));
      expect(kit.consumables, anyElement(contains('MCB')));
      expect(kit.safetyGear, anyElement(contains('1000V')));
    });

    test('Electrical: Ceiling fan triggers motor capacitor', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Electrical',
        issueText: 'Ceiling fan is running very slow and humming',
      );
      expect(kit.consumables, anyElement(contains('Capacitor')));
      expect(kit.primaryTools, anyElement(contains('Ladder')));
    });

    test('Carpentry: Door lock triggers hand plane & mortise chisel', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Carpentry',
        issueText: 'Main entrance wooden door lock jammed and sticking',
      );
      expect(kit.primaryTools, anyElement(contains('Hand Plane')));
      expect(kit.primaryTools, anyElement(contains('Wood Chisel')));
      expect(kit.consumables, anyElement(contains('Lock')));
    });

    test('AC Service: Cooling issue triggers manifold gauge & vacuum pump', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'AC Service',
        issueText: 'Split AC not cooling properly, low gas suspected',
      );
      expect(kit.primaryTools, anyElement(contains('Manifold Pressure Gauge')));
      expect(kit.primaryTools, anyElement(contains('Vacuum Pump')));
      expect(kit.consumables, anyElement(contains('Refrigerant Gas')));
    });

    test('Appliance Repair: Washing machine triggers drain pump & drive belt', () {
      final kit = TradeToolCatalog.getEquipmentKit(
        serviceType: 'Appliance Repair',
        issueText: 'Front load washing machine not spinning or draining water',
      );
      expect(kit.consumables, anyElement(contains('Drive Belt')));
      expect(kit.consumables, anyElement(contains('Drain Pump')));
    });

    test('Flat list helper returns all tools without duplication', () {
      final tools = TradeToolCatalog.getRecommendedTools(
        serviceType: 'Electrical',
        issueText: 'Switch board sparking',
      );
      expect(tools.isNotEmpty, isTrue);
      expect(tools, anyElement(contains('Switch')));
    });
  });
}
