# -*- coding: utf-8 -*-
"""
Injects onboarding translations into _embeddedTranslations in packages/workgo_core/lib/src/localization/trade_localization.dart
"""

import os
from sync_all_onboarding_22_locales import TRANSLATIONS

TARGET_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib", "src", "localization", "trade_localization.dart")

def main():
    with open(TARGET_FILE, "r", encoding="utf-8") as fp:
        content = fp.read()

    marker = "  \"radar_label\": {\n"
    if marker not in content:
        print("Marker not found!")
        return

    # Check if already injected
    if "\"cat_plumbing\":" in content:
        print("Already injected.")
        return

    # We want to insert our keys right after the radar_label closing brace or right before line 1573
    radar_end = content.find("  },\n};\n\n\n/// Resilient string translation")
    if radar_end == -1:
        radar_end = content.find("  },\n};\n\n/// Resilient string translation")
    if radar_end == -1:
        print("Closing brace marker not found!")
        return

    en_keys = TRANSLATIONS["en"].keys()

    lines = []
    for k in sorted(en_keys):
        lines.append(f'  "{k}": {{')
        for lang_code, trans_map in TRANSLATIONS.items():
            if k in trans_map:
                # Escape quotes and backslashes if needed
                val = trans_map[k].replace('\\', '\\\\').replace('"', '\\"')
                lines.append(f'    "{lang_code}": "{val}",')
        lines.append('  },')

    injected_str = "\n" + "\n".join(lines) + "\n"

    # Insert after radar_label's "  },"
    split_pos = radar_end + len("  },")
    new_content = content[:split_pos] + injected_str + content[split_pos:]

    with open(TARGET_FILE, "w", encoding="utf-8") as fp:
        fp.write(new_content)

    print("Successfully injected all onboarding keys into _embeddedTranslations!")

if __name__ == "__main__":
    main()
