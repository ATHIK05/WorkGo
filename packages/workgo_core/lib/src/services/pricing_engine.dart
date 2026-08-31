/// WorkGo Cooperative Pricing Engine
/// Implements dynamic, transparent on-demand fare calculation modeled after
/// fair cooperative standards and ride-hailing/on-demand algorithms (e.g. Rapido / Urban Company).
///
/// Formula:
/// Total Estimated Fare = Base Trade Visit & Diagnosis Fee
///                     + (Distance in km * Transit Rate per km)
///                     + (Experience Bonus if 5+ yrs)
///                     + (Emergency 30-min Surcharge)
///                     + (Urgency Booster Tip)
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
  final double totalEstimatedFare;
  final String estimatedArrival;
  final String estimatedJobDuration;

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
    required this.totalEstimatedFare,
    required this.estimatedArrival,
    required this.estimatedJobDuration,
  });

  String get formattedTotal => "₹${totalEstimatedFare.toStringAsFixed(0)}";
  String get formattedBase => "₹${baseVisitFare.toStringAsFixed(0)}";
  String get formattedTransit => "₹${distanceTransitFare.toStringAsFixed(0)}";
  String get formattedDistance => "${distanceKm.toStringAsFixed(1)} km";
}

class CooperativePricingEngine {
  CooperativePricingEngine._();
  static final CooperativePricingEngine instance = CooperativePricingEngine._();

  /// Default trade base visit & diagnosis fares in INR (Fair Co-op floor rates)
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
  };

  /// Standard transit allowance per km (fair travel compensation for artisan)
  static const double standardTransitRatePerKm = 12.0;

  /// Get base visit fare for a service trade category
  double getBaseVisitFare(String category) {
    return _baseVisitFares[category] ?? 149.0;
  }

  /// Estimated job duration based on trade
  String getEstimatedDuration(String category) {
    switch (category) {
      case "Plumbing":
      case "Electrical":
        return "30–45 mins";
      case "Carpentry":
      case "Appliance Repair":
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
    return "~$minutes mins ($distanceKm km)";
  }

  /// Calculate full transparent fare breakdown
  FareBreakdown calculateFare({
    required String category,
    double distanceKm = 2.4,
    int experienceYears = 3,
    bool isEmergency = false,
    double urgencyTip = 0.0,
    double? customBaseRate,
    double? customPerKmRate,
  }) {
    final baseFare = customBaseRate ?? getBaseVisitFare(category);
    final transitRate = customPerKmRate ?? standardTransitRatePerKm;
    
    // Distance transit allowance calculation
    final transitFare = (distanceKm * transitRate).roundToDouble();

    // Master / Senior artisan experience bonus (rewarding skilled cooperative workers)
    final experienceBonus = experienceYears >= 5 ? 30.0 : (experienceYears >= 3 ? 15.0 : 0.0);

    // Emergency instant response charge (30 min guarantee)
    final emergencyFee = isEmergency ? 150.0 : 0.0;

    // Total estimated fare
    final total = baseFare + transitFare + experienceBonus + emergencyFee + urgencyTip;

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
      totalEstimatedFare: total,
      estimatedArrival: getEstimatedEta(distanceKm, isEmergency: isEmergency),
      estimatedJobDuration: getEstimatedDuration(category),
    );
  }
}
