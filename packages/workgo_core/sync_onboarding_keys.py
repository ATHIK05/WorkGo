# -*- coding: utf-8 -*-
"""
Sync all Cooperative Artisan Onboarding translation keys across all language JSON files
in packages/workgo_core/assets/lang/
"""

import os
import json

LANG_DIR = os.path.join(os.path.dirname(__file__), "assets", "lang")

# Key translations
KEYS = {
    "onboarding_step_1_badge": {
        "en": "Step 1 of 3 • Trades",
        "hi": "चरण 1/3 • व्यवसाय",
        "ta": "படி 1/3 • தொழில்கள்",
        "te": "దశ 1/3 • వృత్తులు",
        "kn": "ಹಂತ 1/3 • ಉದ್ಯೋಗಗಳು",
        "ml": "ഘട്ടം 1/3 • തൊഴിലുകൾ",
    },
    "onboarding_step_2_badge": {
        "en": "Step 2 of 3 • Location",
        "hi": "चरण 2/3 • स्थान",
        "ta": "படி 2/3 • இருப்பிடம்",
        "te": "దశ 2/3 • ప్రాంతం",
        "kn": "ಹಂತ 2/3 • ಸ್ಥಳ",
        "ml": "ഘട്ടം 2/3 • സ്ഥലം",
    },
    "onboarding_step_3_badge": {
        "en": "Step 3 of 3 • Schedule",
        "hi": "चरण 3/3 • समय",
        "ta": "படி 3/3 • வேலை நேரம்",
        "te": "దశ 3/3 • సమయం",
        "kn": "ಹಂತ 3/3 • ಸಮಯ",
        "ml": "ഘട്ടം 3/3 • സമയം",
    },
    "onboarding_step1_title": {
        "en": "Select Your Trades & Skills",
        "hi": "अपने व्यवसाय और कौशल चुनें",
        "ta": "உங்கள் தொழில் மற்றும் திறன்கள்",
        "te": "మీ వృత్తులు మరియు నైపుణ్యాలను ఎంచుకోండి",
        "kn": "ನಿಮ್ಮ ಉದ್ಯೋಗ ಮತ್ತು ಕೌಶಲ್ಯಗಳನ್ನು ಆಯ್ಕೆಮಾಡಿ",
        "ml": "നിങ്ങളുടെ തൊഴിലുകളും കഴിവുകളും തിരഞ്ഞെടുക്കുക",
    },
    "onboarding_step1_sub": {
        "en": "Choose the occupations you provide. Tap any trade to preview.",
        "hi": "वे व्यवसाय चुनें जो आप करते हैं। पूर्वावलोकन के लिए किसी भी व्यवसाय पर टैप करें।",
        "ta": "நீங்கள் வழங்கும் தொழில்களைத் தேர்ந்தெடுக்கவும். முன்னோட்டத்தைக் காண ஏதேனும் ஒன்றைத் தொடவும்.",
        "te": "మీరు అందించే సేవలను ఎంచుకోండి. ప్రివ్యూ కోసం ఏదైనా వృత్తిపై నొక్కండి.",
        "kn": "ನೀವು ಒದಗಿಸುವ ಸೇವೆಗಳನ್ನು ಆಯ್ಕೆಮಾಡಿ. ಮುನ್ನೋಟಕ್ಕಾಗಿ ಯಾವುದೇ ಉದ್ಯೋಗವನ್ನು ಟ್ಯಾಪ್ ಮಾಡಿ.",
        "ml": "നിങ്ങൾ നൽകുന്ന സേവനങ്ങൾ തിരഞ്ഞെടുക്കുക. പ്രിവ്യൂ കാണാൻ ഏതെങ്കിലും തൊഴിലിൽ ടാപ്പ് ചെയ്യുക.",
    },
    "onboarding_step2_title": {
        "en": "Operating Base & Coverage",
        "hi": "कार्य स्थल और सेवा दायरा",
        "ta": "பணி தளம் மற்றும் சேவை எல்லை",
        "te": "పని కేంద్రం మరియు సేవా పరిధి",
        "kn": "ಕಾರ್ಯಾಚರಣೆ ಕೇಂದ್ರ ಮತ್ತು ಸೇವಾ ವ್ಯಾಪ್ತಿ",
        "ml": "പ്രവർത്തന കേന്ദ്രവും സേവന പരിധിയും",
    },
    "onboarding_step2_sub": {
        "en": "Set your workshop location and customer dispatch radius",
        "hi": "अपना कार्य स्थान और ग्राहक सेवा दायरा सेट करें",
        "ta": "உங்கள் இருப்பிடம் மற்றும் சேவை வரம்பை அமைக்கவும்",
        "te": "మీ వర్క్‌షాప్ స్థానం మరియు సర్వీస్ వ్యాసార్థాన్ని సెట్ చేయండి",
        "kn": "ನಿಮ್ಮ ಕಾರ್ಯಾಗಾರದ ಸ್ಥಳ ಮತ್ತು ಸೇವಾ ವ್ಯಾಪ್ತಿಯನ್ನು ಹೊಂದಿಸಿ",
        "ml": "നിങ്ങളുടെ വർക്ക്‌ഷോപ്പ് ലൊക്കേഷനും സേവന പരിധിയും സജ്ജമാക്കുക",
    },
    "onboarding_step3_title": {
        "en": "Daily Available Working Hours",
        "hi": "दैनिक उपलब्ध कार्य समय",
        "ta": "தினசரி வேலை நேரம்",
        "te": "రోజువారీ అందుబాటు పని గంటలు",
        "kn": "ದೈನಂದಿನ ಲಭ್ಯವಿರುವ ಕೆಲಸದ ಸಮಯ",
        "ml": "പ്രതിദിന ലഭ്യമായ ജോലി സമയം",
    },
    "onboarding_step3_sub": {
        "en": "Specify the hours when you are available to accept incoming jobs",
        "hi": "काम स्वीकार करने के लिए अपना समय बताएं",
        "ta": "வேலைகளை ஏற்க நீங்கள் கிடைக்கும் நேரத்தைக் குறிப்பிடவும்",
        "te": "కొత్త పనులను స్వీకరించడానికి మీరు అందుబాటులో ఉండే సమయాన్ని పేర్కొనండి",
        "kn": "ಹೊಸ ಕೆಲಸಗಳನ್ನು ಸ್ವೀಕರಿಸಲು ನೀವು ಲಭ್ಯವಿರುವ ಸಮಯವನ್ನು ನಮೂದಿಸಿ",
        "ml": "പുതിയ ജോലികൾ സ്വീകരിക്കാൻ നിങ്ങൾ ലഭ്യമാകുന്ന സമയം വ്യക്തമാക്കുക",
    },
    "btn_continue": {
        "en": "Continue",
        "hi": "आगे बढ़ें",
        "ta": "தொடரவும்",
        "te": "కొనసాగించండి",
        "kn": "ಮುಂದುವರಿಯಿರಿ",
        "ml": "തുടരുക",
    },
    "btn_back": {
        "en": "Back",
        "hi": "वापस",
        "ta": "பின்செல்",
        "te": "వెనుకకు",
        "kn": "ಹಿಂದೆ",
        "ml": "പിന്നോട്ട്",
    },
    "select_at_least_one_skill_onboarding": {
        "en": "Please select at least one trade skill you can do",
        "hi": "कृपया कम से कम एक व्यवसाय चुनें",
        "ta": "தயவுசெய்து குறைந்தது ஒரு தொழிலையாவது தேர்ந்தெடுக்கவும்",
        "te": "దయచేసి కనీసం ఒక వృత్తిని ఎంచుకోండి",
        "kn": "ದಯವಿಟ್ಟು ಕನಿಷ್ಠ ಒಂದು ಉದ್ಯೋಗವನ್ನು ಆಯ್ಕೆಮಾಡಿ",
        "ml": "ദയവായി ഒരു തൊഴിലെങ്കിലും തിരഞ്ഞെടുക്കുക",
    },
    "preset_full_day": {
        "en": "Full Day (8 AM - 8 PM)",
        "hi": "पूरा दिन (सुबह 8 - रात 8)",
        "ta": "முழு நாள் (காலை 8 - இரவு 8)",
        "te": "పూర్తి రోజు (ఉదయం 8 - రాత్రి 8)",
        "kn": "ಪೂರ್ಣ ದಿನ (ಬೆಳಿಗ್ಗೆ 8 - ರಾತ್ರಿ 8)",
        "ml": "പൂർണ്ണ ദിനം (രാവിലെ 8 - രാത്രി 8)",
    },
    "preset_morning": {
        "en": "Morning Shift (7 AM - 3 PM)",
        "hi": "सुबह की पाली (सुबह 7 - दोपहर 3)",
        "ta": "காலை ஷிப்ட் (காலை 7 - மதியம் 3)",
        "te": "ఉదయపు షిఫ్ట్ (ఉదయం 7 - మధ్యాహ్నం 3)",
        "kn": "ಬೆಳಗಿನ ಪಾಳಿ (ಬೆಳಿಗ್ಗೆ 7 - ಮಧ್ಯಾಹ್ನ 3)",
        "ml": "രാവിലെ ഷിഫ്റ്റ് (രാവിലെ 7 - ഉച്ചയ്ക്ക് 3)",
    },
    "preset_evening": {
        "en": "Evening Shift (12 PM - 9 PM)",
        "hi": "शाम की पाली (दोपहर 12 - रात 9)",
        "ta": "மாலை ஷிப்ட் (மதியம் 12 - இரவு 9)",
        "te": "సాయంత్రపు షిఫ్ట్ (మధ్యాహ్నం 12 - రాత్రి 9)",
        "kn": "ಸಂಜೆಯ ಪಾಳಿ (ಮಧ್ಯಾಹ್ನ 12 - ರಾತ್ರಿ 9)",
        "ml": "വൈകുന്നേരത്തെ ഷിഫ്റ്റ് (ഉച്ചയ്ക്ക് 12 - രാത്രി 9)",
    },
    "coop_guarantee_title": {
        "en": "Cooperative Dispatch Guarantee",
        "hi": "सहकारी कार्य प्रेषण गारंटी",
        "ta": "கூட்டுறவு நேரடி பணி உறுதி",
        "te": "సహకార ప్రత్యక్ష పని హామీ",
        "kn": "ಸಹಕಾರ ನೇರ ಕೆಲಸದ ಭರವಸೆ",
        "ml": "സഹകരണ നേരിട്ടുള്ള ജോലി ഗ്യാരണ്ടി",
    },
    "coop_guarantee_sub": {
        "en": "Direct customer bookings are dispatched with 0% middleman deduction.",
        "hi": "बिना किसी बिचौलिये के सीधे ग्राहक बुकिंग आपको भेजी जाती है।",
        "ta": "இடைத்தரகர் பிடித்தம் இல்லாமல் 100% நேரடி வாடிக்கையாளர் முன்பதிவுகள்.",
        "te": "మధ్యవర్తి కమీషన్ లేకుండా నేరుగా కస్టమర్ బుకింగ్‌లు.",
        "kn": "ಮಧ್ಯವರ್ತಿ ಕಮಿಷನ್ ಇಲ್ಲದೆ ನೇರ ಗ್ರಾಹಕರ ಬುಕಿಂಗ್‌ಗಳು.",
        "ml": "ഇടനിലക്കാരുടെ കമ്മീഷനില്ലാതെ നേരിട്ടുള്ള കസ്റ്റമർ ബുക്കിംഗുകൾ.",
    },
    "select_language_title": {
        "en": "Select Language",
        "hi": "भाषा चुनें",
        "ta": "மொழியைத் தேர்ந்தெடுக்கவும்",
        "te": "భాషను ఎంచుకోండి",
        "kn": "ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ",
        "ml": "ഭാഷ തിരഞ്ഞെടുക്കുക",
    },
    "hours_daily_label": {
        "en": "Hours Daily Availability",
        "hi": "घंटे दैनिक उपलब्धता",
        "ta": "மணிநேரம் தினசரி கிடைக்கும் நேரம்",
        "te": "గంటలు రోజువారీ అందుబాటు",
        "kn": "ಗಂಟೆಗಳು ದೈನಂದಿನ ಲಭ್ಯತೆ",
        "ml": "മണിക്കൂർ പ്രതിദിന ലഭ്യത",
    },
    "btn_skip": {
        "en": "Skip",
        "hi": "छोड़ें",
        "ta": "தவிர்",
        "te": "దాటవేయి",
        "kn": "ಬಿಟ್ಟುಬಿಡಿ",
        "ml": "ഒഴിവാക്കുക",
    },
    "btn_accept": {
        "en": "Accept",
        "hi": "स्वीकार करें",
        "ta": "ஏற்கவும்",
        "te": "అంగీకరించు",
        "kn": "ಸ್ವೀಕರಿಸಿ",
        "ml": "സ്വീകരിക്കുക",
    },
    "btn_accepted": {
        "en": "Accepted",
        "hi": "स्वीकृत",
        "ta": "ஏற்கப்பட்டது",
        "te": "అంగీకరించబడింది",
        "kn": "ಸ್ವೀಕರಿಸಲಾಗಿದೆ",
        "ml": "സ്വീകരിച്ചു",
    },
    "btn_remove": {
        "en": "Remove",
        "hi": "हटाएं",
        "ta": "நீக்கு",
        "te": "తొలగించు",
        "kn": "ತೆಗೆದುಹಾಕಿ",
        "ml": "നീക്കംചെയ്യുക",
    },
    "trade_accepted_badge": {
        "en": "Added to Profile",
        "hi": "प्रोफ़ाइल में जोड़ा गया",
        "ta": "சுயவிவரத்தில் சேர்க்கப்பட்டது",
        "te": "ప్రొఫైల్‌కు జోడించబడింది",
        "kn": "ಪ್ರೊಫೈಲ್‌ಗೆ ಸೇರಿಸಲಾಗಿದೆ",
        "ml": "പ്രൊഫൈലിൽ ചേർത്തു",
    },
}

def main():
    if not os.path.exists(LANG_DIR):
        print(f"Error: {LANG_DIR} does not exist")
        return

    files = [f for f in os.listdir(LANG_DIR) if f.endswith(".json")]
    print(f"Found {len(files)} language files.")

    for f in sorted(files):
        lang_code = f.replace(".json", "")
        file_path = os.path.join(LANG_DIR, f)

        try:
            with open(file_path, "r", encoding="utf-8") as fp:
                data = json.load(fp)
        except Exception as e:
            print(f"Error reading {f}: {e}")
            continue

        updated = False
        for key, trans in KEYS.items():
            val = trans.get(lang_code, trans["en"])
            if key not in data or data[key] != val:
                data[key] = val
                updated = True

        if updated:
            with open(file_path, "w", encoding="utf-8") as fp:
                json.dump(data, fp, ensure_ascii=False, indent=2)
            print(f"Updated {f}")
        else:
            print(f"No change for {f}")

if __name__ == "__main__":
    main()
