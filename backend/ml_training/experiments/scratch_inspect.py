# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from sentence_transformers import SentenceTransformer
from transformers import AutoTokenizer

tok = AutoTokenizer.from_pretrained('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')
model = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')

s1 = 'എസി തണുപ്പിക്കുന്നില്ല കംപ്രസ്സർ ഓൺ ആകുന്നില്ല ഗ്യാസ് ലീക്ക് ചൂട് കാറ്റ്'
s2 = 'സെക്യൂരിറ്റി അലാറം അകാരണമായി മുഴങ്ങുന്നു, മോഷൻ സെൻസർ തെറ്റായി പ്രവർത്തിക്കുന്നു, സ്മോക്ക് അലാറം ബീപ്'
s3 = 'The air conditioner is not cooling and blowing hot air'
s4 = 'എയർ കണ്ടീഷണർ എസി തണുപ്പിക്കുന്നില്ല, എസി കംപ്രസ്സർ പ്രവർത്തിക്കുന്നില്ല, കൂളിംഗ് ഗ്യാസ് ലീക്ക് ആയി, ചൂട് കാറ്റ് വരുന്നു'

v1 = model.encode(s1, normalize_embeddings=True)
v2 = model.encode(s2, normalize_embeddings=True)
v3 = model.encode(s3, normalize_embeddings=True)
v4 = model.encode(s4, normalize_embeddings=True)

print('cos(AC Query, Security Alarm Malayalam):', float(v1 @ v2))
print('cos(AC Query, AC English):', float(v1 @ v3))
print('cos(AC Query, AC Catalog Malayalam):', float(v1 @ v4))
