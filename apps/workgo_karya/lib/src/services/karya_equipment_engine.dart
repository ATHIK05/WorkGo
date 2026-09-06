// karya_equipment_engine.dart
// Rule-based local AI equipment suggestion fallback for Karya artisans.

class KaryaEquipmentEngine {
  KaryaEquipmentEngine._();

  static const Map<String, Map<String, List<String>>> _toolMap = {
    'Plumbing': {
      'leak': ['Pipe wrench', 'PTFE tape', 'Basin wrench', 'Bucket & sponge', 'Silicone sealant'],
      'drip': ['Adjustable spanner', 'Replacement cartridge', 'PTFE tape', 'Silicone grease'],
      'drain': ['Drain auger', 'Plunger', 'Chemical drain cleaner', 'Bucket'],
      'clog': ['Drain auger', 'Plunger', 'Wet-dry vacuum', 'Drain rod set'],
      'block': ['Drain rod set', 'Plunger', 'High-pressure pump', 'Bucket'],
      'pipe': ['Pipe cutter', 'Pipe wrench', 'PTFE tape', 'PVC solvent cement', 'Pipe fittings'],
      'tap': ['Adjustable spanner', 'Replacement washer', 'Silicone sealant', 'Basin wrench'],
      'flush': ['Cistern repair kit', 'Adjustable spanner', 'Rubber gloves', 'Bucket'],
      'toilet': ['Toilet auger', 'Rubber gloves', 'Cistern repair kit', 'Silicone sealant'],
      'geyser': ['Multimeter', 'Adjustable spanner', 'Heating element', 'Teflon tape', 'Safety gloves'],
      'tank': ['Float valve', 'Adjustable spanner', 'PTFE tape', 'Pipe fittings'],
      'default': ['Pipe wrench', 'Adjustable spanner', 'PTFE tape', 'Plunger', 'Silicone sealant'],
    },
    'Electrical': {
      'fan': ['Screwdrivers', 'Multimeter', 'Electrical tape', 'Capacitor', 'Ladder'],
      'switch': ['Screwdrivers', 'Multimeter', 'Replacement switch', 'Electrical tape', 'Insulated pliers'],
      'socket': ['Screwdrivers', 'Multimeter', 'Replacement socket', 'Electrical tape', 'Wire stripper'],
      'mcb': ['Screwdrivers', 'Multimeter', 'Replacement MCB', 'Insulated gloves', 'Tester'],
      'fuse': ['Replacement fuse wire', 'Screwdrivers', 'Multimeter', 'Electrical tape'],
      'light': ['Replacement bulb', 'Screwdrivers', 'Ladder', 'Multimeter', 'Electrical tape'],
      'short': ['Multimeter', 'Insulated gloves', 'Wire stripper', 'Electrical tape', 'Cable'],
      'wiring': ['Wire stripper', 'Electrical tape', 'Screwdrivers', 'Multimeter', 'Cable connectors'],
      'inverter': ['Multimeter', 'Screwdrivers', 'Battery terminal cleaner', 'Distilled water', 'Safety gloves'],
      'ac': ['Refrigerant gauge set', 'Screwdrivers', 'Multimeter', 'Vacuum pump', 'Safety gloves'],
      'default': ['Screwdrivers', 'Multimeter', 'Electrical tape', 'Phase tester', 'Insulated pliers'],
    },
    'Carpentry': {
      'door': ['Hammer', 'Chisel set', 'Screwdrivers', 'Hinge set', 'Door handle', 'Wood plane'],
      'window': ['Hammer', 'Chisel set', 'Screwdrivers', 'Window handle', 'Glass cutter', 'Putty'],
      'furniture': ['Screwdrivers', 'Allen key set', 'Hammer', 'Wood glue', 'Sandpaper', 'Drill'],
      'shelf': ['Drill', 'Wall plugs', 'Screws', 'Spirit level', 'Measuring tape', 'Screwdrivers'],
      'cabinet': ['Screwdrivers', 'Allen key set', 'Hinge set', 'Drawer runner', 'Wood glue'],
      'crack': ['Wood filler', 'Putty knife', 'Sandpaper', 'Wood paint', 'Brush'],
      'default': ['Hammer', 'Screwdrivers', 'Chisel set', 'Measuring tape', 'Wood glue', 'Sandpaper'],
    },
    'Cleaning': {
      'bathroom': ['Scrubbing brush', 'Tile cleaner', 'Rubber gloves', 'Squeegee', 'Mop', 'Bucket'],
      'kitchen': ['Degreaser', 'Scrubbing pad', 'Rubber gloves', 'Microfiber cloth', 'Spray bottle'],
      'floor': ['Mop & bucket', 'Floor cleaner', 'Scrubbing brush', 'Squeegee'],
      'glass': ['Glass cleaner', 'Microfiber cloth', 'Squeegee', 'Ladder'],
      'sofa': ['Upholstery cleaner', 'Soft brush', 'Microfiber cloth', 'Vacuum'],
      'carpet': ['Carpet shampoo', 'Scrubbing brush', 'Wet vacuum', 'Microfiber cloth'],
      'tank': ['Rubber gloves', 'Scrubbing brush', 'Disinfectant', 'Bucket', 'Hose'],
      'pest': ['Pest spray', 'Rubber gloves', 'Mask', 'Sprayer', 'Protective eyewear'],
      'default': ['Mop & bucket', 'Rubber gloves', 'Microfiber cloth', 'All-purpose cleaner', 'Scrubbing brush'],
    },
    'Painting': {
      'wall': ['Paint rollers', 'Paint brushes', 'Drop cloth', 'Masking tape', 'Paint tray', 'Putty knife'],
      'ceiling': ['Extension pole roller', 'Paint', 'Drop cloth', 'Masking tape', 'Safety goggles'],
      'waterproof': ['Waterproof paint', 'Roller', 'Brush', 'Primer', 'Drop cloth'],
      'polish': ['Wood polish', 'Fine sandpaper', 'Cloth', 'Masking tape'],
      'default': ['Paint rollers', 'Paint brushes', 'Drop cloth', 'Masking tape', 'Paint tray'],
    },
    'AC Service': {
      'cooling': ['Refrigerant gauge set', 'Vacuum pump', 'Leak detector', 'Screwdrivers', 'Refrigerant'],
      'gas': ['Refrigerant cylinder', 'Gauge manifold', 'Vacuum pump', 'Safety gloves', 'Leak detector'],
      'filter': ['Replacement filter', 'Screwdrivers', 'Vacuum', 'Microfiber cloth'],
      'noise': ['Screwdrivers', 'Anti-vibration pad', 'Multimeter', 'Spanner set'],
      'leak': ['Leak detector', 'Sealant', 'Refrigerant gauge set', 'Screwdrivers'],
      'default': ['Screwdrivers', 'Gauge manifold', 'Vacuum pump', 'Multimeter', 'Cleaning brush'],
    },
    'Appliance Repair': {
      'washing': ['Screwdrivers', 'Multimeter', 'Belt', 'Pump', 'Rubber gloves', 'Bucket'],
      'refrigerator': ['Multimeter', 'Screwdrivers', 'Refrigerant gauge set', 'Thermostat', 'Safety gloves'],
      'microwave': ['Screwdrivers', 'Multimeter', 'Capacitor', 'Thermal fuse', 'Insulated gloves'],
      'tv': ['Screwdrivers', 'Multimeter', 'Soldering iron', 'Solder wire', 'Anti-static gloves'],
      'motor': ['Multimeter', 'Screwdrivers', 'Bearing', 'Capacitor', 'Safety gloves'],
      'default': ['Screwdrivers', 'Multimeter', 'Electrical tape', 'Insulated pliers', 'Safety gloves'],
    },
  };

  static List<String> suggestTools(String serviceType, String? issueText) {
    final normalizedService = _normalizeService(serviceType);
    final serviceMap = _toolMap[normalizedService];
    if (serviceMap == null) return _toolMap['Electrical']!['default']!;
    if (issueText == null || issueText.isEmpty) return serviceMap['default'] ?? [];
    final issueLower = issueText.toLowerCase();
    for (final entry in serviceMap.entries) {
      if (entry.key == 'default') continue;
      if (issueLower.contains(entry.key)) return entry.value;
    }
    return serviceMap['default'] ?? [];
  }

  static String _normalizeService(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('plumb')) return 'Plumbing';
    if (lower.contains('electric') || lower.contains('wiring')) return 'Electrical';
    if (lower.contains('carpentr') || lower.contains('wood') || lower.contains('furniture')) return 'Carpentry';
    if (lower.contains('clean')) return 'Cleaning';
    if (lower.contains('paint')) return 'Painting';
    if (lower.contains('ac') || lower.contains('air condition')) return 'AC Service';
    if (lower.contains('applianc') || lower.contains('washing') || lower.contains('fridge') ||
        lower.contains('refriger') || lower.contains('microwave') || lower.contains('repair')) {
      return 'Appliance Repair';
    }
    return raw;
  }
}
