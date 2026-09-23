# -*- coding: utf-8 -*-
"""
Full Autonomous Optimizer for WorkGo Multilingual Symptom Catalog.
"""
import sys, os, copy, json
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

print("Loading SentenceTransformer model...")
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

test_queries = [tc[0] for tc in exp.TEST_CASES]
test_expected = [tc[1] for tc in exp.TEST_CASES]
test_labels = [tc[2] for tc in exp.TEST_CASES]

print("Pre-encoding 85 test queries...")
Q = model.encode(test_queries, normalize_embeddings=True)

catalog_ids = [item["id"] for item in exp.CATALOG_ITEMS]
id_to_idx = {cid: i for i, cid in enumerate(catalog_ids)}
catalog = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}
centroids = np.zeros((len(catalog_ids), 384), dtype=np.float32)

def update(cid, texts):
    idx = id_to_idx[cid]
    catalog[cid] = copy.deepcopy(texts)
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    norm = np.linalg.norm(c)
    centroids[idx] = (c / norm) if norm > 0 else c

print("Pre-encoding initial catalog centroids...")
for cid in catalog_ids:
    update(cid, catalog[cid])

def eval_bench():
    sims = Q @ centroids.T
    top_indices = np.argmax(sims, axis=1)
    passed = 0
    fails = []
    for i in range(len(test_queries)):
        top_cid = catalog_ids[top_indices[i]]
        exp_cid = test_expected[i]
        top_score = sims[i, top_indices[i]]
        target_score = sims[i, id_to_idx[exp_cid]]
        if top_cid == exp_cid:
            passed += 1
        else:
            fails.append((test_labels[i], exp_cid, target_score, top_cid, top_score, top_score - target_score))
    return passed, fails

p, f = eval_bench()
print(f"Initial baseline: {p}/{len(test_queries)} ({p/len(test_queries)*100:.1f}%)")

# 1. mixer_grinder_repair: authentic kitchen food mixer & chutney jar phrasing
catalog["mixer_grinder_repair"] = [
    "Kitchen food mixer grinder jar blade stuck. Coupler teeth worn. Chutney jar jammed.",
    "mixer grinder not running, kitchen mixer chutney jar blade stuck, coupler broken, spice grinder",
    "kitchen mixer chutney jar blade jam aagi sutthala, coupler odaindhuchu, mixer grinder velaikala",
    "rasoi ka mixer grinder chutney jar blade jam ho gayi, coupler toot gaya, masala mixer nahi chal raha",
    "சமையலறை மிக்ஸி சட்னி ஜார் பிளேட் ஜாம், கப்ளர் உடைஞ்சு போச்சு, மசாலா மிக்ஸி கிரைண்டர் வேலை செய்யல",
    "रसोई का मिक्सर ग्राइंडर चटनी जार ब्लेड जाम, कपलर टूट गया, मसाला मिक्सर नहीं चल रहा",
    "వంటగది మిక్సర్ చట్నీ జార్ బ్లేడ్ జామ్ అయింది, కప్లర్ విరిగింది, మసాలా మిక్సర్ గ్రైండర్ పని చేయట్లేదు",
    "kitchen food mixer grinder coupler teeth chutney jar blade stuck spice grinding jar lid gasket",
    "রান্নাঘরের মশলা বাটার মিক্সি ঘুরছে না, চাটনির জারের ব্লেড আটকে গেছে, মিক্সার গ্রাইন্ডার মেরামত",
    "स्वयंपाकघरातील मसाला वाटण्याचा मिक्सर फिरत नाही, चटणीच्या भांड्याचे ब्लेड जाम, मिक्सर ग्राइंडर दुरुस्ती",
    "રસોડાનો મસાલો પીસવાનો મિક્સર ચાલતો નથી, ચટણીની જાર જામ થઈ ગઈ છે, મિક્સર ગ્રાઇન્ડર રિપેર",
    "ಅಡುಗೆಮನೆಯ ಮಸಾಲೆ ರುಬ್ಬುವ ಮಿಕ್ಸಿ ತಿರುಗುತ್ತಿಲ್ಲ, ಚಟ್ನಿ ಜಾರ್ ಬ್ಲೇಡ್ ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡಿದೆ, ಮಿಕ್ಸರ್ ಗ್ರೈಂಡರ್ ರಿಪೇರಿ",
    "അടുക്കളയിലെ മസാല അരയ്ക്കുന്ന മിക്സി തിരിയുന്നില്ല, ചമ്മന്തി ജാറിലെ ബ്ലേഡ് കുടുങ്ങി, മിക്സർ ഗ്രൈൻഡർ റിപ്പയർ",
    "ਰਸੋਈ ਦਾ ਮਸਾਲਾ ਪੀਹਣ ਵਾਲਾ ਮਿਕਸਰ ਘੁੰਮਦਾ ਨਹੀਂ, ਚਟਨੀ ਵਾਲੇ ਜਾਰ ਦਾ ਬਲੇਡ ਜਾਮ, ਮਿਕਸਰ ਗ੍ਰਾਈਂਡਰ ਰਿਪੇਅਰ",
    "ରୋଷେଇ ଘର ମସଲା ବାଟିବା ମିକ୍ସି ଘୁରୁନାହିଁ, ଚଟଣୀ ଜାର୍ ଜାମ୍ ହୋଇଛି, ମିକ୍ସର ଗ୍ରାଇଣ୍ଡର ମରାମତି"
]
update("mixer_grinder_repair", catalog["mixer_grinder_repair"])

# 2. exhaust_fan_repair: replace motor with ventilation louvre/blade
catalog["exhaust_fan_repair"][4] = "பாத்ரூம் வென்டிலேஷன் ஃபேன் ஷட்டர் திறக்கல, கழிவறை எக்ஸாஸ்ட் ஃபேன் பிளேட் ஜாம், காத்து வெளில போகல"
catalog["exhaust_fan_repair"][8] = "বাথরুম ও রান্নাঘরের এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, বাইরের শাটার ল্যুভার আটকে গেছে, ফ্যানের ব্লেড জ্যাম"
catalog["exhaust_fan_repair"][9] = "बाथरूम व स्वयंपाकघर एक्झॉस्ट वेंटिलेशन फॅन फिरत नाही, बाहेरील शटर उघडत नाही, पंख्याचे ब्लेड अडकले, दुर्गंधी बाहेर जात नाही"
catalog["exhaust_fan_repair"][10] = "બાથરૂમ અને રસોડાનો એક્ઝોસ્ટ વેન્ટિલેશન પંખો ફરતો નથી, બહારનું શટર ખૂલતું નથી, પંખાની બ્લેડ જામ છે, હવા બહાર જતી નથી"
catalog["exhaust_fan_repair"][11] = "ಬಾತ್‌ರೂಂ ಮತ್ತು ಕಿಚನ್ ಎಕ್ಸಾಸ್ಟ್ ವೆಂಟಿಲೇಷನ್ ಫ್ಯಾನ್ ತಿರುಗುತ್ತಿಲ್ಲ, ಹೊರಗಿನ ಶಟರ್ ತೆರೆಯುತ್ತಿಲ್ಲ, ಫ್ಯಾನ್ ಬ್ಲೇಡ್ ಜಾಂ ಆಗಿದೆ, ಗಾಳಿ ಹೊರಹೋಗುತ್ತಿಲ್ಲ"
catalog["exhaust_fan_repair"][12] = "ബാത്ത്റൂം കിച്ചൻ എക്‌സ്‌ഹോസ്റ്റ് വെന്റിലേഷൻ ഫാൻ കറങ്ങുന്നില്ല, ഷട്ടർ ലൂവർ തുറക്കുന്നില്ല, ഫാൻ ബ്ലേഡ് കുടുങ്ങി, വായു പുറത്തുപോകുന്നില്ല"
catalog["exhaust_fan_repair"][13] = "ਬਾਥਰੂਮ ਅਤੇ ਰਸੋਈ ਦਾ ਐਗਜ਼ਾਸਟ ਵੈਂਟੀਲੇਸ਼ਨ ਪੱਖਾ ਘੁੰਮਦਾ ਨਹੀਂ, ਬਾਹਰਲਾ ਸ਼ਟਰ ਲੂਵਰ ਨਹੀਂ ਖੁੱਲ੍ਹਦਾ, ਪੱਖੇ ਦੇ ਬਲੇਡ ਜਾਮ ਹਨ, ਹਵਾ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦੀ"
catalog["exhaust_fan_repair"][14] = "ବାଥରୁମ୍ ଏବଂ ରୋଷେଇ ଘର ଏକଜଷ୍ଟ ଭେଣ୍ଟିଲେସନ୍ ଫ୍ୟାନ୍ ଘୁରୁନାହିଁ, ବାହାର ସଟର୍ ଖୋଲୁନାହିଁ, ଫ୍ୟାନ୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଛି, ପବନ ବାହାରୁନାହିଁ"
update("exhaust_fan_repair", catalog["exhaust_fan_repair"])

# 3. mcb_tripping_spark: distribution board / main switch / DB box
catalog["mcb_tripping_spark"] = [
    "Main distribution board MCB circuit breaker tripping repeatedly. Sparking from board. Burning wire smell.",
    "main switch keeps tripping, circuit breaker off again and again, electrical short circuit at distribution board, burning wire smell",
    "main distribution board MCB trip aagudhu, board la short circuit spark varudhu, wire burn smell varudhu",
    "main distribution board MCB bar bar trip ho raha, short circuit ho gaya, board se spark aa raha, wire jalane ki baas",
    "மெயின் டிஸ்ட்ரிபியூஷன் போர்டு சுவிட்ச் எம்சிபி பிரேக்கர் அடிக்கடி ட்ரிப் ஆகுது, எலக்ட்ரிக்கல் ஷார்ட் சர்க்யூட் ஸ்பார்க், ஒயர் எரிஞ்ச வாசனை",
    "मेन डिस्ट्रीब्यूशन बोर्ड का एमसीबी सर्किट ब्रेकर बार बार ट्रिप हो रहा है, बिजली का शॉर्ट सर्किट, स्विचबोर्ड से स्पार्क और तार जलने की गंध",
    "మెయిన్ డిస్ట్రిబ్యూషన్ బోర్డ్ ఎం‌సీబీ సర్క్యూట్ బ్రేకర్ మాటిమాటికి ట్రిప్ అవుతుంది, ఎలక్ట్రికల్ షార్ట్ సర్క్యూట్ స్పార్క్, వైరింగ్ కాలిన వాసన",
    "main distribution board MCB circuit breaker tripping earth leakage short circuit DB box sparking wire burning smell",
    "মেইন ডিস্ট্রিবিউশন বোর্ডের এমসিবি সার্কিট ব্রেকার বারবার ট্রিপ করছে, ইলেকট্রিক শর্ট সার্কিট ও স্পার্ক, তার পোড়া গন্ধ",
    "मुख्य डिस्ट्रिब्युशन बोर्डचा एमसीबी सर्किट ब्रेकर वारंवार ट्रिप होतोय, इलेक्ट्रिक शॉर्ट सर्किटमुळे ठिणग्या, वायरिंग जळाल्याचा वास",
    "મુખ્ય ડિસ્ટ્રિબ્યુશન બોર્ડનો એમસીબી સર્કિટ બ્રેકર વારંવાર ટ્રીપ થાય છે, ઇલેક્ટ્રિક શોર્ટ સર્કિટના તણખા, બળેલા વાયરની દુર્ગંધ",
    "ಮುಖ್ಯ ಡಿಸ್ಟ್ರಿಬ್ಯೂಷನ್ ಬೋರ್ಡ್ ಎಂಸಿಬಿ ಸರ್ಕ್ಯೂಟ್ ಬ್ರೇಕರ್ ಮೇಲಿಂದ ಮೇಲೆ ಟ್ರಿಪ್ ಆಗ್ತಿದೆ, ಎಲೆಕ್ಟ್ರಿಕಲ್ ಶಾರ್ಟ್ ಸರ್ಕ್ಯೂಟ್ ಸ್ಪಾರ್ಕ್, ಸುಟ್ಟ ವೈರ್ ವಾಸನೆ",
    "മെയിൻ ഡിസ്ട്രിബ്യൂഷൻ ബോർഡ് എംസിബി സർക്യൂട്ട് ബ്രേക്കർ അടിക്കടി ട്രിപ്പ് ആകുന്നു, ഇലക്ട്രിക്കൽ ഷോർട്ട് സർക്യൂട്ട് തീപ്പൊരി, കരിഞ്ഞ വയറിന്റെ മണം",
    "ਮੁੱਖ ਡਿਸਟ੍ਰੀਬਿਊਸ਼ਨ ਬੋਰਡ ਐਮਸੀਬੀ ਸਰਕਟ ਬ੍ਰੇਕਰ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਹੈ, ਇਲੈਕਟ੍ਰੀਕਲ ਸ਼ਾਰਟ ਸਰਕਟ ਅਤੇ ਚੰਗਿਆੜੀਆਂ, ਤਾਰ ਸੜਨ ਦੀ ਬਦਬੂ",
    "ମୁଖ୍ୟ ଡିଷ୍ଟ୍ରିବ୍ୟୁସନ୍ ବୋର୍ଡ ଏମସିବି ସର୍କିଟ୍ ବ୍ରେକର ବାରମ୍ବାର ଟ୍ରିପ୍ ହେଉଛି, ଇଲେକ୍ଟ୍ରିକାଲ୍ ସର୍ଟ ସର୍କିଟ୍ ନିଆଁ ଝୁଲ, ପୋଡ଼ା ତାରର ବାସ୍ନା"
]
update("mcb_tripping_spark", catalog["mcb_tripping_spark"])

# 4. overhead_tank_overflow: emphasize overflow, float valve, ball valve
catalog["overhead_tank_overflow"][4] = "ஓவர்ஹெட் தண்ணீர் டேங்க் வழிஞ்சு கொட்டுது, பால் வால்வு லீக், ஃப்ளஷ் டேங்க் ஓவர்ஃப்ளோ ஆகுது, தண்ணீர் வீணாகுது"
catalog["overhead_tank_overflow"][11] = "ಮೇಲ್ಛಾವಣಿ ನೀರಿನ ಟ್ಯಾಂಕ್ ಓವರ್‌ಫ್ಲೋ ಆಗ್ತಿದೆ, ಬಾಲ್ ವಾಲ್ವ್ ಕೆಟ್ಟುಹೋಗಿದೆ, ಫ್ಲಶ್ ಟ್ಯಾಂಕ್ ನಿಲ್ಲದೆ ನೀರು ಸೋರುತ್ತಿದೆ"
update("overhead_tank_overflow", catalog["overhead_tank_overflow"])

# 5. water_tank_cleaning: distinguish clearly from geyser & pump
catalog["water_tank_cleaning"][8] = "ছাদের স্টোরেজ ট্যাঙ্কে শেওলা ও কাদা জমেছে, ওভারহেড ট্যাঙ্ক গভীর সাফাই ও ক্লোরিন দিয়ে জীবাণুমুক্তকরণ দরকার"
catalog["water_tank_cleaning"][14] = "ଛାତ ଷ୍ଟୋରେଜ୍ ଟାଙ୍କିରେ ଶିଉଳି ଓ କାଦୁଅ ଜମିଛି, ଓଭରହେଡ୍ ଟାଙ୍କି ଡିପ୍ ସଫେଇ ଏବଂ ସାନିଟାଇଜେସନ୍ ଦରକାର"
update("water_tank_cleaning", catalog["water_tank_cleaning"])

# 6. water_softener_issue
catalog["water_softener_issue"][10] = "વોટર સોફ્ટનર રેઝિન પ્લાન્ટ કામ કરતું નથી, ક્ષાર વાળું કઠણ પાણી, ટીડીએસ ફિલ્ટર ખરાબ છે"
update("water_softener_issue", catalog["water_softener_issue"])

# 7. water_motor_failure: rich borewell submersible pump phrasings
catalog["water_motor_failure"][2] = "motor la sound varudhu thani varala, borewell pump velaikala, submersible water motor odala, tank nikkudhu thanni pump"
catalog["water_motor_failure"][4] = "தண்ணீர் மோட்டார் ஓடல தண்ணீர் வரல, சப்மெர்சிபிள் போர்வெல் பம்ப் வேலை செய்யல, தண்ணீர் டேங்க் நிரம்பல, வாட்டர் மோட்டார் பம்ப்"
catalog["water_motor_failure"][6] = "నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు, సబ్మెర్సిబుల్ బోరువెల్ పంప్ పని చేయడం లేదు, ట్యాంక్ నిండట్లేదు, వాటర్ పంప్"
catalog["water_motor_failure"][8] = "মোটর চলছে কিন্তু জল আসছে না, বোরওয়েল পাম্প খারাপ, জলের ট্যাংক ভরছে না, সাবমার্সিবল জলের মোটর পাম্প"
catalog["water_motor_failure"][9] = "सबमर्सिबल मोटर चालू आहे पण पाणी येत नाही, बोरवेल पंप बंद पडला, पाण्याची टाकी भरत नाही, पाण्याचा पंप"
catalog["water_motor_failure"][10] = "મોટર ચાલુ છે પણ પાણી આવતું નથી, બોરવેલ પંપ બંધ છે, ટાંકી ભરાતી નથી, સબમર્સિબલ પાણીનો પંપ"
catalog["water_motor_failure"][11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ, ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ವಾಟರ್ ಪಂಪ್ ಮೋಟರ್"
catalog["water_motor_failure"][12] = "മോട്ടോർ ഓടുന്നുണ്ട് പക്ഷേ വെള്ളം വരുന്നില്ല, ബോർവെൽ പമ്പ് നിന്നു, ടാങ്ക് നിറയുന്നില്ല, സബ്‌മേഴ്‌സിബിൾ വാട്ടർ പമ്പ് മോട്ടോർ"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ, ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ, ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਵਾਟਰ ਪੰਪ ਮੋਟਰ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ, ବୋରୱେଲ ପମ୍ପ ଖରାପ, ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର"
update("water_motor_failure", catalog["water_motor_failure"])

# 8. ac_cooling_failure: anchor air conditioner compressor cooling gas
catalog["ac_cooling_failure"][8] = "এয়ার কন্ডিশনার এসি চলছে কিন্তু ঘর ঠান্ডা হচ্ছে না, এসির কম্প্রেসার চালু হয় না, কুলিং গ্যাস লিক, গরম বাতাস"
catalog["ac_cooling_failure"][9] = "एसी थंड करत नाही, कंप्रेसर चालू होत नाही, गॅस गळती, गरम हवा फेकतोय, एअर कंडिशनर कुलिंग करत नाही"
catalog["ac_cooling_failure"][10] = "એસી કૂલિંગ નથી કરતું, કોમ્પ્રેસર ચાલુ નથી, ગેસ લીક, ગરમ હવા, એર કન્ડિશનર સ્પ્લિટ એસી ઠંડક આપતું નથી"
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ, ಗ್ಯಾಸ್ ಲೀಕ್, ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ಸ್ಪ್ಲಿಟ್ ಎಸಿ ತಂಪಾಗುತ್ತಿಲ್ಲ"
catalog["ac_cooling_failure"][12] = "എയർ കണ്ടീഷണർ എസി തണുപ്പിക്കുന്നില്ല, എസി കംപ്രസ്സർ ഓൺ ആകുന്നില്ല, കൂളിംഗ് ഗ്യാസ് ലീക്ക് ആയി, ചൂട് കാറ്റ് വരുന്നു"
catalog["ac_cooling_failure"][13] = "ਏਸੀ ਕੂਲਿੰਗ ਨਹੀਂ ਕਰ ਰਿਹਾ, ਏਸੀ ਕੰਪ੍ਰੈਸਰ ਚਾਲੂ ਨਹੀਂ ਹੁੰਦਾ, ਗੈਸ ਲੀਕ, ਗਰਮ ਹਵਾ ਸੁੱਟ ਰਿਹਾ ਹੈ, ਏਅਰ ਕੰਡੀਸ਼ਨਰ"
catalog["ac_cooling_failure"][14] = "ଏୟାର କଣ୍ଡିସନର ଏସି ଥଣ୍ଡା କରୁନାହିଁ, ଏସି କମ୍ପ୍ରେସର ଚାଲୁନାହିଁ, କୁଲିଂ ଗ୍ୟାସ ଲିକ୍ ହୋଇଛି, ଗରମ ପବନ ଆସୁଛି"
update("ac_cooling_failure", catalog["ac_cooling_failure"])

# 9. geyser_heating_issue: bathroom water heater geyser element
catalog["geyser_heating_issue"][8] = "বাথরুমের গিজার বা ওয়াটার হিটার গরম জল দিচ্ছে না, গিজার খারাপ, হিটিং এলিমেন্ট নষ্ট, ঠান্ডা জল আসছে"
catalog["geyser_heating_issue"][9] = "गिझर गरम पाणी देत नाही, बाथरूमचा वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, थंड पाणी येतंय"
catalog["geyser_heating_issue"][10] = "ગીઝર ગરમ પાણી આપતું નથી, બાથરૂમનું વોટર હીટર ખરાબ છે, હીટિંગ એલિમેન્ટ બળી ગયું છે, માત્ર ઠંડું પાણી આવે છે"
catalog["geyser_heating_issue"][12] = "ബാത്ത്റൂം ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, തണുത്ത വെള്ളം മാത്രം, ഗീസർ ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി"
catalog["geyser_heating_issue"][14] = "ବାଥରୁମ୍ ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ, ବାଥରୁମ୍ ୱାଟର ହିଟର ଖରାପ, ଥଣ୍ଡା ପାଣି ଆସୁଛି, ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି"
update("geyser_heating_issue", catalog["geyser_heating_issue"])

# 10. drain_block_sewerage
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે, પાણી નીકળતું નથી, ગટર વાસ, ડ્રેનેજ સીવરેજ પાઇપ લાઇન બ્લોક"
update("drain_block_sewerage", catalog["drain_block_sewerage"])

# 11. inverter_backup_failure: natural household inverter descriptions
catalog["inverter_backup_failure"][11] = "ಮನೆಯ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಟರಿ"
catalog["inverter_backup_failure"][14] = "ଘରେ କରେଣ୍ଟ ଗଲେ ଇନଭର୍ଟର ବ୍ୟାକଅପ୍ ଦେଉନାହିଁ, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, ଇନଭର୍ଟର ବିପ୍ ଶବ୍ଦ କରୁଛି, ୟୁପିଏସ୍ ଖରାପ"
update("inverter_backup_failure", catalog["inverter_backup_failure"])

# 12. washing_machine_fault
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಬಟ್ಟೆ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ, ಡ್ರಮ್ ತಿರುಗ್ತಿಲ್ಲ, ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಡ್ರೈನ್ ಆಗಿಲ್ಲ, ವಾಷಿಂಗ್ ಮೆಷಿನ್ ಎರರ್ ಕೋಡ್"
update("washing_machine_fault", catalog["washing_machine_fault"])

# 13. fan_repair_issue
catalog["fan_repair_issue"][11] = "ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ತುಂಬಾ ನಿಧಾನವಾಗಿ ತಿರುಗುತ್ತಿದೆ, ಕೆಪಾಸಿಟರ್ ಹೋಗಿದೆ, ಗುಂಯ್ ಶಬ್ದ, ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ರಿಪೇರಿ"
catalog["fan_repair_issue"][13] = "ਛੱਤ ਵਾਲਾ ਪੱਖਾ ਬਹੁਤ ਹੌਲੀ ਚੱਲਦਾ, ਕਪੈਸਿਟਰ ਸੜ ਗਿਆ, ਗੂੰਜਣ ਦੀ ਆਵਾਜ਼, ਛੱਤ ਵਾਲਾ ਸੀਲਿੰਗ ਪੱਖਾ"
update("fan_repair_issue", catalog["fan_repair_issue"])

# 14. deep_cleaning_sanitization
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ, ഉപ്പ് പാടുകൾ, ബാത്ത്റൂം ടൈൽ ക്ലീനിംഗ് ആസിഡ് വാഷ് ഡീപ് ക്ലീനിംഗ് സാനിറ്റൈସേഷൻ"
update("deep_cleaning_sanitization", catalog["deep_cleaning_sanitization"])

# 15. wall_dampness_painting
catalog["wall_dampness_painting"][12] = "ഭിത്തിയിലെ പെയിന്റ് അടർന്നു വീഴുന്നു, ഈർപ്പവും പൂപ്പലും പടർന്നു, വാട്ടർപ്രൂഫിംഗ് പുട്ടി പെയിന്റിംഗ് വേണം"
update("wall_dampness_painting", catalog["wall_dampness_painting"])

# 16. curtain_blind_mounting
catalog["curtain_blind_mounting"][13] = "ਖਿੜਕੀ ਦੇ ਪਰਦਿਆਂ ਵਾਲਾ ਪਾਈਪ ਢਿੱਲਾ ਹੋ ਕੇ ਡਿੱਗ ਪਿਆ, ਰੋਲਰ ਬਲਾਇੰਡਸ ਅੜ ਗਏ, ਨਵਾਂ ਕਰਟਨ ਰੌਡ ਬਰੈਕਟ ਲਗਵਾਉਣਾ ਹੈ"
update("curtain_blind_mounting", catalog["curtain_blind_mounting"])

# 17. security_alarm_system
catalog["security_alarm_system"][13] = "ਸੁਰੱਖਿਆ ਚੋਰੀ ਅਲਾਰਮ ਬਿਨਾਂ ਵਜ੍ਹਾ ਵੱਜ ਰਿਹਾ ਹੈ, ਮੋਸ਼ਨ ਸੈਂਸਰ ਫਾਲਸ ਅਲਾਰਮ, ਸਮੋਕ ਡਿਟੈਕਟਰ ਸਾਇਰਨ"
catalog["security_alarm_system"][14] = "ସୁରକ୍ଷା ଚୋରି ଆଲାର୍ମ ବିନା କାରଣରେ ବାଜୁଛି, ମୋସନ୍ ସେନ୍ସର ଭୁଲ୍ ସିଗ୍ନାଲ୍, ସ୍ମୋକ୍ ଡିଟେକ୍ଟର ସାଇରନ୍"
update("security_alarm_system", catalog["security_alarm_system"])

p, f = eval_bench()
print(f"\nResult after Step 3: {p}/{len(test_queries)} ({p/len(test_queries)*100:.1f}%)")
if f:
    print(f"Remaining {len(f)} fails:")
    for lbl, exp_c, ts, top_c, tops, margin in f:
        print(f"  ✗ {lbl:30s} -> Target: {exp_c:26s} ({ts:.3f}) | Top: {top_c:26s} ({tops:.3f}) [+{margin:.3f}]")
