/// WorkGo Cooperative Pricing Engine
/// Implements dynamic, transparent on-demand fare calculation modeled after
/// fair cooperative standards, the Code on Wages (2019), and transparent
/// on-demand benchmarks.
///
/// Formula:
/// Total Estimated Fare = Base Trade Visit & Diagnosis Fee (includes first 45 mins labor)
///                     + (Distance in km * Transit Rate per km)
///                     + (Experience Bonus for Senior / Master Artisan)
///                     + (Emergency 30-min Priority Surcharge)
///                     + (Tool / Heavy Machinery Allowance)
///                     + (Temporal / Odd-Hour Surcharge)
///                     + (Actual Duration Overtime Extension: ₹60 per 30 mins)
///                     + (Urgency Booster Tip - 100% to artisan)
class FareBreakdown {
  final String category;
  final double baseVisitFare;
  final double distanceKm;
  final double perKmRate;
  final double distanceTransitFare;
  final double experienceBonus;
  final int experienceYears;
  final double emergencySurcharge;
  final double urgencyTip;
  final double toolAllowance;
  final String? toolType;
  final double temporalSurcharge;
  final String? temporalTier;
  final int baseLaborIncludedMinutes;
  final double hourlyExtensionRate;
  final int actualDurationMinutes;
  final int timeExtensionSlabs;
  final double timeExtensionFare;
  final double welfareContributionPercent;
  final double welfareContributionFare;
  final double workerTakeHomeFare;
  final double totalEstimatedFare;
  final String estimatedArrival;
  final String estimatedJobDuration;
  final bool isFinalSettlement;
  // HMAC-SHA256 Server Signature & Anti-Tampering Guarantee
  final String? quoteSignature;
  final DateTime? quoteExpiresAt;
  final bool isSignatureVerified;

  const FareBreakdown({
    required this.category,
    required this.baseVisitFare,
    required this.distanceKm,
    required this.perKmRate,
    required this.distanceTransitFare,
    required this.experienceBonus,
    required this.experienceYears,
    required this.emergencySurcharge,
    required this.urgencyTip,
    this.toolAllowance = 0.0,
    this.toolType,
    this.temporalSurcharge = 0.0,
    this.temporalTier,
    this.baseLaborIncludedMinutes = 45,
    this.hourlyExtensionRate = 120.0,
    this.actualDurationMinutes = 0,
    this.timeExtensionSlabs = 0,
    this.timeExtensionFare = 0.0,
    this.welfareContributionPercent = 2.0,
    this.welfareContributionFare = 0.0,
    this.workerTakeHomeFare = 0.0,
    required this.totalEstimatedFare,
    required this.estimatedArrival,
    required this.estimatedJobDuration,
    this.isFinalSettlement = false,
    this.quoteSignature,
    this.quoteExpiresAt,
    this.isSignatureVerified = false,
  });

  bool get isExpired => quoteExpiresAt != null && DateTime.now().isAfter(quoteExpiresAt!);

  String generateCanonicalPayload() {
    final exp = quoteExpiresAt?.toIso8601String() ?? '';
    return [
      category.trim(),
      distanceKm.toStringAsFixed(2),
      baseVisitFare.toStringAsFixed(2),
      totalEstimatedFare.toStringAsFixed(2),
      exp,
    ].join(':');
  }

  String get formattedTotal => "₹${totalEstimatedFare.toStringAsFixed(0)}";
  String get formattedBase => "₹${baseVisitFare.toStringAsFixed(0)}";
  String get formattedTransit => "₹${distanceTransitFare.toStringAsFixed(0)}";
  String get formattedDistance => "${distanceKm.toStringAsFixed(1)} km";
  String get formattedExperienceBonus => "+₹${experienceBonus.toStringAsFixed(0)}";
  String get formattedToolAllowance => "+₹${toolAllowance.toStringAsFixed(0)}";
  String get formattedTimeExtension => "+₹${timeExtensionFare.toStringAsFixed(0)}";
  String get formattedWelfare => "₹${welfareContributionFare.toStringAsFixed(1)}";
  String get formattedWorkerTakeHome => "₹${workerTakeHomeFare.toStringAsFixed(0)}";

  Map<String, dynamic> toMap() => {
        'category': category,
        'baseVisitFare': baseVisitFare,
        'distanceKm': distanceKm,
        'perKmRate': perKmRate,
        'distanceTransitFare': distanceTransitFare,
        'experienceBonus': experienceBonus,
        'experienceYears': experienceYears,
        'emergencySurcharge': emergencySurcharge,
        'urgencyTip': urgencyTip,
        'toolAllowance': toolAllowance,
        'toolType': toolType,
        'temporalSurcharge': temporalSurcharge,
        'temporalTier': temporalTier,
        'baseLaborIncludedMinutes': baseLaborIncludedMinutes,
        'hourlyExtensionRate': hourlyExtensionRate,
        'actualDurationMinutes': actualDurationMinutes,
        'timeExtensionSlabs': timeExtensionSlabs,
        'timeExtensionFare': timeExtensionFare,
        'welfareContributionPercent': welfareContributionPercent,
        'welfareContributionFare': welfareContributionFare,
        'workerTakeHomeFare': workerTakeHomeFare,
        'totalEstimatedFare': totalEstimatedFare,
        'estimatedArrival': estimatedArrival,
        'estimatedJobDuration': estimatedJobDuration,
        'isFinalSettlement': isFinalSettlement,
        'quoteSignature': quoteSignature,
        'quoteExpiresAt': quoteExpiresAt?.toIso8601String(),
        'isSignatureVerified': isSignatureVerified,
      };

  factory FareBreakdown.fromMap(Map<String, dynamic> map) {
    DateTime? expires;
    if (map['quoteExpiresAt'] != null) {
      if (map['quoteExpiresAt'] is DateTime) {
        expires = map['quoteExpiresAt'] as DateTime;
      } else {
        expires = DateTime.tryParse(map['quoteExpiresAt'].toString());
      }
    }

    return FareBreakdown(
      category: map['category'] as String? ?? 'General Repair',
      baseVisitFare: (map['baseVisitFare'] as num?)?.toDouble() ?? 149.0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      perKmRate: (map['perKmRate'] as num?)?.toDouble() ?? 12.0,
      distanceTransitFare: (map['distanceTransitFare'] as num?)?.toDouble() ?? 0.0,
      experienceBonus: (map['experienceBonus'] as num?)?.toDouble() ?? 0.0,
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 3,
      emergencySurcharge: (map['emergencySurcharge'] as num?)?.toDouble() ?? 0.0,
      urgencyTip: (map['urgencyTip'] as num?)?.toDouble() ?? 0.0,
      toolAllowance: (map['toolAllowance'] as num?)?.toDouble() ?? 0.0,
      toolType: map['toolType'] as String?,
      temporalSurcharge: (map['temporalSurcharge'] as num?)?.toDouble() ?? 0.0,
      temporalTier: map['temporalTier'] as String?,
      baseLaborIncludedMinutes: (map['baseLaborIncludedMinutes'] as num?)?.toInt() ?? 45,
      hourlyExtensionRate: (map['hourlyExtensionRate'] as num?)?.toDouble() ?? 120.0,
      actualDurationMinutes: (map['actualDurationMinutes'] as num?)?.toInt() ?? 0,
      timeExtensionSlabs: (map['timeExtensionSlabs'] as num?)?.toInt() ?? 0,
      timeExtensionFare: (map['timeExtensionFare'] as num?)?.toDouble() ?? 0.0,
      welfareContributionPercent: (map['welfareContributionPercent'] as num?)?.toDouble() ?? 2.0,
      welfareContributionFare: (map['welfareContributionFare'] as num?)?.toDouble() ?? 0.0,
      workerTakeHomeFare: (map['workerTakeHomeFare'] as num?)?.toDouble() ?? 0.0,
      totalEstimatedFare: (map['totalEstimatedFare'] as num?)?.toDouble() ?? 0.0,
      estimatedArrival: map['estimatedArrival'] as String? ?? '',
      estimatedJobDuration: map['estimatedJobDuration'] as String? ?? '',
      isFinalSettlement: map['isFinalSettlement'] as bool? ?? false,
      quoteSignature: map['quoteSignature'] as String?,
      quoteExpiresAt: expires,
      isSignatureVerified: map['isSignatureVerified'] as bool? ?? false,
    );
  }

  FareBreakdown copyWith({
    String? category,
    double? baseVisitFare,
    double? distanceKm,
    double? perKmRate,
    double? distanceTransitFare,
    double? experienceBonus,
    int? experienceYears,
    double? emergencySurcharge,
    double? urgencyTip,
    double? toolAllowance,
    String? toolType,
    double? temporalSurcharge,
    String? temporalTier,
    int? baseLaborIncludedMinutes,
    double? hourlyExtensionRate,
    int? actualDurationMinutes,
    int? timeExtensionSlabs,
    double? timeExtensionFare,
    double? welfareContributionPercent,
    double? welfareContributionFare,
    double? workerTakeHomeFare,
    double? totalEstimatedFare,
    String? estimatedArrival,
    String? estimatedJobDuration,
    bool? isFinalSettlement,
    String? quoteSignature,
    DateTime? quoteExpiresAt,
    bool? isSignatureVerified,
  }) {
    return FareBreakdown(
      category: category ?? this.category,
      baseVisitFare: baseVisitFare ?? this.baseVisitFare,
      distanceKm: distanceKm ?? this.distanceKm,
      perKmRate: perKmRate ?? this.perKmRate,
      distanceTransitFare: distanceTransitFare ?? this.distanceTransitFare,
      experienceBonus: experienceBonus ?? this.experienceBonus,
      experienceYears: experienceYears ?? this.experienceYears,
      emergencySurcharge: emergencySurcharge ?? this.emergencySurcharge,
      urgencyTip: urgencyTip ?? this.urgencyTip,
      toolAllowance: toolAllowance ?? this.toolAllowance,
      toolType: toolType ?? this.toolType,
      temporalSurcharge: temporalSurcharge ?? this.temporalSurcharge,
      temporalTier: temporalTier ?? this.temporalTier,
      baseLaborIncludedMinutes: baseLaborIncludedMinutes ?? this.baseLaborIncludedMinutes,
      hourlyExtensionRate: hourlyExtensionRate ?? this.hourlyExtensionRate,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      timeExtensionSlabs: timeExtensionSlabs ?? this.timeExtensionSlabs,
      timeExtensionFare: timeExtensionFare ?? this.timeExtensionFare,
      welfareContributionPercent: welfareContributionPercent ?? this.welfareContributionPercent,
      welfareContributionFare: welfareContributionFare ?? this.welfareContributionFare,
      workerTakeHomeFare: workerTakeHomeFare ?? this.workerTakeHomeFare,
      totalEstimatedFare: totalEstimatedFare ?? this.totalEstimatedFare,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      estimatedJobDuration: estimatedJobDuration ?? this.estimatedJobDuration,
      isFinalSettlement: isFinalSettlement ?? this.isFinalSettlement,
      quoteSignature: quoteSignature ?? this.quoteSignature,
      quoteExpiresAt: quoteExpiresAt ?? this.quoteExpiresAt,
      isSignatureVerified: isSignatureVerified ?? this.isSignatureVerified,
    );
  }
}

class CooperativePricingEngine {
  CooperativePricingEngine._();
  static final CooperativePricingEngine instance = CooperativePricingEngine._();

  /// Default trade base visit & diagnosis fares in INR (Fair Co-op floor rates).
  /// Guarantees coverage of on-site diagnostic triage + first 45 minutes of labor.
  static const Map<String, double> _baseVisitFares = {
    "Plumbing": 149.0,
    "Electrical": 149.0,
    "Carpentry": 199.0,
    "Cleaning": 249.0,
    "Painting": 299.0,
    "Appliance Repair": 199.0,
    "Masonry": 299.0,
    "Gardening": 179.0,
    "Sanitary Fittings": 149.0,
    "Solar Inverters": 249.0,
    "Welder / Metal": 249.0,
  };

  /// Standard transit allowance per km (fair travel & fuel compensation for artisan).
  static const double standardTransitRatePerKm = 12.0;

  /// Standard included labor window in base visit (in minutes).
  static const int standardIncludedLaborMinutes = 45;

  /// Incremental extension block size (in minutes).
  static const int extensionBlockMinutes = 30;

  /// Incremental extension rate per 30-minute block in INR (₹120 / hour).
  static const double extensionBlockRate = 60.0;

  /// Standard hourly extension rate in INR.
  static const double standardHourlyExtensionRate = 120.0;

  /// Cooperative social welfare & micro-insurance contribution percentage (PMJJBY / PMSBY pool).
  static const double standardWelfarePercent = 2.0;

  /// Get base visit fare for a service trade category
  double getBaseVisitFare(String category) {
    return _baseVisitFares[category] ?? 149.0;
  }

  /// Estimated job duration based on trade
  String getEstimatedDuration(String category) {
    switch (category) {
      case "Plumbing":
      case "Electrical":
      case "Sanitary Fittings":
        return "30–45 mins";
      case "Carpentry":
      case "Appliance Repair":
      case "Solar Inverters":
      case "Welder / Metal":
        return "45–60 mins";
      case "Painting":
      case "Masonry":
        return "2–4 hours";
      case "Cleaning":
        return "60–90 mins";
      case "Gardening":
        return "60–120 mins";
      default:
        return "30–60 mins";
    }
  }

  /// Estimated arrival ETA string based on distance
  String getEstimatedEta(double distanceKm, {bool isEmergency = false}) {
    if (isEmergency) return "< 20 mins (Priority Rush)";
    final minutes = (distanceKm * 3.5 + 4).clamp(5, 45).round();
    return "~$minutes mins (${distanceKm.toStringAsFixed(1)} km)";
  }

  /// Calculate full transparent fare breakdown for upfront booking estimation.
  /// 100% backward-compatible with all existing app callers.
  FareBreakdown calculateFare({
    required String category,
    double distanceKm = 2.4,
    int experienceYears = 3,
    bool isEmergency = false,
    double urgencyTip = 0.0,
    double? customBaseRate,
    double? customPerKmRate,
    double toolAllowance = 0.0,
    String? toolType,
    double temporalSurcharge = 0.0,
    String? temporalTier,
  }) {
    final baseFare = customBaseRate ?? getBaseVisitFare(category);
    final transitRate = customPerKmRate ?? standardTransitRatePerKm;

    // Distance transit allowance calculation
    final transitFare = (distanceKm * transitRate).roundToDouble();

    // Master / Senior artisan experience bonus (rewarding skilled cooperative workers)
    final experienceBonus = experienceYears >= 5 ? 30.0 : (experienceYears >= 3 ? 15.0 : 0.0);

    // Emergency instant response charge (30 min guarantee)
    final emergencyFee = isEmergency ? 150.0 : 0.0;

    // Total upfront estimated fare
    final total = baseFare +
        transitFare +
        experienceBonus +
        emergencyFee +
        toolAllowance +
        temporalSurcharge +
        urgencyTip;

    // 2% cooperative welfare deduction from labor fare
    final grossLabor = baseFare + experienceBonus + toolAllowance;
    final welfareFare = ((grossLabor * standardWelfarePercent) / 100.0);
    final workerTakeHome = (total - welfareFare);

    return FareBreakdown(
      category: category,
      baseVisitFare: baseFare,
      distanceKm: distanceKm,
      perKmRate: transitRate,
      distanceTransitFare: transitFare,
      experienceBonus: experienceBonus,
      experienceYears: experienceYears,
      emergencySurcharge: emergencyFee,
      urgencyTip: urgencyTip,
      toolAllowance: toolAllowance,
      toolType: toolType,
      temporalSurcharge: temporalSurcharge,
      temporalTier: temporalTier,
      baseLaborIncludedMinutes: standardIncludedLaborMinutes,
      hourlyExtensionRate: standardHourlyExtensionRate,
      actualDurationMinutes: 0,
      timeExtensionSlabs: 0,
      timeExtensionFare: 0.0,
      welfareContributionPercent: standardWelfarePercent,
      welfareContributionFare: double.parse(welfareFare.toStringAsFixed(1)),
      workerTakeHomeFare: double.parse(workerTakeHome.toStringAsFixed(1)),
      totalEstimatedFare: total,
      estimatedArrival: getEstimatedEta(distanceKm, isEmergency: isEmergency),
      estimatedJobDuration: getEstimatedDuration(category),
      isFinalSettlement: false,
    );
  }

  /// Calculates post-job final transparent wage settlement based on the exact
  /// elapsed time between `startedAt` (Start OTP entered) and `completedAt` (C2PA proof uploaded).
  ///
  /// Time Calculation Rules:
  /// - First [standardIncludedLaborMinutes] (45 mins) are covered under the Base Visit Fare (0 overtime).
  /// - Time beyond 45 mins is metered in 30-minute slabs at ₹60/slab (₹120/hr).
  /// - Exceeding 4.5 hours caps automatically at the full-day ceiling to protect the customer from runaway meters.
  FareBreakdown calculateFinalSettlementFare({
    required FareBreakdown upfrontFare,
    required Duration actualDuration,
  }) {
    final int elapsedMinutes = actualDuration.inMinutes;

    int extensionSlabs = 0;
    double extensionFare = 0.0;

    if (elapsedMinutes > upfrontFare.baseLaborIncludedMinutes) {
      final overtimeMinutes = elapsedMinutes - upfrontFare.baseLaborIncludedMinutes;
      // Calculate 30-minute slabs with ceiling
      extensionSlabs = (overtimeMinutes / extensionBlockMinutes).ceil();

      // Ceiling protection: cap overtime to 8 slabs (4 hours overtime = 4.75 hrs total)
      if (extensionSlabs > 8) {
        extensionSlabs = 8;
      }
      extensionFare = extensionSlabs * extensionBlockRate;
    }

    final totalSettlementFare = upfrontFare.totalEstimatedFare + extensionFare;

    // Recalculate 2% welfare contribution on gross labor (including overtime)
    final grossLabor = upfrontFare.baseVisitFare +
        upfrontFare.experienceBonus +
        upfrontFare.toolAllowance +
        extensionFare;

    final welfareFare = ((grossLabor * upfrontFare.welfareContributionPercent) / 100.0);
    final workerTakeHome = (totalSettlementFare - welfareFare);

    return FareBreakdown(
      category: upfrontFare.category,
      baseVisitFare: upfrontFare.baseVisitFare,
      distanceKm: upfrontFare.distanceKm,
      perKmRate: upfrontFare.perKmRate,
      distanceTransitFare: upfrontFare.distanceTransitFare,
      experienceBonus: upfrontFare.experienceBonus,
      experienceYears: upfrontFare.experienceYears,
      emergencySurcharge: upfrontFare.emergencySurcharge,
      urgencyTip: upfrontFare.urgencyTip,
      toolAllowance: upfrontFare.toolAllowance,
      toolType: upfrontFare.toolType,
      temporalSurcharge: upfrontFare.temporalSurcharge,
      temporalTier: upfrontFare.temporalTier,
      baseLaborIncludedMinutes: upfrontFare.baseLaborIncludedMinutes,
      hourlyExtensionRate: upfrontFare.hourlyExtensionRate,
      actualDurationMinutes: elapsedMinutes,
      timeExtensionSlabs: extensionSlabs,
      timeExtensionFare: extensionFare,
      welfareContributionPercent: upfrontFare.welfareContributionPercent,
      welfareContributionFare: double.parse(welfareFare.toStringAsFixed(1)),
      workerTakeHomeFare: double.parse(workerTakeHome.toStringAsFixed(1)),
      totalEstimatedFare: totalSettlementFare,
      estimatedArrival: upfrontFare.estimatedArrival,
      estimatedJobDuration: upfrontFare.estimatedJobDuration,
      isFinalSettlement: true,
    );
  }
}
