# -*- coding: utf-8 -*-
"""
Sync all Dial Karya translation keys across all 23 language JSON files
in packages/workgo_core/assets/lang/
"""

import os
import json

LANG_DIR = os.path.join(os.path.dirname(__file__), "assets", "lang")

# Translations for key languages
TRANSLATIONS = {
    "en": {
        "dial_karya_title": "Dial Karya Telephony",
        "dial_karya_subtitle": "Registered via Voice IVR • Peer Verified",
        "dial_karya_badge": "Dial Karya Artisan",
        "dial_badge": "DIAL",
        "dial_karya_btn": "Dial Karya",
        "dial_karya_gateway_title": "Dial Karya Voice Gateway",
        "dial_karya_gateway_sub": "Telephony Gateway & Peer KYC Station",
        "dial_karya_gateway_desc": "Connect non-smartphone feature phones to Extension 1000 or MizuDroid. Spoken Bhashini AI voice dispatches customer bookings automatically in 22 languages.",
        "dial_gateway_desc": "Connect non-smartphone feature phones to Extension 1000 or MizuDroid. Spoken Bhashini AI voice dispatches customer bookings automatically in 22 languages.",
        "nearby_dial_artisans_title": "Nearby Dial Artisans Awaiting KYC",
        "nearby_dial_artisans_sub": "Verify feature-phone artisans in person to earn ₹150 bounty.",
        "gateway_status_live": "WSL2 ASTERISK SIP GATEWAY • ACTIVE",
        "dial_ext_btn": "Dial Ext 1000",
        "call_hotline_btn": "Call Hotline",
        "peer_kyc_bounties_title": "Dial Karya Peer KYC Bounties",
        "peer_kyc_bounties_subtitle": "₹150 earned per verified feature-phone artisan",
        "peer_kyc_bounty_item": "Peer KYC Bounty",
        "peer_kyc_bounty_hint": "Verify nearby dial workers via home alerts to earn ₹150 instantly into your wallet.",
        "no_dial_workers_pending": "No Dial Workers Pending KYC",
        "dial_worker_instruction": "When a feature-phone worker dials 1000 to register, they will appear here for in-person KYC verification.",
        "kyc_verified_badge": "KYC Verified",
        "kyc_pending_badge": "Pending KYC",
        "verify_kyc_btn": "Verify (₹150)",
    },
    "hi": {
        "dial_karya_title": "डायल कार्य टेलीफोनी",
        "dial_karya_subtitle": "वॉइस IVR द्वारा पंजीकृत • साथी सत्यापित",
        "dial_karya_badge": "डायल कार्य कारीगर",
        "dial_badge": "डायल",
        "dial_karya_btn": "डायल कार्य",
        "dial_karya_gateway_title": "डायल कार्य वॉइस गेटवे",
        "dial_karya_gateway_sub": "टेलीफोनी गेटवे एवं साथी केवाईसी स्टेशन",
        "dial_karya_gateway_desc": "नॉन-स्मार्टफोन फीचर फोन को एक्सटेंशन 1000 या मिजुड्रॉइड से जोड़ें। भाषिणी एआई 22 भाषाओं में ग्राहक बुकिंग स्वचालित रूप से भेजता है।",
        "dial_gateway_desc": "नॉन-स्मार्टफोन फीचर फोन को एक्सटेंशन 1000 या मिजुड्रॉइड से जोड़ें। भाषिणी एआई 22 भाषाओं में ग्राहक बुकिंग स्वचालित रूप से भेजता है।",
        "nearby_dial_artisans_title": "केवाईसी की प्रतीक्षा कर रहे नजदीकी डायल कारीगर",
        "nearby_dial_artisans_sub": "₹150 इनाम पाने के लिए फीचर-फोन कारीगरों का व्यक्तिगत रूप से सत्यापन करें।",
        "gateway_status_live": "WSL2 एस्टरिस्क एसआईपी गेटवे • सक्रिय",
        "dial_ext_btn": "एक्सटेंशन 1000 डायल करें",
        "call_hotline_btn": "हॉटलाइन पर कॉल करें",
        "peer_kyc_bounties_title": "डायल कार्य साथी KYC इनाम",
        "peer_kyc_bounties_subtitle": "सत्यापित फीचर-फोन कारीगर पर ₹150 अर्जित",
        "peer_kyc_bounty_item": "साथी KYC इनाम",
        "peer_kyc_bounty_hint": "अपने बटुए में तुरंत ₹150 अर्जित करने के लिए गृह अलर्ट के माध्यम से नजदीकी डायल कार्यकर्ताओं को सत्यापित करें।",
        "no_dial_workers_pending": "केवाईसी के लिए कोई डायल कारीगर लंबित नहीं है",
        "dial_worker_instruction": "जब कोई फीचर-फोन कार्यकर्ता पंजीकरण के लिए 1000 डायल करेगा, तो वे व्यक्तिगत केवाईसी सत्यापन के लिए यहां दिखाई देंगे।",
        "kyc_verified_badge": "केवाईसी सत्यापित",
        "kyc_pending_badge": "लंबित केवाईसी",
        "verify_kyc_btn": "सत्यापित करें (₹150)",
    },
    "ta": {
        "dial_karya_title": "டயல் கார்யா தொலைபேசி",
        "dial_karya_subtitle": "குரல் IVR மூலம் பதிவு செய்யப்பட்டது • சக ஊழியரால் சரிபார்க்கப்பட்டது",
        "dial_karya_badge": "டயல் கார்யா பணியாளர்",
        "dial_badge": "டயல்",
        "dial_karya_btn": "டயல் கார்யா",
        "dial_karya_gateway_title": "டயல் கார்யா குரல் நுழைவாயில்",
        "dial_karya_gateway_sub": "டெலிபோனி கேட்வே மற்றும் சக KYC நிலையம்",
        "dial_karya_gateway_desc": "ஸ்மார்ட்போன் அல்லாத சாதாரண போன்களை எக்ஸ்டென்ஷன் 1000 அல்லது மிசுடிராய்டுடன் இணைக்கவும். பாஷிணி AI 22 மொழிகளில் முன்பதிவுகளை அனுப்புகிறது.",
        "dial_gateway_desc": "ஸ்மார்ட்போன் அல்லாத சாதாரண போன்களை எக்ஸ்டென்ஷன் 1000 அல்லது மிசுடிராய்டுடன் இணைக்கவும். பாஷிணி AI 22 மொழிகளில் முன்பதிவுகளை அனுப்புகிறது.",
        "nearby_dial_artisans_title": "KYC க்காக காத்திருக்கும் அருகிலுள்ள டயல் பணியாளர்கள்",
        "nearby_dial_artisans_sub": "₹150 வெகுமதி பெற சாதாரண போன் கைவினைஞர்களை நேரில் சரிபார்க்கவும்.",
        "gateway_status_live": "WSL2 ஆஸ்டரிஸ்க் SIP கேட்வே • நேரலை",
        "dial_ext_btn": "Ext 1000 ஐ டயல் செய்",
        "call_hotline_btn": "ஹாட்லைனை அழைக்கவும்",
        "peer_kyc_bounties_title": "டயல் கார்யா சக KYC வெகுமதிகள்",
        "peer_kyc_bounties_subtitle": "சரிபார்க்கப்பட்ட சாதாரண போன் தொழிலாளிக்கு ₹150 வருமானம்",
        "peer_kyc_bounty_item": "சக KYC வெகுமதி",
        "peer_kyc_bounty_hint": "உங்கள் பணப்பையில் உடனடியாக ₹150 பெற அருகிலுள்ள டயல் பணியாளர்களை சரிபார்க்கவும்.",
        "no_dial_workers_pending": "KYC நிலுவையில் டயல் தொழிலாளர்கள் எவருமில்லை",
        "dial_worker_instruction": "ஒரு சாதாரண போன் தொழிலாளி பதிவு செய்ய 1000 ஐ டயல் செய்யும் போது, அவர்கள் நேரில் KYC சரிபார்ப்பிற்காக இங்கு தோன்றுவார்கள்.",
        "kyc_verified_badge": "KYC சரிபார்க்கப்பட்டது",
        "kyc_pending_badge": "நிலுவையில் உள்ள KYC",
        "verify_kyc_btn": "சரிபார்க்கவும் (₹150)",
    },
    "te": {
        "dial_karya_title": "డయల్ కార్య టెలిఫోనీ",
        "dial_karya_subtitle": "వాయిస్ IVR ద్వారా నమోదు • తోటి ఉద్యోగి ద్వారా ధృవీకరించబడింది",
        "dial_karya_badge": "డయల్ కార్య కళాకారుడు",
        "dial_badge": "డయల్",
        "dial_karya_btn": "డయల్ కార్య",
        "dial_karya_gateway_title": "డయల్ కార్య వాయిస్ గేట్‌వే",
        "dial_karya_gateway_sub": "టెలిఫోనీ గేట్‌వే & పీర్ KYC స్టేషన్",
        "dial_karya_gateway_desc": "ఫీచర్ ఫోన్‌లను ఎక్స్‌టెన్షన్ 1000 లేదా మిజుడ్రాయిడ్‌కు కనెక్ట్ చేయండి. భాషిణి AI 22 భాషల్లో బుకింగ్‌లను ఆటోమేటిక్‌గా పంపుతుంది.",
        "dial_gateway_desc": "ఫీచర్ ఫోన్‌లను ఎక్స్‌టెన్షన్ 1000 లేదా మిజుడ్రాయిడ్‌కు కనెక్ట్ చేయండి. భాషిణి AI 22 భాషల్లో బుకింగ్‌లను ఆటోమేటిక్‌గా పంపుతుంది.",
        "nearby_dial_artisans_title": "KYC కోసం వేచి ఉన్న సమీప డయల్ కళాకారులు",
        "nearby_dial_artisans_sub": "₹150 బహుమతి సంపాదించడానికి ఫీచర్-ఫోన్ కళాకారులను స్వయంగా ధృవీకరించండి.",
        "gateway_status_live": "WSL2 ఆస్టరిస్క్ SIP గేట్‌వే • యాక్టివ్",
        "dial_ext_btn": "Ext 1000 డయల్ చేయండి",
        "call_hotline_btn": "హాట్‌లైన్‌కు కాల్ చేయండి",
        "peer_kyc_bounties_title": "డయల్ కార్య పీర్ KYC బహుమతులు",
        "peer_kyc_bounties_subtitle": "ధృవీకరించబడిన ఫీచర్-ఫోన్ కళాకారుడికి ₹150 సంపాదించబడింది",
        "peer_kyc_bounty_item": "పీర్ KYC బహుమతి",
        "peer_kyc_bounty_hint": "మీ వాలెట్‌లో తక్షణమే ₹150 సంపాదించడానికి సమీపంలోని డయల్ కార్మికులను ధృవీకరించండి.",
        "no_dial_workers_pending": "KYC పెండింగ్‌లో ఉన్న డయల్ వర్కర్లు ఎవరూ లేరు",
        "dial_worker_instruction": "ఫీచర్-ఫోన్ కార్మికుడు రిజిస్టర్ చేసుకోవడానికి 1000 డయల్ చేసినప్పుడు, వారు వ్యక్తిగత KYC ధృవీకరణ కోసం ఇక్కడ కనిపిస్తారు.",
        "kyc_verified_badge": "KYC ధృవీకరించబడింది",
        "kyc_pending_badge": "పెండింగ్ KYC",
        "verify_kyc_btn": "ధృవీకరించండి (₹150)",
    },
    "kn": {
        "dial_karya_title": "ಡಯಲ್ ಕಾರ್ಯ ಟೆಲಿಫೋನಿ",
        "dial_karya_subtitle": "ಧ್ವನಿ IVR ಮೂಲಕ ನೋಂದಣಿ • ಸಹೋದ್ಯೋಗಿ ಪರಿಶೀಲಿತ",
        "dial_karya_badge": "ಡಯಲ್ ಕಾರ್ಯ ಕುಶಲಕರ್ಮಿ",
        "dial_badge": "ಡಯಲ್",
        "dial_karya_btn": "ಡಯಲ್ ಕಾರ್ಯ",
        "dial_karya_gateway_title": "ಡಯಲ್ ಕಾರ್ಯ ಧ್ವನಿ ಗೇಟ್‌ವೇ",
        "dial_karya_gateway_sub": "ಟೆಲಿಫೋನಿ ಗೇಟ್‌ವೇ ಮತ್ತು ಪೀರ್ KYC ಕೇಂದ್ರ",
        "dial_karya_gateway_desc": "ಫೀಚರ್ ಫೋನ್‌ಗಳನ್ನು ಎಕ್ಸ್‌ಟೆನ್ಷನ್ 1000 ಗೆ ಸಂಪರ್ಕಿಸಿ. ಭಾಷಿಣಿ AI 22 ಭಾಷೆಗಳಲ್ಲಿ ಬುಕಿಂಗ್‌ಗಳನ್ನು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಕಳುಹಿಸುತ್ತದೆ.",
        "dial_gateway_desc": "ಫೀಚರ್ ಫೋನ್‌ಗಳನ್ನು ಎಕ್ಸ್‌ಟೆನ್ಷನ್ 1000 ಗೆ ಸಂಪರ್ಕಿಸಿ. ಭಾಷಿಣಿ AI 22 ಭಾಷೆಗಳಲ್ಲಿ ಬುಕಿಂಗ್‌ಗಳನ್ನು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಕಳುಹಿಸುತ್ತದೆ.",
        "nearby_dial_artisans_title": "KYC ಗಾಗಿ ಕಾಯುತ್ತಿರುವ ಸಮೀಪದ ಡಯಲ್ ಕುಶಲಕರ್ಮಿಗಳು",
        "nearby_dial_artisans_sub": "₹150 ಬೌಂಟಿ ಗಳಿಸಲು ಫೀಚರ್-ಫೋನ್ ಕುಶಲಕರ್ಮಿಗಳನ್ನು ಖುದ್ದಾಗಿ ಪರಿಶೀಲಿಸಿ.",
        "gateway_status_live": "WSL2 ಆಸ್ಟರಿಸ್ಕ್ SIP ಗೇಟ್‌ವೇ • ಸಕ್ರಿಯ",
        "dial_ext_btn": "Ext 1000 ಡಯಲ್ ಮಾಡಿ",
        "call_hotline_btn": "ಹಾಟ್‌ಲೈನ್‌ಗೆ ಕರೆ ಮಾಡಿ",
        "peer_kyc_bounties_title": "ಡಯಲ್ ಕಾರ್ಯ ಪೀರ್ KYC ಬೌಂಟಿ",
        "peer_kyc_bounties_subtitle": "ಪರಿಶೀಲಿಸಿದ ಫೀಚರ್-ಫೋನ್ ಕುಶಲಕರ್ಮಿಗೆ ₹150 ಗಳಿಸಲಾಗಿದೆ",
        "peer_kyc_bounty_item": "ಪೀರ್ KYC ಬೌಂಟಿ",
        "peer_kyc_bounty_hint": "ನಿಮ್ಮ ವ್ಯಾಲೆಟ್‌ಗೆ ₹150 ತಕ್ಷಣ ಗಳಿಸಲು ಸಮೀಪದ ಡಯಲ್ ಕಾರ್ಮಿಕರನ್ನು ಪರಿಶೀಲಿಸಿ.",
        "no_dial_workers_pending": "KYC ಬಾಕಿ ಇರುವ ಯಾವುದೇ ಡಯಲ್ ಕಾರ್ಮಿಕರಿಲ್ಲ",
        "dial_worker_instruction": "ಫೀಚರ್-ಫೋನ್ ಕಾರ್ಮಿಕ ನೋಂದಣಿಗೆ 1000 ಡಯಲ್ ಮಾಡಿದಾಗ, ಅವರು ವ್ಯಕ್ತಿಗತ KYC ಗಾಗಿ ಇಲ್ಲಿ ಕಾಣಿಸಿಕೊಳ್ಳುತ್ತಾರೆ.",
        "kyc_verified_badge": "KYC ಪರಿಶೀಲಿಸಲಾಗಿದೆ",
        "kyc_pending_badge": "ಬಾಕಿ KYC",
        "verify_kyc_btn": "ಪರಿಶೀಲಿಸಿ (₹150)",
    },
    "ml": {
        "dial_karya_title": "ഡയൽ കാര്യ ടെലിഫോണി",
        "dial_karya_subtitle": "വോയ്‌സ് IVR വഴി രജിസ്റ്റർ ചെയ്തത് • സഹപ്രവർത്തകൻ പരിശോധിച്ചു",
        "dial_karya_badge": "ഡയൽ കാര്യ തൊഴിലാളി",
        "dial_badge": "ഡയൽ",
        "dial_karya_btn": "ഡയൽ കാര്യ",
        "dial_karya_gateway_title": "ഡയൽ കാര്യ വോയ്‌സ് ഗേറ്റ്‌വേ",
        "dial_karya_gateway_sub": "ടെലിഫോണി ഗേറ്റ്‌വേയും പിയർ KYC സ്റ്റേഷനും",
        "dial_karya_gateway_desc": "ഫീച്ചർ ഫോണുകളെ എക്സ്റ്റൻഷൻ 1000 ലേക്ക് ബന്ധിപ്പിക്കുക. ഭാഷിണി AI 22 ഭാഷകളിൽ ബുക്കിംഗുകൾ അയയ്ക്കുന്നു.",
        "dial_gateway_desc": "ഫീച്ചർ ഫോണുകളെ എക്സ്റ്റൻഷൻ 1000 ലേക്ക് ബന്ധിപ്പിക്കുക. ഭാഷിണി AI 22 ഭാഷകളിൽ ബുക്കിംഗുകൾ അയയ്ക്കുന്നു.",
        "nearby_dial_artisans_title": "KYC കാത്തിരിക്കുന്ന സമീപത്തെ ഡയൽ തൊഴിലാളികൾ",
        "nearby_dial_artisans_sub": "₹150 ബോണസ് നേടാൻ ഫീച്ചർ ഫോൺ തൊഴിലാളികളെ നേരിട്ട് പരിശോധിച്ച് ഉറപ്പാക്കുക.",
        "gateway_status_live": "WSL2 ആസ്റ്ററിസ്ക് SIP ഗേറ്റ്‌വേ • സജീവം",
        "dial_ext_btn": "Ext 1000 ഡയൽ ചെയ്യുക",
        "call_hotline_btn": "ഹോട്ട്‌ലൈനിൽ വിളിക്കുക",
        "peer_kyc_bounties_title": "ഡയൽ കാര്യ പിയർ KYC ബോണസ്",
        "peer_kyc_bounties_subtitle": "സ്ഥിരീകരിച്ച ഫീച്ചർ-ഫോൺ തൊഴിലാളിക്ക് ₹150 ലഭിച്ചു",
        "peer_kyc_bounty_item": "പിയർ KYC ബോണസ്",
        "peer_kyc_bounty_hint": "നിങ്ങളുടെ വാലറ്റിലേക്ക് തൽക്ഷണം ₹150 നേടാൻ സമീപത്തെ ഡയൽ തൊഴിലാളികളെ പരിശോധിക്കുക.",
        "no_dial_workers_pending": "KYC ബാക്കിയുള്ള ഡയൽ തൊഴിലാളികൾ ആരുമില്ല",
        "dial_worker_instruction": "ഒരു ഫീച്ചർ ഫോൺ തൊഴിലാളി രജിസ്റ്റർ ചെയ്യാൻ 1000 ഡയൽ ചെയ്യുമ്പോൾ, അവർ ഇവിടെ ദൃശ്യമാകും.",
        "kyc_verified_badge": "KYC പരിശോധിച്ചു",
        "kyc_pending_badge": "തീർപ്പുകൽപ്പിക്കാത്ത KYC",
        "verify_kyc_btn": "പരിശോധിക്കുക (₹150)",
    },
    "mr": {
        "dial_karya_title": "डायल कार्य टेलिफोनी",
        "dial_karya_subtitle": "व्हॉइस IVR द्वारे नोंदणीकृत • सहकारी पडताळणीकृत",
        "dial_karya_badge": "डायल कार्य कारागीर",
        "dial_badge": "डायल",
        "dial_karya_btn": "डायल कार्य",
        "dial_karya_gateway_title": "डायल कार्य व्हॉइस गेटवे",
        "dial_karya_gateway_sub": "टेलिफोनी गेटवे आणि सहकारी केवायसी स्टेशन",
        "dial_karya_gateway_desc": "नॉन-स्मार्टफोन फीचर फोन एक्सटेंशन 1000 किंवा मिझुड्रॉइडशी जोडा. भाषिणी एआय 22 भाषांमध्ये ग्राहक बुकिंग पाठवते.",
        "dial_gateway_desc": "नॉन-स्मार्टफोन फीचर फोन एक्सटेंशन 1000 किंवा मिझुड्रॉइडशी जोडा. भाषिणी एआय 22 भाषांमध्ये ग्राहक बुकिंग पाठवते.",
        "nearby_dial_artisans_title": "केवायसीच्या प्रतीक्षेत असलेले जवळचे डायल कारागीर",
        "nearby_dial_artisans_sub": "₹150 मिळवण्यासाठी फीचर-फोन कारागीरांची प्रत्यक्ष पडताळणी करा.",
        "gateway_status_live": "WSL2 एस्टरिस्क एसआयपी गेटवे • सक्रिय",
        "dial_ext_btn": "Ext 1000 डायल करा",
        "call_hotline_btn": "हॉटलाइनवर कॉल करा",
        "peer_kyc_bounties_title": "डायल कार्य सहकारी केवायसी बक्षीस",
        "peer_kyc_bounties_subtitle": "पडताळणी केलेल्या फीचर-फोन कारागिरासाठी ₹150 कमावले",
        "peer_kyc_bounty_item": "सहकारी केवायसी बक्षीस",
        "peer_kyc_bounty_hint": "आपल्या वॉलेटमध्ये त्वरित ₹150 मिळवण्यासाठी जवळच्या डायल कामगारांची पडताळणी करा.",
        "no_dial_workers_pending": "केवायसीसाठी कोणताही डायल कामगार प्रलंबित नाही",
        "dial_worker_instruction": "जेव्हा फीचर-फोन कामगार नोंदणीसाठी 1000 डायल करेल, तेव्हा तो पडताळणीसाठी येथे दिसेल.",
        "kyc_verified_badge": "केवायसी पडताळणी पूर्ण",
        "kyc_pending_badge": "केवायसी प्रलंबित",
        "verify_kyc_btn": "पडताळणी करा (₹150)",
    },
    "gu": {
        "dial_karya_title": "ડાયલ કાર્ય ટેલિફોની",
        "dial_karya_subtitle": "વૉઇસ IVR દ્વારા નોંધાયેલ • સાથીદાર દ્વારા ચકાસાયેલ",
        "dial_karya_badge": "ડાયલ કાર્ય કારીગર",
        "dial_badge": "ડાયલ",
        "dial_karya_btn": "ડાયલ કાર્ય",
        "dial_karya_gateway_title": "ડાયલ કાર્ય વૉઇસ ગેટવે",
        "dial_karya_gateway_sub": "ટેલિફોની ગેટવે અને સાથી કેવાયસી સ્ટેશન",
        "dial_karya_gateway_desc": "નોન-સ્માર્ટફોન ફીચર ફોનને એક્સ્ટેંશન 1000 સાથે જોડો. ભાષિણી AI 22 ભાષાઓમાં બુકિંગ મોકલે છે.",
        "dial_gateway_desc": "નોન-સ્માર્ટફોન ફીચર ફોનને એક્સ્ટેંશન 1000 સાથે જોડો. ભાષિણી AI 22 ભાષાઓમાં બુકિંગ મોકલે છે.",
        "nearby_dial_artisans_title": "KYC ની રાહ જોઈ રહેલા નજીકના ડાયલ કારીગરો",
        "nearby_dial_artisans_sub": "₹150 કમાવવા માટે ફીચર-ફોન કારીગરોની જાતે ચકાસણી કરો.",
        "gateway_status_live": "WSL2 એસ્ટેરિસ્ક SIP ગેટવે • સક્રિય",
        "dial_ext_btn": "Ext 1000 ડાયલ કરો",
        "call_hotline_btn": "હોટલાઇન પર કૉલ કરો",
        "peer_kyc_bounties_title": "ડાયલ કાર્ય સાથી KYC બોનસ",
        "peer_kyc_bounties_subtitle": "ચકાસાયેલ ફીચર-ફોન કારીગર દીઠ ₹150 ની કમાણી",
        "peer_kyc_bounty_item": "સાથી KYC બોનસ",
        "peer_kyc_bounty_hint": "તમારા વૉલેટમાં તરત જ ₹150 મેળવવા માટે નજીકના ડાયલ વર્કર્સની ચકાસણી કરો.",
        "no_dial_workers_pending": "કોઈ ડાયલ વર્કર બાકી નથી",
        "dial_worker_instruction": "જ્યારે ફીચર-ફોન વર્કર નોંધણી માટે 1000 ડાયલ કરશે, ત્યારે તેઓ અહીં દેખાશે.",
        "kyc_verified_badge": "KYC ચકાસાયેલ",
        "kyc_pending_badge": "KYC બાકી",
        "verify_kyc_btn": "ચકાસો (₹150)",
    },
    "bn": {
        "dial_karya_title": "ডায়াল কার্য টেলিফোনি",
        "dial_karya_subtitle": "ভয়েস IVR মাধ্যমে নিবন্ধিত • সহকর্মী দ্বারা যাচাইকৃত",
        "dial_karya_badge": "ডায়াল কার্য কারিগর",
        "dial_badge": "ডায়াল",
        "dial_karya_btn": "ডায়াল কার্য",
        "dial_karya_gateway_title": "ডায়াল কার্য ভয়েস গেটওয়ে",
        "dial_karya_gateway_sub": "টেলিফোনি গেটওয়ে এবং সমকক্ষ কেওয়াইসি স্টেশন",
        "dial_karya_gateway_desc": "ফিচার ফোন এক্সটেনশন 1000 এ সংযুক্ত করুন। ভাষিণী এআই 22টি ভাষায় গ্রাহক বুকিং পাঠায়।",
        "dial_gateway_desc": "ফিচার ফোন এক্সটেনশন 1000 এ সংযুক্ত করুন। ভাষিণী এআই 22টি ভাষায় গ্রাহক বুকিং পাঠায়।",
        "nearby_dial_artisans_title": "কেওয়াইসির অপেক্ষায় থাকা কাছাকাছি ডায়াল কারিগর",
        "nearby_dial_artisans_sub": "₹150 উপার্জনের জন্য ফিচার-ফোন কারিগরদের যাচাই করুন।",
        "gateway_status_live": "WSL2 অ্যাসটারিস্ক এসআইপি গেটওয়ে • সক্রিয়",
        "dial_ext_btn": "Ext 1000 ডায়াল করুন",
        "call_hotline_btn": "হটলাইনে কল করুন",
        "peer_kyc_bounties_title": "ডায়াল কার্য সমকক্ষ কেওয়াইসি পুরস্কার",
        "peer_kyc_bounties_subtitle": "যাচাইকৃত ফিচার-ফোন কারিগর প্রতি ₹150 অর্জিত",
        "peer_kyc_bounty_item": "সমকক্ষ কেওয়াইসি পুরস্কার",
        "peer_kyc_bounty_hint": "আপনার ওয়ালেটে সঙ্গে সঙ্গে ₹150 উপার্জন করতে কাছাকাছি ডায়াল কর্মীদের যাচাই করুন।",
        "no_dial_workers_pending": "কোনো ডায়াল কর্মী অপেক্ষমাণ নেই",
        "dial_worker_instruction": "ফিচার-ফোন কর্মী নিবন্ধনের জন্য 1000 ডায়াল করলে, তারা এখানে উপস্থিত হবেন।",
        "kyc_verified_badge": "কেওয়াইসি যাচাই সম্পন্ন",
        "kyc_pending_badge": "কেওয়াইসি অপেক্ষমাণ",
        "verify_kyc_btn": "যাচাই করুন (₹150)",
    },
    "pa": {
        "dial_karya_title": "ਡਾਇਲ ਕਾਰਜ ਟੈਲੀਫੋਨੀ",
        "dial_karya_subtitle": "ਵਾਇਸ IVR ਰਾਹੀਂ ਰਜਿਸਟਰਡ • ਸਾਥੀ ਵੱਲੋਂ ਪ੍ਰਮਾਣਿਤ",
        "dial_karya_badge": "ਡਾਇਲ ਕਾਰਜ ਕਾਰੀਗਰ",
        "dial_badge": "ਡਾਇਲ",
        "dial_karya_btn": "ਡਾਇਲ ਕਾਰਜ",
        "dial_karya_gateway_title": "ਡਾਇਲ ਕਾਰਿਆ ਵੌਇਸ ਗੇਟਵੇ",
        "dial_karya_gateway_sub": "ਟੈਲੀਫੋਨੀ ਗੇਟਵੇਅ ਅਤੇ ਸਾਥੀ ਕੇਵਾਈਸੀ ਸਟੇਸ਼ਨ",
        "dial_karya_gateway_desc": "ਨਾਨ-ਸਮਾਰਟਫੋਨ ਫੀਚਰ ਫੋਨਾਂ ਨੂੰ ਐਕਸਟੈਂਸ਼ਨ 1000 ਨਾਲ ਜੋੜੋ। ਭਾਸ਼ਿਣੀ ਏਆਈ 22 ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਬੁਕਿੰਗ ਭੇਜਦੀ ਹੈ।",
        "dial_gateway_desc": "ਨਾਨ-ਸਮਾਰਟਫੋਨ ਫੀਚਰ ਫੋਨਾਂ ਨੂੰ ਐਕਸਟੈਂਸ਼ਨ 1000 ਨਾਲ ਜੋੜੋ। ਭਾਸ਼ਿਣੀ ਏਆਈ 22 ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਬੁਕਿੰਗ ਭੇਜਦੀ ਹੈ।",
        "nearby_dial_artisans_title": "ਕੇਵਾਈਸੀ ਦੀ ਉਡੀਕ ਕਰ ਰਹੇ ਨੇੜਲੇ ਡਾਇਲ ਕਾਰੀਗਰ",
        "nearby_dial_artisans_sub": "₹150 ਕਮਾਉਣ ਲਈ ਫੀਚਰ-ਫੋਨ ਕਾਰੀਗਰਾਂ ਦੀ ਖੁਦ ਤਸਦੀਕ ਕਰੋ।",
        "gateway_status_live": "WSL2 ਐਸਟ੍ਰਿਸਕ SIP ਗੇਟਵੇ • ਸਰਗਰਮ",
        "dial_ext_btn": "Ext 1000 ਡਾਇਲ ਕਰੋ",
        "call_hotline_btn": "ਹੌਟਲਾਈਨ 'ਤੇ ਕਾਲ ਕਰੋ",
        "peer_kyc_bounties_title": "ਡਾਇਲ ਕਾਰਜ ਸਾਥੀ ਕੇਵਾਈਸੀ ਇਨਾਮ",
        "peer_kyc_bounties_subtitle": "ਤਸਦੀਕਸ਼ੁਦਾ ਫੀਚਰ-ਫੋਨ ਕਾਰੀਗਰ ਪ੍ਰਤੀ ₹150 ਕਮਾਏ",
        "peer_kyc_bounty_item": "ਸਾਥੀ ਕੇਵਾਈਸੀ ਇਨਾਮ",
        "peer_kyc_bounty_hint": "ਆਪਣੇ ਬਟੂਏ ਵਿੱਚ ਤੁਰੰਤ ₹150 ਕਮਾਉਣ ਲਈ ਨੇੜਲੇ ਡਾਇਲ ਕਾਮਿਆਂ ਦੀ ਤਸਦੀਕ ਕਰੋ।",
        "no_dial_workers_pending": "ਕੋਈ ਡਾਇਲ ਕਾਮਾ ਬਾਕੀ ਨਹੀਂ",
        "dial_worker_instruction": "ਜਦੋਂ ਕੋਈ ਫੀਚਰ-ਫੋਨ ਕਾਮਾ ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਲਈ 1000 ਡਾਇਲ ਕਰੇਗਾ, ਉਹ ਇੱਥੇ ਦਿਖਾਈ ਦੇਵੇਗਾ।",
        "kyc_verified_badge": "ਕੇਵਾਈਸੀ ਤਸਦੀਕਸ਼ੁਦਾ",
        "kyc_pending_badge": "ਲੰਬਿਤ ਕੇਵਾਈਸੀ",
        "verify_kyc_btn": "ਤਸਦੀਕ ਕਰੋ (₹150)",
    },
    "ur": {
        "dial_karya_title": "ڈائل کاریا ٹیلی فونی",
        "dial_karya_subtitle": "وائس IVR کے ذریعے رجسٹرڈ • ساتھی سے تصدیق شدہ",
        "dial_karya_badge": "ڈائل کاریا کاریگر",
        "dial_badge": "ڈائل",
        "dial_karya_btn": "ڈائل کاریا",
        "dial_karya_gateway_title": "ڈائل کاریا وائس گیٹ وے",
        "dial_karya_gateway_sub": "ٹیلی فونی گیٹ وے اور پیر کے وائی سی اسٹیشن",
        "dial_karya_gateway_desc": "فیچر فونز کو ایکسٹینشن 1000 سے مربوط کریں۔ بھاشنی AI 22 زبانوں میں بکنگ فراہم کرتا ہے۔",
        "dial_gateway_desc": "فیچر فونز کو ایکسٹینشن 1000 سے مربوط کریں۔ بھاشنی AI 22 زبانوں میں بکنگ فراہم کرتا ہے۔",
        "nearby_dial_artisans_title": "کے وائی سی کے منتظر قریبی ڈائل کاریگر",
        "nearby_dial_artisans_sub": "₹150 انعام حاصل کرنے کے لیے فیچر فون کاریگروں کی تصدیق کریں۔",
        "gateway_status_live": "WSL2 Asterisk SIP گیٹ وے • فعال",
        "dial_ext_btn": "ایکسٹینشن 1000 ڈائل کریں",
        "call_hotline_btn": "ہاٹ لائن پر کال کریں",
        "peer_kyc_bounties_title": "ڈائل کاریا پیر کے وائی سی انعامات",
        "peer_kyc_bounties_subtitle": "تصدیق شدہ فیچر فون کاریگر پر ₹150 حاصل",
        "peer_kyc_bounty_item": "پیر کے وائی سی انعام",
        "peer_kyc_bounty_hint": "اپنے بٹوے میں فوری ₹150 کمانے کے لیے قریبی ڈائل ورکرز کی تصدیق کریں۔",
        "no_dial_workers_pending": "کوئی ڈائل ورکرز زیر التوا نہیں",
        "dial_worker_instruction": "جب فیچر فون ورکر 1000 ڈائل کرے گا تو وہ تصدیق کے لیے یہاں ظاہر ہوگا۔",
        "kyc_verified_badge": "کے وائی سی تصدیق شدہ",
        "kyc_pending_badge": "زیر التوا کے وائی سی",
        "verify_kyc_btn": "تصدیق کریں (₹150)",
    },
}

def sync_all():
    en_dict = TRANSLATIONS["en"]
    hi_dict = TRANSLATIONS["hi"]

    for fname in os.listdir(LANG_DIR):
        if not fname.endswith(".json"):
            continue
        code = fname.replace(".json", "")
        fpath = os.path.join(LANG_DIR, fname)

        with open(fpath, "r", encoding="utf-8") as f:
            try:
                data = json.load(f)
            except Exception as e:
                print(f"Failed to load {fname}: {e}")
                continue

        # Pick best dictionary
        source = TRANSLATIONS.get(code)
        if not source:
            # For remaining scheduled languages (as, or, sa, sd, etc.), fall back to Hindi / English
            source = hi_dict if code in ["sa", "mai", "doi", "kok", "ks"] else en_dict

        added = 0
        updated = 0
        for k, v in en_dict.items():
            localized_v = source.get(k, v)
            if k not in data:
                data[k] = localized_v
                added += 1
            elif not data[k] or data[k] == k:
                data[k] = localized_v
                updated += 1

        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"[{code}] Added {added}, updated {updated} Dial Karya keys.")

if __name__ == "__main__":
    sync_all()
