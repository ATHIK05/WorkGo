import os
import subprocess
from gtts import gTTS

LOCAL_DIR = os.path.join(os.path.dirname(__file__), "..", "sounds")
WSL_DIR = "/var/lib/asterisk/sounds/workgo"

os.makedirs(LOCAL_DIR, exist_ok=True)

PROMPTS = [
    # ── Language Selection Menu (English) ────────────────────────────────────
    {
        "name": "select_language_en",
        "lang": "en",
        "text": "Welcome to WorkGo. Please choose your language. Press 1 for Tamil, 2 for Hindi, 3 for Telugu, 4 for Kannada, 5 for Malayalam, 6 for Bengali, 7 for Marathi, 8 for Gujarati, 9 for Punjabi, or 0 for English."
    },

    # ── English (0) ─────────────────────────────────────────────────────────
    {
        "name": "ask_name_en",
        "lang": "en",
        "text": "Please speak your full name after the tone."
    },
    {
        "name": "ask_location_en",
        "lang": "en",
        "text": "Please speak your city or local area after the tone."
    },
    {
        "name": "ask_pincode_en",
        "lang": "en",
        "text": "Please enter your six-digit area pincode on your phone keypad."
    },
    {
        "name": "ask_trade_desc_en",
        "lang": "en",
        "text": "Please speak what work you do, such as plumbing, electrical, or carpentry, and describe your skills in detail after the tone."
    },
    {
        "name": "registration_done_en",
        "lang": "en",
        "text": "Thank you! Your registration and work details have been saved. A nearby Karya Mitra and admin will contact you soon for verification."
    },

    # ── Tamil (1) ────────────────────────────────────────────────────────────
    {
        "name": "ask_name_ta",
        "lang": "ta",
        "text": "பீப் ஒலிக்கு பிறகு உங்கள் முழு பெயரை தெளிவாக கூறவும்."
    },
    {
        "name": "ask_location_ta",
        "lang": "ta",
        "text": "பீப் ஒலிக்கு பிறகு உங்கள் ஊர் அல்லது பகுதியை கூறவும்."
    },
    {
        "name": "ask_pincode_ta",
        "lang": "ta",
        "text": "உங்கள் பகுதியின் ஆறு இலக்க பின்கோடை டயல் செய்யவும்."
    },
    {
        "name": "ask_trade_desc_ta",
        "lang": "ta",
        "text": "நீங்கள் என்ன வேலை செய்கிறீர்கள், பிளம்பிங், எலக்ட்ரிக்கல், அல்லது தச்சு வேலை, மற்றும் உங்கள் அனுபவத்தை விரிவாக கூறவும்."
    },
    {
        "name": "registration_done_ta",
        "lang": "ta",
        "text": "நன்றி! உங்கள் விவரங்கள் பதிவு செய்யப்பட்டுள்ளன. சரிபார்ப்பிற்காக ஒரு கார்ய மித்ரா விரைவில் உங்களைத் தொடர்புகொள்வார்."
    },

    # ── Hindi (2) ────────────────────────────────────────────────────────────
    {
        "name": "ask_name_hi",
        "lang": "hi",
        "text": "बीप के बाद कृपया अपना पूरा नाम बताएं।"
    },
    {
        "name": "ask_location_hi",
        "lang": "hi",
        "text": "बीप के बाद अपने शहर या इलाके का नाम बताएं।"
    },
    {
        "name": "ask_pincode_hi",
        "lang": "hi",
        "text": "कृपया अपने इलाके का 6 अंकों का पिनकोड डायल करें।"
    },
    {
        "name": "ask_trade_desc_hi",
        "lang": "hi",
        "text": "आप क्या काम करते हैं, जैसे प्लम्बर, इलेक्ट्रीशियन, या बढ़ई, और अपने काम व अनुभव का विवरण विस्तार से बताएं।"
    },
    {
        "name": "registration_done_hi",
        "lang": "hi",
        "text": "धन्यवाद! आपका पंजीकरण और कार्य विवरण दर्ज हो गया है। एक कार्या मित्र और एडमिन जल्द ही आपसे वेरिफिकेशन के लिए संपर्क करेंगे।"
    },

    # ── Telugu (3) ───────────────────────────────────────────────────────────
    {
        "name": "ask_name_te",
        "lang": "te",
        "text": "బీప్ తర్వాత దయచేసి మీ పూర్తి పేరు చెప్పండి."
    },
    {
        "name": "ask_location_te",
        "lang": "te",
        "text": "బీప్ తర్వాత మీ నగరం లేదా ప్రాంతం పేరు చెప్పండి."
    },
    {
        "name": "ask_pincode_te",
        "lang": "te",
        "text": "దయచేసి మీ ప్రాంతం యొక్క ఆరు అంకెల పిన్‌కోడ్‌ను డయల్ చేయండి."
    },
    {
        "name": "ask_trade_desc_te",
        "lang": "te",
        "text": "మీరు ఏమి పని చేస్తారు, ప్లంబింగ్, ఎలక్ట్రికల్, లేదా వడ్రంగి పని, మరియు మీ అనుభవాన్ని వివరంగా చెప్పండి."
    },
    {
        "name": "registration_done_te",
        "lang": "te",
        "text": "ధన్యవాదాలు! మీ వివరాలు నమోదు చేయబడ్డాయి. ధృవీకరణ కోసం ఒక కార్య మిత్ర త్వరలోనే మిమ్మల్ని సంప్రదిస్తారు."
    },

    # ── Kannada (4) ──────────────────────────────────────────────────────────
    {
        "name": "ask_name_kn",
        "lang": "kn",
        "text": "ಬೀಪ್ ನಂತರ ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪೂರ್ಣ ಹೆಸರನ್ನು ತಿಳಿಸಿ."
    },
    {
        "name": "ask_location_kn",
        "lang": "kn",
        "text": "ಬೀಪ್ ನಂತರ ನಿಮ್ಮ ಊರು ಅಥವಾ ಪ್ರದೇಶವನ್ನು ತಿಳಿಸಿ."
    },
    {
        "name": "ask_pincode_kn",
        "lang": "kn",
        "text": "ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪ್ರದೇಶದ 6 ಅಂಕಿಯ ಪಿನ್‌ಕೋಡ್ ನಮೂದಿಸಿ."
    },
    {
        "name": "ask_trade_desc_kn",
        "lang": "kn",
        "text": "ನೀವು ಯಾವ ಕೆಲಸ ಮಾಡುತ್ತೀರಿ, ಪ್ಲಂಬಿಂಗ್, ಎಲೆಕ್ಟ್ರಿಕಲ್, ಅಥವಾ ಬಡಗಿ ಕೆಲಸ, ಮತ್ತು ನಿಮ್ಮ ಅನುಭವವನ್ನು ವಿವರವಾಗಿ ತಿಳಿಸಿ."
    },
    {
        "name": "registration_done_kn",
        "lang": "kn",
        "text": "ಧನ್ಯವಾದಗಳು! ನಿಮ್ಮ ವಿವರಗಳು ದಾಖಲಾಗಿವೆ. ಪರಿಶೀಲನೆಗಾಗಿ ಕಾರ್ಯ ಮಿತ್ರ ಶೀಘ್ರದಲ್ಲೇ ನಿಮ್ಮನ್ನು ಸಂಪರ್ಕಿಸುತ್ತಾರೆ."
    },

    # ── Malayalam (5) ────────────────────────────────────────────────────────
    {
        "name": "ask_name_ml",
        "lang": "ml",
        "text": "ബീപ്പിന് ശേഷം ദയവായി നിങ്ങളുടെ പൂർണ്ണ പേര് പറയുക."
    },
    {
        "name": "ask_location_ml",
        "lang": "ml",
        "text": "ബീപ്പിന് ശേഷം നിങ്ങളുടെ നഗരമോ സ്ഥലമോ പറയുക."
    },
    {
        "name": "ask_pincode_ml",
        "lang": "ml",
        "text": "ദയവായി നിങ്ങളുടെ പ്രദേശത്തെ 6 അക്ക പിൻകോഡ് ഡയൽ ചെയ്യുക."
    },
    {
        "name": "ask_trade_desc_ml",
        "lang": "ml",
        "text": "നിങ്ങൾ എന്ത് ജോലിയാണ് ചെയ്യുന്നത്, പ്ലംബിംഗ്, ഇലക്ട്രിക്കൽ, അല്ലെങ്കിൽ ആശാരിപ്പണി, നിങ്ങളുടെ അനുഭവങ്ങൾ വിശദമായി പറയുക."
    },
    {
        "name": "registration_done_ml",
        "lang": "ml",
        "text": "നന്ദി! നിങ്ങളുടെ വിവരങ്ങൾ രേഖപ്പെടുത്തിയിട്ടുണ്ട്. സ്ഥിരീകരണത്തിനായി ഒരു കാര്യ മിത്ര ഉടൻ നിങ്ങളെ ബന്ധപ്പെടും."
    },

    # ── Bengali (6) ──────────────────────────────────────────────────────────
    {
        "name": "ask_name_bn",
        "lang": "bn",
        "text": "বীপের পর অনুগ্রহ করে আপনার পুরো নাম বলুন।"
    },
    {
        "name": "ask_location_bn",
        "lang": "bn",
        "text": "বীপের পর আপনার শহর বা এলাকার নাম বলুন।"
    },
    {
        "name": "ask_pincode_bn",
        "lang": "bn",
        "text": "অনুগ্রহ করে আপনার এলাকার ছয় ডিজিটের পিনকোড ডায়াল করুন।"
    },
    {
        "name": "ask_trade_desc_bn",
        "lang": "bn",
        "text": "আপনি কি কাজ করেন, যেমন প্লাম্বিং, ইলেকট্রিক্যাল বা ছুতারের কাজ, এবং আপনার অভিজ্ঞতার কথা বিস্তারিত বলুন।"
    },
    {
        "name": "registration_done_bn",
        "lang": "bn",
        "text": "ধন্যবাদ! আপনার বিবরণ রেকর্ড করা হয়েছে। যাচাইকরণের জন্য একজন কার্য মিত্র শীঘ্রই আপনার সাথে যোগাযোগ করবেন।"
    },

    # ── Marathi (7) ──────────────────────────────────────────────────────────
    {
        "name": "ask_name_mr",
        "lang": "mr",
        "text": "बीप नंतर कृपया आपले पूर्ण नाव सांगा."
    },
    {
        "name": "ask_location_mr",
        "lang": "mr",
        "text": "बीप नंतर आपल्या शहराचे किंवा परिसराचे नाव सांगा."
    },
    {
        "name": "ask_pincode_mr",
        "lang": "mr",
        "text": "कृपया आपल्या परिसराचा ६ अंकी पिनकोड डायल करा."
    },
    {
        "name": "ask_trade_desc_mr",
        "lang": "mr",
        "text": "तुम्ही कोणते काम करता, जसे प्लम्बर, इलेक्ट्रिशियन, किंवा सुतारकाम, आणि आपल्या अनुभवाबद्दल सविस्तर सांगा."
    },
    {
        "name": "registration_done_mr",
        "lang": "mr",
        "text": "धन्यवाद! आपली नोंदणी पूर्ण झाली आहे. पडताळणीसाठी एक कार्य मित्र लवकरच आपल्याशी संपर्क करेल."
    },

    # ── Gujarati (8) ─────────────────────────────────────────────────────────
    {
        "name": "ask_name_gu",
        "lang": "gu",
        "text": "બીપ પછી કૃપા કરીને તમારું પૂરું નામ બોલો."
    },
    {
        "name": "ask_location_gu",
        "lang": "gu",
        "text": "બીપ પછી તમારા શહેર અથવા વિસ્તારનું નામ બોલો."
    },
    {
        "name": "ask_pincode_gu",
        "lang": "gu",
        "text": "કૃપા કરીને તમારા વિસ્તારનો 6 અંકનો પિનકોડ ડાયલ કરો."
    },
    {
        "name": "ask_trade_desc_gu",
        "lang": "gu",
        "text": "તમે શું કામ કરો છો, જેમ કે પ્લમ્બિંગ, ઇલેક્ટ્રિકલ, અથવા સુથારી કામ, અને તમારા અનુભવ વિશે વિગતવાર જણાવો."
    },
    {
        "name": "registration_done_gu",
        "lang": "gu",
        "text": "આભાર! તમારી વિગતો નોંધાઈ ગઈ છે. વેરિફિકેશન માટે કાર્ય મિત્ર ટૂંક સમયમાં તમારો સંપર્ક કરશે."
    },

    # ── Punjabi (9) ──────────────────────────────────────────────────────────
    {
        "name": "ask_name_pa",
        "lang": "pa",
        "text": "ਬੀਪ ਤੋਂ ਬਾਅਦ ਕਿਰਪਾ ਕਰਕੇ ਆਪਣਾ ਪੂਰਾ ਨਾਮ ਦੱਸੋ।"
    },
    {
        "name": "ask_location_pa",
        "lang": "pa",
        "text": "ਬੀਪ ਤੋਂ ਬਾਅਦ ਆਪਣੇ ਸ਼ਹਿਰ ਜਾਂ ਇਲਾਕੇ ਦਾ ਨਾਮ ਦੱਸੋ।"
    },
    {
        "name": "ask_pincode_pa",
        "lang": "pa",
        "text": "ਕਿਰਪਾ ਕਰਕੇ ਆਪਣੇ ਇਲਾਕੇ ਦਾ 6 ਅੰਕਾਂ ਦਾ ਪਿਨਕੋਡ ਡਾਇਲ ਕਰੋ।"
    },
    {
        "name": "ask_trade_desc_pa",
        "lang": "pa",
        "text": "ਤੁਸੀਂ ਕੀ ਕੰਮ ਕਰਦੇ ਹੋ, ਜਿਵੇਂ ਪਲੰਬਿੰਗ, ਇਲੈਕਟ੍ਰੀਕਲ, ਜਾਂ ਤਰਖਾਣ ਦਾ ਕੰਮ, ਅਤੇ ਆਪਣੇ ਤਜ਼ਰਬੇ ਬਾਰੇ ਵਿਸਥਾਰ ਵਿੱਚ ਦੱਸੋ।"
    },
    {
        "name": "registration_done_pa",
        "lang": "pa",
        "text": "ਧੰਨਵਾਦ! ਤੁਹਾਡਾ ਵੇਰਵਾ ਦਰਜ ਕਰ ਲਿਆ ਗਿਆ ਹੈ। ਵੈਰੀਫਿਕੇਸ਼ਨ ਲਈ ਇੱਕ ਕਾਰਜ ਮਿੱਤਰ ਜਲਦੀ ਹੀ ਤੁਹਾਡੇ ਨਾਲ ਸੰਪਰਕ ਕਰੇਗਾ।"
    }
]

print(f"Synthesizing {len(PROMPTS)} multilingual IVR voice prompts...")
for i, p in enumerate(PROMPTS, start=1):
    name = p["name"]
    text = p["text"]
    lang = p["lang"]
    
    mp3_path = os.path.join(LOCAL_DIR, f"{name}.mp3")
    wav_path = os.path.join(LOCAL_DIR, f"{name}.wav")
    
    print(f"[{i}/{len(PROMPTS)}] Generating {name} ({lang})...")
    tts = gTTS(text=text, lang=lang, slow=False)
    tts.save(mp3_path)
    
    # Convert MP3 to standard Asterisk telephony WAV (8000Hz, 16-bit, Mono PCM)
    cmd = f'wsl ffmpeg -y -i "$(wslpath "{mp3_path}")" -ar 8000 -ac 1 -acodec pcm_s16le /var/lib/asterisk/sounds/workgo/{name}.wav'
    subprocess.run(cmd, shell=True, check=True)

print("All multilingual IVR audio files generated and loaded into Asterisk!")
