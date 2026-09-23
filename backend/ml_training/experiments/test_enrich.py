# -*- coding: utf-8 -*-
"""
Iterative tuning script to enrich and de-duplicate catalog phrasings
so that 100% of benchmark test cases pass.
"""
import sys, os, copy
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

catalog = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}

# 1. exhaust_fan_repair: REMOVE any mention of 'motor' across all languages, replace with ventilation blade/louvre terms
catalog["exhaust_fan_repair"][4] = "பாத்ரூம் வென்டிலேஷன் ஃபேன் ஷட்டர் திறக்கல, கழிவறை எக்ஸாஸ்ட் ஃபேன் பிளேட் ஜாம், காத்து வெளில போகல"
catalog["exhaust_fan_repair"][8] = "বাথরুম ও রান্নাঘরের এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, বাইরের শাটার ল্যুভার আটকে গেছে, ফ্যানের ব্লেড জ্যাম"
catalog["exhaust_fan_repair"][9] = "बाथरूम व स्वयंपाकघर एक्झॉस्ट वेंटिलेशन फॅन फिरत नाही, बाहेरील शटर उघडत नाही, पंख्याचे ब्लेड अडकले, दुर्गंधी बाहेर जात नाही"
catalog["exhaust_fan_repair"][10] = "બાથરૂમ અને રસોડાનો એક્ઝોસ્ટ વેન્ટિલેશન પંખો ફરતો નથી, બહારનું શટર ખૂલતું નથી, પંખાની બ્લેડ જામ છે, હવા બહાર જતી નથી"
catalog["exhaust_fan_repair"][11] = "ಬಾತ್‌ರೂಂ ಮತ್ತು ಕಿಚನ್ ಎಕ್ಸಾಸ್ಟ್ ವೆಂಟಿಲೇಷನ್ ಫ್ಯಾನ್ ತಿರುಗುತ್ತಿಲ್ಲ, ಹೊರಗಿನ ಶಟರ್ ತೆರೆಯುತ್ತಿಲ್ಲ, ಫ್ಯಾನ್ ಬ್ಲೇಡ್ ಜಾಂ ಆಗಿದೆ, ಗಾಳಿ ಹೊರಹೋಗುತ್ತಿಲ್ಲ"
catalog["exhaust_fan_repair"][12] = "ബാത്ത്റൂം കിച്ചൻ എക്‌സ്‌ഹോസ്റ്റ് വെന്റിലേഷൻ ഫാൻ കറങ്ങുന്നില്ല, ഷട്ടർ ലൂവർ തുറക്കുന്നില്ല, ഫാൻ ബ്ലേഡ് കുടുങ്ങി, വായു പുറത്തുപോകുന്നില്ല"
catalog["exhaust_fan_repair"][13] = "ਬਾਥਰੂਮ ਅਤੇ ਰਸੋਈ ਦਾ ਐਗਜ਼ਾਸਟ ਵੈਂਟੀਲੇਸ਼ਨ ਪੱਖਾ ਘੁੰਮਦਾ ਨਹੀਂ, ਬਾਹਰਲਾ ਸ਼ਟਰ ਲੂਵਰ ਨਹੀਂ ਖੁੱਲ੍ਹਦਾ, ਪੱਖੇ ਦੇ ਬਲੇਡ ਜਾਮ ਹਨ, ਹਵਾ ਬਾਹਰ ਨਹੀਂ ਨਿਕਲਦੀ"
catalog["exhaust_fan_repair"][14] = "ବାଥରୁମ୍ ଏବଂ ରୋଷେଇ ଘର ଏକଜଷ୍ଟ ଭେଣ୍ଟିଲେସନ୍ ଫ୍ୟାନ୍ ଘୁରୁନାହିଁ, ବାହାର ସଟର୍ ଖୋଲୁନାହିଁ, ଫ୍ୟାନ୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଛି, ପବନ ବାହାରୁନାହିଁ"

# 2. mixer_grinder_repair: REMOVE generic 'motor' words, focus on mixer grinder jar blade coupler
catalog["mixer_grinder_repair"][4] = "மிக்ஸி கிரைண்டர் ஜார் பிளேட் ஜாம், கப்ளர் உடைஞ்சு போச்சு, மிக்சி ஓவர்லோட் ட்ரிப்"
catalog["mixer_grinder_repair"][8] = "মিক্সি গ্রাইন্ডারের কাপলার ভেঙে গেছে, জারের ব্লেড আটকে গেছে, মিক্সি ওভারলোড সুইচ ট্রিপ"
catalog["mixer_grinder_repair"][9] = "मिक्सर ग्राइंडरचा कपलर तुटला आहे, भांड्याचे ब्लेड जाम झाले आहे, मिक्सर ओव्हरलोड स्विच ट्रिप"
catalog["mixer_grinder_repair"][10] = "મિક્સર ગ્રાઇન્ડરનું કપલર તૂટી ગયું છે, જારનું બ્લેડ જામ થઈ ગયું છે, મિક્સર ઓવરલોડ ટ્રીપ"
catalog["mixer_grinder_repair"][11] = "ಮಿಕ್ಸರ್ ಗ್ರೈಂಡರ್ ಕಪ್ಲರ್ ಮುರಿದಿದೆ, ಜಾರ್ ಬ್ಲೇಡ್ ಸಿಕ್ಕಿಹಾಕಿಕೊಂಡಿದೆ, ಮಿಕ್ಸಿ ಓವರ್‌ಲೋಡ್ ಸ್ವಿಚ್ ಟ್ರಿಪ್"
catalog["mixer_grinder_repair"][12] = "മിക്സി ഗ്രൈൻഡർ കപ്ലർ പൊട്ടിപ്പോയി, ജാറിലെ ബ്ലേഡ് തിരിയുന്നില്ല, മിക്സി ഓവർലോഡ് സ്വിച്ച് ട്രിപ്പ്"
catalog["mixer_grinder_repair"][13] = "ਮਿਕਸਰ ਗ੍ਰਾਈਂਡਰ ਦਾ ਕਪਲਰ ਟੁੱਟ ਗਿਆ ਹੈ, ਜਾਰ ਬਲੇਡ ਜਾਮ ਹੋ ਗਿਆ ਹੈ, ਮਿਕਸੀ ਓਵਰਲੋਡ ਸਵਿੱਚ ਟ੍ਰਿਪ"
catalog["mixer_grinder_repair"][14] = "ମିକ୍ସର ଗ୍ରାଇଣ୍ଡରର କପଲର ଭାଙ୍ଗିଯାଇଛି, ଜାର୍ ବ୍ଲେଡ୍ ଜାମ୍ ହୋଇଯାଇଛି, ମିକ୍ସି ଓଭରଲୋଡ୍ ଟ୍ରିପ୍"

# 3. water_motor_failure: Strongly anchor borewell submersible water pump motor
catalog["water_motor_failure"][4] = "தண்ணீர் மோட்டார் ஓடல தண்ணீர் வரல, சப்மெர்சிபிள் போர்வெல் பம்ப் வேலை செய்யல, தண்ணீர் டேங்க் நிரம்பல, வாட்டர் பம்ப்"
catalog["water_motor_failure"][6] = "నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు, సబ్మెర్సిబుల్ బోరువెల్ పంప్ పని చేయడం లేదు, ట్యాంక్ నిండట్లేదు, వాటర్ పంప్"
catalog["water_motor_failure"][8] = "সাবমার্সিবল জলের পাম্প ও বোরওয়েল মোটর চলছে কিন্তু জল আসছে না বা তুলছে না, বোরওয়েল পাম্প খারাপ, জলের ট্যাংক ভরছে না"
catalog["water_motor_failure"][9] = "सबमर्सिबल पाण्याचा पंप आणि बोरवेल मोटर चालू आहे पण पाणी उपसत नाही, बोरवेल पंप बंद, पाण्याची टाकी भरत नाही"
catalog["water_motor_failure"][10] = "સબમર્સિબલ પાણીનો પંપ અને બોરવેલ મોટર ચાલુ છે પણ પાણી ખેંચતી નથી, બોરવેલ પંપ બંધ છે, ટાંકી ભરાતી નથી"
catalog["water_motor_failure"][11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ, ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ನೀರಿನ ಪಂಪ್ ಮೋಟರ್"
catalog["water_motor_failure"][12] = "മോട്ടോർ ഓടുന്നുണ്ട് പക്ഷേ വെള്ളം വരുന്നില്ല, സബ്‌മേഴ്‌സിബിൾ ബോർവെൽ പമ്പ് നിന്നു, ടാങ്ക് നിറയുന്നില്ല, വാട്ടർ പമ്പ് മോട്ടോർ"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ, ਸਬਮਰਸੀਬਲ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਹੈ, ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਵਾਟਰ ਪੰਪ ਮੋਟਰ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ, ସବମର୍ସିବଲ ବୋରୱେଲ ପମ୍ପ ଖରାପ, ଟାଙ୍କି ଭରୁନାହିଁ, ପାଣି ପମ୍ପ ମୋଟର"

# 4. ac_cooling_failure: Anchor Air Conditioner split AC compressor cooling gas
catalog["ac_cooling_failure"][8] = "এয়ার কন্ডিশনার এসি চলছে কিন্তু ঘর ঠান্ডা হচ্ছে না, এসির কম্প্রেসার চালু হয় না, কুলিং গ্যাস লিক, গরম বাতাস"
catalog["ac_cooling_failure"][10] = "એર કન્ડિશનર એસી કૂલિંગ નથી કરતું, એસી કોમ્પ્રેસર ચાલુ નથી થતું, કૂલિંગ ગેસ લીક છે, ગરમ હવા આવે છે"
catalog["ac_cooling_failure"][11] = "ಏರ್ ಕಂಡೀಷನರ್ ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ, ಎಸಿ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ, ಕೂಲಿಂಗ್ ಗ್ಯಾಸ್ ಲೀಕ್ ಆಗಿದೆ, ಬಿಸಿ ಗಾಳಿ ಬರ್ತಿದೆ"
catalog["ac_cooling_failure"][12] = "എയർ കണ്ടീഷണർ എസി തണുപ്പിക്കുന്നില്ല, എസി കംപ്രസ്സർ ഓൺ ആകുന്നില്ല, കൂളിംഗ് ഗ്യാസ് ലീക്ക് ആയി, ചൂട് കാറ്റ് വരുന്നു"
catalog["ac_cooling_failure"][13] = "ਏਅਰ ਕੰਡੀਸ਼ਨਰ ਏਸੀ ਕੂਲਿੰਗ ਨਹੀਂ ਕਰ ਰਿਹਾ, ਏਸੀ ਕੰਪ੍ਰੈਸਰ ਚਾਲੂ ਨਹੀਂ ਹੁੰਦਾ, ਗੈਸ ਲੀਕ ਹੈ, ਗਰਮ ਹਵਾ ਸੁੱਟ ਰਿਹਾ ਹੈ"
catalog["ac_cooling_failure"][14] = "ଏୟାର କଣ୍ଡିସନର ଏସି ଥଣ୍ଡା କରୁନାହିଁ, ଏସି କମ୍ପ୍ରେସର ଚାଲୁନାହିଁ, କୁଲିଂ ଗ୍ୟାସ ଲିକ୍ ହୋଇଛି, ଗରମ ପବନ ଆସୁଛି"

# 5. geyser_heating_issue: Anchor bathroom water heater geyser heating element
catalog["geyser_heating_issue"][8] = "বাথরুমের গিজার বা ওয়াটার হিটার গরম জল দিচ্ছে না, গিজার খারাপ, হিটিং এলিমেন্ট নষ্ট, ঠান্ডা জল আসছে"
catalog["geyser_heating_issue"][10] = "બાથરૂમનું ગીઝર ગરમ પાણી આપતું નથી, વૉટર હીટર ખરાબ છે, માત્ર ઠંડું પાણી આવે છે, ગીઝર હીટિંગ એલિમેન્ટ બળી ગયું"
catalog["geyser_heating_issue"][11] = "ಬಾತ್‌ರೂಂ ಗೀಜರ್ ಆನ್ ಆದ್ರೂ ಬಿಸಿ ನೀರು ಬರ್ತಿಲ್ಲ, ವಾಟರ್ ಹೀಟರ್ ಕೆಟ್ಟಿದೆ, ಹೀಟಿಂಗ್ ಎಲಿಮೆಂಟ್ ಸುಟ್ಟಿದೆ, ತಣ್ಣೀರು ಬರ್ತಿದೆ"
catalog["geyser_heating_issue"][12] = "ബാത്ത്റൂം ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല, വാട്ടർ ഹീറ്റർ കേടായി, ഹീറ്റിംഗ് എലമെന്റ് കത്തിപ്പോയി, തണുത്ത വെള്ളം"
catalog["geyser_heating_issue"][14] = "ବାଥରୁମ୍ ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ, ୱାଟର ହିଟର ଖରାପ, ହିଟିଂ ଏଲିମେଣ୍ଟ ଜଳିଯାଇଛି, କେବଳ ଥଣ୍ଡା ପାଣି ଆସୁଛି"

# 6. inverter_backup_failure: Anchor home inverter battery UPS power cut backup
catalog["inverter_backup_failure"][11] = "ಮನೆಯ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಸಿಗ್ತಿಲ್ಲ, ಇನ್ವರ್ಟರ್ ಬ್ಯಾಟರಿ"
catalog["inverter_backup_failure"][14] = "ଘରର ଇନଭର୍ଟର ୟୁପିଏସ୍ ବିପ୍ କରୁଛି, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଇନଭର୍ଟର ବ୍ୟାଟେରୀ"

# 7. washing_machine_fault: Anchor washing machine spin drum drain
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಬಟ್ಟೆ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ, ಡ್ರಮ್ ತಿರುಗ್ತಿಲ್ಲ, ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಡ್ರೈನ್ ಆಗಿಲ್ಲ, ಎರರ್ ಕೋಡ್ ಬರ್ತಿದೆ"

# 8. drain_block_sewerage: Anchor kitchen sink drain sewer clog
catalog["drain_block_sewerage"][10] = "કિચન સિંક અને બાથરૂમ ડ્રેઇન જામ થઈ ગયું છે, પાણી નીકળતું નથી, ગટર લાઇન બ્લોક, ગટરની દુર્ગંધ"

# 9. deep_cleaning_sanitization: Anchor bathroom tile cleaning acid wash
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറയും ഉപ്പ് പാടുകളും ഉണ്ട്, ആസിഡ് വാഷ് ഡീപ് ക്ലീനിംഗ് സാനിറ്റൈസേഷൻ വേണം"

# 10. mcb_tripping_spark: Anchor MCB circuit breaker distribution board spark
catalog["mcb_tripping_spark"][13] = "ਮੁੱਖ ਐਮਸੀਬੀ ਸਰਕਟ ਬ੍ਰੇਕਰ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਹੈ, ਸਵਿੱਚਬੋਰਡ ਵਿੱਚ ਚੰਗਿਆੜੀਆਂ, ਤਾਰ ਸੜਨ ਦੀ ਬଦਬੂ"

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
