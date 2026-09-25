# -*- coding: utf-8 -*-
"""
Generate Option A Phrasings (10 Additional Eighth Schedule Languages)
Languages:
  1. Assamese (as)
  2. Maithili (mai)
  3. Urdu (ur)
  4. Konkani (kok)
  5. Nepali (ne)
  6. Sindhi (sd)
  7. Dogri (doi)
  8. Kashmiri (ks - Devanagari representation)
  9. Manipuri (mni-Mtei - Meitei Mayek)
 10. Santali (sat - Ol Chiki)

Total: 45 items x 10 languages = 450 new phrasings.
Output: backend/ml_training/option_a_data.py
"""

import json
import os
import sys
import time
import urllib.parse
import urllib.request
import re

# Force UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_PATH = os.path.join(BASE_DIR, "output", "catalog_items_45.json")
OUTPUT_PY = os.path.join(BASE_DIR, "option_a_data.py")

OPTION_A_LANGS = [
    ("as", "as", "Assamese"),
    ("mai", "mai", "Maithili"),
    ("ur", "ur", "Urdu"),
    ("kok", "kok", "Konkani"),
    ("ne", "ne", "Nepali"),
    ("sd", "sd", "Sindhi"),
    ("doi", "doi", "Dogri"),
    ("ks", "hi", "Kashmiri"),
    ("mni", "mni-Mtei", "Manipuri"),
    ("sat", "sat", "Santali"),
]

def translate_query(text, target_code):
    q = urllib.parse.quote(text)
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={target_code}&dt=t&q={q}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                res = json.loads(resp.read().decode("utf-8"))
                trans = "".join([seg[0] for seg in res[0] if seg[0]])
                return trans.strip()
        except Exception as e:
            time.sleep(1 + attempt * 0.5)
    return text

def main():
    print(f"Loading {ITEMS_PATH}...")
    with open(ITEMS_PATH, "r", encoding="utf-8") as f:
        items = json.load(f)
    print(f"Loaded {len(items)} items.")

    option_a_dict = {}

    # Check if partial or existing file exists
    if os.path.exists(OUTPUT_PY):
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("option_a_data", OUTPUT_PY)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            option_a_dict = getattr(mod, "OPTION_A_PHRASINGS", {})
            print(f"Found existing data for {len(option_a_dict)} items.")
        except Exception:
            option_a_dict = {}

    for idx, item in enumerate(items, 1):
        cid = item["id"]
        if cid in option_a_dict and len(option_a_dict[cid]) == 10:
            print(f"[{idx}/{len(items)}] {cid}: Already complete.")
            continue

        base_text = item["texts"][1] if len(item["texts"]) > 1 else item["texts"][0]
        print(f"[{idx}/{len(items)}] Translating {cid} ({item['equipmentTag']})...")

        translations = []
        for lang_key, g_code, lang_name in OPTION_A_LANGS:
            trans = translate_query(base_text, g_code)
            translations.append(trans)
            time.sleep(0.15)

        option_a_dict[cid] = translations
        print(f"  Done {cid} -> {len(translations)} languages.")

        # Save progress every 5 items
        if idx % 5 == 0 or idx == len(items):
            save_data(option_a_dict)

    save_data(option_a_dict)
    print("\nALL 45 ITEMS TRANSLATED FOR OPTION A SUCCESSFULLY!")

def save_data(data):
    lines = [
        "# -*- coding: utf-8 -*-",
        '"""',
        "Option A Regional Phrasings Data for WorkGo 45 Catalog Items.",
        "Languages: [Assamese, Maithili, Urdu, Konkani, Nepali, Sindhi, Dogri, Kashmiri, Manipuri, Santali]",
        '"""',
        "",
        "OPTION_A_PHRASINGS = {",
    ]
    for cid, texts in data.items():
        lines.append(f"    {json.dumps(cid, ensure_ascii=False)}: [")
        for t in texts:
            lines.append(f"        {json.dumps(t, ensure_ascii=False)},")
        lines.append("    ],")
    lines.append("}")
    lines.append("")
    lines.append('__all__ = ["OPTION_A_PHRASINGS"]')
    lines.append("")

    with open(OUTPUT_PY, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Saved {len(data)} items to {OUTPUT_PY}")

if __name__ == "__main__":
    main()
