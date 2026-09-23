# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import numpy as np
from sentence_transformers import SentenceTransformer
import test_enrich as te

model = te.model
catalog = te.catalog
test_cases = te.exp.TEST_CASES

# Encode all catalog texts once
print("Encoding catalog items...")
encoded_catalog = {}
for cid, texts in catalog.items():
    encoded_catalog[cid] = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)

def eval_method(name, get_centroid_fn):
    cents = {}
    for cid, vecs in encoded_catalog.items():
        c = get_centroid_fn(vecs)
        c = c / np.linalg.norm(c)
        cents[cid] = c
    
    passed = 0
    for q, exp_id, lbl in test_cases:
        qv = model.encode(q, normalize_embeddings=True)
        sims = [(cid, float(np.dot(qv, cents[cid]))) for cid in cents]
        sims.sort(key=lambda x: x[1], reverse=True)
        passed += (sims[0][0] == exp_id)
    print(f"{name:35s}: {passed}/{len(test_cases)} ({passed/len(test_cases)*100:.1f}%)")

# 1. Simple Mean
eval_method("1. Simple np.mean", lambda v: np.mean(v, axis=0))

# 2. SVD 1st Component
def svd_first(v):
    # Center then 1st singular vector or raw 1st singular vector
    u, s, vt = np.linalg.svd(v, full_matrices=False)
    vec = vt[0]
    # Ensure sign matches mean
    if np.dot(vec, np.mean(v, axis=0)) < 0:
        vec = -vec
    return vec
eval_method("2. SVD 1st Component", svd_first)

# 3. Script-Balanced Mean:
# Scripts: Latin (0,1,2,3,7), Tamil (4), Hindi (5), Telugu (6), Bengali (8), Marathi (9), Gujarati (10), Kannada (11), Malayalam (12), Punjabi (13), Odia (14)
# 11 distinct script groups!
groups = [
    [0, 1, 2, 3, 7], # Latin/Roman
    [4],             # Tamil
    [5],             # Hindi (Devanagari)
    [6],             # Telugu
    [8],             # Bengali
    [9],             # Marathi (Devanagari)
    [10],            # Gujarati
    [11],            # Kannada
    [12],            # Malayalam
    [13],            # Gurmukhi
    [14],            # Odia
]
def script_balanced_mean(v):
    group_means = [np.mean(v[g], axis=0) for g in groups]
    # L2-normalize each group mean first so all scripts contribute equally
    group_means = [g / np.linalg.norm(g) for g in group_means]
    return np.mean(group_means, axis=0)
eval_method("3. Script-Balanced Mean", script_balanced_mean)

# 4. Indic-Prioritized Balanced Mean (e.g. Indic 80%, Latin 20%)
def indic_prioritized_mean(v):
    latin_mean = np.mean(v[[0, 1, 2, 3, 7]], axis=0)
    latin_mean = latin_mean / np.linalg.norm(latin_mean)
    indic_means = [v[i] for i in [4, 5, 6, 8, 9, 10, 11, 12, 13, 14]]
    indic_mean = np.mean([g / np.linalg.norm(g) for g in indic_means], axis=0)
    indic_mean = indic_mean / np.linalg.norm(indic_mean)
    return 0.3 * latin_mean + 0.7 * indic_mean
eval_method("4. Indic-Prioritized (70/30)", indic_prioritized_mean)
