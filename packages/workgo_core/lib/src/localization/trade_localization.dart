import 'package:easy_localization/easy_localization.dart';
import '../models/booking.dart';
import '../models/worker.dart';

/// Extension on String to localize dynamic Firebase skill names, trade tags, and areas.
extension DynamicTradeLocalization on String {
  /// Converts trade strings like 'Plumbing', 'Electrical', 'Carpentry' etc. to localized text.
  String toLocalizedTrade() {
    final lower = toLowerCase().trim();
    if (lower.contains('plumb') || lower.contains('tap') || lower.contains('pipe') || lower.contains('faucet')) {
      return 'cat_plumbing'.tr();
    }
    if (lower.contains('electr') || lower.contains('wire') || lower.contains('power')) {
      return 'cat_electrical'.tr();
    }
    if (lower.contains('carpent') || lower.contains('wood') || lower.contains('furniture')) {
      return 'cat_carpentry'.tr();
    }
    if (lower.contains('clean') || lower.contains('housekeep')) {
      return 'cat_cleaning'.tr();
    }
    if (lower.contains('paint')) {
      return 'cat_painting'.tr();
    }
    if (lower.contains('appliance') ||
        lower.contains('repair') ||
        lower.contains('ac') ||
        lower.contains('hvac') ||
        lower.contains('refrigerator') ||
        lower.contains('washing') ||
        lower.contains('geyser') ||
        lower.contains('cooler') ||
        lower.contains('purifier')) {
      return 'cat_appliance'.tr();
    }
    if (lower.contains('mason') || lower.contains('civil') || lower.contains('tile')) {
      return 'cat_masonry'.tr();
    }
    if (lower.contains('garden')) {
      return 'cat_gardening'.tr();
    }
    return this;
  }

  /// Returns a clean localized trade name without parenthetical English annotations
  String toLocalizedTradeClean() {
    final localized = toLocalizedTrade();
    if (localized.contains(' (')) {
      return localized.split(' (').first.trim();
    }
    return localized;
  }

  /// Converts persona trades (e.g. 'Plumber', 'Electrician', 'Carpenter') to canonical trade categories
  /// ('Plumbing', 'Electrical', 'Carpentry', 'Appliance Repair', etc.).
  String toCanonicalTrade() {
    final lower = toLowerCase().trim();
    if (lower.contains('plumb') || lower.contains('tap') || lower.contains('pipe') || lower.contains('faucet')) {
      return 'Plumbing';
    }
    if (lower.contains('electr') || lower.contains('wire') || lower.contains('power')) {
      return 'Electrical';
    }
    if (lower.contains('carpent') || lower.contains('wood') || lower.contains('furniture')) {
      return 'Carpentry';
    }
    if (lower.contains('paint')) {
      return 'Painting';
    }
    if (lower.contains('clean')) {
      return 'Cleaning';
    }
    if (lower.contains('mason') || lower.contains('civil') || lower.contains('tile')) {
      return 'Masonry';
    }
    if (lower.contains('garden')) {
      return 'Gardening';
    }
    if (lower.contains('appliance') ||
        lower.contains('repair') ||
        lower.contains('ac') ||
        lower.contains('hvac') ||
        lower.contains('air condition') ||
        lower.contains('washing') ||
        lower.contains('refrigerator') ||
        lower.contains('cooler') ||
        lower.contains('geyser') ||
        lower.contains('microwave') ||
        lower.contains('ro water') ||
        lower.contains('purifier')) {
      return 'Appliance Repair';
    }
    return this;
  }

  /// Determines if two trade/skill strings represent the same trade cluster (e.g. 'Plumber' vs 'Plumbing').
  bool matchesTrade(String? other) {
    if (other == null || other.trim().isEmpty || trim().isEmpty) return false;
    final a = toCanonicalTrade().toLowerCase();
    final b = other.toCanonicalTrade().toLowerCase();
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;

    final lowerA = toLowerCase().trim();
    final lowerB = other.toLowerCase().trim();
    if (lowerA == lowerB) return true;
    if (lowerA.contains(lowerB) || lowerB.contains(lowerA)) return true;

    if (lowerA.contains('plumb') && lowerB.contains('plumb')) return true;
    if (lowerA.contains('electr') && lowerB.contains('electr')) return true;
    if (lowerA.contains('carpent') && lowerB.contains('carpent')) return true;
    if (lowerA.contains('paint') && lowerB.contains('paint')) return true;
    if (lowerA.contains('clean') && lowerB.contains('clean')) return true;
    if (lowerA.contains('mason') && lowerB.contains('mason')) return true;
    if (lowerA.contains('garden') && lowerB.contains('garden')) return true;
    if ((lowerA.contains('appliance') || lowerA.contains('repair') || lowerA.contains('ac')) &&
        (lowerB.contains('appliance') || lowerB.contains('repair') || lowerB.contains('ac'))) {
      return true;
    }
    return false;
  }
}

/// Extension on Worker for intelligent trade category matching.
extension WorkerTradeMatchingExtension on Worker {
  /// Checks if this worker is skilled in or provides services for the given trade category.
  bool matchesTradeCategory(String? targetCategory) {
    if (targetCategory == null || targetCategory.trim().isEmpty) return false;
    for (final s in skills) {
      if (s.matchesTrade(targetCategory)) return true;
    }
    for (final t in equipmentTags) {
      if (t.matchesTrade(targetCategory)) return true;
    }
    for (final k in serviceKeywords) {
      if (k.matchesTrade(targetCategory)) return true;
    }
    return false;
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
      case BookingStatus.paymentPending:
        return 'status_payment_pending'.trSafe('Payment Pending');
      case BookingStatus.completed:
        return 'status_completed'.tr();
      case BookingStatus.cancelled:
        return 'status_cancelled'.tr();
    }
  }
}

/// Extension on PaymentStatus to get localized label.
extension PaymentStatusLocalization on PaymentStatus {
  String toLocalizedName() {
    switch (this) {
      case PaymentStatus.paid:
        return 'status_paid'.trSafe('PAID');
      case PaymentStatus.unpaid:
        return 'status_unpaid'.trSafe('UNPAID');
      case PaymentStatus.refunded:
        return 'status_refunded'.trSafe('REFUNDED');
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

  /// Synchronously translates landmark and address tokens for zero-latency address display.
  String toLocalizedAddress(String locale) {
    if (locale == 'en' || trim().isEmpty) return this;
    final dict = _addressDictionary[locale];
    if (dict == null) return this;
    String result = this;
    dict.forEach((key, val) {
      final regex = RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false);
      result = result.replaceAllMapped(regex, (m) => val);
    });
    return result;
  }
}

const Map<String, Map<String, String>> _addressDictionary = {
  'hi': {
    'home': 'घर',
    'office': 'कार्यालय',
    'work': 'कार्यस्थल',
    'near': 'के पास',
    'near to': 'के पास',
    'nearby': 'आसपास',
    'opposite': 'के सामने',
    'opp': 'के सामने',
    'behind': 'के पीछे',
    'road': 'मार्ग',
    'rd': 'मार्ग',
    'street': 'गली',
    'st': 'गली',
    'main road': 'मुख्य मार्ग',
    'cross': 'क्रॉस',
    'nagar': 'नगर',
    'colony': 'कॉलोनी',
    'apartment': 'अपार्टमेंट',
    'apt': 'अपार्टमेंट',
    'layout': 'लेआउट',
    'sector': 'सेक्टर',
    'block': 'ब्लॉक',
    'floor': 'मंजिल',
    'tamil nadu': 'तमिलनाडु',
    'erode': 'इरोड',
    'chennai': 'चेन्नई',
    'coimbatore': 'कोयंबटूर',
    'salem': 'सेलम',
    'madurai': 'मदुरै',
    'tirupur': 'तिरुपुर',
    'bangalore': 'बेंगलुरु',
    'bengaluru': 'बेंगलुरु',
    'mumbai': 'मुंबई',
    'delhi': 'दिल्ली',
    'hyderabad': 'हैदराबाद',
    'pune': 'पुणे',
    'kolkata': 'कोलकाता',
    'kerala': 'केरल',
    'karnataka': 'कर्नाटक',
    'maharashtra': 'महाराष्ट्र',
    'thanjavur': 'तंजावुर',
    'trichy': 'त्रिची',
    'tiruchirappalli': 'तिरुचिरापल्ली',
    'vellore': 'वेल्लोर',
    'hosur': 'होसुर',
    'e main st': 'ईस्ट मेन स्ट्रीट',
    'main st': 'मेन स्ट्रीट',
    'east': 'पूर्व',
    'west': 'पश्चिम',
    'north': 'उत्तर',
    'south': 'दक्षिण',
  },
  'ta': {
    'home': 'வீடு',
    'office': 'அலுவலகம்',
    'work': 'வேலை இடம்',
    'near': 'அருகில்',
    'near to': 'அருகில்',
    'nearby': 'அருகில்',
    'opposite': 'எதிரில்',
    'opp': 'எதிரில்',
    'behind': 'பின்புறம்',
    'road': 'சாலை',
    'rd': 'சாலை',
    'street': 'தெரு',
    'st': 'தெரு',
    'main road': 'பிரதான சாலை',
    'cross': 'குறுக்குத் தெரு',
    'nagar': 'நகர்',
    'colony': 'காலனி',
    'apartment': 'அபார்ட்மெண்ட்',
    'apt': 'அபார்ட்மெண்ட்',
    'layout': 'லேஅவுட்',
    'sector': 'செக்டார்',
    'block': 'பிளாக்',
    'floor': 'தளம்',
    'tamil nadu': 'தமிழ்நாடு',
    'erode': 'ஈரோடு',
    'chennai': 'சென்னை',
    'coimbatore': 'கோயம்புத்தூர்',
    'salem': 'சேலம்',
    'madurai': 'மதுரை',
    'tirupur': 'திருப்பூர்',
    'bangalore': 'பெங்களூரு',
    'bengaluru': 'பெங்களூரு',
    'mumbai': 'மும்பை',
    'delhi': 'டெல்லி',
    'hyderabad': 'ஹைதராபாத்',
    'pune': 'புனே',
    'kolkata': 'கொல்கத்தா',
    'kerala': 'கேரளா',
    'karnataka': 'கர்நாடகா',
    'maharashtra': 'மகாராஷ்டிரா',
    'thanjavur': 'தஞ்சாவூர்',
    'trichy': 'திருச்சி',
    'tiruchirappalli': 'திருச்சிராப்பள்ளி',
    'vellore': 'வேலூர்',
    'hosur': 'ஓசூர்',
    'e main st': 'கிழக்கு பிரதான சாலை',
    'main st': 'பிரதான சாலை',
    'east': 'கிழக்கு',
    'west': 'மேற்கு',
    'north': 'வடக்கு',
    'south': 'தெற்கு',
  },
};
