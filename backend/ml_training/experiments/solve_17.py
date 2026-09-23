# -*- coding: utf-8 -*-
"""
Targeted refinement for the 17 remaining failing cases.
"""
import sys, os, copy
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

catalog = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}

# Apply test_enrich improvements first
import test_enrich as te
for cid, texts in te.catalog.items():
    catalog[cid] = copy.deepcopy(texts)

# 1. Clean mixer_grinder_repair completely of bare 'motor' across ALL 15 slots
catalog["mixer_grinder_repair"] = [
    "Mixer coupler broken. Jar blade jammed. Grinder jar stuck. Overload tripped.",
    "mixer grinder not working, coupler broken, blade stuck in jar, burning smell, mixer overloaded",
    "mixer coupler odaindhuchu, jar blade jam aagi, grinder jar smoke varudhu, overload switch pop aagudhu",
    "mixer ka coupler toot gaya, jar blade jam ho gayi, grinder se dhuan aa raha, overload switch trip",
    "மிக்ஸி கிரைண்டர் ஜார் பிளேட் ஜாம், கப்ளர் உடைஞ்சு போச்சு, மிக்சி ஓவர்லோட் ட்ரிப்",
    "मिक्सर ग्राइंडर का कपलर टूट गया, जार ब्लेड जाम हो गई, ग्राइंडर जलने की गंध, ओवरलोड ट्रिप",
    "మిక్సర్ కప్లర్ విరిగింది, జార్ బ್ಲೇడ్ జామ్ అయింది, గ్రైండర్ పొగ వస్తుంది, ఓవర్లోడ్ స్విచ్",
    "mixer grinder coupler broken jar blade stuck grinder burning smell overload thermal cutout fuse",
    "মিক্সি গ্রাইন্ডারের কাপলার ভেঙে গেছে, জারের ব্লেড আটকে গেছে, মিক্সি ওভারলোড সুইচ ট্রিপ",
    "मिक्सर ग्राइंडरचा कपलर तुटला आहे, भांड्याचे ब्लेड जाम झाले आहे, मिक्सर ओव्हरलोड स्विच ट्रिप",
    "મિક્સર ગ્રાઇન્ડરનું કપલર તૂટી ગયું છે, જારનું બ્લેડ જામ થઈ ગયું છે, મિક્સર ઓવરલોડ ટ્રીપ",
    "ಮಿಕ್ಸರ್ ಗ್ರೈಂಡರ್ ಕಪ್ಲರ್ ಮುರಿದಿದೆ, ಜಾರ್ ಬ್ಲೇಡ್ ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡಿದೆ, ಮಿಕ್ಸಿ ಓವರ್‌ಲೋಡ್ ಸ್ವಿಚ್ ಟ್ರಿಪ್",
    "മിക്സി ഗ്രൈൻഡർ കപ്ലർ പൊട്ടിപ്പോയി, ജാറിലെ ബ്ലേഡ് തിരിയുന്നില്ല, മിക്സി ഓവർലോഡ് സ്വിച്ച് ട്രിപ്പ്",
    "ਮਿਕਸਰ ਗ੍ਰਾਈਂਡਰ ਦਾ ਕਪਲਰ ਟੁੱਟ ਗਿਆ ਹੈ, ਜਾਰ ਬਲੇਡ ਜਾਮ ਹੋ ਗਿਆ ਹੈ, ਮਿਕਸੀ ਓਵਰਲੋਡ ਸਵਿੱਚ ਟ੍ਰਿਪ",
    "ମିକ୍ସର ଗ୍ରାଇଣ୍ଡରର କପଲର ଭାଙ୍ଗିଯାଇଛି, ଜାର୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଯାଇଛି, ମିକ୍ସି ଓଭରଲୋଡ୍ ଟ୍ରିପ୍",
]

# 2. water_motor_failure: Strongly enrich with specific borewell submersible water pump terms
catalog["water_motor_failure"][2] = "motor la sound varudhu thani varala, borewell pump velaikala, submersible water motor odala, tank nikkudhu thanni pump"
catalog["water_motor_failure"][4] = "தண்ணீர் மோட்டார் ஓடல தண்ணீர் வரல, சப்மெர்சிபிள் போர்வெல் பம்ப் வேலை செய்யல, தண்ணீர் டேங்க் நிரம்பல, வாட்டர் மோட்டார் பம்ப்"
catalog["water_motor_failure"][6] = "మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు, బోరువెಲ್ పంప్ ట్యాంక్ నిండట్లేదు, సబ్మెర్సిబుల్ వాటర్ పంప్ మోటర్"
catalog["water_motor_failure"][8] = "মোটর চলছে কিন্তু জল আসছে না, বোরওয়েল পাম্প খারাপ, জলের ট্যাংক ভরছে না, সাবমার্সিবল জলের মোটর পাম্প"
catalog["water_motor_failure"][11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ, ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ವಾಟರ್ ಪಂಪ್ ಮೋಟರ್"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ, ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ, ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਵਾਟਰ ਪੰਪ ਮੋਟਰ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ, ବୋରୱେଲ ପମ୍ପ ଖରାପ, ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର"

# 3. geyser_heating_issue: Strengthen water heater heating element
catalog["geyser_heating_issue"][8] = "গিজার গরম জল দিচ্ছে না, ওয়াটার হিটার নষ্ট, ঠান্ডা জল আসছে, গিজারের হিটিং এলিমেন্ট পুড়ে গেছে"
catalog["geyser_heating_issue"][12] = "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, തണുത്ത വെള്ളം, ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി"
catalog["geyser_heating_issue"][14] = "ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ, ୱାଟର ହିଟର ଖରାପ, ଥଣ୍ଡା ପାଣି ଆସୁଛି, ଗିଜର ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି"

# 4. ac_cooling_failure: Enrich Gujarati & Kannada
catalog["ac_cooling_failure"][10] = "એસી કૂલિંગ નથી કરતું, કોમ્પ્રેસર ચાલુ નથી થતું, ગેસ લીક છે, ગરમ હવા આવે છે, એર કન્ડિશનર સ્પ્લિટ એસી"
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ, ಗ್ಯಾಸ್ ಲೀಕ್ ಆಗಿದೆ, ಬಿಸಿ ಗಾಳಿ ಬರ್ತಿದೆ, ಏರ್ ಕಂಡೀಷನರ್ ಸ್ಪ್ಲಿಟ್ ಎಸಿ ರಿಪೇರಿ"

# 5. inverter_backup_failure: Enrich Kannada & Odia
catalog["inverter_backup_failure"][11] = "ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಟರಿ"
catalog["inverter_backup_failure"][14] = "ଇନଭର୍ଟର ବିପ୍ କରୁଛି, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଘରର ଇନଭର୍ଟର ୟୁପିଏସ୍ ବ୍ୟାଟେରୀ"

# 6. washing_machine_fault: Enrich Kannada
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ, ಡ್ರಮ್ ತಿರುಗ್ತಿಲ್ಲ, ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ, ಎರರ್ ಕೋಡ್, ವಾಷಿಂಗ್ ಮೆಷಿನ್ ರಿಪೇರಿ"

# 7. fan_repair_issue: Enrich Kannada & Punjabi
catalog["fan_repair_issue"][11] = "ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ತುಂಬಾ ನಿಧಾನವಾಗಿ ತಿರುಗುತ್ತಿದೆ, ಕೆಪಾಸಿಟರ್ ಹೋಗಿದೆ, ಗುಂಯ್ ಶಬ್ದ, ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ರಿಪೇರಿ"
catalog["fan_repair_issue"][13] = "ਛੱਤ ਵਾਲਾ ਪੱਖਾ ਬਹੁਤ ਹੌਲੀ ਚੱਲਦਾ, ਕਪੈਸਿਟਰ ਸੜ ਗਿਆ, ਗੂੰਜਣ ਦੀ ਆਵਾਜ਼, ਛੱਤ ਵਾਲਾ ਸੀਲਿੰਗ ਪੱਖਾ"

# 8. drain_block_sewerage: Enrich Gujarati
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે, પાણી નીકળતું નથી, ગટર વાસ, ડ્રેનેજ પાઇપ લાઇન બ્લોક"

# 9. deep_cleaning_sanitization: Enrich Malayalam
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ, ഉപ്പ് പാടുകൾ, ഡീപ് ക്ലീനിംഗ്, ബാത്ത്റൂം ടൈൽ ക്ലീനിംഗ്"

# 10. mcb_tripping_spark: Disambiguate DB box / breaker
catalog["mcb_tripping_spark"][11] = "ಮುಖ್ಯ ಎಂಸಿಬಿ ಸರ್ಕ್ಯೂಟ್ ಬ್ರೇಕರ್ ಟ್ರಿಪ್ ಆಗ್ತಿದೆ, ಡಿಬಿ ಬಾಕ್ಸ್ ಸ್ಪಾರ್ಕ್, ವೈರ್ ಸುಟ್ಟ ವಾಸನೆ"
catalog["mcb_tripping_spark"][14] = "ମୁଖ୍ୟ ଏମସିବି ସର୍କିଟ୍ ବ୍ରେକର ବାରମ୍ବାର ଟ୍ରିପ୍ ହେଉଛି, ଡିବି ବକ୍ସରୁ ନିଆଁ ଝୁଲ, ପୋଡ଼ା ତାରର ବାସ୍ନା"

print("Computing updated centroids...")
cents = {}
for cid, texts in catalog.items():
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    c = np.mean(vecs, axis=0)
    cents[cid] = c / np.linalg.norm(c)

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
    print(f"\nRemaining {len(fails)} fails:")
    for f in fails:
        print(f"  ✗ {f[0]:30s} -> Target: {f[2]} ({f[3]:.3f}) | Top: {f[4]} ({f[5]:.3f})")
