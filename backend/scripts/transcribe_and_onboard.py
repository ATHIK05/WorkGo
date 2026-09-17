#!/usr/bin/env python3
import sys
import os
import json
import base64
import urllib.request
import urllib.error

BHASHINI_USER_ID = os.getenv("BHASHINI_USER_ID", "3b9563b688a74cf081e3497d13ee6db8")
BHASHINI_API_KEY = os.getenv("BHASHINI_API_KEY", "cY10QMJLRMUs7xs4DELjY_HM8pv4vgqUFXJq-IL5bzyomU-553tvYfGWGjk4UnAo")
BHASHINI_PIPELINE_ID = os.getenv("BHASHINI_PIPELINE_ID", "64392f96daac500b55c543d6")
RENDER_BACKEND_URL = os.getenv("RENDER_BACKEND_URL", "https://workgo-api.onrender.com/api/ivr/voice/onboarding")

def transcribe_audio(audio_path, language="hi"):
    """Transcribes an Asterisk WAV audio file using Bhashini Dhruva ASR."""
    if not os.path.exists(audio_path):
        print(f"[ASR] File not found: {audio_path}")
        return ""
    
    file_size = os.path.getsize(audio_path)
    if file_size < 1000:
        print(f"[ASR] Audio file too small/empty ({file_size} bytes): {audio_path}")
        return ""

    try:
        with open(audio_path, "rb") as f:
            audio_base64 = base64.b64encode(f.read()).decode("utf-8")

        # Map language code if needed (Bhashini uses standard codes)
        asr_lang = language if language in ["hi", "ta", "te", "kn", "ml", "bn", "mr", "gu", "pa"] else "en"

        headers = {
            "Content-Type": "application/json",
            "userID": BHASHINI_USER_ID,
            "ulcaApiKey": BHASHINI_API_KEY,
            "Authorization": BHASHINI_API_KEY
        }

        payload = {
            "pipelineTasks": [{
                "taskType": "asr",
                "config": {
                    "language": {"sourceLanguage": asr_lang},
                    "serviceId": "",
                    "audioFormat": "wav",
                    "samplingRate": 8000
                }
            }],
            "inputData": {
                "audio": [{"audioContent": audio_base64}]
            }
        }

        url = f"https://dhruva-api.bhashini.gov.in/services/inference/pipeline?pipelineId={BHASHINI_PIPELINE_ID}"
        req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            outputs = data.get("pipelineResponse", [{}])[0].get("output", [])
            transcript = outputs[0].get("source", "") if outputs else ""
            print(f"[ASR] Success ({asr_lang}) for {audio_path}: \"{transcript}\"")
            return transcript.strip()

    except Exception as e:
        print(f"[ASR] Error transcribing {audio_path}: {e}")
        return ""

def detect_trade(description_text):
    """Detects primary trade category from user description across languages."""
    lower = description_text.lower()
    
    if any(w in lower for w in ["plumb", "pipe", "leak", "tap", "वाटर", "नल", "குழாய்", "ப்ளம்பர்", "நீர்"]):
        return "plumbing"
    if any(w in lower for w in ["electr", "wire", "switch", "light", "करंट", "बिजली", "மின்னியல்", "எலக்ட்ரீஷியன்"]):
        return "electrical"
    if any(w in lower for w in ["carpent", "wood", "door", "furniture", "लकड़ी", "बढ़ई", "மரவேலை", "தச்சர்"]):
        return "carpentry"
    if any(w in lower for w in ["paint", "color", "wall", "पुट्टी", "रंग", "பெயிண்டிங்", "வர்ணம்"]):
        return "painting"
    if any(w in lower for w in ["clean", "sweep", "housekeep", "झाड़ू", "सफाई", "சுத்தம்"]):
        return "cleaning"
    if any(w in lower for w in ["drive", "driver", "car", "गाड़ी", "ड्राइवर", "ஓட்டுநர்"]):
        return "driving"
    if any(w in lower for w in ["mason", "brick", "cement", "राजमिस्त्री", "கொத்தனார்"]):
        return "masonry"
    
    return "general"

def main():
    if len(sys.argv) < 5:
        print("Usage: transcribe_and_onboard.py <caller> <lang> <pincode> <file_prefix>")
        sys.exit(1)

    caller = sys.argv[1].strip()
    language = sys.argv[2].strip() or "en"
    pincode = sys.argv[3].strip()
    file_prefix = sys.argv[4].strip()

    name_wav = f"{file_prefix}_name.wav"
    loc_wav = f"{file_prefix}_location.wav"
    trade_wav = f"{file_prefix}_trade.wav"

    print(f"\n==================================================")
    print(f"[WorkGo IVR] Processing Voice Onboarding for {caller}")
    print(f"  Language : {language}")
    print(f"  Pincode  : {pincode}")
    print(f"  Prefix   : {file_prefix}")
    print(f"==================================================")

    # 1. Transcribe Name
    worker_name = transcribe_audio(name_wav, language)
    if not worker_name:
        worker_name = f"Artisan ({caller[-4:] if len(caller) >= 4 else caller})"

    # 2. Transcribe Location
    location_text = transcribe_audio(loc_wav, language)

    # 3. Transcribe Trade & Detailed Description
    trade_description = transcribe_audio(trade_wav, language)
    trade_category = detect_trade(trade_description)

    print(f"  Transcribed Name     : {worker_name}")
    print(f"  Transcribed Location : {location_text}")
    print(f"  Detected Category    : {trade_category}")
    print(f"  Skills Description   : {trade_description}")

    # 4. Dispatch to Render Backend
    payload = {
        "caller": caller,
        "name": worker_name,
        "trade": trade_category,
        "tradeText": trade_category,
        "tradeDescription": trade_description,
        "locationText": location_text,
        "pincode": pincode,
        "language": language
    }

    req = urllib.request.Request(
        RENDER_BACKEND_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            print(f"[WorkGo IVR] Onboarding Saved Successfully: {result}")
            with open("/tmp/workgo_onboard.log", "w", encoding="utf-8") as log:
                json.dump(result, log)
    except Exception as e:
        print(f"[WorkGo IVR] Failed to post to cloud backend: {e}")
        with open("/tmp/workgo_onboard.log", "w", encoding="utf-8") as log:
            log.write(f"ERROR: {e}")

if __name__ == "__main__":
    main()
