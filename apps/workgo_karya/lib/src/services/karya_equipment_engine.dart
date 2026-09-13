import 'package:workgo_core/workgo_core.dart';

/// Local AI equipment suggestion engine for Karya artisans.
/// Backed by the domain-accurate [TradeToolCatalog] in `workgo_core`.
class KaryaEquipmentEngine {
  KaryaEquipmentEngine._();

  /// Returns domain-accurate list of tools for [serviceType] and optional [issueText].
  static List<String> suggestTools(String serviceType, String? issueText) {
    return TradeToolCatalog.getRecommendedTools(
      serviceType: serviceType,
      issueText: issueText,
    );
  }

  /// Returns full categorized equipment kit (primary tools, consumables, safety PPE).
  static TradeEquipmentKit getKit({
    required String serviceType,
    String? issueText,
    String? symptomDescription,
    String? equipmentTag,
  }) {
    return TradeToolCatalog.getEquipmentKit(
      serviceType: serviceType,
      issueText: issueText,
      symptomDescription: symptomDescription,
      equipmentTag: equipmentTag,
    );
  }
}
