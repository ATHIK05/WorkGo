# -*- coding: utf-8 -*-
"""
Sync Hero Headline translation keys across all 23 language JSON files
in packages/workgo_core/assets/lang/
"""

import os
import json

LANG_DIR = os.path.join(os.path.dirname(__file__), "assets", "lang")

HERO_TRANSLATIONS = {
    "en": {
        "hero_headline_line1": "We connect you to your",
        "hero_headline_dream": "dream",
        "hero_headline_artisan": "artisan",
    },
    "hi": {
        "hero_headline_line1": "हम आपको जोड़ते हैं आपके",
        "hero_headline_dream": "सपनों के",
        "hero_headline_artisan": "कारीगर से",
    },
    "ta": {
        "hero_headline_line1": "நாங்கள் உங்களை இணைக்கிறோம் உங்கள்",
        "hero_headline_dream": "கனவு",
        "hero_headline_artisan": "கைவினைஞருடன்",
    },
    "te": {
        "hero_headline_line1": "మేము మిమ్మల్ని అనుసంధానిస్తున్నాం మీ",
        "hero_headline_dream": "కలల",
        "hero_headline_artisan": "చేతివృత్తి నిపుణుడితో",
    },
    "kn": {
        "hero_headline_line1": "ನಾವು ನಿಮ್ಮನ್ನು ಸಂಪರ್ಕಿಸುತ್ತೇವೆ ನಿಮ್ಮ",
        "hero_headline_dream": "ಕನಸಿನ",
        "hero_headline_artisan": "ಕುಶಲಕರ್ಮಿಯೊಂದಿಗೆ",
    },
    "ml": {
        "hero_headline_line1": "ഞങ്ങൾ നിങ്ങളെ ബന്ധിപ്പിക്കുന്നു നിങ്ങളുടെ",
        "hero_headline_dream": "സ്വപ്ന",
        "hero_headline_artisan": "വിദഗ്ദ്ധ തൊഴിലാളിയുമായി",
    },
    "bn": {
        "hero_headline_line1": "আমরা আপনাকে যুক্ত করি আপনার",
        "hero_headline_dream": "স্বপ্নের",
        "hero_headline_artisan": "কারিগরদের সাথে",
    },
    "mr": {
        "hero_headline_line1": "आम्ही तुम्हाला जोडतो तुमच्या",
        "hero_headline_dream": "स्वप्नातील",
        "hero_headline_artisan": "कारागिराशी",
    },
    "gu": {
        "hero_headline_line1": "અમે તમને જોડીએ છીએ તમારા",
        "hero_headline_dream": "સ્વપ્ન",
        "hero_headline_artisan": "કારીગર સાથે",
    },
    "pa": {
        "hero_headline_line1": "ਅਸੀਂ ਤੁਹਾਨੂੰ ਜੋੜਦੇ ਹਾਂ ਤੁਹਾਡੇ",
        "hero_headline_dream": "ਸੁਪਨਿਆਂ ਦੇ",
        "hero_headline_artisan": "ਕਾਰੀਗਰ ਨਾਲ",
    },
    "or": {
        "hero_headline_line1": "ଆମେ ଆପଣଙ୍କୁ ଯୋଡ଼ୁ ଆପଣଙ୍କ",
        "hero_headline_dream": "ସ୍ୱପ୍ନର",
        "hero_headline_artisan": "କାରିଗରଙ୍କ ସହିତ",
    },
    "as": {
        "hero_headline_line1": "আমি আপোনাক সংযোগ কৰোঁ আপোনাৰ",
        "hero_headline_dream": "সপোনৰ",
        "hero_headline_artisan": "শিল্পীৰ সৈতে",
    },
    "ur": {
        "hero_headline_line1": "ہم آپ کو جوڑتے ہیں آپ کے",
        "hero_headline_dream": "خوابوں کے",
        "hero_headline_artisan": "کاریگر سے",
    },
    "sa": {
        "hero_headline_line1": "वयं योजयामः भवतः",
        "hero_headline_dream": "स्वप्न",
        "hero_headline_artisan": "शिल्पिना सह",
    },
    "kok": {
        "hero_headline_line1": "आमी तुंकां जोडता तुमच्या",
        "hero_headline_dream": "स्वप्नांतल्या",
        "hero_headline_artisan": "कारागिराकडेन",
    },
    "ks": {
        "hero_headline_line1": "أمہِ چھِ رلاوان تۄہندِس",
        "hero_headline_dream": "خوابن ہندِ",
        "hero_headline_artisan": "کاریگرَس سیتھ",
    },
    "ne": {
        "hero_headline_line1": "हामी तपाईंलाई जोड्छौं तपाईंको",
        "hero_headline_dream": "सपनाको",
        "hero_headline_artisan": "कारीगरसँग",
    },
    "sd": {
        "hero_headline_line1": "اسان اوهان کي ڳنڍيون ٿا اوهان جي",
        "hero_headline_dream": "سپنن جي",
        "hero_headline_artisan": "ڪاريگر سان",
    },
    "doi": {
        "hero_headline_line1": "अस्स तुसेंगी जोड़दे आं तुहांदे",
        "hero_headline_dream": "सपनें दे",
        "hero_headline_artisan": "कारीगर कन्नै",
    },
    "mai": {
        "hero_headline_line1": "हम अहाँकेँ जोड़ैत छी अहाँक",
        "hero_headline_dream": "सपनाक",
        "hero_headline_artisan": "कारीगर सँ",
    },
    "mni": {
        "hero_headline_line1": "ঐখোয়না নখোয়বু শমলহলি নখোয়গী",
        "hero_headline_dream": "মংলানগী",
        "hero_headline_artisan": "হৈশিংবা মীগা",
    },
    "sat": {
        "hero_headline_line1": "ᱟᱞᱮ ᱟᱢ ᱞᱮ ᱡᱚᱲᱟᱣᱮᱫ ᱢᱮᱭᱟ ᱟᱢᱟᱜ",
        "hero_headline_dream": "ᱠᱩᱠᱢᱩ",
        "hero_headline_artisan": "ᱠᱟᱹᱨᱤᱜᱚᱞ ᱥᱟᱶ",
    },
    "brx": {
        "hero_headline_line1": "जों नोंखौ खौसे खालामो नोंनि",
        "hero_headline_dream": "सिमांनि",
        "hero_headline_artisan": "फावदांब्राजों",
    },
}

def sync():
    count = 0
    for code, keys in HERO_TRANSLATIONS.items():
        json_path = os.path.join(LANG_DIR, f"{code}.json")
        if not os.path.exists(json_path):
            print(f"[WARN] {json_path} does not exist, skipping.")
            continue
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            print(f"[ERROR] Failed to load {json_path}: {e}")
            continue

        for k, v in keys.items():
            data[k] = v

        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        count += 1
        print(f"[OK] Updated {code}.json with {len(keys)} hero headline keys.")

    print(f"\nDone! Successfully updated {count} language files.")

if __name__ == "__main__":
    sync()
