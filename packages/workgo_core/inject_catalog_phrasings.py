# -*- coding: utf-8 -*-
"""
Synchronizes all 675 phrasings from backend/ml_training/output/catalog_items_45.json
into packages/workgo_core/lib/src/models/symptom_catalog.dart.
Preserves all questions, causes, tools, and pricing metadata.
"""
import json
import os
import re
import sys

# Ensure UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE_ROOT = os.path.abspath(os.path.join(BASE_DIR, "..", ".."))

JSON_PATH = os.path.join(WORKSPACE_ROOT, "backend", "ml_training", "output", "catalog_items_45.json")
DART_PATH = os.path.join(BASE_DIR, "lib", "src", "models", "symptom_catalog.dart")

print(f"Loading {JSON_PATH}...")
with open(JSON_PATH, "r", encoding="utf-8") as f:
    catalog_items = json.load(f)

print(f"Loaded {len(catalog_items)} items from JSON.")

# Build map from item ID -> list of 15 phrasings
items_by_id = {item["id"]: item for item in catalog_items}

with open(DART_PATH, "r", encoding="utf-8") as f:
    dart_content = f.read()

# Pattern to find each SymptomItem and its searchTokens block
# Each item starts with const SymptomItem(\n      id: '...'
item_pattern = re.compile(
    r"(const\s+SymptomItem\s*\(\s*id:\s*'([a-z0-9_]+)'.*?searchTokens:\s*\[)(.*?)(\],\s*likelyCauses:)",
    re.DOTALL
)

def escape_dart_str(s: str) -> str:
    # Escape backslashes, single quotes, and dollar signs for Dart strings
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")

matches = list(item_pattern.finditer(dart_content))
print(f"Found {len(matches)} SymptomItem searchTokens blocks in Dart file.")

if len(matches) != 45:
    raise ValueError(f"Expected 45 items in Dart, found {len(matches)}!")

# Multi-script equipment nouns to enrich _equipmentTokens
EQUIPMENT_REGIONAL_NOUNS = {
    'fan_repair_issue': ['পাখা', 'पंखा', 'પંખો', 'ಫ್ಯಾನ್', 'പങ്ക', 'ਪੱਖਾ', 'ଫ୍ୟାନ'],
    'refrigerator_cooling_issue': ['ফ্রিজ', 'फ्रिज', 'રેફ્રિજરેટર', 'ಫ್ರಿಡ್ಜ್', 'ഫ്രിഡ്ജ്', 'ਫਰਿੱਜ', 'ଫ୍ରିଜ'],
    'mixer_grinder_repair': ['মিক্সার', 'ग्राइंडर', 'મિક્સર', 'ಮಿಕ್ಸರ್', 'മിക്സി', 'ਮਿਕਸਰ', 'ମିକସର'],
    'microwave_oven_issue': ['মাইক্রোওয়েভ', 'ओव्हन', 'માઇક્રોવેવ', 'ಮೈಕ್ರೋವೇವ್', 'മൈക്രോവേവ്', 'ਮਾਈਕ੍ਰੋਵੇਵ', 'ମାଇକ୍ରୋୱେଭ'],
    'drain_block_sewerage': ['সিঙ্ক', 'ড্রেন', 'गटर', 'સિંક', 'ಡ್ರೈನೇಜ್', 'ഡ്രെയിൻ', 'ਡਰੇਨ', 'ଡ୍ରେନ'],
    'door_lock_woodwork': ['দরজা', 'লক', 'दरवाजा', 'कुलूप', 'દરવાજો', 'ಬಾಗಿಲು', 'ലോക്ക്', 'ਵਾਡਰੋਬ', 'କବାଟ'],
    'wall_dampness_painting': ['পেন্টিং', 'রং', 'रंगकाम', 'વોલ પેઇન્ટ', 'ಪೆಂಟಿಂಗ್', 'പെയിന്റിംഗ്', 'ਰੰਗ', 'ରଙ୍ଗ'],
    'deep_cleaning_sanitization': ['ডিপ ক্লিনিং', 'सफाई', 'ડીપ ક્લીનિંગ', 'ಕ್ಲೀನಿಂಗ್', 'ഡീപ് ക്ലീനിംഗ്', 'ਸਫਾਈ', 'ସଫା'],
    'metal_gate_welding': ['ওয়েল্ডিং', 'গ্রিল', 'वेल्डिंग', 'વેલ્ડિંગ', 'ವೆಲ್ಡಿಂಗ್', 'വെൽഡിംഗ്', 'ਵੈਲਡਿੰਗ', 'ୱେଲ୍ଡିଂ'],
    'masonry_tile_plaster_repair': ['টাইলস', 'প্লাস্টার', 'गिलावा', 'ટાઇલ્સ', 'ಪ್ಲಾಸ್ಟರ್', 'ടൈൽ', 'ਟਾਈਲਾਂ', 'ଟାଇଲ୍ସ'],
    'gas_stove_hob_repair': ['গ্যাস ওভেন', 'गॅस शेગડી', 'ગેસ સ્ટવ', 'ಗ್ಯಾಸ್ ಸ್ಟೌವ್', 'ഗ്യാസ് അടുപ്പ്', 'ਗੈਸ ਚੁੱਲ੍ਹਾ', 'ଗ୍ୟାସ ଚୁଲା'],
    'water_motor_failure': ['মোটর', 'পাম্প', 'मोटार', 'पंप', 'મોટર', 'ಮೋಟರ್', 'മോട്ടോർ', 'ਮੋਟਰ', 'ମୋଟର'],
    'inverter_backup_failure': ['ইনভার্টার', 'ব্যাটারি', 'इन्व्हर्टर', 'ઇન્વર્ટર', 'ಇನ್ವರ್ಟರ್', 'ഇൻവർട്ടർ', 'ਇਨਵਰਟਰ', 'ଇନଭର୍ଟର'],
    'geyser_heating_issue': ['গিজার', 'হিটার', 'गिझर', 'ગીઝર', 'ಗೀಜರ್', 'ഗീസർ', 'ਗੀਜ਼ਰ', 'ଗିଜର'],
    'ac_cooling_failure': ['এসি', 'কম্প্রেসার', 'एसी', 'એસી', 'ಎಸಿ', 'എസി', 'ਏਸੀ', 'ଏସି'],
    'mcb_tripping_spark': ['এমসিবি', 'সুইচবোর্ড', 'एमसीबी', 'स्विचबोर्ड', 'એમસીબી', 'ಸ್ವಿಚ್‌ಬೋರ್ಡ್', 'എംസിബി', 'ਐਮਸੀਬੀ', 'ଏମସିବି'],
    'pipe_leakage_dampness': ['পাইপ লিক', 'নল', 'पाईप गळती', 'પાણીની પાઇપ', 'ಪೈಪ್ ಲೀಕ್', 'പൈപ്പ് ചോർച്ച', 'ਪਾਈਪ ਲੀਕ', 'ପାଇପ୍ ଲିକ୍'],
    'ro_purifier_issue': ['আরও', 'পিউরিফায়ার', 'प्युरिफायर', 'પ્યુરિફાયર', 'ಪ್ಯೂರಿಫೈಯರ್', 'പ്യൂരിഫയർ', 'ਪਿਊਰੀਫਾਇਰ', 'ପ୍ୟୁରିଫାୟର'],
    'washing_machine_fault': ['ওয়াশিং মেশিন', 'वॉशिंग मशीन', 'વોશિંગ મશીન', 'ವಾಷಿಂಗ್ ಮಷಿನ್', 'വാഷിംഗ് മെഷീൻ', 'ਵਾਸ਼ਿੰਗ ਮਸ਼ੀਨ', 'ୱାଶିଂ ମେସିନ'],
    'overhead_tank_overflow': ['ওভারহেড ট্যাঙ্ক', 'छतावरील टाकी', 'ઓવરહેડ ટાંકી', 'ಓವರ್‌ಹೆಡ್ ಟ್ಯಾಂಕ್', 'വാട്ടർ ടാങ്ക്', 'ਓਵਰਫਲੋਅ', 'ଓଭରହେଡ୍ ଟାଙ୍କି'],
    'chimney_exhaust_failure': ['চিমনি', 'चि chimneys', 'ચીમની', 'ಚಿಮಣಿ', 'ചിമ്മിനി', 'ਚਿਮਨੀ', 'ଚିମନି'],
    'induction_kettle_coil_failure': ['ইন্ডাকশন', 'केटली', 'ઇન્ડક્શન', 'ಇಂಡಕ್ಷನ್', 'ഇൻഡക്ഷൻ', 'ਇੰਡਕਸ਼ਨ', 'ଇନଡକ୍ସନ'],
    'dishwasher_drainage_issue': ['ডিশওয়াশার', 'डिशवॉशर', 'ડિશવૉશર', 'ಡಿಶ್‌ವಾಶರ್', 'ഡിഷ്‌വാഷർ', 'ਡਿਸ਼ਵਾਸ਼ਰ', 'ଡିସୱାସର'],
    'solar_water_heater_issue': ['সোলার গিজার', 'सोलर हिटर', 'સોલર વોટર હીટર', 'ಸೋಲಾರ್ ಹೀಟರ್', 'സോളാർ ഹീറ്റർ', 'ਸੋਲਰ ਹੀਟਰ', 'ସୋଲାର ହିଟର'],
    'smart_doorbell_cctv_fault': ['সিসিটিভি', 'डोरबेल', 'સીસીટીવી', 'ಸಿ yarnಿಟಿವಿ', 'സിസിടിവി', 'ਸੀਸੀਟੀਵੀ', 'ସିସିଟିଭି'],
    'sliding_window_roller_glass': ['স্লাইডিং উইন্ডো', 'सरकती खिडकी', 'સ્લાઇડિંગ બારી', 'ಸ್ಲೈಡಿಂಗ್ ಕಿಟಕಿ', 'സ്ലൈഡിംഗ് ജനൽ', 'ਸਲਾਈਡਿੰਗ ਖਿੜਕੀ', 'ସ୍ଲାଇଡିଂ ଝରକା'],
    'bathroom_tile_grouting_seepage': ['গ্রাফটিং', 'ग्राउटिंग', 'ગ્રાઉટિંગ', 'ಗ್ರೌಟಿಂಗ್', 'ഗ്രൗട്ടിംഗ്', 'ਗ੍ਰਾਉਟਿੰਗ', 'ଗ୍ରାଉଟିଙ୍ଗ'],
    'wood_termite_damage': ['উইপোকা', 'वाळवी', 'ઉધઈ', 'ಗೆದ್ದಲು', 'ചിതൽ', 'ਸਿਉਂਕ', 'ଉଇ'],
    'balcony_pulley_wire_snap': ['পুলির তার', 'कपडे सुकवण्याची पुली', 'કપડાં સુકવવાની પુલી', 'ಪುಲ್ಲಿ ವೈರ್', 'പുള്ളി വയർ', 'ਪੁਲੀ', 'ପୁଲି ତାର'],
    'desert_cooler_repair': ['এয়ার কুলার', 'कूलर', 'કૂલર', 'ಕೂಲರ್', 'കൂളർ', 'ਕੂਲਰ', 'କୁଲର'],
    'ac_service_gas_recharge': ['এসি গ্যাস', 'एसी गॅस', 'એસી ગેસ રિચાર્જ', 'ಎಸಿ ಗ್ಯಾಸ್', 'എസി ഗ്യാസ്', 'ਏਸੀ ਗੈਸ', 'ଏସି ଗ୍ୟାସ'],
    'tv_wall_mounting': ['টিভি মাউন্টিং', 'टीव्ही माउंट', 'ટીવી ફિટિંગ', 'ಟಿವಿ ಮೌಂಟಿಂಗ್', 'ടിവി മൗണ്ടിംഗ്', 'ਟੀਵੀ ਮਾਊਂਟਿੰਗ', 'ଟିଭି ମାଉଣ୍ଟିଙ୍ଗ'],
    'led_panel_light_installation': ['এলইডি লাইট', 'एलईडी दिवा', 'એલઇડી લાઇટ', 'ಎಲ್‌ಇಡಿ ಲೈಟ್', 'എൽഇഡി ലൈറ്റ്', 'ਐਲਈਡੀ ਲਾਈਟ', 'ଏଲଇଡି ଲାଇଟ'],
    'pest_control_treatment': ['পোকামাকড় দমন', 'कीटक नियंत्रण', 'પેસ્ટ કંટ્રોલ', 'ಕೀಟ ನಿಯಂತ್ರಣ', 'കീടനിയന്ത്രണം', 'ਕੀਟ ਨਿਯੰਤਰਣ', 'ପୋକ ନିୟନ୍ତ୍ରଣ'],
    'water_tank_cleaning': ['ট্যাঙ্ক পরিষ্কার', 'टाकी स्वच्छता', 'ટાંકી સફાઈ', 'ಟ್ಯಾಂಕ್ ಸ್ವಚ್ಛತೆ', 'ടാങ്ക് ക്ലീനിംഗ്', 'ਟੈਂਕੀ ਸਫਾਈ', 'ଟାଙ୍କି ସଫା'],
    'curtain_blind_mounting': ['পর্দা', 'पडदे', 'પડદા ફિટિંગ', 'ಕರ್ಟನ್ ರಾಡ್', 'കർട്ടൻ റോഡ്', 'ਪਰਦੇ', 'ପରଦା'],
    'air_purifier_issue': ['এয়ার পিউরিফায়ার', 'हवा शुद्धीकरण', 'એર પ્યુરિફાયર', 'ಏರ್ ಪ್ಯೂರಿಫೈಯರ್', 'എയർ പ്യൂരിഫയർ', 'ਏਅਰ ਪਿਊਰੀਫਾਇਰ', 'ଏୟାର ପ୍ୟୁରିଫାୟର'],
    'treadmill_gym_equipment': ['ট্রেডমিল', 'ट्रेडमिल', 'ટ્રેડમિલ', 'ಟ್ರೆಡ್‌ಮಿಲ್', 'ട്രെഡ്മിൽ', 'ਟ੍ਰੈਡਮਿੱਲ', 'ଟ୍ରେଡମିଲ'],
    'exhaust_fan_repair': ['এক্সহস্ট ফ্যান', 'एक्झॉस्ट फॅन', 'એક્ઝોસ્ટ ફેન', 'ಎಕ್ಸಾಸ್ಟ್ ಫ್ಯಾನ್', 'എക്‌സ്‌ഹോസ്റ്റ് ഫാൻ', 'ਐਗਜ਼ੌਸਟ ਫੈਨ', 'ଏକଜଷ୍ଟ ଫ୍ୟାନ'],
    'furniture_sofa_polish_repair': ['সোফা মেরামত', 'सोफा दुरुस्ती', 'સોફા રિપેર', 'ಸೋಫಾ ರಿಪೇರಿ', 'സോഫ റിപ്പയർ', 'ਸੋਫਾ ਮੁਰੰਮਤ', 'ସୋଫା ମରାମତି'],
    'water_softener_issue': ['ওয়াটার সফটনার', 'वॉटर सॉफ्टनर', 'વોટર સોફ્ટનર', 'ವಾಟರ್ ಸಾಫ್ಟ್ನರ್', 'വാട്ടർ സോഫ്റ്റനർ', 'ਵਾਟਰ ਸਾਫਟਨਰ', 'ୱାଟର ସଫ୍ଟନର'],
    'security_alarm_system': ['নিরাপত্তা অ্যালার্ম', 'सुरक्षा गजर', 'સિક્યોરિટી એલાર્મ', 'ಸೆಕ್ಯುರಿಟಿ ಅಲಾರಾಂ', 'സെക്യൂരിറ്റി അലാറം', 'ਸੁਰੱਖਿਆ ਅਲਾਰਮ', 'ସୁରକ୍ଷା ଆଲାର୍ମ'],
    'floor_polishing_epoxy': ['মেঝে পলিশ', 'फरशी पॉलिश', 'ફ્લોર પોલિશિંગ', 'ಫ್ಲೋರ್ ಪಾಲಿಶಿಂಗ್', 'ഫ്ലോർ പോളിഷിംഗ്', 'ਫਰਸ਼ ਪਾਲਿਸ਼', 'ଚଟାଣ ପଲିସିଂ'],
    'generator_dg_set_issue': ['জেনারেটর', 'जनरेटर', 'જનરેટર', 'ಜನರೇಟರ್', 'ജനറേറ്റർ', 'ਜਨਰੇਟਰ', 'ଜେନେରେଟର'],
    'mosquito_mesh_repair': ['মশার নেট', 'डासांची जाळी', 'મચ્છરદાની જાળી', 'ಸೊಳ್ಳೆ ಪರದೆ', 'കൊതുക് വല', 'ਮੱਛਰ ਜਾਲੀ', 'ମଶା ଜାଲି'],
}

# Process each item
def update_item_tokens(item_id, existing_tokens_block):
    # Parse existing tokens (strings between quotes)
    existing_tokens = re.findall(r"'([^']*)'", existing_tokens_block)
    
    # Get 15 phrasings from JSON
    json_item = items_by_id[item_id]
    texts = json_item["texts"] # 15 sentences
    
    # Collect all tokens
    all_tokens = []
    seen = set()
    
    def add_token(t):
        clean = t.strip()
        if clean and clean.lower() not in seen and len(clean) >= 2:
            seen.add(clean.lower())
            all_tokens.append(clean)
            
    # Keep existing core tokens first (short keywords, Tanglish/Hinglish)
    for tok in existing_tokens:
        add_token(tok)
        
    # Add each of the 15 complete sentences
    for sent in texts:
        add_token(sent)
        # Also split each sentence by comma or semicolon to get granular clauses
        clauses = re.split(r"[,;।\n]+", sent)
        for clause in clauses:
            add_token(clause)
            
    # Format Dart searchTokens block
    lines = ["\n"]
    for t in all_tokens:
        lines.append(f"        '{escape_dart_str(t)}',\n")
    lines.append("      ")
    return "".join(lines)

# Reconstruct dart file
output_parts = []
last_end = 0

for m in matches:
    prefix = m.group(1)
    item_id = m.group(2)
    old_tokens = m.group(3)
    suffix = m.group(4)
    
    new_tokens = update_item_tokens(item_id, old_tokens)
    
    # Append unreplaced content up to match start
    output_parts.append(dart_content[last_end:m.start()])
    output_parts.append(prefix)
    output_parts.append(new_tokens)
    output_parts.append(suffix)
    last_end = m.end()

output_parts.append(dart_content[last_end:])
updated_dart = "".join(output_parts)

# Now update _equipmentTokens with regional nouns
for equip_id, nouns in EQUIPMENT_REGIONAL_NOUNS.items():
    # Find the line in _equipmentTokens for this equip_id
    pattern = rf"('{equip_id}':\s*\[)(.*?)(\],)"
    eq_match = re.search(pattern, updated_dart)
    if eq_match:
        existing_eq = re.findall(r"'([^']*)'", eq_match.group(2))
        combined_eq = []
        eq_seen = set()
        for x in existing_eq:
            if x not in eq_seen:
                eq_seen.add(x)
                combined_eq.append(x)
        for noun in nouns:
            if noun not in eq_seen:
                eq_seen.add(noun)
                combined_eq.append(noun)
        new_eq_str = ", ".join(f"'{escape_dart_str(x)}'" for x in combined_eq)
        replacement = f"'{equip_id}': [{new_eq_str}],"
        updated_dart = updated_dart[:eq_match.start()] + replacement + updated_dart[eq_match.end():]

print(f"Original size: {len(dart_content)} chars")
print(f"Updated size:  {len(updated_dart)} chars")

with open(DART_PATH, "w", encoding="utf-8") as f:
    f.write(updated_dart)

print(f"Successfully updated {DART_PATH} with all 675 phrasings + regional equipment tokens!")
