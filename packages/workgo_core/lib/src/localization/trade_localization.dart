import 'package:easy_localization/easy_localization.dart';
import '../models/booking.dart';
import '../models/worker.dart';

/// Extension on String to localize dynamic Firebase skill names, trade tags, and areas.
extension DynamicTradeLocalization on String {
  /// Converts trade strings like 'Plumbing', 'Electrical', 'Carpentry' etc. to localized text.
  String toLocalizedTrade() {
    final lower = toLowerCase().trim();
    if (lower.contains('plumb') || lower.contains('tap') || lower.contains('pipe') || lower.contains('faucet')) {
      return 'cat_plumbing'.trSafe('Plumbing');
    }
    if (lower.contains('electr') || lower.contains('wire') || lower.contains('power')) {
      return 'cat_electrical'.trSafe('Electrical');
    }
    if (lower.contains('carpent') || lower.contains('wood') || lower.contains('furniture')) {
      return 'cat_carpentry'.trSafe('Carpentry');
    }
    if (lower.contains('clean') || lower.contains('housekeep')) {
      return 'cat_cleaning'.trSafe('Cleaning');
    }
    if (lower.contains('paint')) {
      return 'cat_painting'.trSafe('Painting');
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
      return 'cat_appliance'.trSafe('Appliance Repair');
    }
    if (lower.contains('mason') || lower.contains('civil') || lower.contains('tile')) {
      return 'cat_masonry'.trSafe('Masonry');
    }
    if (lower.contains('garden')) {
      return 'cat_gardening'.trSafe('Gardening');
    }
    if (lower.contains('weld') || lower.contains('metal') || lower.contains('iron') || lower.contains('grill')) {
      return 'cat_welding'.trSafe('Welding / Metal');
    }
    return this;
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
    if (lower.contains('weld') || lower.contains('metal') || lower.contains('iron') || lower.contains('grill')) {
      return 'Welder / Metal';
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
    if ((lowerA.contains('weld') || lowerA.contains('metal')) &&
        (lowerB.contains('weld') || lowerB.contains('metal'))) {
      return true;
    }
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
        return 'status_pending'.trSafe('Pending');
      case BookingStatus.accepted:
        return 'status_accepted'.trSafe('Accepted');
      case BookingStatus.inProgress:
        return 'status_in_progress'.trSafe('In Progress');
      case BookingStatus.paymentPending:
        return 'status_payment_pending'.trSafe('Payment Pending');
      case BookingStatus.completed:
        return 'status_completed'.trSafe('Completed');
      case BookingStatus.cancelled:
        return 'status_cancelled'.trSafe('Cancelled');
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
        return 'kyc_approved'.trSafe('VERIFIED');
      case VerificationStatus.pending:
        return 'kyc_pending'.trSafe('PENDING');
      case VerificationStatus.rejected:
        return 'reject_worker_btn'.trSafe('REJECTED');
    }
  }
}

/// Extension on AvailabilityStatus to get localized label.
extension AvailabilityStatusLocalization on AvailabilityStatus {
  String toLocalizedName() {
    switch (this) {
      case AvailabilityStatus.online:
        return 'online_ready'.trSafe('ONLINE');
      case AvailabilityStatus.offline:
        return 'offline_status'.trSafe('OFFLINE');
      case AvailabilityStatus.busy:
        return 'status_in_progress'.trSafe('BUSY');
    }
  }
}

/// In-memory dictionary for high-frequency dynamic screens ensuring zero warning logs
/// even before a full Hot Restart reloads JSON asset files.
const Map<String, Map<String, String>> _embeddedTranslations = {
  // ── Core Service Categories ──
  "cat_plumbing": {
    "en": "Plumbing",
    "hi": "नलसाज़ी (प्लंबर)",
    "ta": "குழாய் பழுதுபார்ப்பு (பிளம்பர்)",
    "te": "ప్లంబింగ్",
    "kn": "ಪ್ಲಂಬಿಂಗ್",
    "ml": "പ്ലംബിംഗ്",
    "mr": "प्लंबिंग",
    "bn": "প্লাম্বিং",
    "gu": "પ્લમ્બિંગ",
    "ur": "پلمبنگ",
  },
  "cat_electrical": {
    "en": "Electrical",
    "hi": "विद्युत सेवा (इलेक्ट्रीशियन)",
    "ta": "மின்சார வேலை (எலக்ட்ரீசியன்)",
    "te": "ఎలక్ట్రికల్",
    "kn": "ಎಲೆಕ್ಟ್ರಿಕಲ್",
    "ml": "ഇലക്ട്രിക്കൽ",
    "mr": "इलेक्ट्रिकल",
    "bn": "বৈদ্যুতিক",
    "gu": "ઇલેક્ટ્રિકલ",
    "ur": "الیکٹریکل",
  },
  "cat_carpentry": {
    "en": "Carpentry",
    "hi": "बढ़ईगीरी (कारपेंटर)",
    "ta": "மரவேலை (தச்சர்)",
    "te": "వడ్రంగి",
    "kn": "ಬಡಗಿ ಕೆಲಸ",
    "ml": "ആശാരിപ്പണി",
    "mr": "सुतारकाम",
    "bn": "ছুতোর কাজ",
    "gu": "સુથારી કામ",
    "ur": "بڑھئی کا کام",
  },
  "cat_painting": {
    "en": "Painting",
    "hi": "पेंटिंग (रंगाई)",
    "ta": "வண்ணப்பூச்சு (பெயிண்டர்)",
    "te": "పెయింటింగ్",
    "kn": "ಪೇಂಟಿಂಗ್",
    "ml": "പെയിന്റിംഗ്",
    "mr": "रंगकाम",
    "bn": "পেইন্টিং",
    "gu": "કલર કામ",
    "ur": "پینٹنگ",
  },
  "cat_cleaning": {
    "en": "Cleaning",
    "hi": "सफाई सेवा",
    "ta": "சுத்தம் செய்தல்",
    "te": "క్లీనింగ్",
    "kn": "ಸ್ವಚ್ಛತೆ",
    "ml": "ക്ലീനിംഗ്",
    "mr": "स्वच्छता",
    "bn": "পরিষ্কার",
    "gu": "સફાઈ",
    "ur": "صفائی",
  },
  "cat_appliance": {
    "en": "Appliance Repair",
    "hi": "उपकरण मरम्मत",
    "ta": "சாதனம் பழுதுபார்ப்பு",
    "te": "ఉపకరణాల మరమ్మతు",
    "kn": "ಉಪಕರಣ ದುರಸ್ತಿ",
    "ml": "ഉപകരണ അറ്റകുറ്റപ്പണി",
    "mr": "उपकरण दुरुस्ती",
    "bn": "যন্ত্রপাতি মেরামত",
    "gu": "ઉપકરણ રિપેરીંગ",
    "ur": "سامان کی مرمت",
  },
  "cat_masonry": {
    "en": "Masonry",
    "hi": "राजमिस्त्री (चिनाई)",
    "ta": "கட்டட வேலை (கொத்தனார்)",
    "te": "మేస్త్రీ పని",
    "kn": "ಮೇಸ್ತ್ರಿ ಕೆಲಸ",
    "ml": "കൊത്തുപണി",
    "mr": "गवंडी काम",
    "bn": "রাজমিস্ত্রি",
    "gu": "કડિયા કામ",
    "ur": "معماری",
  },
  "cat_gardening": {
    "en": "Gardening",
    "hi": "बागवानी",
    "ta": "தோட்டக்கலை",
    "te": "తోటపని",
    "kn": "ತೋಟಗಾರಿಕೆ",
    "ml": "തോട്ടപ്പണി",
    "mr": "बागकाम",
    "bn": "বাগান কাজ",
    "gu": "બાગકામ",
    "ur": "باغبانی",
  },
  "cat_welding": {
    "en": "Welding / Metal",
    "hi": "वेल्डिंग / धातु कार्य",
    "ta": "வெல்டிங் / உலோக வேலை",
    "te": "వెల్డింగ్ / మెటల్ వర్క్",
    "kn": "ವೆಲ್ಡಿಂಗ್ / ಮೆಟಲ್ ವರ್ಕ್",
    "ml": "വെൽഡിംഗ്",
    "mr": "वेल्डिंग",
    "bn": "ওয়েল্ডিং",
    "gu": "વેલ્ડિંગ",
    "ur": "ویلڈنگ",
  },

  // ── Booking Statuses ──
  "status_pending": {
    "en": "Pending",
    "hi": "लंबित",
    "ta": "நிலுவையில் உள்ளது",
    "te": "పెండింగ్",
    "kn": "ಬಾಕಿ ಇದೆ",
    "ml": "തീർപ്പുകൽപ്പിക്കാത്തത്",
    "mr": "प्रलंबित",
    "bn": "মুলতুবি",
    "gu": "બાકી",
  },
  "status_accepted": {
    "en": "Accepted",
    "hi": "स्वीकृत",
    "ta": "ஏற்றுக்கொள்ளப்பட்டது",
    "te": "ఆమోదించబడింది",
    "kn": "ಸ್ವೀಕರಿಸಲಾಗಿದೆ",
    "ml": "സ്വീകരിച്ചു",
    "mr": "स्वीकृत",
    "bn": "গৃহীত",
    "gu": "સ્વીકારેલ",
  },
  "status_in_progress": {
    "en": "In Progress",
    "hi": "प्रगति पर है",
    "ta": "செயலில் உள்ளது",
    "te": "ప్రగతిలో ఉంది",
    "kn": "ಪ್ರಗತಿಯಲ್ಲಿದೆ",
    "ml": "നടന്നുകൊണ്ടിരിക്കുന്നു",
    "mr": "प्रगतीपथावर",
    "bn": "চলমান",
    "gu": "ચાલુ છે",
  },
  "status_payment_pending": {
    "en": "Payment Pending",
    "hi": "भुगतान लंबित",
    "ta": "பணம் நிலுவையில் உள்ளது",
    "te": "చెల్లింపు పెండింగ్",
    "kn": "ಪಾವತಿ ಬಾಕಿ ಇದೆ",
    "ml": "പേയ്‌മെന്റ് ബാക്കി",
    "mr": "पेमेंट प्रलंबित",
    "bn": "পেমেন্ট বাকি",
    "gu": "ચૂકવણી બાકી",
  },
  "status_completed": {
    "en": "Completed",
    "hi": "पूर्ण हुआ",
    "ta": "முடிக்கப்பட்டது",
    "te": "పూర్తయింది",
    "kn": "ಪೂರ್ಣಗೊಂಡಿದೆ",
    "ml": "പൂർത്തിയായി",
    "mr": "पूर्ण झाले",
    "bn": "সম্পূর্ণ",
    "gu": "પૂર્ણ થયું",
  },
  "status_cancelled": {
    "en": "Cancelled",
    "hi": "रद्द किया गया",
    "ta": "ரத்து செய்யப்பட்டது",
    "te": "రద్దు చేయబడింది",
    "kn": "ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ",
    "ml": "റദ്ദാക്കി",
    "mr": "रद्द केले",
    "bn": "বাতিল",
    "gu": "રદ કરેલ",
  },
  "status_paid": {
    "en": "Paid",
    "hi": "भुगतान किया गया",
    "ta": "செலுத்தப்பட்டது",
    "te": "చెల్లించబడింది",
    "kn": "ಪಾವತಿಸಲಾಗಿದೆ",
    "ml": "നൽകി",
    "mr": "भरले",
    "bn": "পরিশোধিত",
    "gu": "ચૂકવેલ",
  },
  "status_unpaid": {
    "en": "Unpaid",
    "hi": "अदत्त",
    "ta": "செலுத்தப்படவில்லை",
    "te": "చెల్లించలేదు",
    "kn": "ಪಾವತಿಸಿಲ್ಲ",
    "ml": "നൽകിയിട്ടില്ല",
    "mr": "न भरलेले",
    "bn": "অপরিশোধিত",
    "gu": "ન ચૂકવેલ",
  },
  "status_refunded": {
    "en": "Refunded",
    "hi": "वापस किया गया",
    "ta": "திரும்பப் பெறப்பட்டது",
    "te": "రీఫండ్ చేయబడింది",
    "kn": "ಮರುಪಾವತಿಸಲಾಗಿದೆ",
    "ml": "റീഫണ്ട് ചെയ്തു",
    "mr": "रिफंड केले",
    "bn": "ফেরত দেওয়া হয়েছে",
    "gu": "રીફંડ થયેલ",
  },
  "kyc_approved": {
    "en": "VERIFIED",
    "hi": "सत्यापित",
    "ta": "சரிபார்க்கப்பட்டது",
    "te": "ధృవీకరించబడింది",
    "kn": "ಪರಿಶೀಲಿಸಲಾಗಿದೆ",
    "ml": "സ്ഥിരീകരിച്ചു",
    "mr": "पडताळणी पूर्ण",
    "bn": "যাচাইকৃত",
    "gu": "ચકાસાયેલ",
  },
  "kyc_pending": {
    "en": "PENDING",
    "hi": "लंबित",
    "ta": "நிலுவை",
    "te": "పెండింగ్",
    "kn": "ಬಾಕಿ",
    "ml": "ബാക്കി",
    "mr": "प्रलंबित",
    "bn": "মুলতুবি",
    "gu": "બાકી",
  },
  "reject_worker_btn": {
    "en": "REJECTED",
    "hi": "अस्वीकृत",
    "ta": "நிராகரிக்கப்பட்டது",
    "te": "తిరస్కరించబడింది",
    "kn": "ತಿರಸ್ಕರಿಸಲಾಗಿದೆ",
    "ml": "നിരസിച്ചു",
    "mr": "नाकारले",
    "bn": "প্রত্যাখ্যাত",
    "gu": "અસ્વીકાર્ય",
  },
  "online_ready": {
    "en": "ONLINE",
    "hi": "ऑनलाइन",
    "ta": "ஆன்லைன்",
    "te": "ఆన్‌లైన్",
    "kn": "ಆನ್‌ಲೈನ್",
    "ml": "ഓൺലൈൻ",
    "mr": "ऑनलाइन",
    "bn": "অনলাইন",
    "gu": "ઓનલાઈન",
  },
  "offline_status": {
    "en": "OFFLINE",
    "hi": "ऑफलाइन",
    "ta": "ஆஃப்லைன்",
    "te": "ఆఫ్‌లైన్",
    "kn": "ಆಫ್‌ಲೈನ್",
    "ml": "ഓഫ്‌ലൈൻ",
    "mr": "ऑफलाइन",
    "bn": "অফলাইন",
    "gu": "ઓફલાઇન",
  },

  // ── Live Radar Cockpit & Dispatches ──
  "live_radar_greeting": {
    "en": "Glad you're online,",
    "hi": "खुशी हुई आप ऑनलाइन हैं,",
    "ta": "நீங்கள் ஆன்லைனில் இருப்பது மகிழ்ச்சி,",
  },
  "radar_scanning_active": {
    "en": "Live Dispatch",
    "hi": "लाइव डिस्पैच",
    "ta": "நேரலை அனுப்புதல்",
  },
  "trade_channels_active": {
    "en": "Trade Channels",
    "hi": "ट्रेड चैनल",
    "ta": "தொழில் சேனல்கள்",
  },
  "no_trade_channels": {
    "en": "No Skills Added",
    "hi": "कोई कौशल नहीं जोड़ा गया",
    "ta": "திறன்கள் சேர்க்கப்படவில்லை",
  },
  "coverage_radius": {
    "en": "Radar Coverage",
    "hi": "रडार कवरेज",
    "ta": "ரேடார் கவரேஜ்",
  },
  "all_registered_channels": {
    "en": "All Registered",
    "hi": "सभी पंजीकृत",
    "ta": "பதிவுசெய்த அனைத்தும்",
  },
  "no_skills_registered_hint": {
    "en": "No trade skills configured. Add trade skills in Profile to receive job broadcasts.",
    "hi": "कोई ट्रेड कौशल कॉन्फ़िगर नहीं किया गया है। कार्य प्रसारण प्राप्त करने के लिए प्रोफ़ाइल में ट्रेड कौशल जोड़ें।",
    "ta": "தொழில் திறன்கள் எதுவும் அமைக்கப்படவில்லை. பணி அறிவிப்புகளைப் பெற சுயவிவரத்தில் தொழில் திறன்களைச் சேர்க்கவும்.",
  },
  "radar_tuning_title": {
    "en": "Complete Setup & Listen",
    "hi": "सेटअप पूरा करें और सुनें",
    "ta": "அமைப்பை நிறைவு செய்து கேளுங்கள்",
  },
  "search_radius": {
    "en": "Search Radius",
    "hi": "खोज दायरा",
    "ta": "தேடல் ஆரம்",
  },
  "audio_broadcast_alerts": {
    "en": "Audio Broadcast Chime",
    "hi": "ऑडियो प्रसारण चेतावनी",
    "ta": "ஆடியோ ஒலி அறிவிப்பு",
  },
  "high_demand_hotspots": {
    "en": "High-Demand Hotspots",
    "hi": "अधिक मांग वाले क्षेत्र",
    "ta": "அதிக தேவை உள்ள பகுதிகள்",
  },
  "radar_chime_enabled": {
    "en": "Audio Broadcast Chime Enabled",
    "hi": "ऑडियो प्रसारण सक्षम",
    "ta": "ஆடியோ ஒலி இயக்கப்பட்டது",
  },
  "radar_chime_muted": {
    "en": "Radar Audio Muted",
    "hi": "रडार ऑडियो म्यूट",
    "ta": "ரேடார் ஆடியோ முடக்கப்பட்டது",
  },
  "refer_job_title": {
    "en": "Refer Job to Peer Artisan",
    "hi": "साथी कारीगर को काम रेफर करें",
    "ta": "சக தொழிலாளிக்கு வேலையை பரிந்துரைக்கவும்",
  },
  "refer_job_hint": {
    "en": "Transfer this dispatch to a verified co-op peer in your network.",
    "hi": "इस कार्य को अपने नेटवर्क के सत्यापित साथी कारीगर को ट्रांसफर करें।",
    "ta": "இந்த வேலையை உங்கள் நெட்வொர்க்கில் உள்ள சரிபார்க்கப்பட்ட தொழிலாளிக்கு மாற்றவும்.",
  },
  "peer_contact_label": {
    "en": "Peer Name or Phone",
    "hi": "साथी का नाम या फोन",
    "ta": "தொழிலாளியின் பெயர் அல்லது தொலைபேசி",
  },
  "cancel": {
    "en": "Cancel",
    "hi": "रद्द करें",
    "ta": "ரத்துசெய்",
  },
  "job_referred_success": {
    "en": "Job referred to peer successfully.",
    "hi": "कार्य सफलतापूर्वक साथी को रेफर किया गया।",
    "ta": "வேலை வெற்றிகரமாக பரிந்துரைக்கப்பட்டது.",
  },
  "transfer_job": {
    "en": "Transfer Job",
    "hi": "कार्य ट्रांसफर करें",
    "ta": "வேலையை மாற்றவும்",
  },
  "customer_premises": {
    "en": "Customer Premises · In Zone",
    "hi": "ग्राहक परिसर · क्षेत्र में",
    "ta": "வாடிக்கையாளர் இருப்பிடம் · பகுதியில்",
  },
  "emergency_badge": {
    "en": "EMERGENCY",
    "hi": "आपातकालीन",
    "ta": "அவசரம்",
  },
  "refer": {
    "en": "Refer",
    "hi": "रेफर करें",
    "ta": "பரிந்துரை",
  },
  "accept_dispatch": {
    "en": "Accept Dispatch",
    "hi": "डिस्पैच स्वीकारें",
    "ta": "அனுப்புதலை ஏற்கவும்",
  },
  "radar_coverage_updated": {
    "en": "Radar coverage set to {} km",
    "hi": "रडार कवरेज {} किमी पर सेट किया गया",
    "ta": "ரேடார் கவரேஜ் {} கி.மீ ஆக அமைக்கப்பட்டது",
  },

  // ── Today's Earnings Neo-Bento Cards ──
  "build_daily_payout": {
    "en": "Build Your Daily Payout",
    "hi": "अपना दैनिक भुगतान बनाएं",
    "ta": "உங்கள் தினசரி வருமானத்தை உருவாக்குங்கள்",
  },
  "personal_net_payout": {
    "en": "Personal Net Payout",
    "hi": "व्यक्तिगत शुद्ध भुगतान",
    "ta": "தனிநபர் நிகர வருமானம்",
  },
  "settlement_target_label": {
    "en": "Settlement Target",
    "hi": "निपटान लक्ष्य",
    "ta": "பரிமாற்ற இலக்கு",
  },
  "instant_upi_settlement_pill": {
    "en": "Instant UPI 18:00 Settlement",
    "hi": "तत्काल यूपीआई 18:00 निपटान",
    "ta": "உடனடி UPI 18:00 தீர்வு",
  },
  "coop_welfare_reserve": {
    "en": "Co-op Welfare Reserve",
    "hi": "सहकारी कल्याण कोष",
    "ta": "கூட்டுறவு நல நிதி",
  },
  "coop_safety_net_label": {
    "en": "Cooperative Safety Net",
    "hi": "सहकारी सुरक्षा कवच",
    "ta": "கூட்டுறவு பாதுகாப்பு திட்டம்",
  },
  "view_medical_cover_pill": {
    "en": "View Medical & Tool Cover",
    "hi": "चिकित्सा एवं उपकरण सुरक्षा देखें",
    "ta": "மருத்துவ மற்றும் உபகரண காப்பீடு காண்க",
  },
  "period_today": {
    "en": "Today",
    "hi": "आज",
    "ta": "இன்று",
  },
  "period_this_week": {
    "en": "This Week",
    "hi": "इस सप्ताह",
    "ta": "இந்த வாரம்",
  },
  "period_this_month": {
    "en": "This Month",
    "hi": "इस माह",
    "ta": "இந்த மாதம்",
  },
  "period_all_time": {
    "en": "All Time",
    "hi": "कुल समय",
    "ta": "எல்லா நேரமும்",
  },
  "recorded_job_ledger": {
    "en": "Recorded Job Ledger",
    "hi": "दर्ज कार्य लेज़र",
    "ta": "பதிவுசெய்யப்பட்ட பணி லெட்ஜர்",
  },
  "jobs_recorded_count": {
    "en": "{} RECORDED",
    "hi": "{} दर्ज",
    "ta": "{} பதிவுசெய்யப்பட்டது",
  },
  "medical_cover_title": {
    "en": "Co-op Artisan Safety Net",
    "hi": "सहकारी कारीगर सुरक्षा कवच",
    "ta": "கூட்டுறவு தொழிலாளர் பாதுகாப்பு",
  },
  "medical_cover_desc": {
    "en": "2% of each completed booking directly funds your health coverage, OPD reimbursements, and tool repair insurance.",
    "hi": "प्रत्येक पूर्ण कार्य का 2% सीधे आपके स्वास्थ्य कवर, ओपीडी प्रतिपूर्ति और उपकरण मरम्मत बीमा में जाता है।",
    "ta": "ஒவ்வொரு நிறைவுற்ற பணியின் 2% நேரடியாக உங்கள் மருத்துவ காப்பீடு, OPD மற்றும் உபகரண பழுதுபார்ப்பு காப்பீட்டிற்குச் செல்கிறது.",
  },
  "instant_payout_notice": {
    "en": "Earnings are settled directly to your verified UPI account daily at 18:00.",
    "hi": "कमाई प्रतिदिन 18:00 बजे सीधे आपके सत्यापित यूपीआई खाते में जमा की जाती है।",
    "ta": "வருமானம் தினமும் 18:00 மணிக்கு நேரடியாக உங்கள் சரிபார்க்கப்பட்ட UPI கணக்கில் செலுத்தப்படும்.",
  },

  // ── Earnings UX Simplification & Job Ledger ──
  "earnings_title": {
    "en": "Earnings",
    "hi": "कमाई",
    "ta": "வருமானம்",
  },
  "jobs_done_stat": {
    "en": "Done",
    "hi": "पूर्ण",
    "ta": "முடிந்தது",
  },
  "avg_per_job_stat": {
    "en": "Avg/Job",
    "hi": "औसत/कार्य",
    "ta": "சராசரி/வேலை",
  },
  "settlement_time_stat": {
    "en": "UPI Out",
    "hi": "UPI निकासी",
    "ta": "UPI வெளியே",
  },
  "paid_count_label": {
    "en": "Paid",
    "hi": "भुगतान",
    "ta": "செலுத்தப்பட்டது",
  },
  "other_count_label": {
    "en": "Other",
    "hi": "अन्य",
    "ta": "மற்றவை",
  },
  "job_ledger_title": {
    "en": "Job Ledger",
    "hi": "कार्य लेज़र",
    "ta": "பணி லெட்ஜர்",
  },
  "not_settled_label": {
    "en": "Not Settled",
    "hi": "अनिर्धारित",
    "ta": "தீர்க்கப்படவில்லை",
  },
  "empty_ledger_title": {
    "en": "No Jobs Yet",
    "hi": "कोई कार्य नहीं मिला",
    "ta": "வேலைகள் இல்லை",
  },
  "empty_ledger_desc": {
    "en": "Accept live requests from the Radar to generate payouts.",
    "hi": "भुगतान प्राप्त करने के लिए Radar से लाइव अनुरोध स्वीकार करें।",
    "ta": "வருமானம் பெற Radar-இல் இருந்து நேரலை கோரிக்கைகளை ஏற்கவும்.",
  },
  "ledger_label_paid": {
    "en": "PAID — TAP FOR RECEIPT",
    "hi": "भुगतान हुआ — रसीद देखें",
    "ta": "செலுத்தப்பட்டது — ரசீது காண்க",
  },
  "ledger_label_cancelled": {
    "en": "CANCELLED — NO PAYOUT",
    "hi": "रद्द — कोई भुगतान नहीं",
    "ta": "ரத்து — தொகை இல்லை",
  },
  "ledger_label_unpaid": {
    "en": "AWAITING PAYMENT",
    "hi": "भुगतान प्रतीक्षित",
    "ta": "பணம் நிலுவையில்",
  },
  "ledger_label_inprogress": {
    "en": "IN PROGRESS",
    "hi": "प्रगति पर",
    "ta": "நடைபெறுகிறது",
  },
  "ledger_label_enroute": {
    "en": "WORKER ENROUTE",
    "hi": "कारीगर रास्ते में",
    "ta": "பணியாளர் வழியில்",
  },
  "ledger_pill_receipt": {
    "en": "Export Receipt",
    "hi": "रसीद निर्यात करें",
    "ta": "ரசீது ஏற்றுமதி",
  },
  "ledger_pill_cancelled": {
    "en": "Job Cancelled",
    "hi": "कार्य रद्द",
    "ta": "வேலை ரத்து",
  },
  "ledger_pill_payment": {
    "en": "Payment Pending",
    "hi": "भुगतान बाकी",
    "ta": "பணம் நிலுவை",
  },
  "ledger_pill_active": {
    "en": "Job In Progress",
    "hi": "कार्य जारी",
    "ta": "வேலை நடக்கிறது",
  },
  "cancelled_job_notice": {
    "en": "This job was cancelled. No payout is generated.",
    "hi": "यह कार्य रद्द कर दिया गया था। कोई भुगतान नहीं बनेगा।",
    "ta": "இந்த வேலை ரத்து செய்யப்பட்டது. தொகை இல்லை.",
  },
  "active_job_notice": {
    "en": "Job in progress. Payout recorded after completion.",
    "hi": "कार्य प्रगति पर है। पूरा होने पर भुगतान दर्ज किया जाएगा।",
    "ta": "வேலை நடைபெறுகிறது. முடிந்த பிறகு தொகை பதிவாகும்.",
  },

  // ── Dispatch Concurrency & Active Service Protection ──
  "job_already_taken": {
    "en": "Another artisan has already accepted this dispatch. Keep your radar active!",
    "hi": "यह कार्य किसी अन्य कारीगर द्वारा स्वीकार कर लिया गया है। रडार सक्रिय रखें!",
    "ta": "இந்த வேலையை மற்றொரு தொழிலாளி ஏற்றுக்கொண்டுள்ளார். ரேடாரை இயக்கத்தில் வைக்கவும்!",
  },
  "active_job_busy_title": {
    "en": "Active Job in Progress",
    "hi": "सक्रिय कार्य प्रगति पर है",
    "ta": "தற்போதைய வேலை செயலில் உள்ளது",
  },
  "active_job_busy_desc": {
    "en": "You have an ongoing service in progress. Complete your current job before accepting new dispatches.",
    "hi": "आपका एक कार्य प्रगति पर है। नया कार्य स्वीकार करने से पहले वर्तमान कार्य पूरा करें।",
    "ta": "தங்களுக்கு ஏற்கனவே ஒரு வேலை செயலில் உள்ளது. புதிய வேலைகளை ஏற்கும் முன் தற்போதைய வேலையை முடிக்கவும்.",
  },
  "resume_ongoing_job": {
    "en": "Resume Active Job",
    "hi": "सक्रिय कार्य जारी रखें",
    "ta": "தற்போதைய வேலையைத் தொடரவும்",
  },
  "finish_active_job_first": {
    "en": "Finish Active Job First",
    "hi": "पहले सक्रिय कार्य पूरा करें",
    "ta": "முதலில் நடப்பு வேலையை முடிக்கவும்",
  },
  "ongoing_job_badge": {
    "en": "ONGOING JOB",
    "hi": "सक्रिय कार्य",
    "ta": "நடப்பு வேலை",
  },
  "ongoing_job_hint": {
    "en": "Finish current service to accept new dispatches",
    "hi": "नया कार्य लेने के लिए वर्तमान सेवा पूरी करें",
    "ta": "புதிய வேலைகளை ஏற்க தற்போதைய சேவையை முடிக்கவும்",
  },
};

/// Resilient string translation fallback extension.
extension SafeTranslationExtension on String {
  /// Translates key or returns fallback if key is missing or unresolved.
  String trSafe([String? fallback, List<String>? args]) {
    try {
      // In-memory zero-warning fallback resolver
      if (_embeddedTranslations.containsKey(this)) {
        final entry = _embeddedTranslations[this]!;
        String locale = 'en';
        try {
          final cur = Intl.getCurrentLocale();
          if (cur.isNotEmpty) {
            locale = cur.split('_').first.toLowerCase();
          }
        } catch (_) {}
        var val = entry[locale] ?? entry['en'] ?? fallback ?? this;
        if (args != null && args.isNotEmpty) {
          for (final a in args) {
            val = val.replaceFirst('{}', a);
          }
        }
        return val;
      }

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
  'te': {
    'home': 'ఇల్లు',
    'office': 'కార్యాలయం',
    'work': 'పనిస్థలం',
    'near': 'దగ్గర',
    'near to': 'దగ్గర',
    'nearby': 'సమీపంలో',
    'opposite': 'ఎదురుగా',
    'opp': 'ఎదురుగా',
    'behind': 'వెనుక',
    'road': 'రోడ్డు',
    'rd': 'రోడ్డు',
    'street': 'వీధి',
    'st': 'వీధి',
    'main road': 'ప్రధాన రహదారి',
    'cross': 'క్రాస్',
    'nagar': 'నగర్',
    'colony': 'కాలనీ',
    'apartment': 'అపార్ట్‌మెంట్',
    'apt': 'అపార్ట్‌మెంట్',
    'floor': 'అంతస్తు',
    'hyderabad': 'హైదరాబాద్',
    'bangalore': 'బెంగళూరు',
    'bengaluru': 'బెంగళూరు',
    'chennai': 'చెన్నై',
    'vijayawada': 'విజయవాడ',
    'visakhapatnam': 'విశాఖపట్నం',
    'east': 'తూర్పు',
    'west': 'పడమర',
    'north': 'ఉత్తరం',
    'south': 'దక్షిణం',
  },
  'kn': {
    'home': 'ಮನೆ',
    'office': 'ಕಚೇರಿ',
    'work': 'ಕೆಲಸದ ಸ್ಥಳ',
    'near': 'ಹತ್ತಿರ',
    'near to': 'ಹತ್ತಿರ',
    'nearby': 'ಹತ್ತಿರದಲ್ಲಿ',
    'opposite': 'ಎದುರು',
    'opp': 'ಎದುರು',
    'behind': 'ಹಿಂಭಾಗ',
    'road': 'ರಸ್ತೆ',
    'rd': 'ರಸ್ತೆ',
    'street': 'ಬೀದಿ',
    'st': 'ಬೀದಿ',
    'main road': 'ಮುಖ್ಯ ರಸ್ತೆ',
    'cross': 'ಕ್ರಾಸ್',
    'nagar': 'ನಗರ',
    'colony': 'ಕಾಲೋನಿ',
    'floor': 'ಮಹಡಿ',
    'bangalore': 'ಬೆಂಗಳೂರು',
    'bengaluru': 'ಬೆಂಗಳೂರು',
    'mysore': 'ಮೈಸೂರು',
    'hubli': 'ಹುಬ್ಬಳ್ಳಿ',
    'mangalore': 'ಮಂಗಳೂರು',
    'east': 'ಪೂರ್ವ',
    'west': 'ಪಶ್ಚಿಮ',
    'north': 'ಉತ್ತರ',
    'south': 'ದಕ್ಷಿಣ',
  },
  'ml': {
    'home': 'വീട്',
    'office': 'ഓഫീസ്',
    'work': 'ജോലിസ്ഥലം',
    'near': 'അടുത്ത്',
    'near to': 'അടുത്ത്',
    'nearby': 'സമീപം',
    'opposite': 'എതിർവശം',
    'opp': 'എതിർവശം',
    'behind': 'പിന്നിൽ',
    'road': 'റോഡ്',
    'rd': 'റോഡ്',
    'street': 'തെരുവ്',
    'st': 'തെരുവ്',
    'main road': 'പ്രധാന റോഡ്',
    'cross': 'ക്രോസ്',
    'nagar': 'നഗർ',
    'colony': 'കോളനി',
    'floor': 'നില',
    'kochi': 'കൊച്ചി',
    'trivandrum': 'തിരുവനന്തപുരം',
    'kozhikode': 'കോഴിക്കോട്',
    'kerala': 'കേരളം',
    'east': 'കിഴക്ക്',
    'west': 'പടിഞ്ഞാറ്',
    'north': 'വടക്ക്',
    'south': 'തെക്ക്',
  },
  'mr': {
    'home': 'घर',
    'office': 'कार्यालय',
    'work': 'कार्यस्थळ',
    'near': 'जवळ',
    'near to': 'जवळ',
    'nearby': 'आसपास',
    'opposite': 'समोर',
    'opp': 'समोर',
    'behind': 'मागे',
    'road': 'रस्ता',
    'rd': 'रस्ता',
    'street': 'गल्ली',
    'st': 'गल्ली',
    'main road': 'मुख्य रस्ता',
    'cross': 'क्रॉस',
    'nagar': 'नगर',
    'colony': 'कॉलनी',
    'floor': 'मजला',
    'mumbai': 'मुंबई',
    'pune': 'पुणे',
    'nagpur': 'नागपूर',
    'nashik': 'नाशिक',
    'maharashtra': 'महाराष्ट्र',
    'east': 'पूर्व',
    'west': 'पश्चिम',
    'north': 'उत्तर',
    'south': 'दक्षिण',
  },
  'bn': {
    'home': 'বাড়ি',
    'office': 'অফিস',
    'work': 'কর্মস্থল',
    'near': 'কাছে',
    'near to': 'কাছে',
    'nearby': 'কাছাকাছি',
    'opposite': 'বিপরীতে',
    'opp': 'বিপরীতে',
    'behind': 'পেছনে',
    'road': 'রাস্তা',
    'rd': 'রাস্তা',
    'street': 'গলি',
    'st': 'গলি',
    'main road': 'প্রধান রাস্তা',
    'cross': 'ক্রস',
    'nagar': 'নগর',
    'colony': 'কলোনি',
    'floor': 'তলা',
    'kolkata': 'কলকাতা',
    'howrah': 'হাওড়া',
    'east': 'পূর্ব',
    'west': 'পশ্চিম',
    'north': 'উত্তর',
    'south': 'দক্ষিণ',
  },
  'gu': {
    'home': 'ઘર',
    'office': 'ઓફિસ',
    'work': 'કામનું સ્થળ',
    'near': 'નજીક',
    'near to': 'નજીક',
    'nearby': 'આસપાસ',
    'opposite': 'સામે',
    'opp': 'સામે',
    'behind': 'પાછળ',
    'road': 'રોડ',
    'rd': 'રોડ',
    'street': 'શેરી',
    'st': 'શેરી',
    'main road': 'મુખ્ય રોડ',
    'cross': 'ક્રોસ',
    'nagar': 'નગર',
    'colony': 'કોલોની',
    'floor': 'માળ',
    'ahmedabad': 'અમદાવાદ',
    'surat': 'સુરત',
    'vadodara': 'વડોદરા',
    'rajkot': 'રાજકોટ',
    'gujarat': 'ગુજરાત',
    'east': 'પૂર્વ',
    'west': 'પશ્ચિમ',
    'north': 'ઉત્તર',
    'south': 'દક્ષિણ',
  },
};

