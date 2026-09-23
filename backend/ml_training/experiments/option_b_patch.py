# -*- coding: utf-8 -*-
"""
Option B Expansion Patch — 7 More Indian Languages
Adds: Bengali (বাংলা), Marathi (मराठी), Gujarati (ગુજરાતી),
      Kannada (ಕನ್ನಡ), Malayalam (മലയാളം), Punjabi (ਪੰਜਾਬੀ), Odia (ଓଡ଼ିଆ)

Expands: 8 phrasings/item → 15 phrasings/item  |  360 → 675 total
Market:  ~65% → ~87% of India's population covered
"""

import sys
import os
import json
import re
import importlib

# Ensure UTF-8 stdout/stderr on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from option_b_data import OPTION_B_PHRASINGS as OPTION_B

REGIONAL_TEST_CASES = [
    # ── Bengali (বাংলা) ──
    ("মোটর চলছে কিন্তু জল আসছে না বোরওয়েল পাম্প খারাপ ট্যাংক ভরছে না", "water_motor_failure", "Water Motor (Bengali)"),
    ("এসি চলছে ঘর ঠান্ডা হচ্ছে না কম্প্রেসার চালু হয় না গ্যাস লিক", "ac_cooling_failure", "AC Cooling (Bengali)"),
    ("গিজার গরম জল দিচ্ছে না ওয়াটার হিটার নষ্ট ঠান্ডা জল", "geyser_heating_issue", "Geyser (Bengali)"),
    ("রান্নাঘরের সিঙ্ক ব্লক জল জমে আছে ড্রেন দিয়ে দুর্গন্ধ", "drain_block_sewerage", "Drain (Bengali)"),
    ("ইনভার্টার বিপ করছে ব্যাটারি চার্জ হচ্ছে না কারেন্ট গেলে ব্যাকআপ নেই", "inverter_backup_failure", "Inverter (Bengali)"),

    # ── Marathi (मराठी) ──
    ("सबमर्सिबल मोटर चालू आहे पण पाणी येत नाही टाकी भरत नाही", "water_motor_failure", "Water Motor (Marathi)"),
    ("एसी थंड करत नाही कंप्रेसर चालू होत नाही गॅस गळती गरम हवा", "ac_cooling_failure", "AC Cooling (Marathi)"),
    ("एमसीबी वारंवार ट्रिप होतोय स्विचबोर्ड ठिणग्या जळाल्याचा वास", "mcb_tripping_spark", "MCB (Marathi)"),
    ("वॉशिंग मशीन फिरत नाही ड्रम अडकलाय पाणी बाहेर पडत नाही", "washing_machine_fault", "WM (Marathi)"),
    ("सिलिंग फॅन खूप संथ फिरतोय कॅपेसिटर गेलाय मोठा आवाज", "fan_repair_issue", "Fan (Marathi)"),

    # ── Gujarati (ગુજરાતી) ──
    ("મોટર ચાલુ છે પણ પાણી આવતું નથી બોરવેલ પંપ બંધ ટાંકી ભરાતી નથી", "water_motor_failure", "Water Motor (Gujarati)"),
    ("એસી કૂલિંગ નથી કરતું કોમ્પ્રેસર ચાલુ નથી ગેસ લીક ગરમ હવા", "ac_cooling_failure", "AC Cooling (Gujarati)"),
    ("ગીઝર ગરમ પાણી નથી આપતું વોટર હીટર ખરાબ માત્ર ઠંડું પાણી", "geyser_heating_issue", "Geyser (Gujarati)"),
    ("ફ્રિજ ઠંડુ થતું નથી અંદરનું ખાવાનું બગડે છે કોમ્પ્રેસર અવાજ", "refrigerator_cooling_issue", "Fridge (Gujarati)"),
    ("કિચન સિંક જામ થઈ ગયું છે પાણી નીકળતું નથી ગટર વાસ", "drain_block_sewerage", "Drain (Gujarati)"),

    # ── Kannada (ಕನ್ನಡ) ──
    ("ಮೋಟರ್ ಓಡ್ತಿದೆ ಆದ್ರೆ ನೀರು ಬರ್ತಿಲ್ಲ ಬೋರ್‌ವೆಲ್ ಪಂಪ್ ಕೆಟ್ಟಿದೆ ಟ್ಯಾಂಕ್ ತುಂಬ್ತಿಲ್ಲ", "water_motor_failure", "Water Motor (Kannada)"),
    ("ಎಸಿ ಕೂಲಿಂಗ್ ಆಗ್ತಿಲ್ಲ ಕಂಪ್ರೆಸರ್ ಆನ್ ಆಗ್ತಿಲ್ಲ ಗ್ಯಾಸ್ ಲೀಕ್ ಬಿಸಿ ಗಾಳಿ", "ac_cooling_failure", "AC Cooling (Kannada)"),
    ("ಇನ್ವರ್ಟರ್ ಬೀಪ್ ಆಗ್ತಿದೆ ಬ್ಯಾಟರಿ ಚಾರ್ಜ್ ಇಲ್ಲ ಕರೆಂಟ್ ಹೋದಾಗ ಬ್ಯಾಕಪ್ ಇಲ್ಲ", "inverter_backup_failure", "Inverter (Kannada)"),
    ("ವಾಷಿಂಗ್ ಮಷಿನ್ ಸ್ಪಿನ್ ಆಗ್ತಿಲ್ಲ ನೀರು ಹೊರಹೋಗ್ತಿಲ್ಲ ಎರರ್ ಕೋಡ್", "washing_machine_fault", "WM (Kannada)"),
    ("ಸೀಲಿಂಗ್ ಫ್ಯಾನ್ ತುಂಬಾ ನಿಧಾನವಾಗಿ ತಿರುಗುತ್ತಿದೆ ಕೆಪಾಸಿಟರ್ ಹೋಗಿದೆ ಗುಂಯ್ ಶಬ್ದ", "fan_repair_issue", "Fan (Kannada)"),

    # ── Malayalam (മലയാളം) ──
    ("മോട്ടോർ ഓടുന്നുണ്ട് പക്ഷേ വെള്ളം വരുന്നില്ല ബോർവെൽ പമ്പ് നിന്നു ടാങ്ക് നിറയുന്നില്ല", "water_motor_failure", "Water Motor (Malayalam)"),
    ("എസി തണുപ്പിക്കുന്നില്ല കംപ്രസ്സർ ഓൺ ആകുന്നില്ല ഗ്യാസ് ലീക്ക് ചൂട് കാറ്റ്", "ac_cooling_failure", "AC Cooling (Malayalam)"),
    ("ഗീസർ ഓൺ ആണ് പക്ഷേ ചൂടുവെള്ളം വരുന്നില്ല വാട്ടർ ഹീറ്റർ കേടായി", "geyser_heating_issue", "Geyser (Malayalam)"),
    ("ഫ്രിഡ്ജ് തണുക്കുന്നില്ല ഭക്ഷണം കേടാകുന്നു ഐസ് കട്ടപിടിക്കുന്നില്ല", "refrigerator_cooling_issue", "Fridge (Malayalam)"),
    ("ബാത്ത്റൂം ടൈലുകളിൽ കടുത്ത മഞ്ഞ കറ ഉപ്പ് പാടുകൾ ഡീപ് ക്ലീനിംഗ്", "deep_cleaning_sanitization", "Deep Clean (Malayalam)"),

    # ── Punjabi (ਪੰਜਾਬੀ) ──
    ("ਮੋਟਰ ਚੱਲ ਰਹੀ ਹੈ ਪਰ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ ਬੋਰਵੈੱਲ ਪੰਪ ਖ਼ਰਾਬ ਟੈਂਕੀ ਨਹੀਂ ਭਰਦੀ", "water_motor_failure", "Water Motor (Punjabi)"),
    ("ਏਸੀ ਕੂਲਿੰਗ ਨਹੀਂ ਕਰ ਰਿਹਾ ਕੰਪ੍ਰੈਸਰ ਚਾਲੂ ਨਹੀਂ ਹੁੰਦਾ ਗੈਸ ਲੀਕ ਗਰਮ ਹਵਾ", "ac_cooling_failure", "AC Cooling (Punjabi)"),
    ("ਐਮਸੀਬੀ ਵਾਰ ਵਾਰ ਟ੍ਰਿਪ ਹੋ ਰਿਹਾ ਸਵਿੱਚਬੋਰਡ ਚੰਗਿਆੜੀਆਂ ਸੜਨ ਦੀ ਬਦਬੂ", "mcb_tripping_spark", "MCB (Punjabi)"),
    ("ਛੱਤ ਵਾਲਾ ਪੱਖਾ ਬਹੁਤ ਹੌਲੀ ਚੱਲਦਾ ਕਪੈਸਿਟਰ ਸੜ ਗਿਆ ਗੂੰਜਣ ਦੀ ਆਵਾਜ਼", "fan_repair_issue", "Fan (Punjabi)"),
    ("ਕੰਧ ਦਾ ਰੰਗ ਉੱਖੜ ਰਿਹਾ ਹੈ ਸਿੱਲ੍ਹ ਅਤੇ ਲੂਣ ਚੜ੍ਹ ਰਿਹਾ ਵਾਟਰਪਰੂਫਿੰਗ", "wall_dampness_painting", "Wall Dampness (Punjabi)"),

    # ── Odia (ଓଡ଼ିଆ) ──
    ("ମୋଟର ଚାଲୁଛି କିନ୍ତୁ ପାଣି ଆସୁନାହିଁ ବୋରୱେଲ ପମ୍ପ ଖରାପ ଟାଙ୍କି ଭରୁନାହିଁ", "water_motor_failure", "Water Motor (Odia)"),
    ("ଏସି ଥଣ୍ଡା କରୁନାହିଁ କମ୍ପ୍ରେସର ଚାଲୁନାହିଁ ଗ୍ୟାସ ଲିକ୍ ଗରମ ପବନ", "ac_cooling_failure", "AC Cooling (Odia)"),
    ("ଗିଜର ଗରମ ପାଣି ଦେଉନାହିଁ ୱାଟର ହିଟର ଖରାପ ଥଣ୍ଡା ପାଣି ଆସୁଛି", "geyser_heating_issue", "Geyser (Odia)"),
    ("ଇନଭର୍ଟର ବିପ୍ କରୁଛି ବ୍ୟାଟେରୀ ଚାର୍ଜ ହେଉନାହିଁ କରେଣ୍ଟ ଗଲେ ବ୍ୟାକଅପ୍ ନାହିଁ", "inverter_backup_failure", "Inverter (Odia)"),
    ("କାନ୍ଥ ଭିତରେ ପାଇପ୍ ଲିକ୍ ହେଉଛି ଛାତରେ ଓଦା ଦାଗ ପାଣି ଗଳୁଛି", "pipe_leakage_dampness", "Pipe Leak (Odia)"),
]


def patch_and_rewrite():
    """Load catalog, append Option B phrasings, rewrite file."""
    # Dynamic import to get fresh module
    dir_path = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(dir_path)
    for p in (dir_path, parent_dir):
        if p not in sys.path:
            sys.path.insert(0, p)

    mod_name = "export_multilingual_minilm_onnx"
    if mod_name in sys.modules:
        del sys.modules[mod_name]
    mod = importlib.import_module(mod_name)
    CATALOG_ITEMS = mod.CATALOG_ITEMS
    ORIGINAL_TESTS = mod.TEST_CASES[:50]

    matched, missing = 0, []
    for item in CATALOG_ITEMS:
        iid = item["id"]
        if iid in OPTION_B:
            if len(item["texts"]) == 8:
                item["texts"].extend(OPTION_B[iid])
            elif len(item["texts"]) == 15:
                item["texts"] = item["texts"][:8] + OPTION_B[iid]
            matched += 1
        else:
            missing.append(iid)

    if missing:
        print(f"WARNING: No Option B phrasings for: {missing}")

    print(f"\nPatched {matched}/{len(CATALOG_ITEMS)} items")
    print(f"Phrasings per item: {len(CATALOG_ITEMS[0]['texts'])}")
    print(f"Total phrasings: {sum(len(i['texts']) for i in CATALOG_ITEMS)}")

    # Build replacement catalog block
    lines = ["CATALOG_ITEMS = [\n"]
    for idx, item in enumerate(CATALOG_ITEMS, 1):
        lines.append(f"    # {idx}\n")
        lines.append("    {\n")
        lines.append(f'        "id": {json.dumps(item["id"], ensure_ascii=False)},\n')
        lines.append(f'        "equipmentTag": {json.dumps(item["equipmentTag"], ensure_ascii=False)},\n')
        lines.append(f'        "trade": {json.dumps(item["trade"], ensure_ascii=False)},\n')
        lines.append('        "texts": [\n')
        for t in item["texts"]:
            lines.append(f'            {json.dumps(t, ensure_ascii=False)},\n')
        lines.append("        ],\n")
        lines.append("    },\n")
    lines.append("]")
    new_catalog_block = "".join(lines)

    # Build replacement test cases block
    all_tests = ORIGINAL_TESTS + REGIONAL_TEST_CASES
    t_lines = ["TEST_CASES = [\n"]
    for q, exp_id, lbl in all_tests:
        t_lines.append(f'    ({json.dumps(q, ensure_ascii=False)}, {json.dumps(exp_id, ensure_ascii=False)}, {json.dumps(lbl, ensure_ascii=False)}),\n')
    t_lines.append("]")
    new_test_block = "".join(t_lines)

    file_path = os.path.join(dir_path, "export_multilingual_minilm_onnx.py")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    cat_pattern = r"CATALOG_ITEMS = \[.*?\n\]"
    new_content = re.sub(cat_pattern, new_catalog_block, content, flags=re.DOTALL, count=1)
    if new_content == content:
        print("ERROR: Could not find CATALOG_ITEMS block to replace")
        return False

    test_pattern = r"TEST_CASES = \[.*?\n\]"
    final_content = re.sub(test_pattern, new_test_block, new_content, flags=re.DOTALL, count=1)
    if final_content == new_content:
        print("ERROR: Could not find TEST_CASES block to replace")
        return False

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(final_content)
    print(f"\nFile rewritten successfully: {file_path}")
    return True


if __name__ == "__main__":
    print("=" * 72)
    print("  WorkGo Option B — 7 Language Expansion Patch")
    print("  Bengali · Marathi · Gujarati · Kannada · Malayalam · Punjabi · Odia")
    print("=" * 72)
    ok = patch_and_rewrite()
    if not ok:
        sys.exit(1)
    print("\nNext: run  python backend/ml_training/export_multilingual_minilm_onnx.py")
