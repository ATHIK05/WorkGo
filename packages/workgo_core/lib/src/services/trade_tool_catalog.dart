// trade_tool_catalog.dart
// Authoritative, domain-accurate tool and equipment knowledge catalog for WorkGo trades.

class TradeEquipmentKit {
  final List<String> primaryTools;
  final List<String> consumables;
  final List<String> safetyGear;

  const TradeEquipmentKit({
    required this.primaryTools,
    required this.consumables,
    required this.safetyGear,
  });

  List<String> get allTools => [
        ...primaryTools,
        ...consumables,
        ...safetyGear,
      ];

  Map<String, dynamic> toMap() => {
        'primaryTools': primaryTools,
        'consumables': consumables,
        'safetyGear': safetyGear,
      };
}

class TradeToolCatalog {
  TradeToolCatalog._();

  static const List<String> defaultSafetyGear = [
    'Safety Work Gloves',
    'Protective Eyewear',
    'Dust Mask',
  ];

  /// Core Trade Knowledge Matrix with granular task & symptom mapping.
  static final Map<String, Map<String, TradeEquipmentKit>> _catalog = {
    'plumbing': {
      'leak': const TradeEquipmentKit(
        primaryTools: [
          'Pipe Wrench (12" & 14")',
          'Adjustable Spanner',
          'Basin Wrench',
          'Pipe Hacksaw / Cutter',
          'Slip-Joint Pliers',
        ],
        consumables: [
          'PTFE Thread Seal Tape',
          'PVC Solvent Cement',
          'Assorted Rubber Washers & O-Rings',
          'Silicone Sealant',
        ],
        safetyGear: [
          'Waterproof Work Gloves',
          'Safety Goggles',
        ],
      ),
      'drain': const TradeEquipmentKit(
        primaryTools: [
          'Drain Auger / Pipe Snake (25 ft)',
          'Heavy-Duty Plunger',
          'Drain Rod Set',
          'Utility Bucket',
          'Wet-Dry Vacuum',
        ],
        consumables: [
          'Enzymatic Drain Cleaner',
          'Sanitizing Disinfectant',
        ],
        safetyGear: [
          'Heavy Chemical-Resistant Gloves',
          'Splash Goggles',
          'Respiratory Mask',
        ],
      ),
      'clog': const TradeEquipmentKit(
        primaryTools: [
          'Drain Auger / Pipe Snake (25 ft)',
          'Heavy-Duty Plunger',
          'Drain Rod Set',
          'Utility Bucket',
        ],
        consumables: [
          'Enzymatic Drain Cleaner',
          'Sanitizing Disinfectant',
        ],
        safetyGear: [
          'Heavy Chemical-Resistant Gloves',
          'Splash Goggles',
        ],
      ),
      'tap': const TradeEquipmentKit(
        primaryTools: [
          'Adjustable Spanner',
          'Basin Wrench',
          'Hex Key (Allen) Set',
          'Flathead & Phillips Screwdrivers',
        ],
        consumables: [
          'Ceramic Disc Cartridge',
          'PTFE Thread Seal Tape',
          'Spindle Washers',
          'Silicone Grease',
        ],
        safetyGear: [
          'Light Work Gloves',
          'Protective Eyewear',
        ],
      ),
      'geyser': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter (CAT III)',
          'Element Socket Spanner (38mm/55mm)',
          'Adjustable Spanner',
          'Non-Contact Voltage Tester',
        ],
        consumables: [
          'Replacement Heating Element (2kW/3kW)',
          'Thermostat Sensor Probe',
          'Braided Inlet/Outlet Hoses',
          'PTFE Thread Seal Tape',
        ],
        safetyGear: [
          '1000V Insulated Electrical Gloves',
          'Heat-Resistant Gloves',
          'Safety Goggles',
        ],
      ),
      'tank': const TradeEquipmentKit(
        primaryTools: [
          'Heavy Pipe Wrench (14")',
          'Pipe Hacksaw',
          'Measuring Tape',
          'Pipe Deburring Tool',
        ],
        consumables: [
          'Brass / PVC Ball Float Valve',
          'PVC Union & Couplings',
          'Heavy PVC Solvent Cement',
          'PTFE Thread Seal Tape',
        ],
        safetyGear: [
          'Anti-Slip Safety Boots',
          'Grip Gloves',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Pipe Wrench (12")',
          'Adjustable Spanner',
          'Basin Wrench',
          'Heavy-Duty Plunger',
          'Slip-Joint Pliers',
        ],
        consumables: [
          'PTFE Thread Seal Tape',
          'Assorted Washers',
          'Silicone Sealant',
        ],
        safetyGear: [
          'Waterproof Work Gloves',
          'Safety Glasses',
        ],
      ),
    },

    'electrical': {
      'short': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter (True RMS)',
          'Non-Contact AC Voltage Tester Pen',
          '1000V Insulated Screwdrivers Set',
          'Wire Stripper & Crimper',
          'Insulated Lineman\'s Pliers',
        ],
        consumables: [
          'Flame-Retardant Electrical Tape',
          'Replacement MCB (16A / 32A C-Curve)',
          'Twist-On Wire Connectors / Nuts',
          'Copper Wire (2.5 sq mm)',
        ],
        safetyGear: [
          '1000V Rated Insulated Gloves',
          'Arc-Flash Safety Glasses',
          'Insulated Rubber-Sole Shoes',
        ],
      ),
      'mcb': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter',
          '1000V Insulated Screwdrivers',
          'Non-Contact Voltage Tester Pen',
          'Insulated Needle-Nose Pliers',
        ],
        consumables: [
          'Replacement MCB (16A/25A/32A)',
          'Flame-Retardant PVC Tape',
          'Busbar Connector Comb',
        ],
        safetyGear: [
          '1000V Insulated Gloves',
          'Safety Goggles',
        ],
      ),
      'fan': const TradeEquipmentKit(
        primaryTools: [
          'Step Ladder',
          'Neon Phase Tester Pen',
          'Insulated Screwdrivers (Flat & Phillips)',
          'Wire Stripper',
          'Multimeter (Capacitance Meter)',
        ],
        consumables: [
          'Motor Run Capacitor (2.5uF & 3.15uF)',
          'Ceiling Hook Shackle Kit',
          'Electrical Insulation Tape',
          'Terminal Block Connector',
        ],
        safetyGear: [
          'Insulated Gloves',
          'Safety Eyewear',
        ],
      ),
      'switch': const TradeEquipmentKit(
        primaryTools: [
          'Neon Phase Tester Pen',
          'Insulated Screwdrivers Set',
          'Wire Stripper & Cutter',
          'Insulated Nose Pliers',
        ],
        consumables: [
          'Modular Switch & Socket Units (6A / 16A)',
          'Electrical Tape',
          'FR Copper Wires (1.5 / 2.5 sq mm)',
          'Mounting Screws',
        ],
        safetyGear: [
          'Insulated Work Gloves',
          'Safety Glasses',
        ],
      ),
      'inverter': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter (DC Voltage & Current)',
          'Battery Hydrometer (Specific Gravity)',
          'Terminal Wire Brush',
          'Insulated Socket Wrench (10mm - 14mm)',
        ],
        consumables: [
          'Battery Grade Distilled Water',
          'Petroleum Jelly / Terminal Grease',
          'Battery Terminal Clamps',
          'Heavy DC Battery Cable Lugs',
        ],
        safetyGear: [
          'Acid-Resistant Rubber Gloves',
          'Full Face Shield',
          'Chemical Apron',
        ],
      ),
      'wiring': const TradeEquipmentKit(
        primaryTools: [
          'Spring Steel Fish Tape / Wire Puller (30m)',
          'Cable Continuity Tester',
          'Conduit Pipe Bender / Cutter',
          'Wire Stripper & Crimper',
          'Insulated Lineman\'s Pliers',
        ],
        consumables: [
          'FR Copper Cable Coils (1.5 / 2.5 / 4 sq mm)',
          'Conduit Junction Boxes & Saddles',
          'Wire Pulling Lubricant',
          'Electrical Insulation Tape',
        ],
        safetyGear: [
          'Insulated Work Gloves',
          'Safety Glasses',
          'Hard Hat',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          '1000V Insulated Screwdrivers Set',
          'Digital Multimeter',
          'Non-Contact AC Voltage Tester Pen',
          'Wire Stripper & Cutter',
          'Insulated Lineman\'s Pliers',
        ],
        consumables: [
          'Flame-Retardant Electrical Tape',
          'Twist-On Wire Connectors',
          'Copper Wire Spares',
        ],
        safetyGear: [
          '1000V Insulated Gloves',
          'Safety Glasses',
        ],
      ),
    },

    'carpentry': {
      'door': const TradeEquipmentKit(
        primaryTools: [
          'Jack Hand Plane (Wood Plane)',
          'Wood Chisel Set (1/4", 1/2", 1")',
          'Claw Hammer',
          'Cordless Drill / Driver with Phillips Bits',
          'Mortise Chisel & Wood Mallet',
          'Measuring Tape',
        ],
        consumables: [
          'Mortise Lock / Cylindrical Lockset',
          'Stainless Steel Door Hinges & Screws',
          'Sandpaper (80 & 120 Grit)',
          'Wood Shims',
        ],
        safetyGear: [
          'Leather Work Gloves',
          'Safety Glasses',
          'Dust Mask',
        ],
      ),
      'furniture': const TradeEquipmentKit(
        primaryTools: [
          'Quick-Grip Bar Clamps',
          'Cordless Screwdriver & Drill Bits',
          'Rubber Mallet',
          'Hand Wood Saw',
          'Wood Chisel Set',
        ],
        consumables: [
          'Waterproof Wood Glue (PVA)',
          'Assorted Wood Screws & Dowel Pins',
          'Wood Filler Putty',
          'Sandpaper (120 & 240 Grit)',
        ],
        safetyGear: [
          'Protective Work Gloves',
          'Dust Mask',
          'Safety Goggles',
        ],
      ),
      'cabinet': const TradeEquipmentKit(
        primaryTools: [
          '35mm Forstner Drill Bit',
          'Cordless Drill / Driver',
          'Magnetic Torx / Phillips Bits',
          'Torpedo Spirit Level',
          'Measuring Tape',
        ],
        consumables: [
          'Soft-Close Concealed Hinges (35mm)',
          'Ball-Bearing Drawer Slides',
          'Cabinet Connecting Screws',
        ],
        safetyGear: [
          'Grip Work Gloves',
          'Safety Glasses',
        ],
      ),
      'shelf': const TradeEquipmentKit(
        primaryTools: [
          'Hammer Drill / Rotary Impact Drill',
          'Masonry Drill Bits (6mm & 8mm)',
          'Magnetic Torpedo Spirit Level',
          'Measuring Tape & Pencil',
          'Stud Finder',
        ],
        consumables: [
          'Nylon Wall Rawl Plugs (6mm & 8mm)',
          'Heavy-Duty Anchor Screws',
          'L-Angle Heavy Shelf Brackets',
        ],
        safetyGear: [
          'Impact Safety Glasses',
          'Anti-Vibration Gloves',
          'Particulate Dust Mask',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Claw Hammer',
          'Wood Chisel Set',
          'Cordless Drill / Driver',
          'Hand Wood Saw',
          'Measuring Tape',
          'Torpedo Spirit Level',
        ],
        consumables: [
          'Wood Glue (PVA)',
          'Assorted Wood Screws',
          'Assorted Sandpaper',
        ],
        safetyGear: [
          'Work Gloves',
          'Safety Glasses',
          'Dust Mask',
        ],
      ),
    },

    'appliance_repair': {
      'washing': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter',
          'Nut Driver Set (7mm - 10mm)',
          'Socket Wrench Set (8mm - 13mm)',
          'Hose Spring Clamp Pliers',
          'Adjustable Spanner',
        ],
        consumables: [
          'Replacement Drive Belt',
          'Water Inlet Solenoid Valve',
          'Drain Pump Motor',
          'PTFE Tape & Hose Clamps',
        ],
        safetyGear: [
          'Insulated Electrical Gloves',
          'Waterproof Work Gloves',
        ],
      ),
      'refrigerator': const TradeEquipmentKit(
        primaryTools: [
          'Digital Thermometer Probe',
          'Digital AC/DC Clamp Multimeter',
          'Manifold Pressure Gauge (R134a / R600a)',
          'Piercing Valve / Access Valve',
          'Magnetic Screwdrivers Set',
        ],
        consumables: [
          'Compressor PTC Relay & Overload Protector',
          'Bimetal Defrost Thermostat',
          'Defrost Timer / Sensor',
          'Refrigerant Can (R134a / R600a)',
        ],
        safetyGear: [
          'Thermal Cold-Resistant Gloves',
          'Safety Goggles',
        ],
      ),
      'microwave': const TradeEquipmentKit(
        primaryTools: [
          'High-Voltage Capacitor Discharging Probe',
          'Digital Multimeter (High Voltage Probe)',
          'Torx Tamper-Proof Screwdrivers Set',
          'Long-Nose Insulated Pliers',
        ],
        consumables: [
          'High-Voltage Diode (HVM12)',
          'High-Voltage Fuse (5kV 0.75A)',
          'Door Microswitches',
          'Thermal Cut-Off Fuse',
        ],
        safetyGear: [
          '1000V Insulated Gloves',
          'Safety Glasses',
        ],
      ),
      'tv': const TradeEquipmentKit(
        primaryTools: [
          'Anti-Static ESD Wrist Strap',
          'Precision Screwdriver Kit (64-Piece)',
          'Digital Multimeter',
          'LED Backlight Tester',
          'Temperature-Controlled Soldering Iron & Wick',
        ],
        consumables: [
          'Lead-Free Solder Wire & Rosin Flux',
          'Replacement LED Backlight Strips',
          'Thermal Conductive Tape',
          'Assorted SMD Electrolytic Capacitors',
        ],
        safetyGear: [
          'Anti-Static Gloves',
          'Eye Protection Glasses',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Digital Multimeter',
          'Precision Screwdrivers Set',
          'Nut Driver Set',
          'Insulated Pliers',
          'Adjustable Spanner',
        ],
        consumables: [
          'Electrical Tape',
          'Assorted Fuses',
          'Wire Connectors',
        ],
        safetyGear: [
          'Insulated Work Gloves',
          'Safety Glasses',
        ],
      ),
    },

    'ac_service': {
      'cooling': const TradeEquipmentKit(
        primaryTools: [
          'Dual Manifold Pressure Gauge (R32 / R410A)',
          'Deep Vacuum Pump (2-Stage)',
          'Electronic Refrigerant Leak Detector',
          'Digital Clamp Meter',
          'Adjustable Spanners (Pair)',
        ],
        consumables: [
          'Refrigerant Gas Cylinder (R32 / R410A)',
          'Charging Hoses with Ball Valves',
          'Flaring Copper Washers',
        ],
        safetyGear: [
          'Cryogenic Safety Gloves',
          'Impact & Gas Safety Goggles',
        ],
      ),
      'service': const TradeEquipmentKit(
        primaryTools: [
          'High-Pressure Coil Cleaning Pump & Gun',
          'Split AC Service Wash Jacket / Bag',
          'Condenser Fin Comb',
          'Drain Pipe Flusher Brush',
          'Cordless Screwdriver',
        ],
        consumables: [
          'Antibacterial Aluminum Coil Cleaner Spray',
          'Drain Pipe Chlorine Tablets',
          'Waterproof Taping',
        ],
        safetyGear: [
          'Chemical Splash Goggles',
          'Waterproof Work Apron',
          'Rubber Gloves',
        ],
      ),
      'leak': const TradeEquipmentKit(
        primaryTools: [
          'Electronic Refrigerant Leak Detector',
          'Nitrogen Pressure Testing Kit',
          'Soap Bubble Leak Solution & Brush',
          'Manifold Gauge Set',
          'Adjustable Spanners',
        ],
        consumables: [
          'Copper Flare Nuts & Unions',
          'Silver Brazing Rod & Flux',
          'Refrigerant Sealant',
        ],
        safetyGear: [
          'Cryogenic Gloves',
          'Gas Safety Goggles',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Manifold Pressure Gauge Set',
          'Vacuum Pump',
          'Digital Clamp Meter',
          'Adjustable Spanners',
          'Split AC Service Bag',
        ],
        consumables: [
          'Refrigerant Gas',
          'Coil Cleaner Spray',
          'Insulation Tape',
        ],
        safetyGear: [
          'Cryogenic Gloves',
          'Safety Glasses',
        ],
      ),
    },

    'painting': {
      'wall': const TradeEquipmentKit(
        primaryTools: [
          '9" Microfiber Paint Roller with Extension Pole',
          '2" & 3" Angled Sash Paint Brushes',
          'Paint Roller Tray with Disposable Liners',
          'Putty Knife & Blade (6" & 10")',
          'Sanding Block with Sandpaper (120 & 180)',
        ],
        consumables: [
          'Painter\'s Blue Masking Tape (2" Roll)',
          'Heavy Plastic Drop Cloths & Floor Sheets',
          'Acrylic Wall Putty',
          'Primer & Wall Paint',
        ],
        safetyGear: [
          'Respiratory Paint Mist Mask',
          'Protective Painter\'s Overalls',
          'Eye Protection Glasses',
        ],
      ),
      'waterproof': const TradeEquipmentKit(
        primaryTools: [
          'Moisture Meter (Digital Pinless)',
          'Wire Scratching Brush',
          'Wide Masonry Brush',
          'Heavy-Duty Paint Roller',
          'Putty Knife',
        ],
        consumables: [
          'Elastomeric Waterproofing Membrane',
          'Exterior Crack Filler Putty',
          'Glass Fiber Mesh Tape',
        ],
        safetyGear: [
          'Heavy Chemical Gloves',
          'Dust & Vapor Mask',
          'Safety Goggles',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Paint Rollers with Extension Pole',
          'Angled Sash Brushes (2" & 3")',
          'Paint Roller Tray',
          'Putty Knife',
          'Sanding Block',
        ],
        consumables: [
          'Painter\'s Masking Tape',
          'Drop Cloths',
          'Wall Putty',
          'Sandpaper',
        ],
        safetyGear: [
          'Dust Mask',
          'Eye Protection Glasses',
          'Work Gloves',
        ],
      ),
    },

    'cleaning': {
      'deep': const TradeEquipmentKit(
        primaryTools: [
          'Commercial Wet & Dry Vacuum Cleaner',
          'Electric High-Pressure Washer',
          'Rotary Floor Scrubbing Brush',
          'Telescopic Window Squeegee',
          'Color-Coded Microfiber Towels (Pack of 10)',
        ],
        consumables: [
          'Heavy-Duty Degreaser Concentrate',
          'Tile & Grout Acid-Free Cleaner',
          'Glass Cleaner Concentrate',
          'Sanitizing Disinfectant',
        ],
        safetyGear: [
          'Heavy-Duty Rubber Gauntlet Gloves',
          'Splash Protection Eyewear',
          'Anti-Skid Safety Boots',
        ],
      ),
      'kitchen': const TradeEquipmentKit(
        primaryTools: [
          'Steam Cleaning Machine',
          'Abrasive Scouring Pads & Steel Wool',
          'Detail Grout Scrub Brushes',
          'Microfiber Cleaning Cloths',
          'Spray Bottles',
        ],
        consumables: [
          'Food-Grade Commercial Degreaser',
          'Stainless Steel Polish',
          'Disinfectant Surface Spray',
        ],
        safetyGear: [
          'Heat & Chemical-Resistant Gloves',
          'Eye Protection Goggles',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Commercial Vacuum Cleaner',
          'Floor Mop & Squeegee Set',
          'Detail Scrub Brushes',
          'Microfiber Cloths',
        ],
        consumables: [
          'Multi-Surface Cleaner',
          'Disinfectant Solution',
          'Garbage Disposal Bags',
        ],
        safetyGear: [
          'Waterproof Gloves',
          'Anti-Slip Shoes',
        ],
      ),
    },

    'masonry': {
      'tile': const TradeEquipmentKit(
        primaryTools: [
          '4" Angle Grinder with Diamond Tile Blade',
          '6mm & 8mm Notched Trowel',
          'Rubber Grout Float',
          'Rubber Mallet',
          'Heavy Utility Sponge & Bucket',
        ],
        consumables: [
          'Polymer-Modified Tile Adhesive Mortar',
          'Epoxy / Cementitious Tile Grout',
          'Tile Spacers (2mm & 3mm)',
        ],
        safetyGear: [
          'Knee Pads (Gel / Foam)',
          'Heavy-Duty Dust Mask (FFP2/N95)',
          'Impact Safety Goggles',
          'Cut-Resistant Work Gloves',
        ],
      ),
      'default': const TradeEquipmentKit(
        primaryTools: [
          'Pointing Trowel',
          'Notched Trowel',
          'Rubber Mallet',
          'Spirit Level',
          'Chisel & Club Hammer',
        ],
        consumables: [
          'Cement Mix / Quick-Setting Plaster',
          'Tile Adhesive Mortar',
          'Grout Spacers',
        ],
        safetyGear: [
          'Heavy Work Gloves',
          'Safety Goggles',
          'Dust Mask',
        ],
      ),
    },
  };

  /// Main recommendation resolver: Normalizes trade & inspects issue description,
  /// symptom keywords, and equipment tags to select the most precise domain equipment kit.
  static TradeEquipmentKit getEquipmentKit({
    required String serviceType,
    String? issueText,
    String? symptomDescription,
    String? equipmentTag,
  }) {
    final normalizedTrade = _normalizeTrade(serviceType);
    final tradeMap = _catalog[normalizedTrade] ?? _catalog['electrical']!;

    final combinedText = [
      if (issueText != null) issueText,
      if (symptomDescription != null) symptomDescription,
      if (equipmentTag != null) equipmentTag,
    ].join(' ').toLowerCase();

    if (combinedText.trim().isNotEmpty) {
      for (final key in tradeMap.keys) {
        if (key == 'default') continue;
        if (combinedText.contains(key)) {
          return tradeMap[key]!;
        }
      }
    }

    return tradeMap['default'] ??
        const TradeEquipmentKit(
          primaryTools: ['Standard Tool Kit', 'Diagnostic Meter', 'Safety Gloves'],
          consumables: ['Fasteners', 'Insulation Tape'],
          safetyGear: ['Work Gloves', 'Safety Glasses'],
        );
  }

  /// Convenience helper returning a flat list of recommended tools.
  static List<String> getRecommendedTools({
    required String serviceType,
    String? issueText,
    String? symptomDescription,
    String? equipmentTag,
  }) {
    final kit = getEquipmentKit(
      serviceType: serviceType,
      issueText: issueText,
      symptomDescription: symptomDescription,
      equipmentTag: equipmentTag,
    );
    return kit.allTools;
  }

  static String _normalizeTrade(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('plumb')) return 'plumbing';
    if (lower.contains('electric') || lower.contains('wire') || lower.contains('power')) return 'electrical';
    if (lower.contains('carpent') || lower.contains('wood') || lower.contains('furnitur')) return 'carpentry';
    if (lower.contains('applianc') || lower.contains('washing') || lower.contains('fridge') ||
        lower.contains('refriger') || lower.contains('microwave') || lower.contains('tv')) {
      return 'appliance_repair';
    }
    if (lower.contains('ac') || lower.contains('air condition') || lower.contains('hvac')) return 'ac_service';
    if (lower.contains('paint')) return 'painting';
    if (lower.contains('clean') || lower.contains('deep clean')) return 'cleaning';
    if (lower.contains('mason') || lower.contains('tile') || lower.contains('plaster')) return 'masonry';
    return lower;
  }
}
