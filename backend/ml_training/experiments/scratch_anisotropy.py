# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')

# Let's take 5 completely unrelated Malayalam sentences
sentences = [
    "എസി തണുപ്പിക്കുന്നില്ല കംപ്രസ്സർ ഓൺ ആകുന്നില്ല ഗ്യാസ് ലീക്ക് ചൂട് കാറ്റ്",
    "സെക്യൂരിറ്റി അലാറം അകാരണമായി മുഴങ്ങുന്നു, മോഷൻ സെൻസർ തെറ്റായി പ്രവർത്തിക്കുന്നു",
    "ഇന്ന് മഴ പെയ്യാൻ സാധ്യതയുണ്ട് എന്ന് കാലാവസ്ഥാ നിരീക്ഷകർ പറയുന്നു",
    "കേരളത്തിലെ പ്രകൃതി സൗന്ദര്യം കാണാൻ ധാരാളം സഞ്ചാരികൾ വരുന്നു",
    "പുതിയ മൊബൈൽ ഫോൺ വാങ്ങാൻ ഞാൻ കടയിലേക്ക് പോയി",
]

vecs = model.encode(sentences, normalize_embeddings=True)
sim_matrix = vecs @ vecs.T
print("Cosine similarity matrix between completely unrelated Malayalam sentences:")
print(np.round(sim_matrix, 3))

# And English equivalents:
en_sentences = [
    "AC not cooling compressor not starting refrigerant gas leak warm air",
    "security burglar alarm going off motion sensor false alarm",
    "weather forecasters say it is likely to rain today",
    "many tourists come to see the natural beauty of Kerala",
    "I went to the store to buy a new mobile phone",
]
en_vecs = model.encode(en_sentences, normalize_embeddings=True)
en_sim = en_vecs @ en_vecs.T
print("\nCosine similarity matrix between English sentences:")
print(np.round(en_sim, 3))
