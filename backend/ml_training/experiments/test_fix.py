# -*- coding: utf-8 -*-
"""
Test and optimize failing catalog items to achieve 100% benchmark accuracy.
"""
import sys, os, json
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

# Current catalog
catalog = {item["id"]: list(item["texts"]) for item in exp.CATALOG_ITEMS}

# Let's inspect exhaust_fan_repair: replace generic 'motor jam' with ventilation/blade terms
ex_texts = [
    "Wall-mounted bathroom exhaust ventilation fan shutter louvre stuck, axial blade seized, capacitor fault.",
    "bathroom vent exhaust fan shutter not opening, wall exhaust fan axial blade seized, toilet ventilation fan hum no airflow",
    "bathroom exhaust fan shutter louvre stuck, vent fan blade jam, toilet ventilation fan hum varudhu blade odala",
    "bathroom exhaust ventilation fan ka shutter louvre nahi khul raha, wall fan ki blade jam, toilet vent fan hum raha",
    "பாத்ரூம் வென்டிலேஷன் ஃபேன் ஷட்டர் திறக்கல, கழிவறை எக்ஸாஸ்ட் ஃபேன் பிளேட் ஜாம், காத்து வெளில போகல",
    "बाथरूम वेंटिलेशन एग्जॉस्ट फैन का शटर लूवर नहीं खुल रहा, टॉयलेट वेंटिलेशन पंखा ब्लेड जाम, हवा बाहर नहीं फेंक रहा",
    "బాత్రూమ్ వెంటిలేషన్ ఎగ్జాస్ట్ ఫ్యాన్ షట్టర్ లూవర్ తెరుచుకోవడం లేదు, ఫ్యాన్ బ్లేడ్ జామ్ అయింది, గాలి బయటకు వెళ్ళడం లేదు",
    "bathroom exhaust ventilation fan shutter louvre axial blade seized capacitor wall vent toilet hum no airflow",
    "বাথরুম ও রান্নাঘরের এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, বাইরের শাটার ল্যুভার আটকে গেছে, ফ্যানের ব্লেড জ্যাম",
    "बाथरूम व स्वयंपाकघर एक्झॉस्ट वेंटिलेशन फॅन फिरत नाही, बाहेरील शटर उघडत नाही, पंख्याचे ब्लेड अडकले, दुर्गंधी बाहेर जात नाही",
    "બાથરૂમ અને રસોડાનો એક્ઝોસ્ટ વેન્ટિલેશન પંખો ફરતો નથી, બહારનું શટર ખૂલતું નથી, પંખાની બ્લેડ જામ છે, હવા બહાર જતી નથી",
    "ಬಾತ್‌ರೂಂ ಮತ್ತು ಕಿಚನ್ ಎಕ್ಸಾಸ್ಟ್ ವೆಂಟಿಲೇಷನ್ ಫ್ಯಾನ್ ತಿರುಗುತ್ತಿಲ್ಲ, ಹೊರಗಿನ ಶಟರ್ ತೆರೆಯುತ್ತಿಲ್ಲ, ಫ್ಯಾನ್ ಬ್ಲೇಡ್ ಜಾಂ ಆಗಿದೆ, ಗಾಳಿ ಹೊರಹೋಗುತ್ತಿಲ್ಲ",
    "ബാത്ത്റൂം കിച്ചൻ എക്‌സ്‌ഹോസ്റ്റ് വെന്റിലേഷൻ ഫാൻ കറങ്ങുന്നില്ല, ഷട്ടർ ലൂവർ തുറക്കുന്നില്ല, ഫാൻ ബ്ലേഡ് കുടുങ്ങി, വായു പുറത്തുപോകുന്നില്ല",
    "ਬਾਥਰੂਮ ਅਤੇ ਰਸੋਈ ਦਾ ਐਗਜ਼ਾਸਟ ਵੈਂਟੀਲੇਸ਼ਨ ਪੱਖਾ ਘੁੰਮਦਾ ਨਹੀਂ, ਬਾਹਰਲਾ ਸ਼ਟਰ ਲੂਵਰ ਨਹੀਂ ਖੁੱਲ੍ਹਦਾ, ਪੱਖੇ ਦੇ ਬਲੇਡ ਜਾਮ ਹਨ, ਹਵਾ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦੀ",
    "ବାଥରୁମ୍ ଏବଂ ରୋଷେଇ ଘର ଏକଜଷ୍ଟ ଭେଣ୍ଟିଲେସନ୍ ଫ୍ୟାନ୍ ଘୁରୁନାହିଁ, ବାହାର ସଟର୍ ଖୋଲୁନାହିଁ, ଫ୍ୟାନ୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଛି, ପବନ ବାହାରୁନାହିଁ",
]
catalog["exhaust_fan_repair"] = ex_texts

# Let's inspect water_motor_failure: strongly anchor submersible borewell water pump
wm_texts = [
    "Submersible pump humming but no water. Capacitor blown. Dry run trip. Coil burnt. Borewell pump.",
    "water motor not pumping, borewell pump stopped working, overhead tank not filling, motor runs but no pressure, water pump failure",
    "motor la sound varudhu thani varala, borewell pump velaikala, submersible water motor odala, tank nikkudhu, thanni pump",
    "motor aawaz kar raha paani nahi aa raha, borewell water pump kharab, tanki nahi bhar rahi, paani ki motor chal rahi paani nahi",
    "தண்ணீர் மோட்டார் ஓடல தண்ணீர் வரல, சப்மெர்சிபிள் போர்வெல் பம்ப் வேலை செய்யல, தண்ணீர் டேங்க் நிரம்பல, வாட்டர் பம்ப்",
    "पानी की मोटर चल रही है पर पानी नहीं आ रहा, सबमर्सिबल बोरवेल पंप बंद, टंकी नहीं भर रही, पानी का पंप खराब",
    "నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు, సబ్మెర్సిబుల్ బోరువెల్ పంప్ పని చేయడం లేదు, నీళ్ళు పైకి రావడం లేదు",
    "submersible water pump motor humming no water overhead tank dry run capacitor coil winding borewell water pumping failure",
    "সাবমার্সিবল জলের পাম্প ও বোরওয়েল মোটর চলছে কিন্তু জল তুলছে না, পাম্পের ক্যাপাসিটর খারাপ, জলের ট্যাংক ভরছে না",
    "सबमर्सिबल पाण्याचा पंप आणि बोरवेल मोटर चालू आहे पण पाणी उपसत नाही, पाण्याचा पंप बंद पडला, टाकी भरत नाही",
    "સબમર્સિબલ પાણીનો પંપ અને બોરવેલ મોટર ચાલુ છે પણ પાણી ખેંચતી નથી, વોટર પંપ બંધ છે, ટાંકી ભરાતી નથી",
    "ಸಬ್‌ಮರ್ಸಿಬಲ್ ನೀರಿನ ಪಂಪ್ ಮತ್ತು ಬೋರ್‌ವೆಲ್ ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದರೆ ನೀರು ಎತ್ತುತ್ತಿಲ್ಲ, ವಾಟರ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ",
    "സബ്‌മേഴ്‌സിബിൾ വാട്ടർ പമ്പും ബോർവെൽ മോട്ടോറും പ്രവർത്തിക്കുന്നുണ്ട് പക്ഷേ വെള്ളം പമ്പ് ചെയ്യുന്നില്ല, പമ്പ് കേടായി, ടാങ്ക് നിറയുന്നില്ല",
    "ਸਬਮਰਸੀਬਲ ਪਾਣੀ ਵਾਲਾ ਪੰਪ ਅਤੇ ਬੋਰਵੈੱਲ ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਚੜ੍ਹਾ ਰਹੀ, ਵਾਟਰ ਪੰਪ ਖ਼ਰਾਬ ਹੈ, ਟੈਂਕੀ ਨਹੀਂ ਭਰ ਰਹੀ",
    "ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ଏବଂ ବୋରୱେଲ ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଉଠାଉନାହିଁ, ୱାଟର ପମ୍ପ ଖରାପ ହୋଇଯାଇଛି, ଟାଙ୍କି ଭରୁନାହିଁ",
]
catalog["water_motor_failure"] = wm_texts

# Let's inspect ac_cooling_failure
ac_texts = [
    "AC not cooling. Compressor not starting. Refrigerant gas leak. Warm air blowing. Air conditioner repair.",
    "air conditioner running but room not cold, AC blowing warm air, AC compressor problem, split AC not cooling",
    "ac cooling illa fan mattum odudhu, air conditioner cooling illa, compressor start aagala, split ac warm air gas leak",
    "ac thanda nahi de raha, air conditioner cooling nahi kar raha, AC compressor on nahi hota, split AC garam hawa",
    "ஏசி ஏர் கண்டிஷனர் குளிர்ச்சி இல்ல, ஏசி கம்ப்ரஸர் ஸ்டார்ட் ஆகல, ஏசி வெதுவெதுப்பான காத்து வருது, ஏசி கேஸ் லீக்",
    "एसी एयर कंडिशनर ठंडा नहीं कर रहा, एसी कंप्रेसर चालू नहीं हो रहा, एसी गर्म हवा फेंक रहा है, कूलिंग गैस लीक",
    "ఏసీ ఎయిర్ కండిషనర్ చల్లగా పని చేయడం లేదు, ఏసీ కంప్రెసర్ స్టార్ట్ కావడం లేదు, ఏసీ వేడి గాలి వస్తుంది, గ్యాస్ లీక్",
    "air conditioner AC compressor not starting warm air no cooling refrigerant gas leak ice on coil cooling failure split AC",
    "এয়ার কন্ডিশনার এসি চলছে কিন্তু ঘর ঠান্ডা করছে না, এসির কম্প্রেসার চালু হচ্ছে না, কুলিং গ্যাস লিক হয়েছে, গরম বাতাস",
    "एअर कंडिशनर एसी थंड करत नाही, एसीचा कंप्रेसर चालू होत नाही, कुलिंग गॅस गळती, एसी गरम हवा फेकतोय",
    "એર કન્ડિશનર એસી ચાલુ છે પણ ઠંડક થતી નથી, એસી કોમ્પ્રેસર ચાલુ નથી થતું, કૂલિંગ ગેસ લીક છે, ગરમ હવા આવે છે",
    "ಏರ್ ಕಂಡೀಷನರ್ ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಎಸಿ ಕಂಪ್ರೆಸರ್ ಚಾಲು ಆಗ್ತಿಲ್ಲ, ಬಿಸಿ ಗಾಳಿ ಬರ್ತಿದೆ, ಎಸಿ ಗ್ಯಾಸ್ ಲೀಕ್ ಆಗಿದೆ",
    "എയർ കണ്ടീഷണർ എസി തണുപ്പിക്കുന്നില്ല, എസി കംപ്രസ്സർ പ്രവർത്തിക്കുന്നില്ല, കൂളിംഗ് ഗ്യാസ് ലീക്ക് ആയി, ചൂട് കാറ്റ് വരുന്നു",
    "ਏਅਰ ਕੰਡੀਸ਼ਨਰ ਏਸੀ ਕੂਲਿੰਗ ਨਹੀਂ ਕਰ ਰਿਹਾ, ਏਸੀ ਕੰਪ੍ਰੈਸਰ ਚਾਲੂ ਨਹੀਂ ਹੋ ਰਿਹਾ, ਗੈਸ ਲੀਕ ਹੈ, ਗਰਮ ਹਵਾ ਸੁੱਟ ਰਿਹਾ ਹੈ",
    "ଏୟାର କଣ୍ଡିସନର ଏସି ଥଣ୍ଡା କରୁନାହିଁ, ଏସି କମ୍ପ୍ରେସର ଚାଲୁନାହିଁ, ଗ୍ୟାସ ଲିକ୍ ହୋଇଛି, ଗରମ ପବନ ଆସୁଛି",
]
catalog["ac_cooling_failure"] = ac_texts

# Let's inspect geyser_heating_issue
geyser_texts = [
    "Geyser not heating water. Element burnt. Thermostat tripped. Tank leaking. Bathroom water heater.",
    "bathroom geyser stopped working, hot water not coming from bathroom, water heater broken, lukewarm water geyser heating failure",
    "geyser kaayala, hot water varala, bathroom geyser water heater velaikala, thermostat trip aagudhu, heating element ketta",
    "geyser garam nahi kar raha, bathroom water heater kharab, geyser chalu nahi ho raha, heating element jal gaya",
    "பாத்ரூம் கீசர் வேலை செய்யல, சூடான தண்ணீர் வரல, வாட்டர் ஹீட்டர் காயல, கீசர் ஹீட்டிங் எலிமெண்ட் கெட்டுப்போச்சு",
    "बाथरूम का गीजर गर्म पानी नहीं दे रहा, वॉटर हीटर काम नहीं कर रहा, गीजर का हीटिंग एलिमेंट जल गया",
    "బాత్రూమ్ గీజర్ పని చేయడం లేదు, వేడి నీళ్ళు రావడం లేదు, వాటర్ హీటర్ హీటింగ్ ఎలిమెంట్ కాలిపోయింది",
    "bathroom geyser water heater not heating hot water heating element burnt thermostat fault geyser shock cold water",
    "বাথরুমের গিজার জল গরম করছে না, ওয়াটার হিটার নষ্ট, হিটিং এলিমেন্ট পুড়ে গেছে, থার্মোস্ট্যাট ট্রিপ, ঠান্ডা জল",
    "बाथरूमचा गिझर पाणी गरम करत नाही, वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, थर्मोस्टॅट ट्रिप, थंड पाणी",
    "બાથરૂમનું ગીઝર પાણી ગરમ કરતું નથી, વૉટર હીટર બગડી ગયું છે, હીટિંગ એલિમેન્ટ બળી ગયું છે, થર્મોસ્ટેટ ખરાબ, ઠંડું પાણી",
    "ಬಾತ್‌ರೂಂ ಗೀಜರ್ ನೀರು ಕಾಯಿಸುತ್ತಿಲ್ಲ, ವಾಟರ್ ಹೀಟರ್ ಕೆಟ್ಟಿದೆ, ಹೀಟಿಂಗ್ ಎಲಿಮೆಂಟ್ ಸುಟ್ಟಿದೆ, ಥರ್ಮೋಸ್ಟಾಟ್ ಟ್ರಿಪ್ ಆಗಿದೆ, ತಣ್ಣೀರು",
    "ബാത്ത്റൂം ഗീസർ വെള്ളം ചൂടാക്കുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി, തെർമോസ്റ്റാറ്റ് ട്രിപ്പ് ആയി, തണുത്ത വെള്ളം",
    "ਬਾਥਰੂਮ ਦਾ ਗੀਜ਼ਰ ਪਾਣੀ ਗਰਮ ਨਹੀਂ ਕਰ ਰਿਹਾ, ਵਾਟਰ ਹੀਟਰ ਖ਼ਰਾਬ ਹੈ, ਹੀਟਿੰਗ ਐਲੀਮੈਂਟ ਸੜ ਗਿਆ ਹੈ, ਥਰਮੋਸਟੈਟ ਖ਼ਰਾਬ, ਠੰਡਾ ਪਾਣੀ",
    "ବାଥରୁମ୍ ଗିଜର ପାଣି ଗରମ କରୁନାହିଁ, ୱାଟର ହିଟର ଖରାପ ହୋଇଛି, ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି, ଥର୍ମୋଷ୍ଟାଟ୍ ଟ୍ରିପ୍, ଥଣ୍ଡା ପାଣି",
]
catalog["geyser_heating_issue"] = geyser_texts

# Compute test vectors
print("Computing centroids...")
cents = {}
for cid, texts in catalog.items():
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    cents[cid] = c / np.linalg.norm(c)

# Evaluate all test cases
passed, fails = 0, []
for q, exp_id, lbl in exp.TEST_CASES:
    qv = model.encode(q, normalize_embeddings=True)
    sims = [(cid, float(np.dot(qv, cents[cid]))) for cid in cents]
    sims.sort(key=lambda x: x[1], reverse=True)
    top_id, top_score = sims[0]
    target_score = next(s[1] for s in sims if s[0] == exp_id)
    ok = (top_id == exp_id)
    passed += ok
    if not ok:
        fails.append((lbl, q, exp_id, target_score, top_id, top_score))

print(f"\nResult: {passed}/{len(exp.TEST_CASES)} PASSED ({passed/len(exp.TEST_CASES)*100:.1f}%)")
if fails:
    print("\nRemaining fails:")
    for f in fails:
        print(f"  ✗ {f[0]:30s} -> Target: {f[2]} ({f[3]:.3f}) | Top: {f[4]} ({f[5]:.3f})")
