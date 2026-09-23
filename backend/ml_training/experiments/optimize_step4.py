# -*- coding: utf-8 -*-
"""
Step 4 Targeted Optimizer:
Diagnose and resolve the remaining 15 collisions.
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

# Load current state from solve_interactive.py base
import solve_interactive as si
catalog = copy.deepcopy(si.catalog)
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

eval_bench("Baseline before Step 4")

# Now apply targeted fixes:
# 1. curtain_blind_mounting: de-correlate from generic loanwords
catalog["curtain_blind_mounting"][13] = "ਖਿੜਕੀ ਦੇ ਕੱਪੜੇ ਵਾਲੇ ਪਰਦੇ ਲਾਹੁਣ ਤੇ ਟੰਗਣ ਵਾਲੀ ਪਾਈਪ ਟੁੱਟ ਗਈ, ਨਵਾਂ ਪਰਦਾ ਟੰਗਣ ਵਾਲਾ ਰੌਡ ਲਗਵਾਉਣਾ ਹੈ"
catalog["curtain_blind_mounting"][14] = "ଝରକା କପଡ଼ା ପରଦା ତଳେ ଖସିପଡ଼ିଛି, ପରଦା ଟାଙ୍ଗିବା ପାଇପ୍ ବନ୍ଧନୀ ଭାଙ୍ଗିଯାଇଛି, ନୂଆ ପରଦା ଫିଟିଂ ଦରକାର"
update("curtain_blind_mounting", catalog["curtain_blind_mounting"])

# 2. inverter_backup_failure: boost all Indic slots with power cut & backup phrasing
catalog["inverter_backup_failure"][4] = "வீட்டில் கரண்ட் போனா இன்வெர்ட்டர் பேக்கப் தரல, பேட்டரி சார்ஜ் ஆகல, இன்வெர்ட்டர் பீப் சத்தம் போடுது, யுபிಎಸ್ கெட்டுப்போச்சு"
catalog["inverter_backup_failure"][8] = "ঘরে কারেন্ট বা বিদ্যুৎ চলে গেলে ইনভার্টার ব্যাকআপ দিচ্ছে না, ব্যাটারি চার্জ হচ্ছে না, ইনভার্টার বিপ করছে, ইউপিএস ব্যাকআপ নষ্ট"
catalog["inverter_backup_failure"][11] = "ಮನೆಯಲ್ಲಿ ಕರೆಂಟ್ ಹೋದಾಗ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಕಪ್ ಕೊಡ್ತಿಲ್ಲ, ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ, ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ, ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಬ್ಯಾಟರಿ"
catalog["inverter_backup_failure"][13] = "ਘਰ ਵਿੱਚ ਬਿਜਲੀ ਜਾਣ ਤੇ ਇਨਵਰਟਰ ਬੈਕਅੱਪ ਨਹੀਂ ਦੇ ਰਿਹਾ, ਬੈਟਰੀ ਚਾਰਜ ਨਹੀਂ ਹੋ ਰਹੀ, ਇਨਵਰਟਰ ਬੀਪ ਕਰ ਰਿਹਾ ਹੈ, ਯੂਪੀਐਸ ਖ਼ਰਾਬ"
catalog["inverter_backup_failure"][14] = "ଘରେ କରେଣ୍ଟ ଗଲେ ଇନଭର୍ଟର ବ୍ୟାକଅପ୍ ଦେଉନାହିଁ, ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ, ଇନଭର୍ଟର ବିପ୍ କରୁଛି, କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ"
update("inverter_backup_failure", catalog["inverter_backup_failure"])

# 3. water_motor_failure: distinguish sharply from tank clean & tank overflow
catalog["water_motor_failure"][4] = "மோட்டார் ஓடல தண்ணீர் வரல பம்ப் வேலை செய்யல டேங்க் நிரம்பல, சப்மெர்சிபிள் போர்வெல் மோட்டார் பம்ப் ஓடல"
catalog["water_motor_failure"][8] = "মোটর চলছে কিন্তু জল আসছে না বোরওয়েল পাম্প খারাপ ট্যাংক ভরছে না, সাবমার্সিবল মোটর পাম্প জল তুলছে না"
catalog["water_motor_failure"][11] = "ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ, ಸಬ್‌ಮರ್ಸಿಬಲ್ ನೀರೆತ್ತುವ ಮೋಟರ್ ಕೆಟ್ಟಿದೆ"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਪਾਣੀ ਵਾਲਾ ਪੰਪ ਮੋਟਰ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର"
update("water_motor_failure", catalog["water_motor_failure"])

# 4. water_tank_cleaning: remove generic water words, emphasize cleaning/algae/sludge
catalog["water_tank_cleaning"][4] = "தண்ணீர் தொட்டி அசுத்தமாகி பாசி படிந்துள்ளது, ஓவர்ஹெட் வாட்டர் டேங்க் ஆசிட் வாஷ் மற்றும் பிளீச்சிங் கிளீனிங் தேவை"
catalog["water_tank_cleaning"][8] = "ছাদের জলের ট্যাঙ্কে শেওলা ও কাদা জমেছে, ওভারহেড ট্যাঙ্ক গভীর সাফাই ও ব্লিচিং দিয়ে জীবাণুমুক্তকরণ দরকার"
catalog["water_tank_cleaning"][14] = "ଛାତ ଟାଙ୍କିରେ ଶିଉଳି ଓ କାଦୁଅ ଜମିଛି, ଓଭରହେଡ୍ ଟାଙ୍କି ବ୍ଲିଚିଂ ସଫେଇ ଏବଂ ଡିପ୍ କ୍ଲିନିଂ ଦରକାର"
update("water_tank_cleaning", catalog["water_tank_cleaning"])

# 5. overhead_tank_overflow: emphasize overflow ball valve, no motor words
catalog["overhead_tank_overflow"][8] = "ওভারহেড ছাদের ট্যাঙ্ক উপচে জল পড়ে নষ্ট হচ্ছে, বল ভালভ বা ফ্লোট সুইচ খারাপ, ট্যাঙ্কের জল উপচে পড়া"
catalog["overhead_tank_overflow"][11] = "ಮೇಲ್ಛಾವಣಿ ಓವರ್‌ಹೆಡ್ ಟ್ಯಾಂಕ್ ತುಂಬಿ ನೀರು ಹೊರಗೆ ಚೆಲ್ಲುತ್ತಿದೆ, ಬಾಲ್ ವಾಲ್ವ್ ಫ್ಲೋಟ್ ವಾಲ್ವ್ ಲೀಕ್, ಟ್ಯಾಂಕ್ ತುಂಬಿ ಸೋರುವಿಕೆ"
update("overhead_tank_overflow", catalog["overhead_tank_overflow"])

# 6. ac_cooling_failure: boost Bengali & Kannada
catalog["ac_cooling_failure"][8] = "এসি চলছে ঘর ঠান্ডা হচ্ছে না কম্প্রেসার চালু হয় না গ্যাস লিক, এয়ার কন্ডিশনার কুলিং সমস্যা গরম বাতাস"
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ ಗ್ಯಾಸ್ ಲೀಕ್ ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ತಂಪಾಗುತ್ತಿಲ್ಲ ರೂಮ್ ಕೂಲಿಂಗ್ ಇಲ್ಲ"
update("ac_cooling_failure", catalog["ac_cooling_failure"])

# 7. exhaust_fan_repair: ensure no AC / cooling collision
catalog["exhaust_fan_repair"][8] = "বাথরুম ও রান্নাঘরের বাতাস টানার এগজস্ট ভেন্টিলেশন ফ্যান ঘুরছে না, ধোঁয়া বের করার ফ্যানের ব্লেড আটকে গেছে"
update("exhaust_fan_repair", catalog["exhaust_fan_repair"])

# 8. geyser_heating_issue: boost Bengali & Malayalam
catalog["geyser_heating_issue"][8] = "গিজার গরম জল দিচ্ছে না ওয়াটার হিটার নষ্ট ঠান্ডা জল, বাথরুমের গিজার হিটিং কয়েল খারাপ গরম জল নেই"
catalog["geyser_heating_issue"][12] = "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി, ബാത്ത്റൂം വാട്ടർ ഹീറ്റർ തണുത്ത വെള്ളം മാത്രം ചൂടാകുന്നില്ല"
update("geyser_heating_issue", catalog["geyser_heating_issue"])

# 9. drain_block_sewerage: boost Gujarati sink drain
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે પાણી નીકળતું નથી ગટર વાસ, રસોડાનું સિંક બ્લોક ગંદુ પાણી ભરાયેલું છે"
update("drain_block_sewerage", catalog["drain_block_sewerage"])

# 10. washing_machine_fault: boost Kannada washing machine
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಎರರ್ ಕೋಡ್, ಬಟ್ಟೆ ತೊಳೆಯುವ ವಾಷಿಂಗ್ ಮೆಷಿನ್ ಡ್ರಮ್ ತಿರುಗುತ್ತಿಲ್ಲ"
update("washing_machine_fault", catalog["washing_machine_fault"])

# 11. deep_cleaning_sanitization: boost Malayalam bathroom tiles
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ ഉപ്പ് പാടുകൾ ഡീപ് ക്ലീനിംഗ്, ബാത്ത്റൂം തറയിലെ കറ കളയാൻ ആസിഡ് വാഷ് ക്ലീനിംഗ്"
update("deep_cleaning_sanitization", catalog["deep_cleaning_sanitization"])

# 12. fan_repair_issue: boost Punjabi ceiling fan
catalog["fan_repair_issue"][13] = "ਛੱਤ ਵਾਲਾ ਪੱਖਾ ਬਹੁਤ ਹੌਲੀ ਚੱਲਦਾ ਕਪੈਸਿਟਰ ਸੜ ਗਿਆ ਗੂੰਜਣ ਦੀ ਆਵਾਜ਼, ਛੱਤ ਦਾ ਸੀਲਿੰਗ ਪੱਖਾ ਸਪੀਡ ਨਹੀਂ ਫੜ ਰਿਹਾ"
update("fan_repair_issue", catalog["fan_repair_issue"])

# 13. mcb_tripping_spark: de-correlate from generic appliances by anchoring purely on DB board, meter box, spark
catalog["mcb_tripping_spark"][11] = "ಮುಖ್ಯ ಎಲೆಕ್ಟ್ರಿಕ್ ಮೀಟರ್ ಬಾಕ್ಸ್ ಡಿಬಿ ಬೋರ್ಡ್ ಸ್ಪಾರ್ಕ್, ಮೈನ್ ಸ್ವಿಚ್ ಎಂಸಿಬಿ ಟ್ರಿಪ್, ಶಾರ್ಟ್ ಸರ್ಕ್ಯೂಟ್ ಹೊಗೆ"
catalog["mcb_tripping_spark"][13] = "ਮੁੱਖ ਬਿਜਲੀ ਮੀਟਰ ਬਕਸਾ ਮੇਨ ਸਵਿੱਚਬੋਰਡ ਚੰਗਿਆੜੀਆਂ, ਐਮਸੀਬੀ ਟ੍ਰਿਪ, ਸ਼ਾਰਟ ਸਰਕਟ ਤਾਰਾਂ ਦੀ ਸੜਨ"
catalog["mcb_tripping_spark"][14] = "ମୁଖ୍ୟ ବିଜୁଳି ମିଟର ବାକ୍ସ ଡିଷ୍ଟ୍ରିବ୍ୟୁସନ୍ ବୋର୍ଡ ନିଆଁ ଝୁଲ, ମେନ୍ ସୁଇଚ୍ ଏମସିବି ଟ୍ରିପ୍, ବିଜୁଳି ତାର ପୋଡ଼ିବା"
update("mcb_tripping_spark", catalog["mcb_tripping_spark"])

eval_bench("Step 4 Results")
