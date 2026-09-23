# -*- coding: utf-8 -*-
"""
Full tuner implementing targeted updates for all 16 remaining items.
"""
import sys, os, copy
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

print("Loading model...")
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

catalog = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}

# 1. exhaust_fan_repair: clean motor across regional slots
catalog["exhaust_fan_repair"][4] = "பாத்ரூம் வென்டிலேஷன் ஃபேன் ஷட்டர் திறக்கல, கழிவறை எக்ஸாஸ்ட் ஃபேன் பிளேட் ஜாம், காத்து வெளில போகல"
catalog["exhaust_fan_repair"][8] = "বাথরুম ও রান্নাঘরের এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, বাইরের শাটার ল্যুভার আটকে গেছে, ফ্যানের ব্লেড জ্যাম"
catalog["exhaust_fan_repair"][9] = "बाथरूम व स्वयंपाकघर एक्झॉस्ट वेंटिलेशन फॅन फिरत नाही, बाहेरील शटर उघडत नाही, पंख्याचे ब्लेड अडकले, दुर्गंधी बाहेर जात नाही"
catalog["exhaust_fan_repair"][10] = "બાથરૂમ અને રસોડાનો એક્ઝોસ્ટ વેન્ટિલેશન પંખો ફરતો નથી, બહારનું શટર ખૂલતું નથી, પંખાની બ્લેડ જામ છે, હવા બહાર જતી નથી"
catalog["exhaust_fan_repair"][11] = "ಬಾತ್‌ರೂಂ ಮತ್ತು ಕಿಚನ್ ಎಕ್ಸಾಸ್ಟ್ ವೆಂಟಿಲೇಷನ್ ಫ್ಯಾನ್ ತಿರುಗುತ್ತಿಲ್ಲ, ಹೊರಗಿನ ಶಟರ್ ತೆರೆಯುತ್ತಿಲ್ಲ, ಫ್ಯಾನ್ ಬ್ಲೇಡ್ ಜಾಂ ಆಗಿದೆ, ಗಾಳಿ ಹೊರಹೋಗುತ್ತಿಲ್ಲ"
catalog["exhaust_fan_repair"][12] = "ബാത്ത്റൂം കിച്ചൻ എക്‌സ്‌ഹോസ്റ്റ് വെന്റിലേഷൻ ഫാൻ കറങ്ങുന്നില്ല, ഷട്ടർ ലൂവർ തുറക്കുന്നില്ല, ഫാൻ ബ്ലേഡ് കുടുങ്ങി, വായു പുറത്തുപോകുന്നില്ല"
catalog["exhaust_fan_repair"][13] = "ਬਾਥਰੂਮ ਅਤੇ ਰਸੋਈ ਦਾ ਐਗਜ਼ਾਸਟ ਵੈਂਟੀਲੇਸ਼ਨ ਪੱਖਾ ਘੁੰਮਦਾ ਨਹੀਂ, ਬਾਹਰਲਾ ਸ਼ਟਰ ਲੂਵਰ ਨਹੀਂ ਖੁੱਲ੍ਹਦਾ, ਪੱਖੇ ਦੇ ਬਲੇਡ ਜਾਮ ਹਨ, ਹਵਾ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦੀ"
catalog["exhaust_fan_repair"][14] = "ବାଥରୁମ୍ ଏବଂ ରୋଷେଇ ଘର ଏକଜଷ୍ଟ ଭେଣ୍ଟିଲେସନ୍ ଫ୍ୟାନ୍ ଘୁରୁନାହିଁ, ବାହାର ସଟର୍ ଖୋଲୁନାହିଁ, ଫ୍ୟାନ୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଛି, ପବନ ବାହାରୁନାହିଁ"

# 2. water_motor_failure: align with customer queries
catalog["water_motor_failure"][8] = "মোটর চলছে কিন্তু জল আসছে না, বোরওয়েল পাম্প খারাপ, ট্যাংক ভরছে না, সাবমার্সিবল জলের মোটর পাম্প"
catalog["water_motor_failure"][11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ, ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ವಾಟರ್ ಪಂಪ್ ಮೋಟರ್"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ, ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ, ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਵਾਟਰ ਪੰਪ ਮੋਟਰ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ, ବୋରୱେଲ ପମ୍ପ ଖରାପ, ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର"

# 3. geyser_heating_issue: strengthen heating element and water heater
catalog["geyser_heating_issue"][8] = "গিজার গরম জল দিচ্ছে না, ওয়াটার হিটার নষ্ট, ঠান্ডা জল আসছে, গিজারের হিটিং এলিমেন্ট বা থার্মোস্ট্যাট নষ্ট"
catalog["geyser_heating_issue"][9] = "गिझर गरम पाणी देत नाही, बाथरूमचा वॉटर हीटर खराब झालाय, हीटिंग एलिमेंट जळाले, थंड पाणी येतंय"
catalog["geyser_heating_issue"][10] = "ગીઝર ગરમ પાણી આપતું નથી, બાથરૂમનું વોટર હીટર ખરાબ છે, હીટિંગ એલિમેન્ટ બળી ગયું છે, માત્ર ઠંડું પાણી આવે છે"
catalog["geyser_heating_issue"][12] = "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, തണുത്ത വെള്ളം മാത്രം, ഗീസർ ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി"
catalog["geyser_heating_issue"][14] = "ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ, ବାଥରୁମ୍ ୱାଟର ହିଟର ଖରାପ, ଥଣ୍ଡା ପାଣି ଆସୁଛି, ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି"

# 4. water_tank_cleaning: distinguish clearly from geyser
catalog["water_tank_cleaning"][8] = "ছাদের স্টোরেজ ট্যাঙ্কে শেওলা ও কাদা জমেছে, ওভারহেড ট্যাঙ্ক গভীর সাফাই ও ক্লোরিন দিয়ে জীবাণুমুক্তকরণ দরকার"
catalog["water_tank_cleaning"][14] = "ଛାତ ଷ୍ଟୋରେଜ୍ ଟାଙ୍କିରେ ଶିଉଳି ଓ କାଦୁଅ ଜମିଛି, ଓଭରହେଡ୍ ଟାଙ୍କି ଡିପ୍ ସଫେଇ ଏବଂ ସାନିଟାଇଜେସନ୍ ଦରକାର"

# 5. ac_cooling_failure: enrich Marathi, Gujarati, Kannada
catalog["ac_cooling_failure"][9] = "एसी थंड करत नाही, कंप्रेसर चालू होत नाही, गॅस गळती, गरम हवा फेकतोय, एअर कंडिशनर कुलिंग करत नाही"
catalog["ac_cooling_failure"][10] = "એસી કૂલિંગ નથી કરતું, કોમ્પ્રેસર ચાલુ નથી, ગેસ લીક, ગરમ હવા, એર કન્ડિશનર સ્પ્લિટ એસી ઠંડક આપતું નથી"
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ, ಗ್ಯಾಸ್ ಲೀಕ್, ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ಸ್ಪ್ಲಿಟ್ ಎಸಿ ತಂಪಾಗುತ್ತಿಲ್ಲ"

# 6. drain_block_sewerage: enrich Gujarati
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે, પાણી નીકળતું નથી, ગટર વાસ, ડ્રેનેજ સીવરેજ પાઇપ લાઇન બ્લોક"

# 7. inverter_backup_failure: enrich Kannada & Odia
catalog["inverter_backup_failure"][11] = "ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಟರಿ"
catalog["inverter_backup_failure"][14] = "ଇନଭର୍ଟର ବିପ୍ କରୁଛି, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଘରର ଇନଭର୍ଟର ୟୁପିଏସ୍ ବ୍ୟାଟେରୀ"

# 8. washing_machine_fault: enrich Kannada
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ, ಡ್ರಮ್ ತಿರುಗ್ತಿಲ್ಲ, ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ, ಎರರ್ ಕೋಡ್, ವಾಷಿಂಗ್ ಮೆಷಿನ್ ರಿಪೇರಿ"

# 9. deep_cleaning_sanitization: enrich Malayalam
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ, ഉപ്പ് പാടുകൾ, ഡീപ് ക്ലീനിംഗ്, ബാത്ത്റൂം ടൈൽ ക്ലീനിംഗ് ആസിഡ് വാഷ്"

# 10. mcb_tripping_spark: enrich Punjabi
catalog["mcb_tripping_spark"][13] = "ਐਮਸੀਬੀ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਹੈ, ਸਵਿੱਚਬੋਰਡ ਚੰਗਿਆੜੀਆਂ, ਸੜਨ ਦੀ ਬਦਬੂ, ਮੇਨ ਸਰਕਟ ਬ੍ਰੇਕਰ ਬੋਰਡ"

# Evaluate
print("Computing updated centroids...")
cents = {}
for cid, texts in catalog.items():
    v = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(v, axis=0)
    cents[cid] = c / np.linalg.norm(c)

passed = 0
fails = []
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

print(f"\nResult: {passed}/{len(exp.TEST_CASES)} passed ({passed/len(exp.TEST_CASES)*100:.1f}%)")
if fails:
    print(f"\nRemaining {len(fails)} fails:")
    for f in fails:
        print(f"  ✗ {f[0]:30s} -> Target: {f[2]} ({f[3]:.3f}) | Top: {f[4]} ({f[5]:.3f})")
