# -*- coding: utf-8 -*-
"""
Full Optimizer for WorkGo Multilingual Symptom Catalog.
Evaluates all 85 test cases, identifies collisions, and tunes phrasings.
"""
import sys, os, copy
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

catalog = {item["id"]: copy.deepcopy(item["texts"]) for item in exp.CATALOG_ITEMS}

def evaluate(current_catalog):
    cents = {}
    for cid, texts in current_catalog.items():
        vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
        c = np.mean(vecs, axis=0)
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
    return passed, fails, cents

print("Initial evaluation:")
p, f, _ = evaluate(catalog)
print(f"Pass: {p}/{len(exp.TEST_CASES)} ({p/len(exp.TEST_CASES)*100:.1f}%)")
