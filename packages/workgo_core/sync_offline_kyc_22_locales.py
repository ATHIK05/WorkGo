# -*- coding: utf-8 -*-
"""
WorkGo Offline Artisan & KYC Gating — 22 Official Scheduled Indian Languages + English
Comprehensive Localization Synchronizer
"""

import json
import os
import sys

LANG_DIR = r"d:\WorkGo\packages\workgo_core\assets\lang"

translations = {
    "en": {
        "artisan_offline_status": "Offline",
        "artisan_online_status": "Live & Available",
        "artisan_offline_reassurance": "Currently offline. They will receive your booking once they come live.",
        "artisan_offline_schedule_action": "Schedule / Reserve",
        "artisan_offline_notice_title": "Artisan Currently Offline",
        "artisan_offline_notice_desc": "This artisan is off-duty. Confirm now and they will receive your request upon coming live, or pick a scheduled appointment slot.",
        "artisan_offline_queue_hint": "Receives request when live",
        "artisan_online_instant_action": "Book Live Dispatch",
    },
    "hi": {
        "artisan_offline_status": "ऑफलाइन",
        "artisan_online_status": "सक्रिय और उपलब्ध",
        "artisan_offline_reassurance": "वर्तमान में ऑफलाइन हैं। लाइव आते ही उन्हें आपकी बुकिंग प्राप्त हो जाएगी।",
        "artisan_offline_schedule_action": "समय निर्धारित करें / आरक्षित करें",
        "artisan_offline_notice_title": "कारीगर वर्तमान में ऑफलाइन हैं",
        "artisan_offline_notice_desc": "यह कारीगर अभी सेवा में नहीं हैं। अभी पुष्टि करें और लाइव आते ही उन्हें आपका अनुरोध मिल जाएगा, या कोई निर्धारित समय चुनें।",
        "artisan_offline_queue_hint": "लाइव होने पर अनुरोध प्राप्त होगा",
        "artisan_online_instant_action": "लाइव सेवा बुक करें",
    },
    "ta": {
        "artisan_offline_status": "ஆஃப்லைன்",
        "artisan_online_status": "நேரலை மற்றும் கிடைக்கிறது",
        "artisan_offline_reassurance": "தற்போது ஆஃப்லைனில் உள்ளார். நேரலைக்கு வந்தவுடன் உங்கள் முன்பதிவு அவருக்கு சென்றுவிடும்.",
        "artisan_offline_schedule_action": "முன்பதிவு / நேரம் ஒதுக்கு",
        "artisan_offline_notice_title": "தொழிலாளி தற்போது ஆஃப்லைனில் உள்ளார்",
        "artisan_offline_notice_desc": "இந்த தொழிலாளி தற்போது பணியில் இல்லை. இப்போது உறுதிப்படுத்தினால் அவர் நேரலை வந்ததும் கோரிக்கை சென்றுவிடும், அல்லது முன்பதிவு நேரத்தைத் தேர்வுசெய்யவும்.",
        "artisan_offline_queue_hint": "நேரலை வரும்போது கோரிக்கை செல்லும்",
        "artisan_online_instant_action": "நேரலை சேவையை முன்பதிவு செய்",
    },
    "te": {
        "artisan_offline_status": "ఆఫ్‌లైన్",
        "artisan_online_status": "లైవ్ & అందుబాటులో ఉంది",
        "artisan_offline_reassurance": "ప్రస్తుతం ఆఫ్‌లైన్‌లో ఉన్నారు. లైవ్‌లోకి రాగానే మీ బుకింగ్ వారికి చేరుతుంది.",
        "artisan_offline_schedule_action": "షెడ్యూల్ / రిజర్వ్ చేయండి",
        "artisan_offline_notice_title": "కళాకారుడు ప్రస్తుతం ఆఫ్‌లైన్‌లో ఉన్నారు",
        "artisan_offline_notice_desc": "ఈ కళాకారుడు ప్రస్తుతం విధుల్లో లేరు. ఇప్పుడే నిర్ధారించండి, వారు లైవ్‌లోకి రాగానే మీ అభ్యర్థన అందుతుంది, లేదా షెడ్యూల్ స్లాట్ ఎంచుకోండి.",
        "artisan_offline_queue_hint": "లైవ్ వచ్చినప్పుడు అభ్యర్థన అందుతుంది",
        "artisan_online_instant_action": "లైవ్ సేవను బుక్ చేయండి",
    },
    "kn": {
        "artisan_offline_status": "ಆಫ್‌ಲೈನ್",
        "artisan_online_status": "ಲೈವ್ ಮತ್ತು ಲಭ್ಯವಿದೆ",
        "artisan_offline_reassurance": "ಪ್ರಸ್ತುತ ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದಾರೆ. ಲೈವ್‌ಗೆ ಬಂದ ತಕ್ಷಣ ನಿಮ್ಮ ಬುಕಿಂಗ್ ಅವರಿಗೆ ತಲುಪುತ್ತದೆ.",
        "artisan_offline_schedule_action": "ವೇಳಾಪಟ್ಟಿ / ಕಾಯ್ದಿರಿಸಿ",
        "artisan_offline_notice_title": "ಕುಶಲಕರ್ಮಿ ಪ್ರಸ್ತುತ ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದಾರೆ",
        "artisan_offline_notice_desc": "ಈ ಕುಶಲಕರ್ಮಿ ಪ್ರಸ್ತುತ ಕರ್ತವ್ಯದಲ್ಲಿಲ್ಲ. ಈಗ ದೃಢೀಕರಿಸಿ, ಅವರು ಲೈವ್‌ಗೆ ಬಂದ ತಕ್ಷಣ ನಿಮ್ಮ ವಿನಂತಿ ತಲುಪುತ್ತದೆ, ಅಥವಾ ನಿಗದಿತ ಸ್ಲಾಟ್ ಆಯ್ಕೆಮಾಡಿ.",
        "artisan_offline_queue_hint": "ಲೈವ್ ಬಂದಾಗ ವಿನಂತಿ ತಲುಪುತ್ತದೆ",
        "artisan_online_instant_action": "ಲೈವ್ ಸೇವೆ ಬುಕ್ ಮಾಡಿ",
    },
    "ml": {
        "artisan_offline_status": "ഓഫ്‌ലൈൻ",
        "artisan_online_status": "ലൈവ് & ലഭ്യമാണ്",
        "artisan_offline_reassurance": "നിലവിൽ ഓഫ്‌ലൈനിലാണ്. ലൈവിൽ വരുന്ന ഉടൻ നിങ്ങളുടെ ബുക്കിംഗ് ലഭിക്കും.",
        "artisan_offline_schedule_action": "ഷെഡ്യൂൾ / റിസർവ് ചെയ്യുക",
        "artisan_offline_notice_title": "തൊഴിലാളി നിലവിൽ ഓഫ്‌ലൈനിലാണ്",
        "artisan_offline_notice_desc": "ഈ തൊഴിലാളി ഇപ്പോൾ ഡ്യൂട്ടിയിലല്ല. ഇപ്പോൾ സ്ഥിരീകരിച്ചാൽ ലൈവിൽ വരുമ്പോൾ അപേക്ഷ ലഭിക്കും, അല്ലെങ്കിൽ ഷെഡ്യൂൾ ചെയ്ത സ്ലോട്ട് തിരഞ്ഞെടുക്കുക.",
        "artisan_offline_queue_hint": "ലൈവ് വരുമ്പോൾ അപേക്ഷ ലഭിക്കും",
        "artisan_online_instant_action": "ലൈവ് സേവനം ബുക്ക് ചെയ്യുക",
    },
    "mr": {
        "artisan_offline_status": "ऑफलाइन",
        "artisan_online_status": "थेट आणि उपलब्ध",
        "artisan_offline_reassurance": "सध्या ऑफलाइन आहेत. लाइव्ह आल्यावर त्यांना तुमचे बुकिंग प्राप्त होईल.",
        "artisan_offline_schedule_action": "वेळ ठरवा / राखीव करा",
        "artisan_offline_notice_title": "कारागीर सध्या ऑफलाइन आहेत",
        "artisan_offline_notice_desc": "हे कारागीर सध्या कर्तव्यावर नाहीत. आता पुष्टी करा, ते लाइव्ह आल्यावर त्यांना विनंती मिळेल किंवा नियोजित वेळ निवडा.",
        "artisan_offline_queue_hint": "लाइव्ह आल्यावर विनंती मिळेल",
        "artisan_online_instant_action": "थेट सेवा बुक करा",
    },
    "bn": {
        "artisan_offline_status": "অফলাইন",
        "artisan_online_status": "লাইভ এবং উপলব্ধ",
        "artisan_offline_reassurance": "বর্তমানে অফলাইনে আছেন। লাইভে এলেই তারা আপনার বুকিং পাবেন।",
        "artisan_offline_schedule_action": "সময়সূচী / সংরক্ষণ করুন",
        "artisan_offline_notice_title": "কারিগর বর্তমানে অফলাইনে আছেন",
        "artisan_offline_notice_desc": "এই কারিগর বর্তমানে দায়িত্বে নেই। এখনই নিশ্চিত করুন এবং লাইভে এলেই অনুরোধ পাবেন, অথবা নির্ধারিত স্লট বেছে নিন।",
        "artisan_offline_queue_hint": "লাইভে এলে অনুরোধ পাবেন",
        "artisan_online_instant_action": "লাইভ পরিষেবা বুক করুন",
    },
    "gu": {
        "artisan_offline_status": "ઑફલાઇન",
        "artisan_online_status": "લાઇવ અને ઉપલબ્ધ",
        "artisan_offline_reassurance": "હાલમાં ઑફલાઇન છે. લાઇવ આવતા જ તેમને તમારું બુકિંગ મળી જશે.",
        "artisan_offline_schedule_action": "સમય નક્કી કરો / આરક્ષિત કરો",
        "artisan_offline_notice_title": "કારીગર હાલમાં ઑફલાઇન છે",
        "artisan_offline_notice_desc": "આ કારીગર હાલ ફરજ પર નથી. હમણાં પુષ્ટિ કરો અને તેઓ લાઇવ આવતા જ તેમને વિનંતી મળશે, અથવા નિર્ધારિત સમય પસંદ કરો.",
        "artisan_offline_queue_hint": "લાઇવ આવશે ત્યારે વિનંતી મળશે",
        "artisan_online_instant_action": "લાઇવ સેવા બુક કરો",
    },
    "pa": {
        "artisan_offline_status": "ਔਫਲਾਈਨ",
        "artisan_online_status": "ਲਾਈਵ ਅਤੇ ਉਪਲਬਧ",
        "artisan_offline_reassurance": "ਇਸ ਵੇਲੇ ਔਫਲਾਈਨ ਹਨ। ਲਾਈਵ ਹੁੰਦਿਆਂ ਹੀ ਉਨ੍ਹਾਂ ਨੂੰ ਤੁਹਾਡੀ ਬੁਕਿੰਗ ਮਿਲ ਜਾਵੇਗੀ।",
        "artisan_offline_schedule_action": "ਸਮਾਂ ਨਿਰਧਾਰਤ ਕਰੋ / ਰਾਖਵਾਂ ਕਰੋ",
        "artisan_offline_notice_title": "ਕਾਰੀਗਰ ਇਸ ਵੇਲੇ ਔਫਲਾਈਨ ਹਨ",
        "artisan_offline_notice_desc": "ਇਹ ਕਾਰੀਗਰ ਇਸ ਵੇਲੇ ਡਿਊਟੀ 'ਤੇ ਨਹੀਂ ਹਨ। ਹੁਣੇ ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਲਾਈਵ ਹੋਣ 'ਤੇ ਉਨ੍ਹਾਂ ਨੂੰ ਬੇਨਤੀ ਮਿਲੇਗੀ, ਜਾਂ ਤੈਅ ਸਮਾਂ ਚੁਣੋ।",
        "artisan_offline_queue_hint": "ਲਾਈਵ ਹੋਣ 'ਤੇ ਬੇਨਤੀ ਮਿਲੇਗੀ",
        "artisan_online_instant_action": "ਲਾਈਵ ਸੇਵਾ ਬੁੱਕ ਕਰੋ",
    },
    "or": {
        "artisan_offline_status": "ଅଫଲାଇନ୍",
        "artisan_online_status": "ଲାଇଭ୍ ଏବଂ ଉପଲବ୍ଧ",
        "artisan_offline_reassurance": "ବର୍ତ୍ତମାନ ଅଫଲାଇନ୍ ଅଛନ୍ତି | ଲାଇଭ୍ ଆସିବା ମାତ୍ରେ ସେମାନେ ଆପଣଙ୍କ ବୁକିଂ ପାଇବେ |",
        "artisan_offline_schedule_action": "ସମୟ ନିର୍ଦ୍ଧାରଣ / ସଂରକ୍ଷଣ କରନ୍ତୁ",
        "artisan_offline_notice_title": "କାରିଗର ବର୍ତ୍ତମାନ ଅଫଲାଇନ୍ ଅଛନ୍ତି",
        "artisan_offline_notice_desc": "ଏହି କାରିଗର ବର୍ତ୍ତମାନ ଡ୍ୟୁଟିରେ ନାହାଁନ୍ତି | ବର୍ତ୍ତମାନ ନିଶ୍ଚିତ କରନ୍ତୁ ଏବଂ ସେମାନେ ଲାଇଭ୍ ଆସିବା ପରେ ଅନୁରୋଧ ପାଇବେ, କିମ୍ବା ଏକ ନିର୍ଦ୍ଧାରିତ ସ୍ଲଟ୍ ବାଛନ୍ତୁ |",
        "artisan_offline_queue_hint": "ଲାଇଭ୍ ଆସିବା ପରେ ଅନୁରୋଧ ମିଳିବ",
        "artisan_online_instant_action": "ଲାଇଭ୍ ସେବା ବୁକ୍ କରନ୍ତୁ",
    },
    "as": {
        "artisan_offline_status": "অফলাইন",
        "artisan_online_status": "লাইভ আৰু উপলব্ধ",
        "artisan_offline_reassurance": "বৰ্তমান অফলাইনত আছে। লাইভ অহাৰ লগে লগে তেওঁলোকে আপোনাৰ বুকিং লাভ কৰিব।",
        "artisan_offline_schedule_action": "সময় নিৰ্ধাৰণ / সংৰক্ষণ কৰক",
        "artisan_offline_notice_title": "শিল্পী বৰ্তমান অফলাইনত আছে",
        "artisan_offline_notice_desc": "এই শিল্পীজন বৰ্তমান কৰ্তব্যত নাই। এতিয়াই নিশ্চিত কৰক আৰু লাইভ হোৱাৰ লগে লগে তেওঁলোকে অনুৰোধ লাভ কৰিব, বা এটা সময় বাছক।",
        "artisan_offline_queue_hint": "লাইভ হ'লে অনুৰোধ লাভ কৰিব",
        "artisan_online_instant_action": "লাইভ সেৱা বুক কৰক",
    },
    "ur": {
        "artisan_offline_status": "آف لائن",
        "artisan_online_status": "لائیو اور دستیاب",
        "artisan_offline_reassurance": "فی الحال آف لائن ہیں۔ لائیو آتے ہی انہیں آپ کی بکنگ موصول ہو جائے گی۔",
        "artisan_offline_schedule_action": "وقت طے کریں / محفوظ کریں",
        "artisan_offline_notice_title": "کاریگر فی الحال آف لائن ہیں",
        "artisan_offline_notice_desc": "یہ کاریگر فی الحال ڈیوٹی پر نہیں ہیں۔ ابھی تصدیق کریں اور لائیو آتے ہی انہیں درخواست مل جائے گی، یا مقررہ وقت منتخب کریں۔",
        "artisan_offline_queue_hint": "لائیو ہونے پر درخواست ملے گی",
        "artisan_online_instant_action": "لائیو سروس بک کریں",
    },
    "sa": {
        "artisan_offline_status": "अपगतः",
        "artisan_online_status": "प्रत्यक्षम् उपलब्धम् च",
        "artisan_offline_reassurance": "सांप्रतं अपगतः अस्ति। प्रत्यक्षं आगमनानन्तरं तस्मै भवतः आरक्षणं प्राप्स्यते।",
        "artisan_offline_schedule_action": "समयं निर्धारयतु / संरक्षतु",
        "artisan_offline_notice_title": "शिल्पी सांप्रतं अपगतः अस्ति",
        "artisan_offline_notice_desc": "अयं शिल्पी सांप्रतं कर्तव्ये नास्ति। अधुना निश्चयं कुर्वन्तु, सः प्रत्यक्षं आगमनानन्तरं प्रार्थनां लप्स्यते, अथवा निर्धारितसमयं चिनुत।",
        "artisan_offline_queue_hint": "प्रत्यक्षमागते प्रार्थनां लप्स्यते",
        "artisan_online_instant_action": "प्रत्यक्षसेवां आरक्षतु",
    },
    "ks": {
        "artisan_offline_status": "آف لائن",
        "artisan_online_status": "لائیو تہٕ دستیاب",
        "artisan_offline_reassurance": "فی الحال چھُ آف لائن۔ لائیو یِتھۍ مِلِہ تِمن تُہُند بُکِنٛگ۔",
        "artisan_offline_schedule_action": "وَقٕت طے کٔرِو / رِزَرو کٔرِو",
        "artisan_offline_notice_title": "کاریگَر چھُ فی الحال آف لائن",
        "artisan_offline_notice_desc": "یہِ کاریگَر چھُنہٕ فی الحال ڈیوٗٹی پؠٹھ۔ ونِہ کٔرِو تَصدیق تہٕ لائیو یِتھۍ مِلِہ دَرخواست، یا وَقٕت ژارِو۔",
        "artisan_offline_queue_hint": "لائیو یِتھۍ مِلِہ دَرخواست",
        "artisan_online_instant_action": "لائیو سٔروِس بُک کٔرِو",
    },
    "ne": {
        "artisan_offline_status": "अफलाइन",
        "artisan_online_status": "प्रत्यक्ष र उपलब्ध",
        "artisan_offline_reassurance": "हाल अफलाइन हुनुहुन्छ। प्रत्यक्ष आउने बित्तिकै उहाँले तपाईंको बुकिङ प्राप्त गर्नुहुनेछ।",
        "artisan_offline_schedule_action": "समय तालिका / सुरक्षित गर्नुहोस्",
        "artisan_offline_notice_title": "कारीगर हाल अफलाइन हुनुहुन्छ",
        "artisan_offline_notice_desc": "यी कारीगर हाल ड्युटीमा हुनुहुन्न। अहिले पुष्टि गर्नुहोस् र प्रत्यक्ष आउने बित्तिकै अनुरोध प्राप्त हुनेछ, वा निर्धारित समय छान्नुहोस्।",
        "artisan_offline_queue_hint": "प्रत्यक्ष भएपछि अनुरोध प्राप्त हुनेछ",
        "artisan_online_instant_action": "प्रत्यक्ष सेवा बुकिङ गर्नुहोस्",
    },
    "sd": {
        "artisan_offline_status": "آف لائن",
        "artisan_online_status": "لائيو ۽ دستياب",
        "artisan_offline_reassurance": "هن وقت آف لائن آهي. لائيو اچڻ سان ئي کين توهان جي بڪنگ ملي ويندي.",
        "artisan_offline_schedule_action": "وقت مقرر ڪريو / محفوظ ڪريو",
        "artisan_offline_notice_title": "ڪاريگر هن وقت آف لائن آهي",
        "artisan_offline_notice_desc": "هي ڪاريگر هن وقت ڊيوٽي تي ناهي. هاڻي تصديق ڪريو ۽ لائيو اچڻ سان کين درخواست ملندي، يا مقرر وقت چونڊيو.",
        "artisan_offline_queue_hint": "لائيو اچڻ تي درخواست ملندي",
        "artisan_online_instant_action": "لائيو سروس بڪ ڪريو",
    },
    "kok": {
        "artisan_offline_status": "ऑफलायन",
        "artisan_online_status": "लायव्ह आनी उपलब्ध",
        "artisan_offline_reassurance": "सद्या ऑफलायन आसा. लायव्ह येतकच तांकां तुमचें बुकींग पावतलें.",
        "artisan_offline_schedule_action": "वेळ थारावची / राखून दवरचें",
        "artisan_offline_notice_title": "कारागीर सद्या ऑफलायन आसा",
        "artisan_offline_notice_desc": "हो कारागीर सद्या कामाचेर ना. आतांच खात्री करात आनी तो लायव्ह येतकच ताका विनंती पावतली, वा थारायिल्लो वेळ वेंचून काडात.",
        "artisan_offline_queue_hint": "लायव्ह येतकच विनंती पावतली",
        "artisan_online_instant_action": "लायव्ह सेवा बुक करात",
    },
    "doi": {
        "artisan_offline_status": "ऑफलाइन",
        "artisan_online_status": "लाइव ते उपलब्ध",
        "artisan_offline_reassurance": "इस वेले ऑफलाइन न। लाइव औने पर उने गी तुहाडी बुकिंग मिली जाग।",
        "artisan_offline_schedule_action": "समां मुकर्रर करो / रिज़र्व करो",
        "artisan_offline_notice_title": "कारीगर इस वेले ऑफलाइन न",
        "artisan_offline_notice_desc": "एह् कारीगर इस वेले ड्यूटी पर नेईं न। हुने पक्की करो ते लाइव औने पर उने गी अर्जी मिली जाग, या समां चुनो।",
        "artisan_offline_queue_hint": "लाइव औने पर अर्जी मिलग",
        "artisan_online_instant_action": "लाइव सेवा बुक करो",
    },
    "mai": {
        "artisan_offline_status": "ऑफलाइन",
        "artisan_online_status": "लाइव आ उपलब्ध",
        "artisan_offline_reassurance": "वर्तमान मे ऑफलाइन छथि। लाइव अयला पर हुनकें अहाँक बुकिंग भेटि जयतैन।",
        "artisan_offline_schedule_action": "समय निर्धारित करू / आरक्षित करू",
        "artisan_offline_notice_title": "कारीगर वर्तमान मे ऑफलाइन छथि",
        "artisan_offline_notice_desc": "ई कारीगर अखन ड्यूटी पर नहि छथि। अखने पुष्टि करू आ लाइव अयला पर हुनकें अनुरोध भेटतैन, वा निर्धारित समय चुनू।",
        "artisan_offline_queue_hint": "लाइव भेला पर अनुरोध भेटत",
        "artisan_online_instant_action": "लाइव सेवा बुक करू",
    },
    "brx": {
        "artisan_offline_status": "অফলাইন",
        "artisan_online_status": "लाइभ आरो मोननो हागौ",
        "artisan_offline_reassurance": "दासान्दि अफलाइन दं। लाइभ फैनाय लोगो लोगोनो बिसोरो नोंथांनि बुकिंखौ मोनगोन।",
        "artisan_offline_schedule_action": "सम थि खालाम / दोनथुम",
        "artisan_offline_notice_title": "आरथिस्तआ दासान्दि अफलाइन दं",
        "artisan_offline_notice_desc": "बे आरथिस्तआ दासान्दि खामानियाव गैया। दानो थि खालाम आरो बिसोरो लाइभ फैनाय लोगो लोगोनो खावलायनाय मोनगोन, एबा थि सम बासिख।",
        "artisan_offline_queue_hint": "लाइभ जानाय लोगो लोगो खावलायनाय मोनगोन",
        "artisan_online_instant_action": "लाइभ सिबिथा बुकिं खालाम",
    },
    "sat": {
        "artisan_offline_status": "ᱚᱯᱷᱞᱟᱭᱤᱱ",
        "artisan_online_status": "ᱞᱟᱭᱤᱵᱷ ᱟᱨ ᱧᱟᱢᱚᱜ",
        "artisan_offline_reassurance": "ᱱᱤᱛᱚᱜ ᱫᱚ ᱚᱯᱷᱞᱟᱭᱤᱱ ᱢᱮᱱᱟᱭᱟ᱾ ᱞᱟᱭᱤᱵᱷ ᱦᱤᱡᱩᱜ ᱥᱟᱶᱛᱮ ᱟᱢᱟᱜ ᱵᱩᱠᱤᱝ ᱧᱟᱢᱟᱭ᱾",
        "artisan_offline_schedule_action": "ᱚᱠᱛᱚ ᱴᱷᱟᱹᱣᱠᱟᱹ / ᱨᱤᱡᱟᱨᱵᱷ",
        "artisan_offline_notice_title": "ᱠᱟᱹᱨᱤᱜᱚᱞ ᱫᱚ ᱱᱤᱛᱚᱜ ᱚᱯᱷᱞᱟᱭᱤᱱ ᱢᱮᱱᱟᱭᱟ",
        "artisan_offline_notice_desc": "ᱱᱩᱭ ᱠᱟᱹᱨᱤᱜᱚᱞ ᱫᱚ ᱱᱤᱛᱚᱜ ᱠᱟᱹᱢᱤ ᱨᱮ ᱵᱟᱹᱱᱩᱜᱼᱟᱭ᱾ ᱱᱤᱛᱚᱜ ᱴᱷᱟᱹᱣᱠᱟᱹᱭ ᱢᱮ ᱟᱨ ᱞᱟᱭᱤᱵᱷ ᱦᱤᱡᱩᱜ ᱥᱟᱶᱛᱮ ᱱᱮᱦᱚᱸᱨ ᱧᱟᱢᱟᱭ, ᱵᱟᱝᱠᱷᱟᱱ ᱚᱠᱛᱚ ᱵᱟᱪᱷᱟᱣ ᱢᱮ᱾",
        "artisan_offline_queue_hint": "ᱞᱟᱭᱤᱵᱷ ᱦᱮᱡ ᱞᱮᱱᱠᱷᱟᱱ ᱱᱮᱦᱚᱸᱨ ᱧᱟᱢᱚᱜᱼᱟ",
        "artisan_online_instant_action": "ᱞᱟᱭᱤᱵᱷ ᱥᱮᱵᱟ ᱵᱩᱠ ᱢᱮ",
    },
    "mni": {
        "artisan_offline_status": "ꯑꯣꯐꯂꯥꯏꯟ",
        "artisan_online_status": "ꯂꯥꯏꯚ ꯑꯃꯁꯨꯡ ꯐꯪꯒꯅꯤ",
        "artisan_offline_reassurance": "ꯍꯧꯖꯤꯛ ꯑꯣꯐꯂꯥꯏꯟ ꯑꯣꯏꯔꯤ꯫ ꯂꯥꯏꯚ ꯑꯣꯏꯔꯛꯄꯒꯥ ꯃꯈꯣꯏꯅꯥ ꯅꯍꯥꯛꯀꯤ ꯕꯨꯛꯀꯤꯡ ꯐꯪꯒꯅꯤ꯫",
        "artisan_offline_schedule_action": "ꯃꯇꯝ ꯂꯦꯄꯊꯣꯛꯎ / ꯔꯤꯖꯔꯚ ꯇꯧꯔꯨ",
        "artisan_offline_notice_title": "ꯑꯥꯔꯇꯤꯁꯥꯟ ꯍꯧꯖꯤꯛ ꯑꯣꯐꯂꯥꯏꯟ ꯑꯣꯏꯔꯤ",
        "artisan_offline_notice_desc": "ꯑꯥꯔꯇꯤꯁꯥꯟ ꯑꯁꯤ ꯍꯧꯖꯤꯛ ꯊꯕꯛ ꯇꯧꯗꯦ꯫ ꯍꯧꯖꯤꯛ ꯆꯠꯅꯍꯜꯂꯨ ꯑꯃꯁꯨꯡ ꯃꯈꯣꯏꯅꯥ ꯂꯥꯏꯚ ꯑꯣꯏꯔꯛꯄꯒꯥ ꯅꯍꯥꯛꯀꯤ ꯍꯥꯏꯖꯕꯥ ꯐꯪꯒꯅꯤ, ꯅꯠꯔꯒꯥ ꯃꯇꯝ ꯈꯜꯂꯨ꯫",
        "artisan_offline_queue_hint": "ꯂꯥꯏꯚ ꯑꯣꯏꯔꯛꯄꯒꯥ ꯍꯥꯏꯖꯕꯥ ꯐꯪꯒꯅꯤ",
        "artisan_online_instant_action": "ꯂꯥꯏꯚ ꯁꯔꯕꯤꯁ ꯕꯨꯛ ꯇꯧꯔꯨ",
    },
}

def sync():
    total_updated = 0
    for lang, keys in translations.items():
        filepath = os.path.join(LANG_DIR, f"{lang}.json")
        if not os.path.exists(filepath):
            print(f"[!] Warning: {filepath} does not exist. Skipping.")
            continue
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            # Insert / update keys
            for k, v in keys.items():
                data[k] = v
                
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            total_updated += 1
            print(f"[*] Updated {lang}.json with {len(keys)} keys.")
        except Exception as e:
            print(f"[ERROR] Failed to update {filepath}: {e}")
            sys.exit(1)

    print(f"\n[SUCCESS] Successfully synced all {total_updated} language files!")

if __name__ == "__main__":
    sync()
