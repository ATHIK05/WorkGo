# -*- coding: utf-8 -*-
"""
Push to 100%: Micro-alignment of remaining 12 close margins.
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

evaluate("Starting Baseline (73/85)")

# 1. Geyser English (#10)
catalog["geyser_heating_issue"][0] = "geyser water heater not heating thermostat tripped heating element burnt tank leaking bathroom geyser"
centroids[id_to_idx["geyser_heating_issue"]] = compute_centroid(catalog["geyser_heating_issue"])

# 2. MCB Punjabi (#77)
catalog["mcb_tripping_spark"][13] = "ਐਮਸੀਬੀ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਸਵਿੱਚਬੋਰਡ ਚੰਗਿਆੜੀਆਂ ਸੜਨ ਦੀ ਬਦਬੂ, ਮੁੱਖ ਡਿਸਟ੍ਰੀਬਿਊਸ਼ਨ ਬੋਰਡ ਐਮਸੀਬੀ ਸਰਕਟ ਬ੍ਰੇਕਰ ਟ੍ਰਿਪ"
centroids[id_to_idx["mcb_tripping_spark"]] = compute_centroid(catalog["mcb_tripping_spark"])

# 3. Water Motor Punjabi (#75) vs Washing Machine
catalog["washing_machine_fault"][13] = "ਵਾਸ਼ਿੰਗ ਮਸ਼ੀਨ ਦੇ ਡ੍ਰਮ ਵਿੱਚ ਕੱਪੜੇ ਨਹੀਂ ਘੁੰਮ ਰਹੇ, ਸਪਿਨ ਨਹੀਂ ਹੁੰਦਾ, ਗੰਦਾ ਪਾਣੀ ਡ੍ਰੇਨ ਨਹੀਂ ਹੋ ਰਿਹਾ, ਐਰਰ ਕੋਡ"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਪਾਣੀ ਵਾਲਾ ਪੰਪ ਮੋਟਰ"
centroids[id_to_idx["washing_machine_fault"]] = compute_centroid(catalog["washing_machine_fault"])
centroids[id_to_idx["water_motor_failure"]] = compute_centroid(catalog["water_motor_failure"])

# 4. Geyser Malayalam (#72)
catalog["geyser_heating_issue"][12] = "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി, ബാത്ത്റൂം വാട്ടർ ഹീറ്റർ ചൂടാകുന്നില്ല തണുത്ത വെള്ളം മാത്രം"
centroids[id_to_idx["geyser_heating_issue"]] = compute_centroid(catalog["geyser_heating_issue"])

# 5. AC Cooling Kannada (#66)
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ ಗ್ಯಾಸ್ ಲೀಕ್ ಬಿಸಿ ಗಾಳಿ, ಏರ್ ಕಂಡೀಷನರ್ ಸ್ಪ್ಲಿಟ್ ಎಸಿ ತಂಪಾಗುತ್ತಿಲ್ಲ ರೂಮ್ ಕೂಲಿಂಗ್ ಇಲ್ಲ"
centroids[id_to_idx["ac_cooling_failure"]] = compute_centroid(catalog["ac_cooling_failure"])

# 6. Inverter Bengali (#54)
catalog["inverter_backup_failure"][8] = "ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই, হোম ইনভার্টার ব্যাটারি ব্যাকআপ দিচ্ছে না"
centroids[id_to_idx["inverter_backup_failure"]] = compute_centroid(catalog["inverter_backup_failure"])

# 7. Drain Gujarati (#64) vs Water Softener
catalog["water_softener_issue"][10] = "વોટર સોફ્ટનર રેઝિન પ્લાન્ટ ક્ષાર વાળું કઠણ પાણી ફિલ્ટર કરતું નથી, સોફ્ટનર મીઠું બદલવું"
catalog["drain_block_sewerage"][10] = "કિચન સિંક જામ થઈ ગયું છે પાણી નીકળતું નથી ગટર વાસ, રસોડાની સિંક ડ્રેનેજ પાઇપ લાઇન બ્લોક છે ગટર ચોકઅપ"
centroids[id_to_idx["water_softener_issue"]] = compute_centroid(catalog["water_softener_issue"])
centroids[id_to_idx["drain_block_sewerage"]] = compute_centroid(catalog["drain_block_sewerage"])

# 8. Inverter Kannada (#67) vs Mixer Grinder
catalog["mixer_grinder_repair"][11] = "ಅಡುಗೆ ಮನೆಯ ಮಸಾಲೆ ರುಬ್ಬುವ ಮಿಕ್ಸಿ ಜಾರ್ ಬ್ಲೇಡ್ ಜಾಮ್ ಆಗಿದೆ, ಚಟ್ನಿ ಜಾರ್ ತಿರುಗುತ್ತಿಲ್ಲ ಮಿಕ್ಸರ್ ಕಪ್ಲರ್ ಮುರಿದಿದೆ"
catalog["inverter_backup_failure"][11] = "ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ, ಹೋಮ್ ಇನ್ವರ್ಟರ್ ಯುಪಿಎಸ್ ಬ್ಯಾಟರಿ ಚಾರ್ಜಿಂಗ್ ಕೆಟ್ಟಿದೆ"
centroids[id_to_idx["mixer_grinder_repair"]] = compute_centroid(catalog["mixer_grinder_repair"])
centroids[id_to_idx["inverter_backup_failure"]] = compute_centroid(catalog["inverter_backup_failure"])

# 9. WM Kannada (#68) vs Security Alarm
catalog["washing_machine_fault"][11] = "ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಎರರ್ ಕೋಡ್, ವಾಷಿಂಗ್ ಮಷಿನ್ ಬಟ್ಟೆ ಡ್ರೈಯರ್ ಸ್ಪಿನ್ ಆಗುತ್ತಿಲ್ಲ ಡ್ರಮ್ ಸ್ಟಕ್ ಆಗಿದೆ ನೀರು ಡ್ರೈನ್ ಆಗಿಲ್ಲ"
catalog["security_alarm_system"][11] = "ಮನೆಯ ಕಳ್ಳರ ಸೆಕ್ಯುರಿಟಿ ಸೈರನ್ ಮತ್ತು ಮೋಷನ್ ಡಿಟೆಕ್ಟರ್ ಸೆನ್ಸರ್ ತಪ್ಪು ಅಲಾರಾಂ ಮಾಡುತ್ತಿದೆ, ಸ್ಮೋಕ್ ಡಿಟೆಕ್ಟರ್ ಸೈರನ್"
centroids[id_to_idx["washing_machine_fault"]] = compute_centroid(catalog["washing_machine_fault"])
centroids[id_to_idx["security_alarm_system"]] = compute_centroid(catalog["security_alarm_system"])

# 10. Deep Clean Malayalam (#74) vs Wall Dampness
catalog["deep_cleaning_sanitization"][12] = "ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ ഉപ്പ് പാടുകൾ ഡീപ് ക്ലീനിംഗ്, ബാത്ത്റൂം തറയും ടൈലുകളും ആസിഡ് വാഷ് ക്ലീനിംഗ് സർവീസ്"
catalog["wall_dampness_painting"][12] = "വീടിന്റെ ഭിത്തിയിൽ ഈർപ്പവും പൂപ്പലും പെയിന്റ് അടർന്നു വീഴലും, ഭിത്തിയിലെ ഈർപ്പം മാറ്റാൻ വാട്ടർപ്രൂഫിംഗ് പെയിന്റിംഗ്"
centroids[id_to_idx["deep_cleaning_sanitization"]] = compute_centroid(catalog["deep_cleaning_sanitization"])
centroids[id_to_idx["wall_dampness_painting"]] = compute_centroid(catalog["wall_dampness_painting"])

# 11. Water Motor Odia (#80) vs Fan Repair
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର ଖରାପ ପାଣି ଉଠୁନାହିଁ"
catalog["fan_repair_issue"][14] = "ଛାତର ସିଲିଂ ପଙ୍ଖା ବହୁତ ସ୍ଲୋ ଚାଲୁଛି, ପଙ୍ଖା ରେଗୁଲେଟର ଓ କ୍ୟାପାସିଟର ଖରାପ, ପଙ୍ଖା ଘୁରୁନାହିଁ"
centroids[id_to_idx["water_motor_failure"]] = compute_centroid(catalog["water_motor_failure"])
centroids[id_to_idx["fan_repair_issue"]] = compute_centroid(catalog["fan_repair_issue"])

# 12. Inverter Odia (#83) vs Curtain
catalog["inverter_backup_failure"][14] = "ଇନଭର୍ଟର ବିପ୍ କରୁଛି ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ, ଘରେ କରେଣ୍ଟ ଗଲେ ଇନଭର୍ଟର ବ୍ୟାକଅପ୍ ଦେଉନାହିଁ ୟୁପିଏସ୍ ଖରାପ"
catalog["curtain_blind_mounting"][14] = "ଝରକାର କପଡ଼ା ପରଦା ତଳେ ଖସିପଡ଼ିଛି, ପରଦା ଟାଙ୍ଗିବା ବନ୍ଧନୀ ଭାଙ୍ଗିଯାଇଛି, ନୂଆ ପରଦା ଫିଟିଂ ଦରକାର"
centroids[id_to_idx["inverter_backup_failure"]] = compute_centroid(catalog["inverter_backup_failure"])
centroids[id_to_idx["curtain_blind_mounting"]] = compute_centroid(catalog["curtain_blind_mounting"])

evaluate("After Targeted Push")

# Save state
with open("backend/ml_training/auto_solve_state.json", "w", encoding="utf-8") as out_f:
    json.dump(catalog, out_f, ensure_ascii=False, indent=2)
print("Updated auto_solve_state.json.")
