# -*- coding: utf-8 -*-
"""
Batch Solver:
Applies synchronized full-catalog batch updates to break through the distractor plateau.
"""
import sys, os, copy, json
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

print("Loading model...")
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

test_queries = [tc[0] for tc in exp.TEST_CASES]
test_expected = [tc[1] for tc in exp.TEST_CASES]
test_labels = [tc[2] for tc in exp.TEST_CASES]

print("Pre-encoding 85 test queries...")
Q = model.encode(test_queries, normalize_embeddings=True)

catalog_ids = [item["id"] for item in exp.CATALOG_ITEMS]
id_to_idx = {cid: i for i, cid in enumerate(catalog_ids)}

# Load current state from auto_solve_state.json
state_path = os.path.join(os.path.dirname(__file__), "auto_solve_state.json")
with open(state_path, "r", encoding="utf-8") as f:
    catalog = json.load(f)

centroids = np.zeros((len(catalog_ids), 384), dtype=np.float32)

def compute_centroid(texts):
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    norm = np.linalg.norm(c)
    return (c / norm) if norm > 0 else c

for cid in catalog_ids:
    centroids[id_to_idx[cid]] = compute_centroid(catalog[cid])

def evaluate(tag=""):
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
            fails.append((i, test_labels[i], exp_cid, float(target_score), top_cid, float(top_score), float(top_score - target_score)))
    print(f"\n[{tag}] Accuracy: {passed}/{len(test_queries)} ({passed/len(test_queries)*100:.1f}%)")
    if fails:
        print(f"Remaining {len(fails)} fails:")
        for idx, lbl, exp_c, ts, top_c, tops, margin in fails:
            print(f"  #{idx:2d} ✗ {lbl:30s} -> Target: {exp_c:26s} ({ts:.3f}) | Top: {top_c:26s} ({tops:.3f}) [+{margin:.3f}]")
    return passed, fails

evaluate("Current Baseline (74/85)")

# ─────────────────────────────────────────────────────────────────────────────
# 1. inverter_backup_failure: Natural conversational phrasing in ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["inverter_backup_failure"] = [
    "Home inverter and battery not giving backup when power goes out, battery not charging and inverter is beeping continuously.",
    "The inverter is beeping and there is no backup during power cut, home inverter battery dead and not charging.",
    "inverter beep pannudhu battery charge aagala, current pona backup illai, home inverter battery problem",
    "Ghar mein bijli jaane par inverter backup nahi de raha, battery charge nahi ho rahi, inverter beep kar raha hai.",
    "வீட்டில் கரண்ட் போனா இன்வெர்ட்டர் பேக்கப் தரல, பேட்டரி சார்ஜ் ஆகல, இன்வெர்ட்டர் பீப் சத்தம் போடுது, யுபிಎಸ್ கெட்டுப்போச்சு",
    "घर में बिजली जाने पर इन्वर्टर बैकअप नहीं दे रहा, बैटरी चार्ज नहीं हो रही है और इन्वर्टर बीप कर रहा है",
    "ఇంట్లో కరెంట్ పోతే ఇన్వర్టర్ బ్యాకప్ ఇవ్వడం లేదు, బ్యాటరీ చార్జ్ కావడం లేదు, ఇన్వర్టర్ బీప్ సౌండ్ వస్తుంది",
    "home inverter battery not charging power cut backup failure beeping alarm UPS inverter repair",
    "ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই, ঘরে বিদ্যুৎ চলে গেলে ইনভার্টার ব্যাকআপ দিচ্ছে না ইউপিএস খারাপ",
    "घरात लाईट किंवा वीज गेल्यावर इन्व्हर्टर बॅकअप देत नाही, बॅटरी चार्ज होत नाही, इन्व्हर्टर बीप आवाज करतोय",
    "ઘરમાં લાઈટ અથવા વીજળી જાય ત્યારે ઇન્વર્ટર બેકઅપ આપતું નથી, બેટરી ચાર્જ થતી નથી, ઇન્વર્ટર સતત બીપ અવાજ કરે છે",
    "ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಮನೆಯಲ್ಲಿ ಕರೆಂಟ್ ಹೋದಾಗ ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಕಪ್ ಕೊಡ್ತಿಲ್ಲ",
    "വീട്ടിൽ കറന്റ് പോയാൽ ഇൻവർട്ടർ യുപിഎസ് ബാക്കപ്പ് തരുന്നില്ല, ബാറ്ററി ചാർജ് ആകുന്നില്ല, ഇൻവർട്ടർ ബീപ് ശബ്ദം ഉണ്ടാക്കുന്നു",
    "ਘਰ ਵਿੱਚ ਬਿਜਲੀ ਜਾਣ ਤੇ ਇਨਵਰਟਰ ਯੂਪੀਐਸ ਬੈਕਅੱਪ ਨਹੀਂ ਦੇ ਰਿਹਾ, ਬੈਟਰੀ ਚਾਰਜ ਨਹੀਂ ਹੋ ਰਹੀ, ਇਨਵਰਟਰ ਬੀਪ ਕਰ ਰਿਹਾ ਹੈ",
    "ଇନଭର୍ଟର ବିପ୍ କରୁଛି ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଘରେ କରେଣ୍ଟ ଗଲେ ଇନଭର୍ଟର ବ୍ୟାକଅପ୍ ଦେଉନାହିଁ ୟୁପିଏସ୍ ଖରାପ",
]
centroids[id_to_idx["inverter_backup_failure"]] = compute_centroid(catalog["inverter_backup_failure"])

# ─────────────────────────────────────────────────────────────────────────────
# 2. washing_machine_fault: Natural conversational phrasing in ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["washing_machine_fault"] = [
    "Washing machine not draining or spinning clothes. Error code shown on display. Drum stuck or vibrating heavily.",
    "washing machine not working, clothes not spinning dry, machine not draining water after wash, error shown on display",
    "washing machine spin aagala, thanni poga matta, machine shake aagudhu, error code varudhu, drum odala",
    "washing machine spin nahi ho raha, paani nahi nikal raha, machine kapkap kar rahi, error code display pe",
    "வாஷிங் மெஷினில் துணி துவைத்த பிறகு டிரம் சுத்தல அல்லது ஸ்பின் ஆகல, தண்ணீர் வெளியே போகல ட்ரைன் ஆகல, எரர் கோடு காட்டுது",
    "वॉशिंग मशीन में कपड़े धोने के बाद ड्रम नहीं घूम रहा या स्पिन नहीं हो रहा, पानी ड्रेन नहीं हो रहा, स्क्रीन पर एरर कोड दिखा रहा है",
    "వాషింగ్ మెషిన్‌లో బట్టలు ఉతికిన తర్వాత డ్రమ్ తిరగడం లేదు లేదా స్పిన్ అవ్వడం లేదు, నీళ్ళు బయటకు పోవడం లేదు, ఎర్రర్ కోడ్ వస్తుంది",
    "washing machine clothes spin wash drain error code drum stuck shaking imbalance inlet drain pump",
    "ওয়াশিং মেশিনে জামাকাপড় ধোয়ার পর ড্রাম ঘুরছে না বা স্পিন হচ্ছে না, জল নিষ্কাশন বা ড্রেন হচ্ছে না, ডিসপ্লেতে এরর কোড দেখাচ্ছে",
    "वॉशिंग मशीनमध्ये कपडे धुतल्यानंतर ड्रम फिरत नाहीये किंवा स्पिन होत नाहीये, पाणी बाहेर पडत नाही, स्क्रीनवर एरर कोड दाखवतोय",
    "વોશિંગ મશીનમાં કપડાં ધોયા પછી ડ્રમ ફરતું નથી અથવા સ્પિન થતું નથી, પાણી ડ્રેઇન થતું નથી, સ્ક્રીન પર એરર કોડ બતાવે છે",
    "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಎರರ್ ಕೋಡ್, ವಾಷಿಂಗ್ ಮಷಿನ್ ಬಟ್ಟೆ ಡ್ರೈಯರ್ ಸ್ಪಿನ್ ಆಗುತ್ತಿಲ್ಲ ಡ್ರಮ್ ಸ್ಟಕ್ ಆಗಿದೆ ನೀರು ಡ್ರೈನ್ ಆಗಿಲ್ಲ",
    "വാഷിംഗ് മെഷീനിൽ തുണി കഴുകിയ ശേഷം ഡ്രം കറങ്ങുന്നില്ല അല്ലെങ്കിൽ സ്പിൻ ചെയ്യുന്നില്ല, വെള്ളം ഡ്രെയിൻ ആകുന്നില്ല, എറർ കോഡ് കാണിക്കുന്നു",
    "ਵਾਸ਼ਿੰਗ ਮਸ਼ੀਨ ਵਿੱਚ ਕੱਪੜੇ ਧੋਣ ਤੋਂ ਬਾਅਦ ਡ੍ਰਮ ਨਹੀਂ ਘੁੰਮ ਰਿਹਾ ਜਾਂ ਸਪਿਨ ਨਹੀਂ ਹੋ ਰਿਹਾ, ਪਾਣੀ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦਾ, ਐਰਰ ਕੋਡ ਆ ਰਿਹਾ ਹੈ",
    "ୱାଶିଂ ମେସିନରେ ଲୁଗା ଧୋଇବା ପରେ ଡ୍ରମ୍ ଘୁରୁନାହିଁ କିମ୍ବା ସ୍ପିନ୍ ହେଉନାହିଁ, ପାଣି ବାହାରକୁ ଯାଉନାହିଁ, ଏରର୍ କୋଡ୍ ଦେଖାଉଛି",
]
centroids[id_to_idx["washing_machine_fault"]] = compute_centroid(catalog["washing_machine_fault"])

# ─────────────────────────────────────────────────────────────────────────────
# 3. curtain_blind_mounting: Pure window curtains across ALL Indic slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["curtain_blind_mounting"] = [
    "Curtain rod bracket fell off wall. Roller blind jammed. New curtain track needed.",
    "curtain rod fell down, curtain bracket broke, roller blind not rolling, motorized blind not working, need to install curtain rail",
    "curtain rod pottupochu, curtain bracket velaikala, roller blind stuck aagi, motorized blind remote work aagala",
    "parda ka rod gir gaya, curtain rod lagana hai, roller blind stuck hai, motorized blind remote se nahi chal raha",
    "ஜன்னல் திரைச்சீலை கம்பி கீழே விழுந்துவிட்டது, கர்டன் ராட் பிராக்கெட் உடைந்துவிட்டது, புதிய திரைச்சீலை மாட்ட வேண்டும்",
    "पर्दे का रॉड गिर गया, पर्दे का ब्रैकेट टूट गया, खिड़की का नया पर्दा लगाना है",
    "కిటికీ కర్టెన్ రాడ్ పడిపోయింది, కర్టెన్ బ్రాకెట్ విరిగిపోయింది, కొత్త కర్టెన్ పైపు బిగించాలి",
    "curtain rod bracket fallen off wall window curtain track rail installation drape rod fitting",
    "জানালার কাপড়ের পর্দার রড খুলে নিচে পড়ে গেছে, পর্দা টাঙানোর ব্র্যাকেট ভেঙে গেছে, নতুন পর্দা লাগানো দরকার",
    "खिडकीचा कापडी पडद्याचा रॉड खाली पडला आहे, पडदा अडकवण्याचा ब्रॅकेट तुटला आहे, नवीन पडदा बसवणे",
    "બારીના કાપડના પડદાનો રોડ નીચે પડી ગયો છે, પડદો લટકાવવાનો બ્રેકેટ તૂટી ગયો છે, નવા પડદા લગાવવા",
    "ಕಿಟಕಿಯ ಬಟ್ಟೆ ಪರದೆ ರಾಡ್ ಸಡಿಲವಾಗಿ ಕೆಳಗೆ ಬಿದ್ದಿದೆ, ಪರದೆ ಹಾಕುವ ಬ್ರಾಕೆಟ್ ಮುರಿದಿದೆ, ಹೊಸ ಕರ್ಟನ್ ರಾಡ್ ಫಿಕ್ಸ್ ಮಾಡಬೇಕು",
    "ജനലിന്റെ തുണി കർട്ടൻ റോഡ് ഇളകി താഴെ വീണു, കർട്ടൻ ബ്രാക്കറ്റ് തകർന്നു, പുതിയ കർട്ടൻ റോഡ് പിടിപ്പിക്കണം",
    "ਖਿੜਕੀ ਦੇ ਕੱਪੜੇ ਵਾਲੇ ਪਰਦੇ ਲਾਹੁਣ ਤੇ ਟੰਗਣ ਵਾਲੀ ਪਾਈਪ ਟੁੱਟ ਗਈ, ਨਵਾਂ ਪਰਦਾ ਟੰਗਣ ਵਾਲਾ ਰੌਡ ਲਗਵਾਉਣਾ ਹੈ",
    "ଝରକାର କପଡ଼ା ପରଦା ତଳେ ଖସିପଡ଼ିଛି, ପରଦା ଟାଙ୍ଗିବା ବନ୍ଧନୀ ଭାଙ୍ଗିଯାଇଛି, ନୂଆ ପରଦା ଫିଟିଂ ଦରକାର",
]
centroids[id_to_idx["curtain_blind_mounting"]] = compute_centroid(catalog["curtain_blind_mounting"])

# ─────────────────────────────────────────────────────────────────────────────
# 4. mosquito_mesh_repair: Pure insect mesh/net across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["mosquito_mesh_repair"] = [
    "Mosquito mesh torn. Window net shredded. Aluminum frame bracket fell off. Sliding net jammed.",
    "mosquito net broke, window insect screen torn, mosquito mesh has holes, sliding mesh window jammed, screen door net torn",
    "mosquito mesh theeyudhu, window net pottupochu, mesh frame velaikala, sliding mesh stuck aagi, frame bracket odaindhuchu",
    "mosquito jali phat gayi, khidki ka jali toot gaya, frame ukhad gaya, sliding mesh jam ho gayi",
    "ஜன்னல் கொசு வலை கிழிந்துவிட்டது, விண்டோ நெட் பிரேம் உடைந்துவிட்டது, புதிய கொசு வலை மாட்ட வேண்டும்",
    "खिड़की की मच्छर जाली फट गई है, नेट फ्रेम टूट गया है, नई मच्छर जाली लगानी है",
    "కిటికీ దోమల జాలి చిరిగిపోయింది, నెట్ ఫ్రేమ్ విరిగిపోయింది, కొత్త దోమల నెట్ అమర్చాలి",
    "mosquito mesh torn hole shredded window insect screen aluminum net frame spline sliding mesh repair",
    "জানালার মশার নেট বা জালি ছিঁড়ে গেছে, মশার জালির ফ্রেম ভেঙে গেছে, নতুন মশার নেট লাগানো দরকার",
    "खिडकीची डासांची जाळी फाटली आहे, ॲल्युमिनियम नेट फ्रेम तुटलीये, नवीन मॉस्किटो नेट बसवायची आहे",
    "બારીની મચ્છરદાની જાળી ફાટી ગઈ છે, નેટ ફ્રેમ તૂટી ગઈ છે, નવી મોસ્કિટો નેટ ફિટ કરાવવી છે",
    "ಕಿಟಕಿಯ ಸೊಳ್ಳೆ ತಡೆಯುವ ಜಾಲರಿ ಹರಿದಿದೆ, ನೆಟ್ ಫ್ರೇಮ್ ಬಿರುಕು ಬಿಟ್ಟಿದೆ, ಹೊಸ ಸೊಳ್ಳೆ ನೆಟ್ ಅಳವಡಿಸಬೇಕು",
    "ജനലിലെ കൊതുക് തടയുന്ന വല കീറിപ്പോയി, നെറ്റ് ഫ്രെയിം തകർന്നു, പുതിയ കൊതുക് വല പിടിപ്പിക്കണം",
    "ਖਿੜਕੀ ਦੀ ਮੱਛਰਾਂ ਵਾਲੀ ਜਾਲੀ ਫਟ ਗਈ ਹੈ, ਨੈੱਟ ਫ੍ਰੇਮ ਖ਼ਰਾਬ ਹੋ ਗਿਆ ਹੈ, ਨਵੀਂ ਮੱਛਰ ਜਾਲੀ ਲਗਵਾਉਣੀ ਹੈ",
    "ଝରକାର ମଶା ନେଟ୍ ଜାଲି ଚିରିଯାଇଛି, ଆଲୁମିନିୟମ ନେଟ୍ ଫ୍ରେମ୍ ଭାଙ୍ଗିଯାଇଛି, ନୂଆ ମଶା ଜାଲି ଲଗାଇବା ଦରକାର",
]
centroids[id_to_idx["mosquito_mesh_repair"]] = compute_centroid(catalog["mosquito_mesh_repair"])

# ─────────────────────────────────────────────────────────────────────────────
# 5. security_alarm_system: Pure burglar siren across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["security_alarm_system"] = [
    "Burglar alarm going off randomly. PIR motion sensor false triggering. Smoke alarm beeping.",
    "home alarm going off by itself, security alarm false alarm, motion sensor not working properly, smoke detector beeping without smoke",
    "alarm veena adigudhu, motion sensor velaikala, smoke alarm beep aagudhu, door sensor work aagala, pir false trigger",
    "alarm bekar baj raha hai raat ko, motion sensor galat alarm de raha, smoke alarm beep without smoke, door sensor offline",
    "வீட்டு செக்யூரிட்டி சைரன் அலாரம் தேவையில்லாமல் அடிக்குது, மோஷன் சென்சார் தப்பு சிக்னல், தீ எச்சரிக்கை சைரன்",
    "घर का सुरक्षा सायरन अलार्म बिना वजह बज रहा है, मोशन सेंसर गलत अलार्म दे रहा, स्मोक अलार्म सायरन",
    "ఇంటి సెక్యూరిటీ సైరన్ అలారం కారణం లేకుండా మోగుతోంది, మోషన్ సెన్సార్ తప్పుడు సిగ్నల్, స్మోక్ అలారం",
    "burglar alarm false trigger PIR motion sensor smoke detector siren alarm security system tamper",
    "সিকিউরিটি সাইরেন অ্যালার্ম কারণ ছাড়াই বাজছে, মোশন সেন্সর ভুল সংকেত দিচ্ছে, স্মোক অ্যালার্ম সাইরেন",
    "सुरक्षा सायरन अलार्म कारण नसताना वाजतोय, मोशन सेन्सर खोटे संकेत देतोय, स्मोक डिटेक्टर सायरन",
    "સિક્યુરિટી સાયરન એલાર્મ કારણ વગર વાગે છે, મોશન સેન્સર ખોટા એલાર્મ આપે છે, સ્મોક ડિટેક્ટર સાયરન",
    "ಮನೆಯ ಕಳ್ಳರ ಸೆಕ್ಯುರಿಟಿ ಸೈರನ್ ಮತ್ತು ಮೋಷನ್ ಡಿಟೆಕ್ಟರ್ ಸೆನ್ಸರ್ ತಪ್ಪು ಅಲಾರಾಂ ಮಾಡುತ್ತಿದೆ, ಸ್ಮೋಕ್ ಡಿಟೆಕ್ಟರ್ ಸೈರನ್",
    "വീട്ടിലെ സെക്യൂരിറ്റി സൈറൻ അലാറം അകാരണമായി മുഴങ്ങുന്നു, മോഷൻ സെൻസർ തെറ്റായി പ്രവർത്തിക്കുന്നു, സ്മോക്ക് സൈറൻ",
    "ਘਰ ਦੀ ਸੁਰੱਖਿਆ ਚੋਰੀ ਸਾਇਰਨ ਬਿਨਾਂ ਵਜ੍ਹਾ ਵੱਜ ਰਿਹਾ ਹੈ, ਮੋਸ਼ਨ ਸੈਂਸਰ ਫਾਲਸ ਅਲਾਰਮ, ਸਮੋਕ ਡਿਟੈਕਟਰ ਸਾਇਰਨ",
    "ଘର ସୁରକ୍ଷା ଚୋରି ସାଇରନ୍ ଆଲାର୍ମ ବିନା କାରଣରେ ବାଜୁଛି, ମୋସନ୍ ସେନ୍ସର ଭୁଲ୍ ସିଗ୍ନାଲ୍, ସ୍ମୋକ୍ ଆଲାର୍ମ ସାଇରନ୍",
]
centroids[id_to_idx["security_alarm_system"]] = compute_centroid(catalog["security_alarm_system"])

# ─────────────────────────────────────────────────────────────────────────────
# 6. wall_dampness_painting: Pure dampness & waterproofing across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["wall_dampness_painting"] = [
    "Wall dampness and seepage. Peeling paint and efflorescence. Putty waterproofing needed.",
    "paint peeling off wet wall, white salt deposits on wall, damp patches on ceiling, wall seepage treatment, repaint wall",
    "suvar la eeram varudhu, paint peeldhu, wall dampness seepage, waterproofing panna vennum, putty paint vela",
    "deewar pe seelan aa rahi hai, paint chhoot raha hai, shora nikal raha, waterproofing aur putty painting karwani hai",
    "சுவரில் ஈரம் மற்றும் கசிவு, பெயிண்ட் உரிந்து விழுகிறது, உப்பு பூத்து போயிருக்கு, வாட்டர்ப்ரூஃபிங் பெயிண்டிங் வேலை",
    "दीवार पर सीलन और पानी का रिसाव, पेंट पपड़ी बनकर छूट रहा है, वाटरप्रूफिंग और पुट्टी पेंटिंग चाहिए",
    "గోడలపై తేమ మరియు నీటి ఊట, పెయింట్ పెచ్చులూడిపోతుంది, వాటర్‌ప్రూఫింగ్ మరియు పుట్టీ పెయింటింగ్ కావాలి",
    "wall dampness seepage moisture efflorescence saltpetre peeling paint blistering waterproofing primer putty",
    "দেয়ালে স্যাঁতসেঁতে ভাব ও জল চুইয়ে পড়া, রঙ চটা ও পপড়ি ওঠা, ওয়াটারপ্রুফিং ও পুটি পেইন্টিং দরকার",
    "भिंतीवर ओलावा आणि गळती, पेंट उखडून पडत आहे, पांढरा थर, वॉटरप्रूफिंग आणि पुट्टी पेंटिंग हवे आहे",
    "દીવાલ પર ભેજ અને પાણીનો ભરાવો, કલર ઊખડી રહ્યો છે, ક્ષાર જામી ગયો છે, વોટરપ્રૂફિંગ પુટ્ટી કલરકામ",
    "ಗೋಡೆಯಲ್ಲಿ ತೇವಾಂಶ ಮತ್ತು ನೀರಿನ ಜಿನುಗುವಿಕೆ, ಬಣ್ಣ ಕಿತ್ತುಬರುತ್ತಿದೆ, ಉಪ್ಪು ಹಿಡಿದಿದೆ, ವಾಟರ್‌ಪ್ರೂಫಿಂಗ್ ಪುಟ್ಟಿ ಪೇಂಟಿಂಗ್ ಬೇಕು",
    "വീടിന്റെ ഭിത്തിയിൽ ഈർപ്പവും പൂപ്പലും പെയിന്റ് അടർന്നു വീഴലും, ഭിത്തിയിലെ ഈർപ്പം മാറ്റാൻ വാട്ടർപ്രൂഫിംഗ് പെയിന്റിംഗ് വേണം",
    "ਕੰਧਾਂ ਤੇ ਸਿੱਲ੍ਹ ਅਤੇ ਲੂਣ ਚੜ੍ਹ ਰਿਹਾ ਹੈ, ਪੇਂਟ ਪੇਪੜੀ ਬਣ ਕੇ ਉੱਖੜ ਰਿਹਾ ਹੈ, ਵਾਟਰਪਰੂਫਿੰਗ ਪੁਟੀ ਪੇਂਟ ਚਾਹੀਦਾ ਹੈ",
    "କାନ୍ଥରେ ଓଦାଳିଆ ଭାବ ଓ ପାଣି ଜିପିବା, ରଙ୍ଗ ଛାଡ଼ି ପପୁଡ଼ି ହେବା, ୱାଟରପ୍ରୁଫିଂ ଏବଂ ପୁଟି ରଙ୍ଗ କାମ ଦରକାର",
]
centroids[id_to_idx["wall_dampness_painting"]] = compute_centroid(catalog["wall_dampness_painting"])

# ─────────────────────────────────────────────────────────────────────────────
# 7. geyser_heating_issue: Natural bathroom geyser water heater across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["geyser_heating_issue"] = [
    "Bathroom geyser not heating water. Heating element burnt. Thermostat tripped. Only cold water coming.",
    "geyser stopped working, hot water not coming from bathroom, water heater broken, lukewarm water only",
    "geyser kaayala, hot water varala, bathroom geyser velaikala, thermostat trip aagudhu, element ketta",
    "geyser garam nahi kar raha, garam paani nahi aa raha, water heater kharab, geyser chalu nahi ho raha",
    "பாத்ரூம் கீசர் போட்டாலும் சூடான தண்ணீர் வரல, வாட்டர் ஹீட்டர் கெட்டுப்போச்சு, ஹீட்டிங் எலிமெண்ட் எரிஞ்சுபோச்சு, வெறும் குளிர்ந்த தண்ணீர்",
    "बाथरूम का गीजर चालू है पर गर्म पानी नहीं आ रहा, वॉटर हीटर खराब है, हीटिंग एलिमेंट जल गया, सिर्फ ठंडा पानी आ रहा है",
    "బాత్‌రూమ్ గీజర్ ఆన్ చేసినా వేడి నీళ్ళు రావడం లేదు, వాటర్ హీటర్ పాడైంది, హీటింగ్ ఎలిమెంట్ కాలిపోయింది, చల్లని నీళ్ళు మాత్రమే వస్తున్నాయి",
    "geyser water heater not working heating element burnt thermostat fault tank leaking lukewarm shock hot water",
    "গিজার গরম জল দিচ্ছে না ওয়াটার হিটার নষ্ট ঠান্ডা জল, বাথরুমের ইলেকট্রিক গিজার হিটিং এলিমেন্ট খারাপ গরম জল নেই",
    "गिझर चालू आहे पण गरम पाणी येत नाही, बाथरूमचा वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, फक्त थंड पाणी येतंय",
    "ગીઝર ગરમ પાણી નથી આપતું વોટર હીટર ખરાબ માત્ર ઠંડું પાણી, ગીઝરનું હીટિંગ એલિમેન્ટ બળી ગયું છે ગરમ પાણી નથી આવતું",
    "ಗೀಜರ್ ಆನ್ ಆದ್ರೂ ಬಿಸಿ ನೀರು ಬರ್ತಿಲ್ಲ, ಬಾತ್‌ರೂಮ್ ವಾಟರ್ ಹೀಟರ್ ಕೆಟ್ಟಿದೆ, ಹೀಟಿಂಗ್ ಎಲಿಮೆಂಟ್ ಸುಟ್ಟುಹೋಗಿದೆ, ಬರೀ ತಣ್ಣೀರು ಮಾತ್ರ ಬರ್ತಿದೆ",
    "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി, ബാത്ത്റൂം ഗീസർ കോയിൽ കരിഞ്ഞു തണുത്ത വെള്ളം മാത്രം",
    "ਗੀਜ਼ਰ ਗਰਮ ਪਾਣੀ ਨਹੀਂ ਦੇ ਰਿਹਾ, ਬਾਥਰੂਮ ਦਾ ਵਾਟਰ ਹੀਟਰ ਖ਼ਰਾਬ ਹੈ, ਹੀਟਿੰਗ ਐਲੀਮੈਂਟ ਸੜ ਗਿਆ ਹੈ, ਸਿਰਫ਼ ਠੰਡਾ ਪਾਣੀ ਆ ਰਿਹਾ ਹੈ",
    "ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ ୱାଟର ହିଟର ଖରାପ ଥଣ୍ଡା ପାଣି ଆସୁଛି, ବାଥରୁମ୍ ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି",
]
centroids[id_to_idx["geyser_heating_issue"]] = compute_centroid(catalog["geyser_heating_issue"])

# ─────────────────────────────────────────────────────────────────────────────
# 8. water_tank_cleaning: Pure overhead storage tank cleaning & bleaching
# ─────────────────────────────────────────────────────────────────────────────
catalog["water_tank_cleaning"] = [
    "Overhead water tank dirty with mud and algae. Deep cleaning and chlorine disinfection required.",
    "overhead tank cleaning needed, water storage tank has dirt and sediment, algae in water tank, sump cleaning service",
    "overhead thanni tank kazhuval, kaai algae varudhu, smell varudhu, sump clean pannum, bleaching podanum",
    "overhead paani ki tanki saaf karni, kaai algae lag gayi, gandh sediment, sump cleaning aur bleaching powder",
    "ஓவர்ஹெட் தண்ணீர் தொட்டி அசுத்தமாகி பாசி படிந்துள்ளது, வாட்டர் டேங்க் டீப் கிளீனிங் மற்றும் பிளீச்சிங் தேவை",
    "छत की पानी की टंकी में काई और कीचड़ जमा है, ओवरहेड टैंक गहरी सफाई और ब्लीचिंग की जरूरत है",
    "పైకప్పు నీటి ట్యాంక్ మురికిగా ఉంది నాచు పట్టింది, ఓవర్‌హెడ్ ట్యాంక్ డీప్ క్లీనింగ్ మరియు బ్లీచింగ్ కావాలి",
    "water tank cleaning overhead storage tank mud sediment algae chlorination bleaching sump cleaning sludge",
    "ছাদের ওভারহেড স্টোরেজ ট্যাঙ্কের ভিতরের কাদা ও শ্যাওলা গভীর সাফাই, ট্যাঙ্ক ব্লিচિંગ ওয়াশ সার্ভিস",
    "छतावरील पाण्याची टाकी घाण झालीये शेवाळ साचले आहे, ओव्हरहेड टाकी स्वच्छता आणि ब्लिचिंग पावडर धुलाई",
    "ધાબા પરની પાણીની ટાંકીમાં કાદવ અને લીલ જામી ગઈ છે, ઓવરહેડ ટાંકી સાફ કરવી અને ક્લોરિનેશન કરાવવું",
    "ಮೇಲ್ಛಾವಣಿ ನೀರಿನ ಸಿಂಟೆಕ್ಸ್ ಟ್ಯಾಂಕ್‌ನಲ್ಲಿ ಪಾಚಿ ಮತ್ತು ಕೆಸರು ತುಂಬಿದೆ, ಓವರ್‌ಹೆಡ್ ಟ್ಯಾಂಕ್ ಆಳವಾದ ಕ್ಲೀನಿಂಗ್ ಮತ್ತು ಬ್ಲೀಚಿಂಗ್",
    "മേൽക്കൂരയിലെ വാട്ടർ ടാങ്കിൽ പായലും ചെളിയും അടിഞ്ഞു കൂടിയിരിക്കുന്നു, ഓവർഹെഡ് ടാങ്ക് ഡീപ് ക്ലീനിംഗ് വേണം",
    "ਛੱਤ ਵਾਲੀ ਪਾਣੀ ਦੀ ਟੈਂਕੀ ਵਿੱਚ ਕਾਈ ਅਤੇ ਗਾਰ ਜੰਮ ਗਈ ਹੈ, ਓਵਰਹੈੱਡ ਟੈਂਕੀ ਡੀਪ ਕਲੀਨਿੰਗ ਅਤੇ ਬਲੀਚਿੰਗ",
    "ଛାତ ଉପରେ ଥିବା ସିଣ୍ଟେକ୍ସ ପାଣି ଟାଙ୍କି ଭିତର ସଫେଇ, କାଦୁଅ ଶିଉଳି ସଫା ଓ ବ୍ଲିଚିଂ ପାଉଡର ଧୁଆ",
]
centroids[id_to_idx["water_tank_cleaning"]] = compute_centroid(catalog["water_tank_cleaning"])

evaluate("After Comprehensive Batch Update")

# Save state
with open("backend/ml_training/auto_solve_state.json", "w", encoding="utf-8") as out_f:
    json.dump(catalog, out_f, ensure_ascii=False, indent=2)
print("Saved state to auto_solve_state.json")
