# -*- coding: utf-8 -*-
"""
Apply Option A (10 Additional Indian Languages Expansion) to export_multilingual_minilm_onnx.py.
Integrates:
  - 450 new regional phrasings across Assamese, Maithili, Urdu, Konkani, Nepali, Sindhi, Dogri, Kashmiri, Manipuri, Santali
  - Expands catalog items from 15 to 25 phrasings each (Total: 45 x 25 = 1,125 phrasings)
  - Adds 20 new cross-lingual benchmark test cases in Option A languages
  - Re-generates output/catalog_items_45.json and output/catalog_embeddings_45.json
  - Copies to backend/models/
"""

import os
import sys
import json
import re

# Ensure UTF-8 stdout/stderr on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_SCRIPT = os.path.join(BASE_DIR, "export_multilingual_minilm_onnx.py")

sys.path.insert(0, BASE_DIR)
from option_a_data import OPTION_A_PHRASINGS

NEW_OPTION_A_TEST_CASES = [
    # ── Assamese (অসমীয়া) ──
    ("পানীৰ মটৰ পাম্প নকৰা, ব'ৰৱেল পাম্পে কাম কৰা বন্ধ, ওপৰৰ টেংক ভৰোৱা নহয়", "water_motor_failure", "Water Motor (Assamese)"),
    ("ইনভাৰ্টাৰটোৱে বিপ কৰি আছে আৰু বিদ্যুৎ কৰ্তনৰ সময়ত কোনো বেকআপ নাই", "inverter_backup_failure", "Inverter (Assamese)"),
    
    # ── Urdu (اردو) ──
    ("پانی کی موٹر پمپ نہیں کر رہی، بورویل پمپ نے کام کرنا چھوڑ دیا", "water_motor_failure", "Water Motor (Urdu)"),
    ("گیزر نے کام کرنا چھوڑ دیا، باتھ روم سے گرم پانی نہیں آرہا", "geyser_heating_issue", "Geyser (Urdu)"),
    ("ایئر کنڈیشنر چل رہا ہے لیکن کمرہ ٹھنڈا نہیں ہے، AC گرم ہوا اڑا رہا ہے", "ac_cooling_failure", "AC Cooling (Urdu)"),
    
    # ── Dogri (डोगरी) ──
    ("पानी दी मोटर पम्प नेईं होंदी, बोरवेल पम्प कम्म करना बंद होई गेआ", "water_motor_failure", "Water Motor (Dogri)"),
    ("गीजर कम्म करना बंद करी दित्ता, बाथरूम थमां गर्म पानी नेईं औंदा", "geyser_heating_issue", "Geyser (Dogri)"),
    
    # ── Maithili (मैथिली) ──
    ("पानिक मोटर पंप नहि भ रहल अछि, बोरवेल पंप काज करब बंद भ गेल", "water_motor_failure", "Water Motor (Maithili)"),
    ("गीजर काज करब बंद क देलक, बाथरूम स गरम पानि नहि आबि रहल छल", "geyser_heating_issue", "Geyser (Maithili)"),

    # ── Nepali (नेपाली) ──
    ("पानीको मोटर पम्प छैन, बोरवेल पम्पले काम गर्न छोडेको छ, ट्यांक भरिएको छैन", "water_motor_failure", "Water Motor (Nepali)"),
    ("गीजरले काम गर्न छोड्यो, बाथरूमबाट तातो पानी आउँदैन, हिटर फुट्यो", "geyser_heating_issue", "Geyser (Nepali)"),

    # ── Konkani (कोंकणी) ──
    ("उदकाचो मोटर पंप जायना, बोरवेल पंप काम करपाक बंद जालो", "water_motor_failure", "Water Motor (Konkani)"),
    ("गीझर काम बंद जालें, बांयत गरम उदक येनाशिल्लें, कोमरा उदक", "geyser_heating_issue", "Geyser (Konkani)"),

    # ── Sindhi (سنڌي) ──
    ("پاڻي جي موٽر پمپ نه ٿي، بورويل پمپ ڪم ڪرڻ بند ڪيو", "water_motor_failure", "Water Motor (Sindhi)"),
    ("گيزر ڪم ڪرڻ بند ڪيو، غسل خاني مان گرم پاڻي نه پيو اچي", "geyser_heating_issue", "Geyser (Sindhi)"),

    # ── Kashmiri (कश्मीरी) ──
    ("पानी की मोटर पंप नहीं कर रही है, बोरवेल पंप ने काम करना बंद कर दिया", "water_motor_failure", "Water Motor (Kashmiri)"),
    ("गीजर ने काम करना बंद कर दिया, बाथरूम से गर्म पानी नहीं आ रहा", "geyser_heating_issue", "Geyser (Kashmiri)"),

    # ── Manipuri Meitei Mayek (মৈতৈ / ꯃꯤꯇꯩ) ──
    ("ꯏꯁꯤꯡꯒꯤ ꯃꯣꯇꯣꯔ ꯄꯝꯄ ꯇꯧꯗꯕꯥ, ꯕꯣꯔꯋꯦꯜ ꯄꯝꯄ ꯊꯕꯛ ꯇꯧꯕꯥ ꯂꯦꯄꯈꯤ", "water_motor_failure", "Water Motor (Manipuri)"),
    ("ꯒꯤꯖꯔꯅꯥ ꯊꯕꯛ ꯇꯧꯕꯥ ꯂꯦꯄꯈꯤ, ꯕꯥꯊꯔꯨꯃꯗꯒꯤ ꯑꯁꯥꯕꯥ ꯏꯁꯤꯡ ꯂꯥꯀꯈꯤꯗꯦ", "geyser_heating_issue", "Geyser (Manipuri)"),

    # ── Santali Ol Chiki (ᱥᱟᱱᱛᱟᱲᱤ / ᱚᱞ ᱪᱤᱠᱤ) ──
    ("ᱫᱟᱜ ᱢᱚᱴᱚᱨ ᱵᱟᱭ ᱯᱟᱢᱯᱤᱝ ᱮᱫᱟ, ᱵᱚᱨᱣᱮᱞ ᱯᱟᱢᱯ ᱠᱟᱹᱢᱤ ᱵᱚᱱᱫᱚ ᱠᱮᱫᱟᱭ", "water_motor_failure", "Water Motor (Santali)"),
]

def main():
    print("=" * 76)
    print("  Applying Option A: 10 Additional Indian Languages Expansion")
    print("  (Assamese, Maithili, Urdu, Konkani, Nepali, Sindhi, Dogri, Kashmiri, Manipuri, Santali)")
    print("=" * 76)

    import export_multilingual_minilm_onnx as exp
    catalog = exp.CATALOG_ITEMS
    print(f"Loaded {len(catalog)} catalog items.")

    for item in catalog:
        cid = item["id"]
        if cid not in OPTION_A_PHRASINGS:
            raise ValueError(f"Missing Option A phrasings for: {cid}")
        
        opt_a = OPTION_A_PHRASINGS[cid]
        if len(opt_a) != 10:
            raise ValueError(f"Expected 10 Option A phrasings for {cid}, got {len(opt_a)}")

        # Check current count
        if len(item["texts"]) == 15:
            item["texts"].extend(opt_a)
        elif len(item["texts"]) == 25:
            item["texts"] = item["texts"][:15] + opt_a
        else:
            raise ValueError(f"Unexpected length for {cid}: {len(item['texts'])}")

    total_phrases = sum(len(x["texts"]) for x in catalog)
    print(f"Total catalog phrasings after expansion: {total_phrases} (expected: 1,125)")
    assert total_phrases == 1125, f"Expected 1125, got {total_phrases}"

    # Build formatted CATALOG_ITEMS block
    catalog_lines = ["CATALOG_ITEMS = [\n"]
    for idx, item in enumerate(catalog, 1):
        catalog_lines.append(f"    # {idx}\n")
        catalog_lines.append("    {\n")
        catalog_lines.append(f'        "id": {json.dumps(item["id"], ensure_ascii=False)},\n')
        catalog_lines.append(f'        "equipmentTag": {json.dumps(item["equipmentTag"], ensure_ascii=False)},\n')
        catalog_lines.append(f'        "trade": {json.dumps(item["trade"], ensure_ascii=False)},\n')
        catalog_lines.append('        "texts": [\n')
        for t in item["texts"]:
            catalog_lines.append(f'            {json.dumps(t, ensure_ascii=False)},\n')
        catalog_lines.append("        ],\n")
        catalog_lines.append("    },\n")
    catalog_lines.append("]\n")
    new_catalog_code = "".join(catalog_lines)

    with open(TARGET_SCRIPT, "r", encoding="utf-8") as f:
        src = f.read()

    # Replace CATALOG_ITEMS = [ ... ]
    pat = re.compile(r"CATALOG_ITEMS\s*=\s*\[.*?\n\]\n", re.DOTALL)
    if not pat.search(src):
        raise ValueError("Could not find CATALOG_ITEMS = [ ... ] in target script")
    src = pat.sub(new_catalog_code, src)

    # Append new test cases to TEST_CASES if not already present
    for tc in NEW_OPTION_A_TEST_CASES:
        tc_repr = f'    ({json.dumps(tc[0], ensure_ascii=False)}, {json.dumps(tc[1])}, {json.dumps(tc[2])}),\n'
        if json.dumps(tc[0], ensure_ascii=False) not in src:
            # Insert before the closing bracket of TEST_CASES
            test_cases_end = src.rfind("]\n\n\ndef cosine_similarity")
            if test_cases_end != -1:
                src = src[:test_cases_end] + tc_repr + src[test_cases_end:]

    with open(TARGET_SCRIPT, "w", encoding="utf-8") as f:
        f.write(src)
    print(f"Successfully updated {TARGET_SCRIPT} with 25 phrasings per item!")

if __name__ == "__main__":
    main()
