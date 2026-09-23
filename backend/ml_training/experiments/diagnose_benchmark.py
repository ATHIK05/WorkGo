# -*- coding: utf-8 -*-
"""
Interactive Diagnostic Script for WorkGo Multilingual Bi-Encoder.
Tests current centroids against failing cases and prints top-3 rankings.
"""
import sys, os, json
import numpy as np

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import export_multilingual_minilm_onnx as exp
from sentence_transformers import SentenceTransformer

def main():
    print("Loading model...")
    model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
    
    print("Computing catalog centroids...")
    catalog_vectors = exp.generate_catalog_embeddings(model)
    
    print("\nRunning benchmark on failing / regional cases:")
    fails = []
    for query, exp_id, lbl in exp.TEST_CASES:
        q_vec = model.encode(query, normalize_embeddings=True)
        scores = []
        for cid, d in catalog_vectors.items():
            sim = float(np.dot(q_vec, np.array(d["vector"], dtype=np.float32)))
            scores.append((cid, d["equipmentTag"], sim))
        scores.sort(key=lambda x: x[2], reverse=True)
        
        top_id, top_tag, top_score = scores[0]
        target_score = next(s[2] for s in scores if s[0] == exp_id)
        ok = (top_id == exp_id)
        if not ok:
            fails.append((lbl, query, exp_id, target_score, top_id, top_tag, top_score, scores[1], scores[2]))
            print(f"FAIL: {lbl:30s} -> Target: {exp_id} ({target_score:.3f}) | Top: {top_id} ({top_score:.3f})")
    
    print(f"\nTotal fails: {len(fails)} / {len(exp.TEST_CASES)}")
    for f in fails:
        lbl, query, exp_id, t_score, top_id, top_tag, top_score, s1, s2 = f
        print(f"\n--- {lbl} ---")
        print(f"Query:  {query}")
        print(f"Target: {exp_id} ({t_score:.3f})")
        print(f"Top 1:  {top_id} ({top_score:.3f})")
        print(f"Top 2:  {s1[0]} ({s1[2]:.3f})")
        print(f"Top 3:  {s2[0]} ({s2[2]:.3f})")

if __name__ == "__main__":
    main()
