# -*- coding: utf-8 -*-
"""
Solver for the remaining 15 fails in WorkGo Multilingual Symptom Catalog.
"""
import sys, os, copy
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
Q = model.encode(test_queries, normalize_embeddings=True)

catalog_ids = [item["id"] for item in exp.CATALOG_ITEMS]
id_to_idx = {cid: i for i, cid in enumerate(catalog_ids)}
catalog_texts = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}
centroids = np.zeros((len(catalog_ids), 384), dtype=np.float32)

def update(cid, texts):
    idx = id_to_idx[cid]
    catalog_texts[cid] = copy.deepcopy(texts)
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    norm = np.linalg.norm(c)
    centroids[idx] = (c / norm) if norm > 0 else c

for cid in catalog_ids:
    update(cid, catalog_texts[cid])

def eval_now():
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
            fails.append({
                "index": i,
                "label": test_labels[i],
                "query": test_queries[i],
                "expected": exp_cid,
                "target_score": float(target_score),
                "top": top_cid,
                "top_score": float(top_score),
                "margin": float(top_score - target_score),
            })
    return passed, fails

# Apply Step 1 cleanups
# 1. exhaust_fan_repair
t = catalog_texts["exhaust_fan_repair"]
t[4] = "பாத்ரூம் வென்டிலேஷன் ஃபேன் ஷட்டர் திறக்கல, கழிவறை எக்ஸாஸ்ட் ஃபேன் பிளேட் ஜாம், காத்து வெளில போகல"
t[8] = "বাথরুম ও রান্নাঘরের এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, বাইরের শাটার ল্যুভার আটকে গেছে, ফ্যানের ব্লেড জ্যাম"
t[9] = "बाथरूम व स्वयंपाकघर एक्झॉस्ट वेंटिलेशन फॅन फिरत नाही, बाहेरील शटर उघडत नाही, पंख्याचे ब्लेड अडकले, दुर्गंधी बाहेर जात नाही"
t[10] = "બાથરૂમ અને રસોડાનો એક્ઝોસ્ટ વેન્ટિલેશન પંખો ફરતો નથી, બહારનું શટર ખૂલતું નથી, પંખાની બ્લેડ જામ છે, હવા બહાર જતી નથી"
t[11] = "ಬಾತ್‌ರೂಂ ಮತ್ತು ಕಿಚನ್ ಎಕ್ಸಾಸ್ಟ್ ವೆಂಟಿಲೇಷನ್ ಫ್ಯಾನ್ ತಿರುಗುತ್ತಿಲ್ಲ, ಹೊರಗಿನ ಶಟರ್ ತೆರೆಯುತ್ತಿಲ್ಲ, ಫ್ಯಾನ್ ಬ್ಲೇಡ್ ಜಾಂ ಆಗಿದೆ, ಗಾಳಿ ಹೊರಹೋಗುತ್ತಿಲ್ಲ"
t[12] = "ബാത്ത്റൂം കിച്ചൻ എക്‌സ്‌ഹോസ്റ്റ് വെന്റിലേഷൻ ഫാൻ കറങ്ങുന്നില്ല, ഷട്ടർ ലൂവർ തുറക്കുന്നില്ല, ഫാൻ ബ്ലേഡ് കുടുങ്ങി, വായു പുറത്തുപോകുന്നില്ല"
t[13] = "ਬਾਥਰੂਮ ਅਤੇ ਰਸੋਈ ਦਾ ਐਗਜ਼ਾਸਟ ਵੈਂਟੀਲੇਸ਼ਨ ਪੱਖਾ ਘੁੰਮਦਾ ਨਹੀਂ, ਬਾਹਰਲਾ ਸ਼ਟਰ ਲੂਵਰ ਨਹੀਂ ਖੁੱਲ੍ਹਦਾ, ਪੱਖੇ ਦੇ ਬਲੇਡ ਜਾਮ ਹਨ, ਹਵਾ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦੀ"
t[14] = "ବାଥରୁମ୍ ଏବଂ ରୋଷେଇ ଘର ଏକଜଷ୍ଟ ଭେଣ୍ଟିଲେସନ୍ ଫ୍ୟାନ୍ ଘୁରୁନାହିଁ, ବାହାର ସଟର୍ ଖୋଲୁନାହିଁ, ଫ୍ୟାନ୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଛି, ପବନ ବାହାରୁନାହିଁ"
update("exhaust_fan_repair", t)

# 2. water_tank_cleaning
t = catalog_texts["water_tank_cleaning"]
t[8] = "ছাদের স্টোরেজ ট্যাঙ্কে শেওলা ও কাদা জমেছে, ওভারহেড ট্যাঙ্ক গভীর সাফাই ও ক্লোরিন দিয়ে জীবাণুমুক্তকরণ দরকার"
t[14] = "ଛାତ ଷ୍ଟୋରେଜ୍ ଟାଙ୍କିରେ ଶିଉଳି ଓ କାଦୁଅ ଜମିଛି, ଓଭରହେଡ୍ ଟାଙ୍କି ଡିପ୍ ସଫେଇ ଏବଂ ସାନିଟାଇଜେସନ୍ ଦରକାର"
update("water_tank_cleaning", t)

# 3. geyser_heating_issue
t = catalog_texts["geyser_heating_issue"]
t[8] = "বাথরুমের গিজার বা ওয়াটার হিটার গরম জল দিচ্ছে না, গিজার খারাপ, হিটিং এলিমেন্ট নষ্ট, ঠান্ডা জল আসছে"
t[9] = "गिझर गरम पाणी देत नाही, बाथरूमचा वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, थंड पाणी येतंय"
t[10] = "ગીઝર ગરમ પાણી આપતું નથી, બાથરૂમનું વોટર હીટર ખરાબ છે, હીટિંગ એલિમેન્ટ બળી ગયું છે, માત્ર ઠંડું પાણી આવે છે"
t[12] = "ബാത്ത്റൂം ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, തണുത്ത വെള്ളം മാത്രം, ഗീസർ ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി"
t[14] = "ବାଥରୁମ୍ ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ, ବାଥରୁମ୍ ୱାଟର ହିଟର ଖରାପ, ଥଣ୍ଡା ପାଣି ଆସୁଛି, ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି"
update("geyser_heating_issue", t)

# 4. water_motor_failure
t = catalog_texts["water_motor_failure"]
t[2] = "motor la sound varudhu thani varala, borewell pump velaikala, submersible water motor odala, tank nikkudhu thanni pump"
t[4] = "தண்ணீர் மோட்டார் ஓடல தண்ணீர் வரல, சப்மெர்சிபிள் போர்வெல் பம்ப் வேலை செய்யல, தண்ணீர் டேங்க் நிரம்பல, வாட்டர் மோட்டார் பம்ப்"
t[6] = "నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు, సబ్మెర్సిబుల్ బోరువెಲ್ పంప్ పని చేయడం లేదు, ట్యాంక్ నిండట్లేదు, వాటర్ పంప్"
t[8] = "মোটর চলছে কিন্তু জল আসছে না, বোরওয়েল পাম্প খারাপ, জলের ট্যাংক ভরছে না, সাবমার্সিবল জলের মোটর পাম্প"
t[9] = "सबमर्सिबल मोटर चालू आहे पण पाणी येत नाही, बोरवेल पंप बंद पडला, पाण्याची टाकी भरत नाही"
t[10] = "મોટર ચાલુ છે પણ પાણી આવતું નથી, બોરવેલ પંપ બંધ છે, ટાંકી ભરાતી નથી, સબમર્સિબલ પાણીનો પંપ"
t[11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ, ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ವಾಟರ್ ಪಂಪ್ ಮೋಟರ್"
t[12] = "മോട്ടോർ ഓടുന്നുണ്ട് പക്ഷേ വെള്ളം വരുന്നില്ല, ബോർവെൽ പമ്പ് നിന്നു, ടാങ്ക് നിറയുന്നില്ല, സബ്‌മേഴ്‌സിബിൾ വാട്ടർ പമ്പ് മോട്ടോർ"
t[13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ, ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ, ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਵਾਟਰ ਪੰਪ ਮੋਟਰ"
t[14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ, ବୋରୱେଲ ପମ୍ପ ଖରାପ, ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର"
update("water_motor_failure", t)

# 5. ac_cooling_failure
t = catalog_texts["ac_cooling_failure"]
t[8] = "এয়ার কন্ডিশনার এসি চলছে কিন্তু ঘর ঠান্ডা হচ্ছে না, এসির কম্প্রেসার চালু হয় না, কুলিং গ্যাস লিক, গরম বাতাস"
t[9] = "एसी थंड करत नाही, कंप्रेसर चालू होत नाही, गॅस गळती, गरम हवा फेकतोय, एअर कंडिशनर कुलिंग करत नाही"
t[10] = "એસી કૂલિંગ નથી કરતું, કોમ્પ્રેસર ચાલુ નથી, ગેસ લીક, ગરમ હવા, એર કન્ડિશનર સ્પ્લિટ એસી ઠંડક આપતું નથી"
t[11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ, ಗ್ಯಾಸ್ ಲೀಕ್, ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ಸ್ಪ್ಲಿಟ್ ಎಸಿ ತಂಪಾಗುತ್ತಿಲ್ಲ"
t[12] = "എയർ കണ്ടീഷണർ എസി തണുപ്പിക്കുന്നില്ല, എസി കംപ്രസ്സർ ഓൺ ആകുന്നില്ല, കൂളിംഗ് ഗ്യാസ് ലീക്ക് ആയി, ചൂട് കാറ്റ് വരുന്നു"
t[13] = "ਏਸੀ ਕੂਲਿੰਗ ਨਹੀਂ ਕਰ ਰਿਹਾ, ਏਸੀ ਕੰਪ੍ਰੈਸਰ ਚਾਲੂ ਨਹੀਂ ਹੁੰਦਾ, ਗੈਸ ਲੀਕ, ਗਰਮ ਹਵਾ ਸੁੱਟ ਰਿਹਾ ਹੈ, ਏਅਰ ਕੰਡੀਸ਼ਨਰ"
t[14] = "ଏୟାର କଣ୍ଡିସନର ଏସି ଥଣ୍ଡା କରୁନାହିଁ, ଏସି କମ୍ପ୍ରେସର ଚାଲୁନାହିଁ, କୁଲିଂ ଗ୍ୟାସ ଲିକ୍ ହୋଇଛି, ଗରମ ପବନ ଆସୁଛି"
update("ac_cooling_failure", t)

# 6. mixer_grinder_repair
t = catalog_texts["mixer_grinder_repair"]
t[8] = "মিক্সি গ্রাইন্ডারের কাপলার ভেঙে গেছে, জারের ব্লেড আটকে গেছে, মিক্সি ওভারলোড সুইচ ট্রিপ"
t[9] = "मिक्सर ग्राइंडरचा कपलर तुटला आहे, भांड्याचे ब्लेड जाम झाले आहे, मिक्सर ओव्हरलोड स्विच ट्रिप"
t[10] = "મિક્સર ગ્રાઇન્ડરનું કપલર તૂટી ગયું છે, જારનું બ્લેડ જામ થઈ ગયું છે, મિક્સર ઓવરલોડ ટ્રીપ"
t[11] = "ಮಿಕ್ಸರ್ ಗ್ರೈಂಡರ್ ಕಪ್ಲರ್ ಮುರಿದಿದೆ, ಜಾರ್ ಬ್ಲೇಡ್ ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡಿದೆ, ಮಿಕ್ಸಿ ಓವರ್‌ಲೋಡ್ ಸ್ವಿಚ್ ಟ್ರಿಪ್"
t[12] = "മിക്സി ഗ്രൈൻഡർ കപ്ലർ പൊട്ടിപ്പോയി, ജാറിലെ ബ്ലേഡ് തിരിയുന്നില്ല, മിക്സി ഓവർലോഡ് സ്വിച്ച് ട്രിപ്പ്"
t[13] = "ਮਿਕਸਰ ਗ੍ਰਾਈਂਡਰ ਦਾ ਕਪਲਰ ਟੁੱਟ ਗਿਆ ਹੈ, ਜਾਰ ਬਲੇਡ ਜਾਮ ਹੋ ਗਿਆ ਹੈ, ਮਿਕਸੀ ਓਵਰਲੋਡ ਸਵਿੱਚ ਟ੍ਰਿਪ"
t[14] = "ମିକ୍ସର ଗ୍ରାଇଣ୍ଡରର କପଲର ଭାଙ୍ଗିଯାଇଛି, ଜାର୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଯାଇଛି, ମିକ୍ସି ଓଭରଲୋଡ୍ ଟ୍ରିପ୍"
update("mixer_grinder_repair", t)

# 7. overhead_tank_overflow: make sure it focuses on overflow / ball valve leakage
t = catalog_texts["overhead_tank_overflow"]
t[4] = "ஓவர்ஹெட் தண்ணீர் டேங்க் வழிஞ்சு கொட்டுது, பால் வால்வு லீக், ஃப்ளஷ் டேங்க் ஓவர்ஃப்ளோ ஆகுது"
t[11] = "ಓವರ್‌ಹೆಡ್ ವಾಟರ್ ಟ್ಯಾಂಕ್ ಉಕ್ಕಿ ಹರಿಯುತ್ತಿದೆ, ಬಾಲ್ ವಾಲ್ವ್ ಕೆಟ್ಟಿದೆ, ಫ್ಲಶ್ ಟ್ಯಾಂಕ್ ನಿಲ್ಲದೆ ನೀರು ಸೋರುತ್ತಿದೆ"
update("overhead_tank_overflow", t)

# 8. drain_block_sewerage
t = catalog_texts["drain_block_sewerage"]
t[10] = "કિચન સિંક જામ થઈ ગયું છે, પાણી નીકળતું નથી, ગટર વાસ, ડ્રેનેજ સીવરેજ પાઇપ લાઇન બ્લોક"
update("drain_block_sewerage", t)

# 9. water_softener_issue
t = catalog_texts["water_softener_issue"]
t[10] = "વોટર સોફ્ટનર રેઝિન પ્લાન્ટ કામ કરતું નથી, ક્ષાર વાળું કઠણ પાણી, ટીડીએસ ફિલ્ટર ખરાબ છે"
update("water_softener_issue", t)

# 10. mcb_tripping_spark
t = catalog_texts["mcb_tripping_spark"]
t[11] = "ಮುಖ್ಯ ಎಂಸಿಬಿ ಸರ್ಕ್ಯೂಟ್ ಬ್ರೇಕರ್ ಮೇಲಿಂದ ಮೇಲೆ ಟ್ರಿಪ್ ಆಗ್ತಿದೆ, ಡಿಬಿ ಬಾಕ್ಸ್ ಸ್ಪಾರ್ಕ್, ವೈರ್ ಸುಟ್ಟ ವಾಸನೆ"
t[13] = "ਮੁੱਖ ਐਮਸੀਬੀ ਸਰਕਟ ਬ੍ਰੇਕਰ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਹੈ, ਸਵਿੱਚਬੋਰਡ ਵਿੱਚ ਚੰਗਿਆੜੀਆਂ, ਤਾਰ ਸੜਨ ਦੀ ਬਦਬੂ"
t[14] = "ମୁଖ୍ୟ ଏମସିବି ସର୍କିଟ୍ ବ୍ରେକର ବାରମ୍ବାର ଟ୍ରିପ୍ ହେଉଛି, ଡିବି ବକ୍ସରୁ ନିଆଁ ଝୁଲ ବାହାରୁଛି, ପୋଡ଼ା ତାରର ବାସ୍ନା"
update("mcb_tripping_spark", t)

# 11. inverter_backup_failure
t = catalog_texts["inverter_backup_failure"]
t[11] = "ಮನೆಯ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಇನ್ವರ್ಟರ್ ಬ್ಯಾಟರಿ ಲೈಟ್ ಇಲ್ಲ"
t[14] = "ଘରର ଇନଭର୍ଟର ୟୁପିଏସ୍ ବିପ୍ କରୁଛି, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ମିଳୁନାହିଁ, ଇନଭର୍ଟର ବ୍ୟାଟେରୀ"
update("inverter_backup_failure", t)

# 12. washing_machine_fault
t = catalog_texts["washing_machine_fault"]
t[11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಬಟ್ಟೆ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ, ಡ್ರಮ್ ತಿರುಗ್ತಿಲ್ಲ, ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಡ್ರೈನ್ ಆಗಿಲ್ಲ, ವಾಷಿಂಗ್ ಮೆಷಿನ್ ಎರರ್ ಕೋಡ್"
update("washing_machine_fault", t)

# 13. fan_repair_issue
t = catalog_texts["fan_repair_issue"]
t[11] = "ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ತುಂಬಾ ನಿಧಾನವಾಗಿ ತಿರುಗುತ್ತಿದೆ, ಕೆಪಾಸಿಟರ್ ಹೋಗಿದೆ, ಗುಂಯ್ ಶಬ್ದ, ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ರಿಪೇರಿ"
t[13] = "ਛੱਤ ਵਾਲਾ ਪੱਖਾ ਬਹੁਤ ਹੌਲੀ ਚੱਲਦਾ, ਕਪੈਸਿਟਰ ਸੜ ਗਿਆ, ਗੂੰਜਣ ਦੀ ਆਵਾਜ਼, ਛੱਤ ਵਾਲਾ ਸੀਲਿੰਗ ਪੱਖਾ"
update("fan_repair_issue", t)

# 14. deep_cleaning_sanitization
t = catalog_texts["deep_cleaning_sanitization"]
t[12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ, ഉപ്പ് പാടുകൾ, ബാത്ത്റൂം ടൈൽ ക്ലീനിംഗ് ആസിഡ് വാഷ് ഡീപ് ക്ലീനിംഗ് സാനിറ്റൈസേഷൻ"
update("deep_cleaning_sanitization", t)

# 15. wall_dampness_painting
t = catalog_texts["wall_dampness_painting"]
t[12] = "ഭിത്തിയിലെ പെയിന്റ് അടർന്നു വീഴുന്നു, ഈർപ്പവും പൂപ്പലും പടർന്നു, വാട്ടർപ്രൂഫിംഗ് പുട്ടി പെയിന്റിംഗ് വേണം"
update("wall_dampness_painting", t)

# 16. curtain_blind_mounting: make sure Punjabi doesn't collide with water motor
t = catalog_texts["curtain_blind_mounting"]
t[13] = "ਖਿੜਕੀ ਦੇ ਪਰਦਿਆਂ ਵਾਲਾ ਪਾਈਪ ਢਿੱਲਾ ਹੋ ਕੇ ਡਿੱਗ ਪਿਆ, ਰੋਲਰ ਬਲਾਇੰਡਸ ਅੜ ਗਏ, ਨਵਾਂ ਕਰਟਨ ਰੌਡ ਬਰੈਕਟ ਲਗਵਾਉਣਾ ਹੈ"
update("curtain_blind_mounting", t)

# 17. security_alarm_system
t = catalog_texts["security_alarm_system"]
t[13] = "ਸੁਰੱਖਿਆ ਚੋਰੀ ਅਲਾਰਮ ਬਿਨਾਂ ਵਜ੍ਹਾ ਵੱਜ ਰਿਹਾ ਹੈ, ਮੋਸ਼ਨ ਸੈਂਸਰ ਫਾਲਸ ਅਲਾਰਮ, ਸਮੋਕ ਡਿਟੈਕਟਰ ਸਾਇਰਨ"
t[14] = "ସୁରକ୍ଷା ଚୋରି ଆଲାର୍ମ ବିନା କାରଣରେ ବାଜୁଛି, ମୋସନ୍ ସେନ୍ସର ଭୁଲ୍ ସିଗ୍ନାଲ୍, ସ୍ମୋକ୍ ଡିଟେକ୍ଟର ସାଇରନ୍"
update("security_alarm_system", t)

p, fails = eval_now()
print(f"\nResult after Step 2: {p}/{len(test_queries)} ({p/len(test_queries)*100:.1f}%)")
if fails:
    print(f"Remaining {len(fails)} fails:")
    for f in fails:
        print(f"  ✗ {f['label']:30s} -> Target: {f['expected']:26s} ({f['target_score']:.3f}) | Top: {f['top']:26s} ({f['top_score']:.3f}) [+{f['margin']:.3f}]")
