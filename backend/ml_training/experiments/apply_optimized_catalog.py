# -*- coding: utf-8 -*-
"""
Apply Optimized 15-Slot Phrasings (675 Total) to export_multilingual_minilm_onnx.py
and execute full production export.
"""
import sys, os, json, re

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Load optimized texts
state_path = os.path.join(os.path.dirname(__file__), "auto_solve_state.json")
with open(state_path, "r", encoding="utf-8") as f:
    optimized_catalog = json.load(f)

export_py_path = os.path.join(os.path.dirname(__file__), "export_multilingual_minilm_onnx.py")
with open(export_py_path, "r", encoding="utf-8") as f:
    content = f.read()

# Verify that all 45 items exist
import export_multilingual_minilm_onnx as exp
for item in exp.CATALOG_ITEMS:
    cid = item["id"]
    assert cid in optimized_catalog, f"Missing {cid} in optimized catalog!"
    assert len(optimized_catalog[cid]) == 15, f"{cid} does not have 15 phrasings!"
    item["texts"] = optimized_catalog[cid]

print(f"Verified all 45 catalog items have 15 slots ({sum(len(i['texts']) for i in exp.CATALOG_ITEMS)} phrasings total).")

# Update CATALOG_ITEMS directly in export_multilingual_minilm_onnx.py
# Format CATALOG_ITEMS cleanly as valid Python code
catalog_code_lines = ["CATALOG_ITEMS = ["]
for idx, item in enumerate(exp.CATALOG_ITEMS, 1):
    catalog_code_lines.append(f"    # {idx}")
    catalog_code_lines.append("    {")
    catalog_code_lines.append(f'        "id": {json.dumps(item["id"])},')
    catalog_code_lines.append(f'        "equipmentTag": {json.dumps(item["equipmentTag"])},')
    catalog_code_lines.append(f'        "trade": {json.dumps(item["trade"])},')
    catalog_code_lines.append('        "texts": [')
    for t in item["texts"]:
        catalog_code_lines.append(f"            {json.dumps(t, ensure_ascii=False)},")
    catalog_code_lines.append("        ],")
    catalog_code_lines.append("    },")
catalog_code_lines.append("]")
new_catalog_code = "\n".join(catalog_code_lines)

# Replace the CATALOG_ITEMS = [...] block in export_multilingual_minilm_onnx.py
pattern = r"CATALOG_ITEMS = \[.*?\]\n\n# Cross-lingual benchmark"
match = re.search(pattern, content, re.DOTALL)
if not match:
    # Alternative pattern without exact trailing comment
    pattern = r"CATALOG_ITEMS = \[.*?\n\]\n"
    match = re.search(pattern, content, re.DOTALL)

assert match, "Could not find CATALOG_ITEMS definition block in export script!"
start, end = match.span()

# If the first pattern matched with the trailing comment, preserve the comment
if "Cross-lingual benchmark" in match.group(0):
    replacement = new_catalog_code + "\n\n# Cross-lingual benchmark"
else:
    replacement = new_catalog_code + "\n"

updated_content = content[:start] + replacement + content[end:]

with open(export_py_path, "w", encoding="utf-8") as f:
    f.write(updated_content)

print(f"Successfully committed optimized 15-slot phrasings into {export_py_path}.")
