/**
 * WorkGo Comprehensive Push Notification Engine
 * Handles multi-lingual FCM messaging, topic dispatch, Android notification channels,
 * sound alarms, and action intents across Customer, Worker, and Admin roles.
 */

const admin = require("firebase-admin");

// ── Multi-Lingual Notification Dictionary ─────────────────────────────────────
const NOTIFICATION_TEMPLATES = {
  // ── Customer Events ─────────────────────────────────────────────────────────
  BOOKING_BROADCAST_STARTED: {
    channelId: "workgo_booking_channel",
    sound: "default",
    en: {
      title: "Broadcasting Request",
      body: "Scanning nearby {category} artisans in your area...",
    },
    hi: {
      title: "अनुरोध प्रसारित हो रहा है",
      body: "आपके क्षेत्र में {category} कारीगरों की खोज की जा रही है...",
    },
    ta: {
      title: "கோரிக்கை ஒளிபரப்பப்படுகிறது",
      body: "உங்கள் பகுதியில் உள்ள {category} பணியாளர்களைத் தேடுகிறது...",
    },
  },

  BOOKING_ACCEPTED: {
    channelId: "workgo_booking_channel",
    sound: "alert_chime.mp3",
    priority: "high",
    en: {
      title: "{workerName} Confirmed",
      body: "Your {category} artisan is en-route! Your Start OTP is: {startOtp}",
    },
    hi: {
      title: "कारीगर {workerName} ने पुष्टि की",
      body: "आपके {category} कारीगर रास्ते में हैं! आपका स्टार्ट OTP है: {startOtp}",
    },
    ta: {
      title: "பணியாளர் {workerName} உறுதிசெய்தார்",
      body: "உங்கள் {category} பணியாளர் கிளம்பிவிட்டார்! உங்கள் தொடக்க OTP: {startOtp}",
    },
  },

  WORKER_ARRIVED_DOORSTEP: {
    channelId: "workgo_booking_channel",
    sound: "doorbell.mp3",
    priority: "high",
    en: {
      title: "Artisan Arrived at Doorstep",
      body: "Share your 4-digit OTP {startOtp} with {workerName} to begin work.",
    },
    hi: {
      title: "कारीगर आपके दरवाजे पर पहुंचे",
      body: "काम शुरू करने के लिए अपना 4-अंकीय OTP {startOtp} {workerName} को बताएं।",
    },
    ta: {
      title: "பணியாளர் வந்து சேர்ந்தார்",
      body: "வேலையைத் தொடங்க உங்கள் 4-இலக்க OTP {startOtp}-ஐ {workerName}-இடம் பகிரவும்.",
    },
  },

  JOB_STARTED_OTP_VERIFIED: {
    channelId: "workgo_booking_channel",
    sound: "default",
    en: {
      title: "Service In Progress",
      body: "Artisan {workerName} verified the OTP and has started your {category} job.",
    },
    hi: {
      title: "सेवा प्रगति पर है",
      body: "कारीगर {workerName} ने OTP सत्यापित किया और {category} कार्य शुरू किया।",
    },
    ta: {
      title: "சேவை தொடங்கப்பட்டது",
      body: "பணியாளர் {workerName} OTP சரிபார்த்து {category} பணியைத் தொடங்கினார்.",
    },
  },

  WORK_COMPLETED_C2PA_READY: {
    channelId: "workgo_booking_channel",
    sound: "success.mp3",
    priority: "high",
    en: {
      title: "Work Completed & C2PA Verified",
      body: "Artisan completed work. Tap to inspect verified cryptographic proof & pay ₹{amount}.",
    },
    hi: {
      title: "कार्य पूर्ण और C2PA सत्यापित",
      body: "कारीगर ने काम पूरा किया। फोटो प्रमाण जांचें और ₹{amount} का भुगतान करें।",
    },
    ta: {
      title: "வேலை முடிந்தது & C2PA சரிபார்க்கப்பட்டது",
      body: "வேலை முடிந்தது. சான்றளிக்கப்பட்ட புகைப்படத்தைப் பார்த்து ₹{amount} செலுத்தவும்.",
    },
  },

  BOOKING_CANCELLED_BY_CUSTOMER: {
    channelId: "workgo_booking_channel",
    sound: "default",
    priority: "high",
    en: {
      title: "Booking Cancelled by Customer",
      body: "Customer cancelled Booking #{bookingId}. Reason: {reason}",
    },
    hi: {
      title: "ग्राहक द्वारा बुकिंग रद्द",
      body: "ग्राहक ने बुकिंग #{bookingId} रद्द कर दी। कारण: {reason}",
    },
    ta: {
      title: "வாடிக்கையாளரால் முன்பதிவு ரத்து செய்யப்பட்டது",
      body: "வாடிக்கையாளர் முன்பதிவு #{bookingId}-ஐ ரத்து செய்தார். காரணம்: {reason}",
    },
    te: {
      title: "కస్టమర్ ద్వారా బుకింగ్ రద్దు చేయబడింది",
      body: "కస్టమర్ బుకింగ్ #{bookingId} రద్దు చేశారు. కారణం: {reason}",
    },
    mr: {
      title: "ग्राहकाद्वारे बुकिंग रद्द",
      body: "ग्राहकाने बुकिंग #{bookingId} रद्द केले. कारण: {reason}",
    },
    kn: {
      title: "ಗ್ರಾಹಕರಿಂದ ಬುಕಿಂಗ್ ರದ್ದಾಗಿದೆ",
      body: "ಗ್ರಾಹಕರು ಬುಕಿಂಗ್ #{bookingId} ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ. ಕಾರಣ: {reason}",
    },
    ml: {
      title: "ഉപഭോക്താവ് ബുക്കിംഗ് റദ്ദാക്കി",
      body: "ഉപഭോക്താവ് ബുക്കിംഗ് #{bookingId} റദ്ദാക്കി. കാരണം: {reason}",
    },
    bn: {
      title: "গ্রাহক দ্বারা বুকিং বাতিল",
      body: "গ্রাহক বুকিং #{bookingId} বাতিল করেছেন। কারণ: {reason}",
    },
    gu: {
      title: "ગ્રાહક દ્વારા બુકિંગ રદ",
      body: "ગ્રાહકે બુકિંગ #{bookingId} રદ કર્યું છે. કારણ: {reason}",
    },
    pa: {
      title: "ਗਾਹਕ ਵੱਲੋਂ ਬੁਕਿੰਗ ਰੱਦ",
      body: "ਗਾਹਕ ਨੇ ਬੁਕਿੰਗ #{bookingId} ਰੱਦ ਕਰ ਦਿੱਤੀ। ਕਾਰਨ: {reason}",
    },
  },

  // ── Dial Karya: Peer KYC Bounty Templates ───────────────────────────────────
  PEER_KYC_BOUNTY_ALERT: {
    channelId: "workgo_kyc_channel",
    sound: "alert_chime.mp3",
    priority: "high",
    en: {
      title: "⚡ Verify Dial Worker Nearby — Earn ₹{amount}!",
      body: "{workerName} ({trade}) needs verification near you. Complete 5-min KYC & earn ₹{amount} instantly.",
    },
    hi: {
      title: "⚡ नजदीक डायल वर्कर — ₹{amount} कमाएं!",
      body: "{workerName} ({trade}) आपके पास verification के लिए तैयार हैं। 5 मिनट में KYC करें और ₹{amount} पाएं।",
    },
    ta: {
      title: "⚡ அருகில் டயல் வொர்க்கர் — ₹{amount} சம்பாதிக்கவும்!",
      body: "{workerName} ({trade}) அருகில் சரிபார்ப்புக்கு தயாராக உள்ளார். 5 நிமிடத்தில் KYC செய்து ₹{amount} பெறுங்கள்.",
    },
  },

  PEER_KYC_BOUNTY_CREDITED: {
    channelId: "workgo_kyc_channel",
    sound: "cash_register.mp3",
    priority: "high",
    en: {
      title: "₹{amount} Credited to Your Wallet! 🎉",
      body: "You successfully verified {workerName} as a Dial Karya member. Great work, Karya Mitra!",
    },
    hi: {
      title: "₹{amount} आपके wallet में जमा! 🎉",
      body: "{workerName} का verification पूरा हुआ। शाबाश, करिया मित्र!",
    },
    ta: {
      title: "₹{amount} உங்கள் wallet-ல் சேர்ந்தது! 🎉",
      body: "{workerName}-ஐ வெற்றிகரமாக சரிபார்த்தீர்கள். நன்று, கார்யா மித்ரா!",
    },
  },


  BOOKING_CANCELLED_BY_WORKER: {
    channelId: "workgo_booking_channel",
    sound: "default",
    priority: "high",
    en: {
      title: "Booking Cancelled by Artisan",
      body: "Artisan had to cancel Booking #{bookingId}. Searching for replacement artisans...",
    },
    hi: {
      title: "कारीगर द्वारा बुकिंग रद्द",
      body: "कारीगर ने बुकिंग #{bookingId} रद्द की। अन्य कारीगरों की खोज की जा रही है...",
    },
    ta: {
      title: "பணியாளரால் முன்பதிவு ரத்து செய்யப்பட்டது",
      body: "பணியாளர் முன்பதிவு #{bookingId}-ஐ ரத்து செய்தார். மாற்று பணியாளர் தேடப்படுகிறது...",
    },
    te: {
      title: "కళాకారుడు ద్వారా బుకింగ్ రద్దు చేయబడింది",
      body: "కళాకారుడు బుకింగ్ #{bookingId} రద్దు చేశారు. ప్రత్యామ్నాయ కళాకారుల కోసం వెతుకుతోంది...",
    },
    mr: {
      title: "कारागिराद्वारे बुकिंग रद्द",
      body: "कारागिराने बुकिंग #{bookingId} रद्द केले. पर्यायी कारागिरांचा शोध घेतला जात आहे...",
    },
    kn: {
      title: "ಕುಶಲಕರ್ಮಿಯಿಂದ ಬುಕಿಂಗ್ ರದ್ದಾಗಿದೆ",
      body: "ಕುಶಲಕರ್ಮಿ ಬುಕಿಂಗ್ #{bookingId} ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ. ಪರ್ಯಾಯ ಕುಶಲಕರ್ಮಿಗಳ ಹುಡುಕಾಟ...",
    },
    ml: {
      title: "തൊഴിലാളി ബുക്കിംഗ് റദ്ദാക്കി",
      body: "തൊഴിലാളി ബുക്കിംഗ് #{bookingId} റദ്ദാക്കി. പകരം തൊഴിലാളിയെ തിരയുന്നു...",
    },
    bn: {
      title: "কারিগর দ্বারা বুকিং বাতিল",
      body: "কারিগর বুকিং #{bookingId} বাতিল করেছেন। বিকল্প কারিগর খোঁজা হচ্ছে...",
    },
    gu: {
      title: "કારીગર દ્વારા બુકિંગ રદ",
      body: "કારીગરે બુકિંગ #{bookingId} રદ કર્યું છે. વૈકલ્પિક કારીગરોની શોધ ચાલુ છે...",
    },
    pa: {
      title: "ਕਾਰੀਗਰ ਵੱਲੋਂ ਬੁਕਿੰਗ ਰੱਦ",
      body: "ਕਾਰੀਗਰ ਨੇ ਬੁਕਿੰਗ #{bookingId} ਰੱਦ ਕਰ ਦਿੱਤੀ। ਬਦਲਵੇਂ ਕਾਰੀਗਰਾਂ ਦੀ ਖੋਜ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ...",
    },
  },

  PAYMENT_CONFIRMED_DIVIDEND: {
    channelId: "workgo_booking_channel",
    sound: "cash_register.mp3",
    en: {
      title: "Payment Confirmed (₹{amount})",
      body: "₹{dividend} welfare dividend deposited to artisan cooperative fund. Thank you!",
    },
    hi: {
      title: "भुगतान सफल (₹{amount})",
      body: "₹{dividend} कल्याण लाभांश सहकारी कोष में जमा हुआ। धन्यवाद!",
    },
    ta: {
      title: "கட்டணம் வெற்றிகரமானது (₹{amount})",
      body: "₹{dividend} நல நிதி கூட்டுறவு கணக்கில் வரவு வைக்கப்பட்டது. நன்றி!",
    },
  },

  SAFETY_FREEZE_ACKNOWLEDGED: {
    channelId: "workgo_emergency_channel",
    sound: "default",
    en: {
      title: "Safety Dispute Logged",
      body: "The artisan has been temporarily suspended pending governance board investigation.",
    },
    hi: {
      title: "सुरक्षा शिकायत दर्ज की गई",
      body: "सहकारी समिति जांच लंबित रहने तक कारीगर को अस्थायी रूप से निलंबित कर दिया गया है।",
    },
    ta: {
      title: "பாதுகாப்பு புகார் பதிவு செய்யப்பட்டது",
      body: "கூட்டுறவு குழு விசாரணை முடியும் வரை பணியாளர் தற்காலிகமாக இடைநீக்கம் செய்யப்பட்டுள்ளார்.",
    },
  },

  // ── Worker / Artisan Events ────────────────────────────────────────────────
  NEW_BROADCAST_REQUEST: {
    channelId: "workgo_broadcast_channel",
    sound: "rapido_horn.mp3",
    priority: "high",
    en: {
      title: "New {category} Request Nearby",
      body: "₹{amount} (Earn ₹{netEarnings}) · {distanceKm} km away at {address}. Tap to accept!",
    },
    hi: {
      title: "नया {category} कार्य पास में उपलब्ध",
      body: "₹{amount} (कमाई ₹{netEarnings}) · {distanceKm} किमी दूर {address} पर। स्वीकार करने के लिए टैप करें!",
    },
    ta: {
      title: "புதிய {category} வேலை அருகில் உள்ளது",
      body: "₹{amount} (வருமானம் ₹{netEarnings}) · {distanceKm} கிமீ தொலைவில் {address}-இல். ஏற்க தட்டவும்!",
    },
  },

  EMERGENCY_SOS_REQUEST: {
    channelId: "workgo_emergency_channel",
    sound: "emergency_alarm.mp3",
    priority: "high",
    en: {
      title: "EMERGENCY {category} SOS (+₹150 Bonus)",
      body: "Immediate repair needed at {address}! Earn ₹{amount}. Rapid dispatch required.",
    },
    hi: {
      title: "आपातकालीन {category} SOS (+₹150 बोनस)",
      body: "{address} पर तत्काल मरम्मत की आवश्यकता! ₹{amount} कमाएं। तुरंत जाएं।",
    },
    ta: {
      title: "அவசர {category} SOS (+₹150 போனஸ்)",
      body: "{address}-இல் உடனடி பழுது தேவை! ₹{amount} சம்பாதிக்கவும். உடனே செல்லவும்.",
    },
  },

  CUSTOMER_BOOSTED_FARE: {
    channelId: "workgo_broadcast_channel",
    sound: "bonus_ping.mp3",
    priority: "high",
    en: {
      title: "Customer Boosted Fare (+₹{bonus})",
      body: "Total payout is now ₹{amount} for {category} job at {address}. Accept now!",
    },
    hi: {
      title: "ग्राहक ने किराया बढ़ाया (+₹{bonus})",
      body: "{address} पर {category} कार्य के लिए कुल राशि अब ₹{amount} है। अभी स्वीकार करें!",
    },
    ta: {
      title: "கட்டணத்தை வாடிக்கையாளர் உயர்த்தினார் (+₹{bonus})",
      body: "{address}-இல் {category} வேலைக்கு மொத்த தொகை ₹{amount}. உடனே ஏற்கவும்!",
    },
  },

  PEER_REFERRAL_RECEIVED: {
    channelId: "workgo_broadcast_channel",
    sound: "alert_chime.mp3",
    en: {
      title: "Peer Job Forwarded by {senderName}",
      body: "Artisan {senderName} referred a {category} job (₹{amount}) to you!",
    },
    hi: {
      title: "{senderName} द्वारा कार्य भेजा गया",
      body: "कारीगर {senderName} ने आपके लिए {category} कार्य (₹{amount}) भेजा है!",
    },
    ta: {
      title: "{senderName} அனுப்பிய வேலை",
      body: "பணியாளர் {senderName} உங்களுக்கு ஒரு {category} வேலையை (₹{amount}) அனுப்பியுள்ளார்!",
    },
  },

  KYC_STAGE_APPROVED: {
    channelId: "workgo_kyc_channel",
    sound: "default",
    en: {
      title: "Verification Step Approved: {stageTitle}",
      body: "Your {stageTitle} passed UIDAI/Co-op validation. Proceed to next step.",
    },
    hi: {
      title: "सत्यापन चरण स्वीकृत: {stageTitle}",
      body: "आपका {stageTitle} सफलतापूर्वक सत्यापित हुआ। अगले चरण पर जाएं।",
    },
    ta: {
      title: "சரிபார்ப்பு படி அங்கீகரிக்கப்பட்டது: {stageTitle}",
      body: "உங்கள் {stageTitle} வெற்றிகரமாக முடிந்தது. அடுத்த படிக்கு செல்லவும்.",
    },
  },

  VIDEO_KYC_SCHEDULED: {
    channelId: "workgo_kyc_channel",
    sound: "default",
    en: {
      title: "Live Video KYC Scheduled",
      body: "Slot confirmed for {slotTime}. Keep physical Aadhaar ready with challenge phrase.",
    },
    hi: {
      title: "लाइव वीडियो KYC निर्धारित",
      body: "{slotTime} के लिए समय तय हुआ। अपना आधार कार्ड साथ रखें।",
    },
    ta: {
      title: "நேரலை வீடியோ KYC திட்டமிடப்பட்டது",
      body: "{slotTime}-க்கு நேரம் உறுதி செய்யப்பட்டது. ஆதார் அட்டையை தயாராக வைக்கவும்.",
    },
  },

  PCC_APPROVED_PUBLIC_LISTING: {
    channelId: "workgo_kyc_channel",
    sound: "success.mp3",
    priority: "high",
    en: {
      title: "Congratulations! Certified Co-op Artisan",
      body: "Police Clearance verified. Your profile is now PUBLIC on customer radar!",
    },
    hi: {
      title: "बधाई! प्रमाणित सहकारी कारीगर",
      body: "पुलिस क्लीयरेंस सत्यापित। आपकी प्रोफाइल अब ग्राहकों के रडार पर लाइव है!",
    },
    ta: {
      title: "வாழ்த்துகள்! சான்றளிக்கப்பட்ட கூட்டுறவு பணியாளர்",
      body: "போலீஸ் சான்றிதழ் சரிபார்க்கப்பட்டது. உங்கள் சுயவிவரம் வாடிக்கையாளர் ரேடாரில் நேரலையில் உள்ளது!",
    },
  },

  ACCOUNT_SUSPENDED_DISPUTE: {
    channelId: "workgo_emergency_channel",
    sound: "emergency_alarm.mp3",
    priority: "high",
    en: {
      title: "Account Temporarily Suspended",
      body: "A safety complaint was logged regarding Booking #{bookingId}. Contact co-op admin.",
    },
    hi: {
      title: "खाता अस्थायी रूप से निलंबित",
      body: "बुकिंग #{bookingId} के संबंध में सुरक्षा शिकायत दर्ज की गई। व्यवस्थापक से संपर्क करें।",
    },
    ta: {
      title: "கணக்கு தற்காலிகமாக இடைநீக்கம் செய்யப்பட்டது",
      body: "முன்பதிவு #{bookingId} தொடர்பாக புகார் வந்துள்ளது. கூட்டுறவு நிர்வாகியைத் தொடர்பு கொள்ளவும்.",
    },
  },

  // ── Standby Demand Mobilization (SIH AI Forecasting) ──────────────────────
  HIGH_DEMAND_ALERT: {
    channelId: "workgo_broadcast_channel",
    sound: "bonus_ping.mp3",
    priority: "high",
    en: {
      title: "High Demand Expected Today",
      body: "Elevated customer demand projected for {trade} in {region}. Check in early for priority dispatch!",
    },
    hi: {
      title: "आज उच्च मांग की उम्मीद",
      body: "आज {region} में {trade} के लिए उच्च मांग की उम्मीद है। प्राथमिकता बुकिंग प्राप्त करने के लिए जल्दी लॉग ऑन करें!",
    },
    ta: {
      title: "இன்று அதிக தேவை எதிர்பார்க்கப்படுகிறது",
      body: "இன்று {region}-இல் {trade} பணிகளுக்கு அதிக தேவை எதிர்பார்க்கப்படுகிறது. முன்னுரிமை பெற முன்கூட்டியே உள்நுழையவும்!",
    },
  },

  // ── Welfare & Insurance Claim Events (SIH 26089) ──────────────────────────
  WELFARE_CLAIM_APPROVED: {
    channelId: "workgo_kyc_channel",
    sound: "success.mp3",
    priority: "high",
    en: {
      title: "Welfare Claim Approved",
      body: "Your welfare claim #{claimId} has been approved by the cooperative committee.",
    },
    hi: {
      title: "कल्याण दावा स्वीकृत",
      body: "सहकारी समिति द्वारा आपका कल्याण दावा #{claimId} स्वीकृत कर लिया गया है।",
    },
    ta: {
      title: "நலத்திட்டக் கோரிக்கை அங்கீகரிக்கப்பட்டது",
      body: "உங்கள் நலத்திட்டக் கோரிக்கை #{claimId} கூட்டுறவுக் குழுவால் அங்கீகரிக்கப்பட்டது.",
    },
  },

  WELFARE_CLAIM_REJECTED: {
    channelId: "workgo_kyc_channel",
    sound: "default",
    priority: "high",
    en: {
      title: "Welfare Claim Update",
      body: "Your welfare claim #{claimId} was not approved. Reason: {reason}",
    },
    hi: {
      title: "कल्याण दावा अपडेट",
      body: "आपका कल्याण दावा #{claimId} स्वीकृत नहीं हुआ। कारण: {reason}",
    },
    ta: {
      title: "நலத்திட்டக் கோரிக்கை புதுப்பிப்பு",
      body: "உங்கள் நலத்திட்டக் கோரிக்கை #{claimId} நிராகரிக்கப்பட்டது. காரணம்: {reason}",
    },
  },
};

// Aliases for lowercase key support
NOTIFICATION_TEMPLATES.welfare_claim_approved = NOTIFICATION_TEMPLATES.WELFARE_CLAIM_APPROVED;
NOTIFICATION_TEMPLATES.welfare_claim_rejected = NOTIFICATION_TEMPLATES.WELFARE_CLAIM_REJECTED;
NOTIFICATION_TEMPLATES.high_demand_alert = NOTIFICATION_TEMPLATES.HIGH_DEMAND_ALERT;

// ── Notification Engine Implementation ────────────────────────────────────────

class NotificationEngine {
  constructor(db, messaging) {
    this.db = db || (admin.apps && admin.apps.length ? admin.firestore() : null);
    this.messaging = messaging || (admin.apps && admin.apps.length ? admin.messaging() : null);
  }

  /**
   * Helper: replace {paramName} with value in template strings
   */
  _formatTemplate(text, params) {
    if (!text) return "";
    return text.replace(/{(\w+)}/g, (match, key) => {
      return params[key] !== undefined ? params[key] : match;
    });
  }

  /**
   * Send notification to a specific user by UID (auto-detects preferred language & FCM tokens)
   */
  async sendToUser(userId, eventKey, params = {}, dataPayload = {}) {
    try {
      const userDoc = await this.db.collection("users").doc(userId).get();
      if (!userDoc.exists) return { success: false, reason: "User not found" };

      const userData = userDoc.data() || {};
      const fcmTokens = userData.fcmTokens || (userData.fcmToken ? [userData.fcmToken] : []);
      if (!fcmTokens || fcmTokens.length === 0) {
        return { success: false, reason: "No FCM tokens registered for user" };
      }

      let lang = userData.preferredLanguage || "en";
      const template = NOTIFICATION_TEMPLATES[eventKey];
      if (!template) {
        throw new Error(`Notification template for key '${eventKey}' not found.`);
      }

      // If exact language is not present in template, map sister languages cleanly
      if (!template[lang]) {
        const LANG_MAP = {
          ur: "hi", sd: "hi", mai: "hi", doi: "hi", bho: "hi", ks: "hi", sa: "hi", sat: "hi",
          as: "bn", or: "bn", brx: "bn", mni: "bn",
          kok: "mr",
        };
        if (LANG_MAP[lang] && template[LANG_MAP[lang]]) {
          lang = LANG_MAP[lang];
        }
      }

      const localized = template[lang] || template.en;
      const title = this._formatTemplate(localized.title, params);
      const body = this._formatTemplate(localized.body, params);

      const message = {
        tokens: fcmTokens,
        notification: { title, body },
        data: {
          eventKey,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...Object.fromEntries(
            Object.entries({ ...params, ...dataPayload }).map(([k, v]) => [k, String(v)])
          ),
        },
        android: {
          priority: template.priority === "high" ? "high" : "normal",
          notification: {
            channelId: template.channelId || "workgo_booking_channel",
            sound: template.sound || "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            icon: "ic_stat_workgo",
            color: "#E8A400",
            priority: template.priority === "high" ? "max" : "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: template.sound || "default",
              badge: 1,
            },
          },
        },
      };

      const response = await this.messaging.sendEachForMulticast(message);
      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (error) {
      console.error(`[NotificationEngine] Error sending to user ${userId}:`, error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Broadcast a message to an FCM Topic (e.g. topic_trades_plumbing)
   */
  async sendToTopic(topic, eventKey, params = {}, dataPayload = {}) {
    try {
      const template = NOTIFICATION_TEMPLATES[eventKey];
      if (!template) throw new Error(`Template '${eventKey}' not found.`);

      const title = this._formatTemplate(template.en.title, params);
      const body = this._formatTemplate(template.en.body, params);

      const message = {
        topic,
        notification: { title, body },
        data: {
          eventKey,
          ...Object.fromEntries(
            Object.entries({ ...params, ...dataPayload }).map(([k, v]) => [k, String(v)])
          ),
        },
        android: {
          priority: "high",
          notification: {
            channelId: template.channelId || "workgo_broadcast_channel",
            sound: template.sound || "default",
            icon: "ic_stat_workgo",
            color: "#E8A400",
          },
        },
      };

      const response = await this.messaging.send(message);
      return { success: true, messageId: response };
    } catch (error) {
      console.error(`[NotificationEngine] Error sending to topic ${topic}:`, error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Broadcast a new booking request to all online, verified workers in radius matching the trade.
   *
   * Dial workers (isDialWorker: true) receive an outbound Asterisk robocall with dynamic
   * Bhashini audio describing the job. Smartphone workers receive FCM push as before.
   */
  async broadcastNewBookingToNearbyWorkers(booking) {
    try {
      const { serviceType, amount, urgencyBonus, isEmergency, id, customerAddressText } = booking;
      const totalAmount = (amount || 0) + (urgencyBonus || 0);
      const netEarnings = (totalAmount * 0.90).toFixed(0); // 90% artisan payout

      const workersSnap = await this.db.collection("workers").get();
      const smartphoneWorkers = [];
      const dialWorkers = [];

      for (const doc of workersSnap.docs) {
        const w = doc.data();
        const skills = w.skills || [];
        const isOnline = w.availabilityStatus === "online" && (w.isCheckedIn === true || w.isCheckedIn === undefined);
        const isVerified = w.verificationStatus === "approved" || w.visibilityStatus === "public";
        const matchesTrade = serviceType === "All" || skills.includes(serviceType);

        if (isOnline && isVerified && matchesTrade) {
          if (w.isDialWorker === true) {
            dialWorkers.push({ id: doc.id, phone: w.phoneForCalling, language: w.dialLanguage || "hi" });
          } else {
            smartphoneWorkers.push({ id: doc.id, userId: w.userId || doc.id });
          }
        }
      }

      console.log(
        `[NotificationEngine] Broadcasting booking #${id} to ${smartphoneWorkers.length} app + ${dialWorkers.length} dial workers.`
      );

      const eventKey = isEmergency ? "EMERGENCY_SOS_REQUEST" : "NEW_BROADCAST_REQUEST";
      const params = {
        category: serviceType,
        amount: String(totalAmount),
        netEarnings: String(netEarnings),
        distanceKm: "1.8",
        address: customerAddressText || "",
        bonus: String(urgencyBonus || 0),
        bookingId: id,
      };

      // ── Smartphone workers: FCM push (existing behaviour) ──────────────────
      const smartphoneResults = await Promise.all(
        smartphoneWorkers.map((w) => this.sendToUser(w.userId, eventKey, params, { bookingId: id }))
      );

      // ── Dial workers: Asterisk outbound robocall ───────────────────────────
      const dialResults = await Promise.allSettled(
        dialWorkers.map(async (w) => {
          if (!w.phone) return { skipped: true, reason: "no phone" };
          try {
            // Generate dynamic Bhashini TTS audio for this specific booking
            const { generateBookingAlertAudio } = require("./bhashini_voice_service");
            const { triggerOutboundJobAlertCall } = require("./voice_call_engine");

            const audioFile = await generateBookingAlertAudio({
              bookingId: id,
              trade: serviceType,
              address: customerAddressText || "",
              payout: Math.round(totalAmount),
              language: w.language,
            });

            const callResult = await triggerOutboundJobAlertCall({
              workerPhone: w.phone,
              bookingId: id,
              trade: serviceType,
              address: customerAddressText || "",
              payout: Math.round(totalAmount),
              language: w.language,
              audioFile,
            });

            // Mark booking as currently alerting this dial worker
            await this.db.collection("bookings").doc(id).update({
              dialCallStatus: "alerting",
              dialWorkerPhone: w.phone,
            }).catch(() => {});

            return callResult;
          } catch (callErr) {
            console.error(`[NotificationEngine] Robocall to ${w.phone} failed:`, callErr.message);
            return { success: false, error: callErr.message };
          }
        })
      );

      return {
        totalRecipients: smartphoneWorkers.length + dialWorkers.length,
        smartphoneResults,
        dialResults: dialResults.map((r) => r.value || r.reason),
      };
    } catch (error) {
      console.error("[NotificationEngine] Broadcast error:", error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Notify a dial worker when a booking is cancelled by the customer.
   * Plays voice cancellation audio incorporating:
   *  - Service type / trade
   *  - Customer address
   *  - 5-minute transit window logic (grace vs late en route cancellation)
   *  - Reason for cancellation
   *  - Restores worker status in Firestore to Online
   *
   * @param {object} booking - Booking data from Firestore
   */
  async notifyDialWorkerBookingCancelled(booking) {
    try {
      const {
        id,
        serviceType,
        customerAddressText,
        cancellationReason,
        acceptedAt,
        cancelledAt,
        workerId,
        dialWorkerPhone,
        workerPhone,
      } = booking;

      // 1. Resolve dial worker details
      let workerData = null;
      let targetPhone = dialWorkerPhone || workerPhone;
      let workerDocRef = null;

      if (workerId && this.db) {
        const doc = await this.db.collection("workers").doc(workerId).get();
        if (doc.exists) {
          workerData = doc.data();
          workerDocRef = doc.ref;
          targetPhone = targetPhone || workerData.phoneForCalling;
        }
      }

      if (!workerData && targetPhone && this.db) {
        const snap = await this.db
          .collection("workers")
          .where("phoneForCalling", "==", targetPhone.startsWith("+") ? targetPhone : `+${targetPhone}`)
          .limit(1)
          .get();
        if (!snap.empty) {
          workerData = snap.docs[0].data();
          workerDocRef = snap.docs[0].ref;
        }
      }

      const lang = workerData?.dialLanguage || "hi";
      const phone = targetPhone || workerData?.phoneForCalling;

      // 2. Cancellation time calculation: elapsed minutes between acceptedAt and cancelledAt
      let elapsedMinutes = null;
      if (acceptedAt) {
        const start = new Date(acceptedAt);
        const end = cancelledAt ? new Date(cancelledAt) : new Date();
        elapsedMinutes = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 60000));
      }

      console.log(
        `[NotificationEngine] Notifying dial worker (${phone || "unknown"}, lang=${lang}) of cancellation on booking #${id}. Elapsed minutes: ${elapsedMinutes}`
      );

      // 3. Atomically restore worker status to Online so they can receive new jobs
      if (workerDocRef) {
        await workerDocRef.update({
          availabilityStatus: "online",
          isCheckedIn: true,
          callIvrStatus: "idle",
          updatedAt: new Date().toISOString(),
        }).catch((e) => console.warn(`[NotificationEngine] Failed to restore worker status:`, e.message));
      }

      // 4. If no phone available, we've at least restored their status
      if (!phone) {
        console.warn(`[NotificationEngine] No phone number found for dial worker on booking #${id}`);
        return { success: false, reason: "No phone number for dial worker" };
      }

      // 5. Generate Bhashini voice audio and trigger outbound cancellation call
      const { generateBookingCancelledAudio } = require("./bhashini_voice_service");
      const { triggerOutboundBookingCancelledCall } = require("./voice_call_engine");

      const audioFile = await generateBookingCancelledAudio({
        bookingId: id,
        trade: serviceType || "काम",
        address: customerAddressText || "",
        reason: cancellationReason || "ग्राहक ने बुकिंग रद्द की",
        elapsedMinutes,
        language: lang,
      });

      const callResult = await triggerOutboundBookingCancelledCall({
        workerPhone: phone,
        bookingId: id,
        trade: serviceType || "Service",
        address: customerAddressText || "",
        reason: cancellationReason || "No reason specified",
        elapsedMinutes,
        language: lang,
        audioFile,
      });

      if (this.db) {
        await this.db.collection("bookings").doc(id).update({
          dialCallStatus: "cancelled_notified",
          dialCancelledAt: new Date().toISOString(),
        }).catch(() => {});
      }

      return callResult;
    } catch (err) {
      console.error("[NotificationEngine] notifyDialWorkerBookingCancelled error:", err);
      return { success: false, error: err.message };
    }
  }
}

module.exports = {
  NotificationEngine,
  NOTIFICATION_TEMPLATES,
};

