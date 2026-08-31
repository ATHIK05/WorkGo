import 'package:easy_localization/easy_localization.dart';
import '../models/booking.dart';
import '../models/worker.dart';

/// Extension on String to localize dynamic Firebase skill names, trade tags, and areas.
extension DynamicTradeLocalization on String {
  /// Converts trade strings like 'Plumbing', 'Electrical', 'Carpentry' etc. to localized text.
  String toLocalizedTrade() {
    final lower = toLowerCase().trim();
    if (lower.contains('plumb')) return 'cat_plumbing'.tr();
    if (lower.contains('electr')) return 'cat_electrical'.tr();
    if (lower.contains('carpent')) return 'cat_carpentry'.tr();
    if (lower.contains('clean')) return 'cat_cleaning'.tr();
    if (lower.contains('paint')) return 'cat_painting'.tr();
    if (lower.contains('appliance')) return 'cat_appliance'.tr();
    if (lower.contains('mason')) return 'cat_masonry'.tr();
    if (lower.contains('garden')) return 'cat_gardening'.tr();
    return this;
  }
}

/// Extension on BookingStatus to get localized label.
extension BookingStatusLocalization on BookingStatus {
  String toLocalizedName() {
    switch (this) {
      case BookingStatus.pending:
        return 'status_pending'.tr();
      case BookingStatus.accepted:
        return 'status_accepted'.tr();
      case BookingStatus.inProgress:
        return 'status_in_progress'.tr();
      case BookingStatus.completed:
        return 'status_completed'.tr();
      case BookingStatus.cancelled:
        return 'status_cancelled'.tr();
    }
  }
}

/// Extension on VerificationStatus to get localized label.
extension VerificationStatusLocalization on VerificationStatus {
  String toLocalizedName() {
    switch (this) {
      case VerificationStatus.approved:
        return 'kyc_approved'.tr();
      case VerificationStatus.pending:
        return 'kyc_pending'.tr();
      case VerificationStatus.rejected:
        return 'reject_worker_btn'.tr();
    }
  }
}

/// Extension on AvailabilityStatus to get localized label.
extension AvailabilityStatusLocalization on AvailabilityStatus {
  String toLocalizedName() {
    switch (this) {
      case AvailabilityStatus.online:
        return 'online_ready'.tr();
      case AvailabilityStatus.offline:
        return 'offline_status'.tr();
      case AvailabilityStatus.busy:
        return 'status_in_progress'.tr();
    }
  }
}

/// Resilient string translation fallback extension.
extension SafeTranslationExtension on String {
  /// Translates key or returns fallback if key is missing or unresolved.
  String trSafe([String? fallback, List<String>? args]) {
    try {
      final res = args != null && args.isNotEmpty ? this.tr(args: args) : this.tr();
      if (res == this && fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
      return res;
    } catch (_) {
      return fallback ?? this;
    }
  }
}
