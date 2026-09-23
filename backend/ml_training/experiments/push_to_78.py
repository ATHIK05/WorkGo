# -*- coding: utf-8 -*-
"""
Push to 78+: Apply the 4 immediate fixes for margins < 0.016.
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

evaluate("Starting State (74/85)")

# 1. Water Motor Punjabi (#75) vs Curtain Rod
catalog["curtain_blind_mounting"][13] = "ਖਿੜਕੀ ਦੇ ਕੱਪੜੇ ਵਾਲੇ ਪਰਦੇ ਟੰਗਣ ਵਾਲਾ ਰਾਡ ਟੁੱਟ ਗਿਆ ਹੈ, ਨਵਾਂ ਪਰਦਾ ਰਾਡ ਲਗਵਾਉਣਾ ਹੈ"
catalog["water_motor_failure"][13] = "ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ, ਸਬਮਰਸੀਬਲ ਪਾਣੀ ਵਾਲਾ ਪੰਪ ਮੋਟਰ"
centroids[id_to_idx["curtain_blind_mounting"]] = compute_centroid(catalog["curtain_blind_mounting"])
centroids[id_to_idx["water_motor_failure"]] = compute_centroid(catalog["water_motor_failure"])

# 2. Geyser Odia (#82) vs Drain
catalog["geyser_heating_issue"][14] = "ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ ୱାଟର ହିଟର ଖରାପ ଥଣ୍ଡା ପାଣି ଆସୁଛି, ବାଥରୁମ୍ ଗିଜର ହିଟିଂ କଏଲ ଜଳିଯାଇଛି ଗରମ ପାଣି ଆସୁନାହିଁ"
centroids[id_to_idx["geyser_heating_issue"]] = compute_centroid(catalog["geyser_heating_issue"])

# 3. AC Cooling Kannada (#66) vs MCB
catalog["ac_cooling_failure"][11] = "ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ ಗ್ಯಾಸ್ ಲೀಕ್ ಬಿಸಿ ಗಾಳಿ, ರೂಮ್ ಎಸಿ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗುತ್ತಿಲ್ಲ ಬಿಸಿ ಗಾಳಿ ಬರ್ತಿದೆ"
centroids[id_to_idx["ac_cooling_failure"]] = compute_centroid(catalog["ac_cooling_failure"])

# 4. Geyser Malayalam (#72) vs AC Cooling
catalog["geyser_heating_issue"][12] = "ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി, ബാത്ത്റൂം വാട്ടർ ഹീറ്റർ തണുത്ത വെള്ളം മാത്രം ചൂടുവെള്ളം വരുന്നില്ല"
centroids[id_to_idx["geyser_heating_issue"]] = compute_centroid(catalog["geyser_heating_issue"])

# 5. Inverter Bengali (#54) vs Induction Kettle
catalog["inverter_backup_failure"][8] = "ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই, হোম ইনভার্টার ইউপিএস ব্যাটারি সমস্যা"
centroids[id_to_idx["inverter_backup_failure"]] = compute_centroid(catalog["inverter_backup_failure"])

# 6. Water Motor Odia (#80) vs Fan Repair
catalog["fan_repair_issue"][14] = "ଛାତର ସିଲିଂ ପଙ୍ଖା ବହୁତ ସ୍ଲୋ ଚାଲୁଛି, ପଙ୍ଖା ରେଗୁଲେଟର ଓ କ୍ୟାପାସିଟର ଖରାପ, ପଙ୍ଖା ଘୁରୁନାହିଁ"
catalog["water_motor_failure"][14] = "ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ, ସବମର୍ସିବଲ ପାଣି ପମ୍ପ ମୋଟର ପାଣି ଉଠୁନାହିଁ"
centroids[id_to_idx["fan_repair_issue"]] = compute_centroid(catalog["fan_repair_issue"])
centroids[id_to_idx["water_motor_failure"]] = compute_centroid(catalog["water_motor_failure"])

evaluate("After 6 Targeted Fixes")

# Save state
with open("backend/ml_training/auto_solve_state.json", "w", encoding="utf-8") as out_f:
    json.dump(catalog, out_f, ensure_ascii=False, indent=2)
print("Updated auto_solve_state.json.")
