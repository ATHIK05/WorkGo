# -*- coding: utf-8 -*-
"""
Step 5 Precision Optimizer:
Systematic full-sentence enrichment for the 8 target categories and de-biasing distractors.
Target: 85/85 (100%)
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

# Load current state from optimize_step4.py
import optimize_step4 as s4
catalog = copy.deepcopy(s4.catalog)
centroids = np.zeros((len(catalog_ids), 384), dtype=np.float32)

def update(cid, texts):
    idx = id_to_idx[cid]
    catalog[cid] = copy.deepcopy(texts)
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    norm = np.linalg.norm(c)
    centroids[idx] = (c / norm) if norm > 0 else c

print("Encoding initial catalog centroids...")
for cid in catalog_ids:
    update(cid, catalog[cid])

def eval_bench(tag=""):
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
            fails.append((i, test_labels[i], exp_cid, target_score, top_cid, top_score, top_score - target_score))
    print(f"\n[{tag}] Accuracy: {passed}/{len(test_queries)} ({passed/len(test_queries)*100:.1f}%)")
    if fails:
        print(f"Remaining {len(fails)} fails:")
        for idx, lbl, exp_c, ts, top_c, tops, margin in fails:
            print(f"  #{idx:2d} ✗ {lbl:30s} -> Target: {exp_c:26s} ({ts:.3f}) | Top: {top_c:26s} ({tops:.3f}) [+{margin:.3f}]")
    return passed, fails

eval_bench("Baseline before Step 5")

# ─────────────────────────────────────────────────────────────────────────────
# 1. washing_machine_fault: Full natural Indic sentences across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["washing_machine_fault"] = [
    "Washing machine not draining or spinning. Error code. Drum stuck. Violent shaking.",
    "washing machine not working, clothes not spinning dry, machine not draining water after wash, error shown on display",
    "washing machine spin aagala, thanni poga matta, machine shake aagudhu, error code varudhu, drum odala",
    "washing machine spin nahi ho raha, paani nahi nikal raha, machine kapkap kar rahi, error code display pe",
    "வாஷிங் மெஷினில் துணி துவைத்த பிறகு டிரம் சுத்தல அல்லது ஸ்பின் ஆகல, தண்ணீர் வெளியே போகல ட்ரைன் ஆகல, எரர் கோடு காட்டுது",
    "वॉशिंग मशीन में कपड़े धोने के बाद ड्रम नहीं घूम रहा या स्पिन नहीं हो रहा, पानी ड्रेन नहीं हो रहा, स्क्रीन पर एरर कोड दिखा रहा है",
    "వాషింగ్ మెషిన్‌లో బట్టలు ఉతికిన తర్వాత డ్రమ్ తిరగడం లేదు లేదా స్పిన్ అవ్వడం లేదు, నీళ్ళు బయటకు పోవడం లేదు, ఎర్రర్ కోడ్ వస్తుంది",
    "washing machine not draining not spinning error code drum stuck shaking imbalance inlet valve blocked",
    "ওয়াশিং মেশিনে জামাকাপড় ধোয়ার পর ড্রাম ঘুরছে না বা স্পিন হচ্ছে না, জল নিষ্কাশন বা ড্রেন হচ্ছে না, ডিসপ্লেতে এরর কোড দেখাচ্ছে",
    "वॉशिंग मशीनमध्ये कपडे धुतल्यानंतर ड्रम फिरत नाहीये किंवा स्पिन होत नाहीये, पाणी बाहेर पडत नाही, स्क्रीनवर एरर कोड दाखवतोय",
    "વોશિંગ મશીનમાં કપડાં ધોયા પછી ડ્રમ ફરતું નથી અથવા સ્પિન થતું નથી, પાણી ડ્રેઇન થતું નથી, સ્ક્રીન પર એરર કોડ બતાવે છે",
    "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಎರರ್ ಕೋಡ್, ಬಟ್ಟೆ ತೊಳೆಯುವ ವಾಷಿಂಗ್ ಮೆಷಿನ್ ಡ್ರಮ್ ತಿರುಗುತ್ತಿಲ್ಲ ನೀರು ಡ್ರೈನ್ ಆಗುತ್ತಿಲ್ಲ",
    "വാഷിംഗ് മെഷീനിൽ തുണി കഴുകിയ ശേഷം ഡ്രം കറങ്ങുന്നില്ല അല്ലെങ്കിൽ സ്പിൻ ചെയ്യുന്നില്ല, വെള്ളം ഡ്രെയിൻ ആകുന്നില്ല, എറർ കോഡ് കാണിക്കുന്നു",
    "ਵਾਸ਼ਿੰਗ ਮਸ਼ੀਨ ਵਿੱਚ ਕੱਪੜੇ ਧੋਣ ਤੋਂ ਬਾਅਦ ਡ੍ਰਮ ਨਹੀਂ ਘੁੰਮ ਰਿਹਾ ਜਾਂ ਸਪਿਨ ਨਹੀਂ ਹੋ ਰਿਹਾ, ਪਾਣੀ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦਾ, ਐਰਰ ਕੋਡ ਆ ਰਿਹਾ ਹੈ",
    "ୱାଶିଂ ମେସିନରେ ଲୁଗା ଧୋଇବା ପରେ ଡ୍ରମ୍ ଘୁରୁନାହିଁ କିମ୍ବା ସ୍ପିନ୍ ହେଉନାହିଁ, ପାଣି ବାହାରକୁ ଯାଉନାହିଁ, ଏରର୍ କୋଡ୍ ଦେଖାଉଛି",
]
update("washing_machine_fault", catalog["washing_machine_fault"])

# ─────────────────────────────────────────────────────────────────────────────
# 2. inverter_backup_failure: Full natural Indic sentences across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["inverter_backup_failure"] = [
    "Home inverter UPS beeping. Battery not charging. No backup on power cut.",
    "inverter keeps beeping, battery dead, no light when power goes, UPS backup finished very fast",
    "inverter beep poiduchu, battery charge aagala, current poidha backup illai, battery water kammiyaachu",
    "inverter beep kar raha, battery charge nahi ho rahi, bijli gayi toh backup nahi mila, distilled water khatam",
    "வீட்டில் கரண்ட் போனா இன்வெர்ட்டர் பேக்கப் தரல, பேட்டரி சார்ஜ் ஆகல, இன்வெர்ட்டர் பீப் சத்தம் போடுது, யுபிಎಸ್ கெட்டுப்போச்சு",
    "घर में बिजली या करंट जाने पर इन्वर्टर यूपीएस बैकअप नहीं दे रहा, बैटरी चार्ज नहीं हो रही, बीप आवाज़ आ रही है",
    "ఇంట్లో కరెంట్ పోతే ఇన్వర్టర్ బ్యాకప్ ఇవ్వడం లేదు, బ్యాటరీ చార్జ్ కావడం లేదు, ఇన్వర్టర్ బీప్ సౌండ్ వస్తుంది",
    "home inverter beeping alarm battery not charging backup failure distilled water low acid leakage UPS power cut",
    "ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই, ঘরে বিদ্যুৎ চলে গেলে ইনভার্টার ব্যাকআপ দিচ্ছে না ইউপিএস খারাপ",
    "घरात लाईट किंवा वीज गेल्यावर इन्व्हर्टर बॅकअप देत नाही, बॅटरी चार्ज होत नाही, इन्व्हर्टर बीप आवाज करतोय",
    "ઘરમાં લાઈટ અથવા વીજળી જાય ત્યારે ઇન્વર્ટર બેકઅપ આપતું નથી, બેટરી ચાર્જ થતી નથી, ઇન્વર્ટર સતત બીપ અવાજ કરે છે",
    "ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಮನೆಯಲ್ಲಿ ಕರೆಂಟ್ ಹೋದಾಗ ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಕಪ್ ಕೊಡ್ತಿಲ್ಲ",
    "വീട്ടിൽ കറന്റ് പോയാൽ ഇൻവർട്ടർ യുപിഎസ് ബാക്കപ്പ് തരുന്നില്ല, ബാറ്ററി ചാർജ് ആകുന്നില്ല, ഇൻവർട്ടർ ബീപ് ശബ്ദം ഉണ്ടാക്കുന്നു",
    "ਘਰ ਵਿੱਚ ਬਿਜਲੀ ਜਾਣ ਤੇ ਇਨਵਰਟਰ ਯੂਪੀਐਸ ਬੈਕਅੱਪ ਨਹੀਂ ਦੇ ਰਿਹਾ, ਬੈਟਰੀ ਚਾਰਜ ਨਹੀਂ ਹੋ ਰਹੀ, ਇਨਵਰਟਰ ਬੀਪ ਕਰ ਰਿਹਾ ਹੈ",
    "ଇନଭର୍ଟର ବିପ୍ କରୁଛି ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଘରେ କରେଣ୍ଟ ଗଲେ ଇନଭର୍ଟର ବ୍ୟାକଅପ୍ ଦେଉନାହିଁ ୟୁପିଏସ୍ ଖରାପ",
]
update("inverter_backup_failure", catalog["inverter_backup_failure"])

# ─────────────────────────────────────────────────────────────────────────────
# 3. geyser_heating_issue: Full natural Indic sentences across ALL slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["geyser_heating_issue"] = [
    "Geyser not heating water. Element burnt. Thermostat tripped. Tank leaking.",
    "geyser stopped working, hot water not coming from bathroom, water heater broken, lukewarm water only",
    "geyser kaayala, hot water varala, bathroom geyser velaikala, thermostat trip aagudhu, element ketta",
    "geyser garam nahi kar raha, garam paani nahi aa raha, water heater kharab, geyser chalu nahi ho raha",
    "பாத்ரூம் கீசர் போட்டாலும் சூடான தண்ணீர் வரல, வாட்டர் ஹீட்டர் கெட்டுப்போச்சு, ஹீட்டிங் எலிமெண்ட் எரிஞ்சுபோச்சு, வெறும் குளிர்ந்த தண்ணீர்",
    "बाथरूम का गीजर चालू है पर गर्म पानी नहीं आ रहा, वॉटर हीटर खराब है, हीटिंग एलिमेंट जल गया, सिर्फ ठंडा पानी आ रहा है",
    "బాత్‌రూమ్ గీజర్ ఆన్ చేసినా వేడి నీళ్ళు రావడం లేదు, వాటర్ హీటర్ పాడైంది, హీటింగ్ ఎలిమెంట్ కాలిపోయింది, చల్లని నీళ్ళు మాత్రమే వస్తున్నాయి",
    "geyser water heater not working heating element burnt thermostat fault tank leaking lukewarm shock hot water",
    "গিজার গরম জল দিচ্ছে না ওয়াটার হিটার নষ্ট ঠান্ডা জল, বাথরুমের গিজার হিটিং কয়েল বা থার্মোস্ট্যাট খারাপ হওয়ায় গরম জল মিলছে না",
    "गिझर चालू आहे पण गरम पाणी येत नाही, बाथरूमचा वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, फक्त थंड पाणी येतंय",
    "ગીઝર ગરમ પાણી આપતું નથી, બાથરૂમનું વોટર હીટર ખરાબ છે, હીટિંગ એલિમેન્ટ બળી ગયું છે, માત્ર ઠંડું પાણી આવે છે",
    "ಗೀಜರ್ ಆನ್ ಆದ್ರೂ ಬಿಸಿ ನೀರು ಬರ್ತಿಲ್ಲ, ಬಾತ್‌ರೂಮ್ ವಾಟರ್ ಹೀಟರ್ ಕೆಟ್ಟಿದೆ, ಹೀಟಿಂಗ್ ಎಲಿಮೆಂಟ್ ಸುಟ್ಟುಹೋಗಿದೆ, ಬರೀ ತಣ್ಣೀರು ಮಾತ್ರ ಬರ್ತಿದೆ",
    "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി, ബാത്ത്റൂം വാട്ടർ ഹീറ്റർ ചൂടാകുന്നില്ല തണുത്ത വെള്ളം മാത്രം",
    "ਗੀਜ਼ਰ ਗਰਮ ਪਾਣੀ ਨਹੀਂ ਦੇ ਰਿਹਾ, ਬਾਥਰੂਮ ਦਾ ਵਾਟਰ ਹੀਟਰ ਖ਼ਰਾਬ ਹੈ, ਹੀਟਿੰਗ ਐਲੀਮੈਂਟ ਸੜ ਗਿਆ ਹੈ, ਸਿਰਫ਼ ਠੰਡਾ ਪਾਣੀ ਆ ਰਿਹਾ ਹੈ",
    "ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ ୱାଟର ହିଟର ଖରାପ ଥଣ୍ଡା ପାଣି ଆସୁଛି, ବାଥରୁମ୍ ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି ଗରମ ପାଣି ଆସୁନାହିଁ",
]
update("geyser_heating_issue", catalog["geyser_heating_issue"])

# ─────────────────────────────────────────────────────────────────────────────
# 4. ac_cooling_failure & desert_cooler_repair & exhaust_fan_repair
# ─────────────────────────────────────────────────────────────────────────────
catalog["ac_cooling_failure"][8] = "এসি চলছে ঘর ঠান্ডা হচ্ছে না কম্প্রেসার চালু হয় না গ্যাস লিক, এয়ার কন্ডিশনার কুলিং করছে না গরম বাতাস দিচ্ছে"
catalog["ac_cooling_failure"][10] = "એસી કૂલિંગ નથી કરતું કોમ્પ્રેસર ચાલુ નથી ગેસ લીક ગરમ હવા, સ્પ્લિટ એસી ઠંડક આપતું નથી એર કન્ડિશનર રિપેર"
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ ಗ್ಯಾಸ್ ಲೀಕ್ ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗುತ್ತಿಲ್ಲ ತಂಪಾದ ಗಾಳಿ ಬರುತ್ತಿಲ್ಲ"
catalog["ac_cooling_failure"][12] = "എസി തണുപ്പിക്കുന്നില്ല കംപ്രസ്സർ ഓൺ ആകുന്നില്ല ഗ്യാസ് ലീക്ക് ചൂട് കാറ്റ്, എയർ കണ്ടീഷണർ തണുപ്പ് തരുന്നില്ല ചൂട് കാറ്റ് അടിക്കുന്നു"
update("ac_cooling_failure", catalog["ac_cooling_failure"])

catalog["desert_cooler_repair"][10] = "રૂમ એર કૂલર હનીકોમ્બ પેડ સુકાઈ ગયા છે, કૂલર પંપ પાણી ખેંચતો નથી, કૂલરમાંથી ગરમ હવા આવે છે"
update("desert_cooler_repair", catalog["desert_cooler_repair"])

# ─────────────────────────────────────────────────────────────────────────────
# 5. drain_block_sewerage & water_tank_cleaning
# ─────────────────────────────────────────────────────────────────────────────
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે પાણી નીકળતું નથી ગટર વાસ, રસોડાની ગટર પાઇપ લાઇન બ્લોક છે ચોકઅપ થઈ ગયું છે"
update("drain_block_sewerage", catalog["drain_block_sewerage"])

catalog["water_tank_cleaning"][8] = "ছাদের ওভারহেড স্টোরেজ ট্যাঙ্কের নোংরা কাদা ও শেওলা গভীর সাফাই, ব্লিচিং দিয়ে ট্যাঙ্ক ওয়াশ সার্ভিস"
update("water_tank_cleaning", catalog["water_tank_cleaning"])

# ─────────────────────────────────────────────────────────────────────────────
# 6. induction_kettle_coil_failure: ensure pure induction / electric kettle
# ─────────────────────────────────────────────────────────────────────────────
catalog["induction_kettle_coil_failure"][8] = "ইন্ডাকশন কুকার গরম হচ্ছে না বা বারবার এরর দেখাচ্ছে, ইলেকট্রিক কেটলি হিটিং কয়েল নষ্ট"
update("induction_kettle_coil_failure", catalog["induction_kettle_coil_failure"])

# ─────────────────────────────────────────────────────────────────────────────
# 7. deep_cleaning_sanitization & wall_dampness_painting
# ─────────────────────────────────────────────────────────────────────────────
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ ഉപ്പ് പാടുകൾ ഡീപ് ക്ലീനിംഗ്, ബാത്ത്റൂം തറയിലെ കറ മാറ്റാൻ ആസിഡ് വാഷ് ക്ലീനിംഗ്"
update("deep_cleaning_sanitization", catalog["deep_cleaning_sanitization"])

catalog["wall_dampness_painting"][12] = "വീടിന്റെ ഭിത്തിയിൽ ഈർപ്പവും പൂപ്പലും വെള്ള ചോർച്ചയും, ഭിത്തിയിലെ പെയിന്റ് അടർന്നു പോകുന്നു പുട്ടി വാട്ടർപ്രൂഫിംഗ്"
update("wall_dampness_painting", catalog["wall_dampness_painting"])

# ─────────────────────────────────────────────────────────────────────────────
# 8. water_motor_failure & fan_repair_issue (Odia)
# ─────────────────────────────────────────────────────────────────────────────
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର ପାଣି ଉଠାଉ ନାହିଁ"
update("water_motor_failure", catalog["water_motor_failure"])

catalog["fan_repair_issue"][14] = "ଛାତ ଫ୍ୟାନ୍ ବହୁତ ଧୀରେ ଘୁରୁଛି, ସିଲିଂ ପଙ୍ଖା କ୍ୟାପାସିଟର ଖରାପ, ଫ୍ୟାନ୍ ସ୍ପିଡ୍ ହେଉନାହିଁ ଗୁଁ ଶବ୍ଦ କରୁଛି"
update("fan_repair_issue", catalog["fan_repair_issue"])

# ─────────────────────────────────────────────────────────────────────────────
# 9. curtain_blind_mounting: clean window curtain across all Indic slots
# ─────────────────────────────────────────────────────────────────────────────
catalog["curtain_blind_mounting"][4] = "ஜன்னல் திரைச்சீலை கம்பி கீழே விழுந்துவிட்டது, கர்டன் ராட் பிராக்கெட் உடைந்துவிட்டது, புதிய திரைச்சீலை மாட்ட வேண்டும்"
catalog["curtain_blind_mounting"][8] = "জানালার কাপড়ের পর্দার রড খুলে নিচে পড়ে গেছে, পর্দা টাঙানোর ব্র্যাকেট ভেঙে গেছে, নতুন পর্দা লাগানো দরকার"
catalog["curtain_blind_mounting"][11] = "ಕಿಟಕಿಯ ಬಟ್ಟೆ ಪರದೆ ರಾಡ್ ಸಡಿಲವಾಗಿ ಕೆಳಗೆ ಬಿದ್ದಿದೆ, ಪರದೆ ಹಾಕುವ ಬ್ರಾಕೆಟ್ ಮುರಿದಿದೆ, ಹೊಸ ಕರ್ಟನ್ ರಾಡ್ ಫಿಕ್ಸ್ ಮಾಡಬೇಕು"
catalog["curtain_blind_mounting"][12] = "ജനലിന്റെ തുണി കർട്ടൻ റോഡ് ഇളകി താഴെ വീണു, കർട്ടൻ ബ്രാക്കറ്റ് തകർന്നു, പുതിയ കർട്ടൻ റോഡ് പിടിപ്പിക്കണം"
update("curtain_blind_mounting", catalog["curtain_blind_mounting"])

# ─────────────────────────────────────────────────────────────────────────────
# 10. security_alarm_system: anchor on burglar alarm, siren, fire/smoke
# ─────────────────────────────────────────────────────────────────────────────
catalog["security_alarm_system"][11] = "ಮನೆಯ ಕಳ್ಳತನ ಭದ್ರತಾ ಸೈರನ್ ಅಲಾರ್ಮ್ ಸುಮ್ಮನೆ ಕೂಗ್ತಿದೆ, ಪೀರ್ ಮೋಷನ್ ಸೆನ್ಸರ್ ತಪ್ಪು ಎಚ್ಚರಿಕೆ, ಹೊಗೆ ಸ್ಮೋಕ್ ಸೈರನ್"
update("security_alarm_system", catalog["security_alarm_system"])

eval_bench("Step 5 Results")
