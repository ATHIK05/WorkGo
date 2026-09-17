import os
import subprocess
from gtts import gTTS

# Target directory in WSL Asterisk
WSL_DIR = r"\\wsl$\Ubuntu\var\lib\asterisk\sounds\workgo"
LOCAL_DIR = os.path.join(os.path.dirname(__file__), "..", "sounds")

os.makedirs(LOCAL_DIR, exist_ok=True)
if os.path.exists(r"\\wsl$\Ubuntu\var\lib\asterisk\sounds"):
    os.makedirs(WSL_DIR, exist_ok=True)

PROMPTS = [
    {
        "name": "welcome_hi",
        "lang": "hi",
        "text": "वर्कगो कार्या में आपका स्वागत है। आपका नंबर दर्ज कर लिया गया है।"
    },
    {
        "name": "ask_trade_hi",
        "lang": "hi",
        "text": "आप क्या काम करते हैं? प्लम्बर के लिए 1 दबाएं, इलेक्ट्रीशियन के लिए 2, कारपेंटर के लिए 3, पेंटर के लिए 4, या अन्य काम के लिए 5 दबाएं।"
    },
    {
        "name": "ask_pincode_hi",
        "lang": "hi",
        "text": "कृपया अपने इलाके का 6 अंकों का पिनकोड डायल करें।"
    },
    {
        "name": "registration_done_hi",
        "lang": "hi",
        "text": "धन्यवाद! आपका पंजीकरण दर्ज हो गया है। एक कार्या मित्र जल्द ही आपसे वेरिफिकेशन के लिए संपर्क करेंगे।"
    },
    {
        "name": "toggle_menu_hi",
        "lang": "hi",
        "text": "ऑनलाइन होने के लिए 1 दबाएं। ऑफलाइन होने के लिए 2 दबाएं।"
    },
    {
        "name": "now_online_hi",
        "lang": "hi",
        "text": "आप अब ऑनलाइन हैं। नया काम आने पर आपको अलर्ट आएगा।"
    },
    {
        "name": "now_offline_hi",
        "lang": "hi",
        "text": "आप अब ऑफलाइन हैं। काम शुरू करने के लिए दोबारा कॉल करें।"
    }
]

print("Synthesizing IVR voice audio files...")
for p in PROMPTS:
    name = p["name"]
    text = p["text"]
    lang = p["lang"]
    
    mp3_path = os.path.join(LOCAL_DIR, f"{name}.mp3")
    wav_path = os.path.join(LOCAL_DIR, f"{name}.wav")
    wsl_wav_path = os.path.join(WSL_DIR, f"{name}.wav")
    
    print(f"Generating: {name} ({lang})...")
    tts = gTTS(text=text, lang=lang, slow=False)
    tts.save(mp3_path)
    
    # Convert MP3 to standard Asterisk telephony WAV (8000Hz, 16-bit, Mono PCM)
    # Using ffmpeg inside WSL or python
    try:
        cmd = f'wsl ffmpeg -y -i "$(wslpath "{mp3_path}")" -ar 8000 -ac 1 -acodec pcm_s16le /var/lib/asterisk/sounds/workgo/{name}.wav'
        subprocess.run(cmd, shell=True, check=True)
        print(f"  -> Converted to Asterisk WAV: /var/lib/asterisk/sounds/workgo/{name}.wav")
    except Exception as e:
        print(f"  -> Conversion note: {e}")

print("Done! All IVR audio files generated.")
