"use strict";

/**
 * WorkGo Bhashini Voice Service
 * Bridges Bhashini Dhruva ASR (Speech-to-Text) and TTS (Text-to-Speech)
 * pipelines specifically for telephony audio streams (8kHz μ-law / PCM WAV).
 *
 * Used by:
 *   - ivr_voice.js (inbound onboarding calls, online/offline toggle)
 *   - voice_call_engine.js (outbound robocall booking alerts)
 *
 * Credentials (set in backend .env):
 *   BHASHINI_USER_ID      — from bhashini.gov.in API Keys page (User ID field)
 *   BHASHINI_API_KEY      — "Inference" key from bhashini.gov.in API Keys page
 *   BHASHINI_PIPELINE_ID  — Dhruva pipeline ID (default: 64392f96daac500b55c543d6)
 */

const https = require("https");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function toWslPath(windowsFilePath) {
  if (!windowsFilePath) return "";
  let norm = windowsFilePath.replace(/\\/g, "/");
  if (norm.startsWith("/mnt/")) return norm;
  const m = norm.match(/^([A-Za-z]):\/(.*)/);
  if (m) {
    return `/mnt/${m[1].toLowerCase()}/${m[2]}`;
  }
  const m2 = norm.match(/^\/([A-Za-z])\/(.*)/);
  if (m2) {
    return `/mnt/${m2[1].toLowerCase()}/${m2[2]}`;
  }
  return norm;
}

const BHASHINI_BASE = "dhruva-api.bhashini.gov.in";
const BHASHINI_PIPELINE_PATH = "/services/inference/pipeline";
const BHASHINI_TIMEOUT_MS = 8000;

// Default Dhruva pipeline ID supporting ASR + TTS for Indian languages
const DEFAULT_PIPELINE_ID =
  process.env.BHASHINI_PIPELINE_ID || "64392f96daac500b55c543d6";

/**
 * Raw HTTPS POST — avoids extra npm dependencies.
 */
function httpsPost(hostname, path, headers, body, timeoutMs = BHASHINI_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const payload = typeof body === "string" ? body : JSON.stringify(body);
    const req = https.request(
      {
        hostname,
        path,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
          ...headers,
        },
      },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(raw) });
          } catch {
            reject(new Error(`Non-JSON response (HTTP ${res.statusCode}): ${raw.slice(0, 300)}`));
          }
        });
      }
    );
    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error("Bhashini API timeout"));
    });
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

/**
 * Build Bhashini auth headers from environment.
 */
function getBhashiniHeaders() {
  const userId = process.env.BHASHINI_USER_ID;
  const apiKey = process.env.BHASHINI_API_KEY;
  if (!userId || !apiKey) {
    throw new Error(
      "BHASHINI_USER_ID and BHASHINI_API_KEY must be set in .env"
    );
  }
  return {
    userID: userId,
    ulcaApiKey: apiKey,
    Authorization: apiKey,
  };
}

// ── ASR: Speech-to-Text ───────────────────────────────────────────────────────

/**
 * Convert spoken audio (base64-encoded WAV/PCM) to text using Bhashini Dhruva ASR.
 *
 * @param {string} audioBase64  - Base64-encoded audio bytes (8kHz or 16kHz, mono WAV)
 * @param {string} language     - BCP-47 language code: 'hi', 'mr', 'ta', 'bn', 'kn', 'te', 'gu', 'pa', 'en'
 * @returns {Promise<string>}   - Transcribed text (empty string on failure)
 */
async function speechToText(audioBase64, language = "hi") {
  try {
    const payload = {
      pipelineTasks: [
        {
          taskType: "asr",
          config: {
            language: { sourceLanguage: language },
            serviceId: "",
            audioFormat: "wav",
            samplingRate: 16000,
          },
        },
      ],
      inputData: {
        audio: [{ audioContent: audioBase64 }],
      },
    };

    const result = await httpsPost(
      BHASHINI_BASE,
      `${BHASHINI_PIPELINE_PATH}?pipelineId=${DEFAULT_PIPELINE_ID}`,
      getBhashiniHeaders(),
      payload
    );

    if (result.status !== 200) {
      console.error("[BhashiniVoice] ASR HTTP error:", result.status, result.body);
      return "";
    }

    const outputList =
      result.body?.pipelineResponse?.[0]?.output ?? [];
    const transcript = outputList[0]?.source ?? "";
    console.log(`[BhashiniVoice] ASR (${language}): "${transcript}"`);
    return transcript.trim();
  } catch (err) {
    console.error("[BhashiniVoice] ASR error:", err.message);
    return "";
  }
}

// ── TTS: Text-to-Speech ───────────────────────────────────────────────────────

/**
 * Convert text to speech audio using Bhashini Dhruva TTS.
 * Returns base64-encoded WAV audio bytes suitable for Asterisk playback.
 *
 * @param {string} text      - Text to speak (in the target language)
 * @param {string} language  - BCP-47 language code: 'hi', 'mr', 'ta', etc.
 * @param {string} gender    - 'male' | 'female'
 * @returns {Promise<string|null>}  - Base64-encoded WAV audio, or null on failure
 */
async function textToSpeech(text, language = "hi", gender = "female") {
  try {
    const payload = {
      pipelineTasks: [
        {
          taskType: "tts",
          config: {
            language: { sourceLanguage: language },
            serviceId: "",
            gender,
            samplingRate: 8000, // 8kHz for telephony compatibility
          },
        },
      ],
      inputData: {
        input: [{ source: text }],
      },
    };

    const result = await httpsPost(
      BHASHINI_BASE,
      `${BHASHINI_PIPELINE_PATH}?pipelineId=${DEFAULT_PIPELINE_ID}`,
      getBhashiniHeaders(),
      payload
    );

    if (result.status !== 200) {
      console.error("[BhashiniVoice] TTS HTTP error:", result.status, result.body);
      return null;
    }

    const audioContent =
      result.body?.pipelineResponse?.[0]?.audio?.[0]?.audioContent ?? null;
    if (!audioContent) {
      console.error("[BhashiniVoice] TTS returned no audio content");
      return null;
    }
    return audioContent;
  } catch (err) {
    console.error("[BhashiniVoice] TTS error:", err.message);
    return null;
  }
}

/**
 * Resolve a writable sounds directory across different environments (Linux, Render, Windows).
 */
function getSoundsDir(customDir) {
  let candidate = customDir;
  if (!candidate || candidate === "/var/lib/asterisk/sounds/workgo") {
    candidate = process.env.ASTERISK_SOUNDS_DIR || path.join(process.cwd(), "sounds");
  }
  // Convert /mnt/<drive>/ paths to Windows drive paths when running on Windows
  if (process.platform === "win32" && typeof candidate === "string" && /^\/mnt\/([a-z])\//i.test(candidate)) {
    const m = candidate.match(/^\/mnt\/([a-z])\/(.*)/i);
    if (m) {
      candidate = `${m[1].toUpperCase()}:\\${m[2].replace(/\//g, "\\")}`;
    }
  }
  const fs = require("fs");
  try {
    if (!fs.existsSync(candidate)) {
      fs.mkdirSync(candidate, { recursive: true });
    }
    return candidate;
  } catch (_) {
    const localDir = path.join(process.cwd(), "sounds");
    try {
      if (!fs.existsSync(localDir)) {
        fs.mkdirSync(localDir, { recursive: true });
      }
      return localDir;
    } catch (_) {
      return require("os").tmpdir();
    }
  }
}

/**
 * Write Bhashini TTS audio to a WAV file on disk for Asterisk Playback().
 * Returns the absolute file path, or null on failure.
 *
 * @param {string} text       - Text to speak
 * @param {string} language   - Language code ('hi', 'mr', 'ta', etc.)
 * @param {string} filename   - Filename without extension (e.g. 'greeting_hi')
 * @param {string} soundsDir  - Asterisk sounds directory (optional)
 * @returns {Promise<string|null>}
 */
async function writeAudioFile(
  text,
  language = "hi",
  filename = "prompt",
  soundsDir = null
) {
  const fs = require("fs");
  const path = require("path");
  const { execSync } = require("child_process");
  const targetDir = getSoundsDir(soundsDir);

  const audioBase64 = await textToSpeech(text, language);
  if (!audioBase64) return null;

  try {
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    // Write raw Bhashini output first (may be IEEE Float)
    const rawPath = path.join(targetDir, `${filename}_raw.wav`);
    const filePath = path.join(targetDir, `${filename}.wav`);
    fs.writeFileSync(rawPath, Buffer.from(audioBase64, "base64"));

    // Transcode to PCM 16-bit 8kHz mono — Asterisk ONLY accepts this format
    // Bhashini TTS often returns IEEE Float 32-bit which Asterisk hard-rejects.
    try {
      const wslRaw = toWslPath(rawPath);
      const wslDest = toWslPath(filePath);
      execSync(
        `wsl -u root ffmpeg -y -i "${wslRaw}" -ar 8000 -ac 1 -acodec pcm_s16le "${wslDest}" -loglevel quiet`,
        { timeout: 15000 }
      );
      // Remove raw file
      try { fs.unlinkSync(rawPath); } catch (_) {}
      console.log(`[BhashiniVoice] Audio written (PCM 8kHz): ${filePath}`);
    } catch (transcodeErr) {
      // ffmpeg not available or failed — use raw file as-is (may not work in Asterisk)
      console.warn(`[BhashiniVoice] ffmpeg transcode failed, using raw output: ${transcodeErr.message}`);
      try { fs.renameSync(rawPath, filePath); } catch (_) {
        fs.writeFileSync(filePath, fs.readFileSync(rawPath));
      }
      console.log(`[BhashiniVoice] Audio written (raw): ${filePath}`);
    }

    return filePath;
  } catch (err) {
    console.error("[BhashiniVoice] File write error:", err.message);
    return null;
  }
}


// ── Pre-baked IVR Prompt Library ──────────────────────────────────────────────

/**
 * Generates and writes all standard IVR audio prompts to Asterisk sounds directory.
 * Call once on backend startup (or on demand) to pre-bake all prompts.
 * Safe to call multiple times — only writes files that don't already exist.
 */
async function prebakeIvrPrompts(soundsDir = null) {
  if (process.env.ENABLE_IVR_PREBAKE !== "true") {
    return;
  }
  const fs = require("fs");
  const path = require("path");
  const targetDir = getSoundsDir(soundsDir);

  // All 10 supported languages: hi, mr, ta, te, kn, ml, bn, gu, pa, en
  const LANGS = [
    { code: "hi", name: "Hindi" },
    { code: "mr", name: "Marathi" },
    { code: "ta", name: "Tamil" },
    { code: "te", name: "Telugu" },
    { code: "kn", name: "Kannada" },
    { code: "ml", name: "Malayalam" },
    { code: "bn", name: "Bengali" },
    { code: "gu", name: "Gujarati" },
    { code: "pa", name: "Punjabi" },
    { code: "en", name: "English" },
  ];

  // Prompt text for each language
  const TEXTS = {
    welcome: {
      hi: "वर्कगो कार्या में आपका स्वागत है। कृपया अपना पूरा नाम बताएं।",
      mr: "वर्कगो कार्यामध्ये आपले स्वागत आहे. कृपया आपले पूर्ण नाव सांगा.",
      ta: "வர்க்கோ கார்யாவில் உங்களை வரவேற்கிறோம். தயவுசெய்து உங்கள் முழு பெயரை சொல்லுங்கள்.",
      te: "వర్క్‌గో కార్యాలో మీకు స్వాగతం. దయచేసి మీ పూర్తి పేరు చెప్పండి.",
      kn: "ವರ್ಕ್‌ಗೋ ಕಾರ್ಯಾಗೆ ಸ್ವಾಗತ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪೂರ್ಣ ಹೆಸರು ಹೇಳಿ.",
      ml: "വർക്ക്‌ഗോ കാര്യയിലേക്ക് സ്വാഗതം. ദയവായി നിങ്ങളുടെ പൂർണ്ണ പേര് പറയൂ.",
      bn: "ওয়ার্কগো কার্যায় আপনাকে স্বাগতম। আপনার পুরো নাম বলুন।",
      gu: "વર્કગો કાર્યામાં આપનું સ્વાગત છે. કૃપા કરીને આપનું પૂરું નામ જણાવો.",
      pa: "ਵਰਕਗੋ ਕਾਰਿਆ ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ। ਕਿਰਪਾ ਕਰਕੇ ਆਪਣਾ ਪੂਰਾ ਨਾਮ ਦੱਸੋ।",
      en: "Welcome to WorkGo Karya. Please say your full name.",
    },
    ask_trade: {
      hi: "आप क्या काम करते हैं? प्लम्बर के लिए 1 दबाएं, इलेक्ट्रीशियन के लिए 2, कारपेंटर के लिए 3, या अपना काम बोलें।",
      mr: "तुम्ही कोणते काम करता? प्लम्बरसाठी 1 दाबा, इलेक्ट्रिशियनसाठी 2, सुताराठी 3, किंवा तुमचे काम सांगा.",
      ta: "நீங்கள் என்ன வேலை செய்கிறீர்கள்? பம்பர் 1, மின்சாரி 2, தச்சர் 3, அல்லது உங்கள் வேலை சொல்லுங்கள்.",
      te: "మీరు ఏ పని చేస్తారు? ప్లంబర్ కు 1, ఎలక్ట్రీషియన్ కు 2, వడ్రంగి కు 3, లేదా మీ పని చెప్పండి.",
      kn: "ನೀವು ಯಾವ ಕೆಲಸ ಮಾಡುತ್ತೀರಿ? ಪ್ಲಂಬರ್ ಗೆ 1, ಎಲೆಕ್ಟ್ರಿಷಿಯನ್ ಗೆ 2, ಮರಗೆಲಸಗಾರ ಗೆ 3, ಅಥವಾ ನಿಮ್ಮ ಕೆಲಸ ಹೇಳಿ.",
      ml: "നിങ്ങൾ എന്ത് ജോലി ചെയ്യുന്നു? പ്ലംബർ 1, ഇലക്ട്രിഷ്യൻ 2, ആശാരി 3, അല്ലെങ്കിൽ നിങ്ങളുടെ ജോലി പറയൂ.",
      bn: "আপনি কী কাজ করেন? প্লাম্বার এর জন্য 1, ইলেকট্রিশিয়ান 2, কাঠমিস্ত্রি 3, বা আপনার কাজ বলুন।",
      gu: "તમે શું કામ કરો છો? પ્લમ્બર માટે 1, ઇલેક્ટ્રિશિયન 2, સુથાર 3, અથવા તમારું કામ કહો.",
      pa: "ਤੁਸੀਂ ਕੀ ਕੰਮ ਕਰਦੇ ਹੋ? ਪਲੰਬਰ ਲਈ 1, ਇਲੈਕਟ੍ਰੀਸ਼ੀਅਨ 2, ਤਰਖਾਣ 3, ਜਾਂ ਆਪਣਾ ਕੰਮ ਦੱਸੋ।",
      en: "What work do you do? Press 1 for plumber, 2 for electrician, 3 for carpenter, or say your trade.",
    },
    ask_pincode: {
      hi: "अपने इलाके का 6 अंकों का पिनकोड डायल करें।",
      mr: "तुमच्या क्षेत्राचा 6 अंकी पिनकोड डायल करा.",
      ta: "உங்கள் பகுதியின் 6 இலக்க பின்கோடை டயல் செய்யுங்கள்.",
      te: "మీ ప్రాంతం యొక్క 6 అంకెల పిన్‌కోడ్ డయల్ చేయండి.",
      kn: "ನಿಮ್ಮ ಪ್ರದೇಶದ 6 ಅಂಕಿ ಪಿನ್‌ಕೋಡ್ ಡಯಲ್ ಮಾಡಿ.",
      ml: "നിങ്ങളുടെ പ്രദേശത്തെ 6 അക്ക പിൻകോഡ് ഡയൽ ചെയ്യൂ.",
      bn: "আপনার এলাকার 6 সংখ্যার পিনকোড ডায়াল করুন।",
      gu: "તમારા વિસ્તારનો 6 અંકનો પિનકોડ ડાયલ કરો.",
      pa: "ਆਪਣੇ ਖੇਤਰ ਦਾ 6 ਅੰਕਾਂ ਦਾ ਪਿਨਕੋਡ ਡਾਇਲ ਕਰੋ।",
      en: "Please dial your area's 6-digit PIN code.",
    },
    registration_done: {
      hi: "आपका पंजीकरण दर्ज हो गया है। एक करिया मित्र जल्द ही आपसे verification के लिए मिलेंगे।",
      mr: "तुमची नोंदणी झाली आहे. एक कार्या मित्र लवकरच पडताळणीसाठी तुम्हाला भेटेल.",
      ta: "உங்கள் பதிவு முடிந்தது. ஒரு காரியா நண்பர் விரைவில் சரிபார்ப்புக்காக உங்களை சந்திப்பார்.",
      te: "మీ నమోదు పూర్తయింది. ఒక కార్య మిత్ర త్వరలో ధృవీకరణ కోసం మీను కలుస్తాడు.",
      kn: "ನಿಮ್ಮ ನೋಂದಣಿ ಆಗಿದೆ. ಒಬ್ಬ ಕಾರ್ಯ ಮಿತ್ರ ಶೀಘ್ರದಲ್ಲೇ ಪರಿಶೀಲನೆಗಾಗಿ ನಿಮ್ಮನ್ನು ಭೇಟಿ ಮಾಡುತ್ತಾರೆ.",
      ml: "നിങ്ങളുടെ രജിസ്ട്രേഷൻ പൂർത്തിയായി. ഒരു കാര്യ മിത്ര ഉടൻ സ്ഥിരീകരണത്തിനായി നിങ്ങളെ കാണും.",
      bn: "আপনার নিবন্ধন সম্পন্ন হয়েছে। একজন কার্য মিত্র শীঘ্রই যাচাইয়ের জন্য আপনার সাথে দেখা করবেন।",
      gu: "તમારી નોંધણી થઈ ગઈ છે. એક કાર્ય મિત્ર ટૂંક સમયમાં ચકાસણી માટે મળશે.",
      pa: "ਤੁਹਾਡੀ ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਹੋ ਗਈ ਹੈ। ਇੱਕ ਕਾਰਿਆ ਮਿੱਤਰ ਜਲਦੀ ਤਸਦੀਕ ਲਈ ਮਿਲੇਗਾ।",
      en: "Your registration is complete. A Karya Mitra will meet you soon for verification.",
    },
    toggle_menu: {
      hi: "ऑनलाइन होने के लिए 1 दबाएं। ऑफलाइन होने के लिए 2 दबाएं।",
      mr: "ऑनलाइन होण्यासाठी 1 दाबा. ऑफलाइन होण्यासाठी 2 दाबा.",
      ta: "ஆன்லைனில் இருக்க 1 அழுத்துங்கள். ஆஃப்லைனில் இருக்க 2 அழுத்துங்கள்.",
      te: "ఆన్‌లైన్ అవడానికి 1 నొక్కండి. ఆఫ్‌లైన్ అవడానికి 2 నొక్కండి.",
      kn: "ಆನ್‌ಲೈನ್ ಆಗಲು 1 ಒತ್ತಿ. ಆಫ್‌ಲೈನ್ ಆಗಲು 2 ಒತ್ತಿ.",
      ml: "ഓൺലൈൻ ആകാൻ 1 അമർത്തൂ. ഓഫ്‌ലൈൻ ആകാൻ 2 അമർത്തൂ.",
      bn: "অনলাইন হতে 1 টিপুন। অফলাইন হতে 2 টিপুন।",
      gu: "ઓનલાઇન થવા 1 દબાવો. ઓફ્લાઇન થવા 2 દબાવો.",
      pa: "ਆਨਲਾਈਨ ਹੋਣ ਲਈ 1 ਦਬਾਓ। ਆਫਲਾਈਨ ਹੋਣ ਲਈ 2 ਦਬਾਓ।",
      en: "Press 1 to go Online. Press 2 to go Offline.",
    },
    now_online: {
      hi: "आप अब ऑनलाइन हैं। नया काम आने पर आपको कॉल आएगा।",
      mr: "तुम्ही आता ऑनलाइन आहात. नवीन काम आल्यावर तुम्हाला कॉल येईल.",
      ta: "நீங்கள் இப்போது ஆன்லைனில் இருக்கிறீர்கள். புதிய வேலை வரும்போது உங்களுக்கு அழைப்பு வரும்.",
      te: "మీరు ఇప్పుడు ఆన్‌లైన్‌లో ఉన్నారు. కొత్త పని వచ్చినప్పుడు మీకు కాల్ వస్తుంది.",
      kn: "ನೀವು ಈಗ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ. ಹೊಸ ಕೆಲಸ ಬಂದಾಗ ನಿಮಗೆ ಕಾಲ್ ಬರುತ್ತದೆ.",
      ml: "നിങ്ങൾ ഇപ്പോൾ ഓൺലൈനിലാണ്. പുതിയ ജോലി വരുമ്പോൾ കാൾ ലഭിക്കും.",
      bn: "আপনি এখন অনলাইনে আছেন। নতুন কাজ এলে আপনাকে কল করা হবে।",
      gu: "તમે હવે ઓનલાઇન છો. નવું કામ આવે ત્યારે ફોન આવશે.",
      pa: "ਤੁਸੀਂ ਹੁਣ ਆਨਲਾਈਨ ਹੋ। ਨਵਾਂ ਕੰਮ ਆਉਣ 'ਤੇ ਕਾਲ ਆਵੇਗੀ।",
      en: "You are now Online. We will call you when a new job arrives.",
    },
    now_offline: {
      hi: "आप अब ऑफलाइन हैं। काम शुरू करने के लिए दोबारा कॉल करें।",
      mr: "तुम्ही आता ऑफलाइन आहात. काम सुरू करण्यासाठी पुन्हा कॉल करा.",
      ta: "நீங்கள் இப்போது ஆஃப்லைனில் இருக்கிறீர்கள். வேலை தொடங்க மீண்டும் அழைக்கவும்.",
      te: "మీరు ఇప్పుడు ఆఫ్‌లైన్‌లో ఉన్నారు. పని ప్రారంభించడానికి మళ్ళీ కాల్ చేయండి.",
      kn: "ನೀವು ಈಗ ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ. ಕೆಲಸ ಶುರು ಮಾಡಲು ಮತ್ತೆ ಕಾಲ್ ಮಾಡಿ.",
      ml: "നിങ്ങൾ ഇപ്പോൾ ഓഫ്‌ലൈനിലാണ്. ജോലി ആരംഭിക്കാൻ വീണ്ടും വിളിക്കൂ.",
      bn: "আপনি এখন অফলাইনে আছেন। কাজ শুরু করতে আবার কল করুন।",
      gu: "તમે હવે ઓફ્લાઇન છો. કામ શરૂ કરવા ફરી ફોન કરો.",
      pa: "ਤੁਸੀਂ ਹੁਣ ਆਫਲਾਈਨ ਹੋ। ਕੰਮ ਸ਼ੁਰੂ ਕਰਨ ਲਈ ਦੁਬਾਰਾ ਕਾਲ ਕਰੋ।",
      en: "You are now Offline. Call again when you want to start working.",
    },
    pending_kyc: {
      hi: "आपका सत्यापन अभी बाकी है। एक करिया मित्र जल्द ही आपसे मिलेंगे।",
      mr: "तुमची पडताळणी अजून बाकी आहे. एक कार्या मित्र लवकरच येईल.",
      ta: "உங்கள் சரிபார்ப்பு இன்னும் நிலுவையில் உள்ளது. ஒரு காரியா நண்பர் விரைவில் வருவார்.",
      te: "మీ ధృవీకరణ ఇంకా పెండింగ్‌లో ఉంది. ఒక కార్య మిత్ర త్వరలో వస్తాడు.",
      kn: "ನಿಮ್ಮ ಪರಿಶೀಲನೆ ಇನ್ನೂ ಬಾಕಿ ಇದೆ. ಒಬ್ಬ ಕಾರ್ಯ ಮಿತ್ರ ಶೀಘ್ರದಲ್ಲೇ ಬರುತ್ತಾರೆ.",
      ml: "നിങ്ങളുടെ സ്ഥിരീകരണം ഇനിയും ബാക്കിയാണ്. ഒരു കാര്യ മിത്ര ഉടൻ വരും.",
      bn: "আপনার যাচাইকরণ এখনও বাকি আছে। একজন কার্য মিত্র শীঘ্রই আসবেন।",
      gu: "તમારી ચકાસણી હજી બાકી છે. એક કાર્ય મિત્ર ટૂંક સમયમાં આવશે.",
      pa: "ਤੁਹਾਡੀ ਤਸਦੀਕ ਅਜੇ ਬਾਕੀ ਹੈ। ਇੱਕ ਕਾਰਿਆ ਮਿੱਤਰ ਜਲਦੀ ਆਵੇਗਾ।",
      en: "Your verification is still pending. A Karya Mitra will visit you soon.",
    },
    booking_confirmed: {
      hi: "बधाई हो! काम आपको मिल गया है। ग्राहक का पता जल्द आपको भेजा जाएगा।",
      mr: "अभिनंदन! काम तुम्हाला मिळाले. ग्राहकाचा पत्ता लवकरच पाठवला जाईल.",
      ta: "வாழ்த்துக்கள்! வேலை உங்களுக்கு கிடைத்தது. வாடிக்கையாளர் முகவரி விரைவில் அனுப்பப்படும்.",
      te: "అభినందనలు! పని మీకు దొరికింది. కస్టమర్ చిరునామా త్వరలో పంపబడుతుంది.",
      kn: "ಅಭಿನಂದನೆಗಳು! ಕೆಲಸ ನಿಮಗೆ ಸಿಕ್ಕಿದೆ. ಗ್ರಾಹಕರ ವಿಳಾಸ ಶೀಘ್ರದಲ್ಲೇ ಕಳಿಸಲಾಗುತ್ತದೆ.",
      ml: "അഭിനന്ദനങ്ങൾ! ജോലി ലഭിച്ചു. ഉടൻ ഉപഭോക്താവിന്റെ വിലാസം ലഭിക്കും.",
      bn: "অভিনন্দন! কাজ আপনি পেয়েছেন। গ্রাহকের ঠিকানা শীঘ্রই পাঠানো হবে।",
      gu: "અભિનંદન! કામ તમને મળ્યું. ગ્રાહકનું સરનામું ટૂંક સમયમાં મોકલવામાં આવશે.",
      pa: "ਵਧਾਈ ਹੋ! ਕੰਮ ਤੁਹਾਨੂੰ ਮਿਲਿਆ। ਗਾਹਕ ਦਾ ਪਤਾ ਜਲਦੀ ਭੇਜਿਆ ਜਾਵੇਗਾ।",
      en: "Congratulations! You got the job. The customer address will be sent to you shortly.",
    },
    booking_declined: {
      hi: "ठीक है। आपने यह काम छोड़ दिया। अगले काम के लिए तैयार रहें।",
      mr: "ठीक आहे. तुम्ही हे काम सोडले. पुढील कामासाठी तयार राहा.",
      ta: "சரி. இந்த வேலையை விட்டுவிட்டீர்கள். அடுத்த வேலைக்கு தயாராக இருங்கள்.",
      te: "సరే. ఈ పనిని వదిలేశారు. తదుపరి పనికి సిద్ధంగా ఉండండి.",
      kn: "ಸರಿ. ಈ ಕೆಲಸ ಬಿಟ್ಟಿದ್ದೀರಿ. ಮುಂದಿನ ಕೆಲಸಕ್ಕೆ ತಯಾರಾಗಿ ಇರಿ.",
      ml: "ശരി. ഈ ജോലി ഒഴിവാക്കി. അടുത്ത ജോലിക്ക് തയ്യാറായിരിക്കൂ.",
      bn: "ঠিক আছে। আপনি এই কাজ ছেড়ে দিয়েছেন। পরবর্তী কাজের জন্য প্রস্তুত থাকুন।",
      gu: "ઠીક છે. તમે આ કામ છોડ્યું. આગળના કામ માટે તૈयार રહો.",
      pa: "ਠੀਕ ਹੈ। ਤੁਸੀਂ ਇਹ ਕੰਮ ਛੱਡ ਦਿੱਤਾ। ਅਗਲੇ ਕੰਮ ਲਈ ਤਿਆਰ ਰਹੋ।",
      en: "OK. You have declined this job. Stay ready for the next one.",
    },
    booking_taken: {
      hi: "यह काम किसी दूसरे आर्टिसन ने ले लिया है। अगले काम के लिए तैयार रहें।",
      mr: "हे काम दुसऱ्या कामगाराने घेतले आहे. पुढील कामासाठी तयार राहा.",
      ta: "இந்த வேலையை வேறொரு தொழிலாளி எடுத்துவிட்டார். அடுத்த வேலைக்கு தயாராக இருங்கள்.",
      te: "ఈ పనిని మరొకరు తీసుకున్నారు. తదుపరి పనికి సిద్ధంగా ఉండండి.",
      kn: "ಈ ಕೆಲಸ ಬೇರೊಬ್ಬರು ತೆಗೆದುಕೊಂಡಿದ್ದಾರೆ. ಮುಂದಿನ ಕೆಲಸಕ್ಕೆ ತಯಾರಾಗಿ ಇರಿ.",
      ml: "ഈ ജോലി മറ്റൊരാൾ എടുത്തു. അടുത്ത ജോലിക്ക് തയ്യാറായിരിക്കൂ.",
      bn: "এই কাজটি অন্য একজন নিয়ে নিয়েছেন। পরবর্তী কাজের জন্য প্রস্তুত থাকুন।",
      gu: "આ કામ બીજા કોઈ એ લઈ લીધું. આગળ ના કામ માટે તૈyaar rahو.",
      pa: "ਇਹ ਕੰਮ ਕਿਸੇ ਹੋਰ ਨੇ ਲੈ ਲਿਆ। ਅਗਲੇ ਕੰਮ ਲਈ ਤਿਆਰ ਰਹੋ।",
      en: "This job was taken by another worker. Stay ready for the next one.",
    },
    booking_cancelled: {
      hi: "ग्राहक ने यह बुकिंग रद्द कर दी है। आप फिर से ऑनलाइन हैं और अगले काम के लिए तैयार रहें।",
      mr: "ग्राहकाने हे बुकिंग रद्द केले आहे. तुम्ही पुन्हा ऑनलाइन आहात आणि पुढील कामासाठी तयार राहा.",
      ta: "வாடிக்கையாளர் இந்த முன்பதிவை ரத்து செய்துவிட்டார். நீங்கள் மீண்டும் ஆன்லைனில் உள்ளீர்கள், அடுத்த வேலைக்கு தயாராக இருங்கள்.",
      te: "కస్టమర్ ఈ బుకింగ్‌ను రద్దు చేశారు. మీరు మళ్లీ ఆన్‌లైన్‌లో ఉన్నారు, తదుపరి పనికి సిద్ధంగా ఉండండి.",
      kn: "ಗ್ರಾಹಕರು ಈ ಬುಕಿಂಗ್ ರದ್ದು ಮಾಡಿದ್ದಾರೆ. ನೀವು ಮತ್ತೆ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ, ಮುಂದಿನ ಕೆಲಸಕ್ಕೆ ತಯಾರಾಗಿ ಇರಿ.",
      ml: "ഉപഭോക്താവ് ഈ ബുക്കിംഗ് റദ്ദാക്കി. നിങ്ങൾ വീണ്ടും ഓൺലൈനിലാണ്, അടുത്ത ജോലിക്ക് തയ്യാറായിരിക്കൂ.",
      bn: "গ্রাহক এই বুকিং বাতিল করেছেন। আপনি আবার অনলাইনে আছেন এবং পরবর্তী কাজের জন্য প্রস্তুত থাকুন।",
      gu: "ગ્રાહકે આ બુકિંગ રદ કર્યું છે. તમે ફરીથી ઓનલાઇન છો અને આગળના કામ માટે તૈયાર રહો.",
      pa: "ਗਾਹਕ ਨੇ ਇਹ ਬੁਕਿੰਗ ਰੱਦ ਕਰ ਦਿੱਤੀ ਹੈ। ਤੁਸੀਂ ਦੁਬਾਰਾ ਆਨਲਾਈਨ ਹੋ ਅਤੇ ਅਗਲੇ ਕੰਮ ਲਈ ਤਿਆਰ ਰਹੋ।",
      en: "The customer has cancelled this booking. You are back online and ready for the next job.",
    },
    online_confirmed: {
      hi: "आप ऑनलाइन हो गए। नया काम आने पर कॉल आएगा।",
      mr: "तुम्ही ऑनलाइन झालात. नवीन काम आल्यावर कॉल येईल.",
      ta: "நீங்கள் ஆன்லைன் ஆனீர்கள். புதிய வேலை வரும்போது அழைப்பு வரும்.",
      te: "మీరు ఆన్‌లైన్ అయ్యారు. కొత్త పని వచ్చినప్పుడు కాల్ వస్తుంది.",
      kn: "ನೀವು ಆನ್‌ಲೈನ್ ಆದಿರಿ. ಹೊಸ ಕೆಲಸ ಬಂದಾಗ ಕಾಲ್ ಬರುತ್ತದೆ.",
      ml: "നിങ്ങൾ ഓൺലൈനായി. പുതിയ ജോലി വരുമ്പോൾ കാൾ ലഭിക്കും.",
      bn: "আপনি অনলাইন হয়েছেন। নতুন কাজ এলে কল আসবে।",
      gu: "તમે ઓનલાઇન થઈ ગયા. નવું કામ આવે ત્યારે ફોન આવશે.",
      pa: "ਤੁਸੀਂ ਆਨਲਾਈਨ ਹੋ ਗਏ। ਨਵਾਂ ਕੰਮ ਆਉਣ 'ਤੇ ਕਾਲ ਆਵੇਗੀ।",
      en: "You are now Online. We will call when a new job arrives.",
    },
    offline_confirmed: {
      hi: "आप ऑफलाइन हो गए। फिर से काम के लिए कॉल करें।",
      mr: "तुम्ही ऑफलाइन झालात. पुन्हा काम करण्यासाठी कॉल करा.",
      ta: "நீங்கள் ஆஃப்லைன் ஆனீர்கள். மீண்டும் வேலை செய்ய அழைக்கவும்.",
      te: "మీరు ఆఫ్‌లైన్ అయ్యారు. మళ్ళీ పని చేయడానికి కాల్ చేయండి.",
      kn: "ನೀವು ಆಫ್‌ಲೈನ್ ಆದಿರಿ. ಮತ್ತೆ ಕೆಲಸ ಮಾಡಲು ಕಾಲ್ ಮಾಡಿ.",
      ml: "നിങ്ങൾ ഓഫ്‌ലൈനായി. വീണ്ടും ജോലി ചെയ്യാൻ വിളിക്കൂ.",
      bn: "আপনি অফলাইন হয়েছেন। আবার কাজ করতে কল করুন।",
      gu: "તમે ઓફ્લાઇન થઈ ગયા. ફરી કામ કરવા ફોન કરો.",
      pa: "ਤੁਸੀਂ ਆਫਲਾਈਨ ਹੋ ਗਏ। ਦੁਬਾਰਾ ਕੰਮ ਕਰਨ ਲਈ ਕਾਲ ਕਰੋ।",
      en: "You are now Offline. Call again when you want to work.",
    },
  };

  // Build full prompt list for all languages
  const prompts = [];
  for (const lang of LANGS) {
    const L = lang.code;
    for (const [key, texts] of Object.entries(TEXTS)) {
      const text = texts[L];
      if (text) {
        prompts.push({ file: `${key}_${L}`, lang: L, text });
      }
    }
  }

  let generated = 0;
  for (const p of prompts) {
    const filePath = path.join(targetDir, `${p.file}.wav`);
    if (!fs.existsSync(filePath)) {
      const result = await writeAudioFile(p.text, p.lang, p.file, targetDir);
      if (result) generated++;
    }
  }
  console.log(`[BhashiniVoice] Pre-baked ${generated} new IVR prompt(s) for ${LANGS.length} languages.`);
}

/**
 * Generate a dynamic booking alert audio file for a specific booking.
 * File is named booking_{bookingId}.wav and stored in Asterisk sounds dir.
 *
 * @param {object} opts
 * @param {string} opts.bookingId
 * @param {string} opts.trade      - e.g. "Plumber"
 * @param {string} opts.address    - e.g. "Flat 402, Green Park"
 * @param {number} opts.payout     - e.g. 350
 * @param {string} opts.language   - 'hi' | 'mr' | 'ta'
 * @param {string} opts.soundsDir
 * @returns {Promise<string|null>} - Path to generated wav file
 */
async function generateBookingAlertAudio({
  bookingId,
  trade = "काम",
  address = "",
  payout = 0,
  language = "hi",
  soundsDir = "/var/lib/asterisk/sounds/workgo",
}) {
  // Booking alert text in all 10 supported languages
  const texts = {
    hi: `वर्कगो अलर्ट! नया ${trade} का काम। ${address}। पेआउट ₹${payout}। यह काम लेने के लिए 1 दबाएं। छोड़ने के लिए 2 दबाएं।`,
    mr: `वर्कगो अलर्ट! नवीन ${trade} काम. ${address}. पेआउट ₹${payout}. हे काम घेण्यासाठी 1 दाबा. सोडण्यासाठी 2 दाबा.`,
    ta: `வர்க்கோ அலர்ட்! புதிய ${trade} வேலை. ${address}. கட்டணம் ₹${payout}. வேலை எடுக்க 1 அழுத்துங்கள். விட 2 அழுத்துங்கள்.`,
    te: `వర్క్‌గో అలర్ట్! కొత్త ${trade} పని. ${address}. చెల్లింపు ₹${payout}. ఈ పని తీసుకోవడానికి 1 నొక్కండి. వదిలేయడానికి 2 నొక్కండి.`,
    kn: `ವರ್ಕ್‌ಗೋ ಅಲರ್ಟ್! ಹೊಸ ${trade} ಕೆಲಸ. ${address}. ಪಾವತಿ ₹${payout}. ಕೆಲಸ ತೆಗೆದುಕೊಳ್ಳಲು 1 ಒತ್ತಿ. ಬಿಡಲು 2 ಒತ್ತಿ.`,
    ml: `വർക്ക്‌ഗോ അലർട്ട്! പുതിയ ${trade} ജോലി. ${address}. പ്രതിഫലം ₹${payout}. ജോലി എടുക്കാൻ 1 അമർത്തൂ. ഒഴിവാക്കാൻ 2 അമർത്തൂ.`,
    bn: `ওয়ার্কগো অ্যালার্ট! নতুন ${trade} কাজ। ${address}। পেমেন্ট ₹${payout}। কাজ নিতে 1 চাপুন। ছেড়ে দিতে 2 চাপুন।`,
    gu: `વર્કગો અlert! નવું ${trade} કામ. ${address}. ચૂકવણી ₹${payout}. કામ લેવા 1 દبाव. છોડવા 2 दबाव.`,
    pa: `ਵਰਕਗੋ ਅਲਰਟ! ਨਵਾਂ ${trade} ਕੰਮ। ${address}। ਭੁਗਤਾਨ ₹${payout}। ਕੰਮ ਲੈਣ ਲਈ 1 ਦਬਾਓ। ਛੱਡਣ ਲਈ 2 ਦਬਾਓ।`,
    en: `WorkGo Alert! New ${trade} job. ${address}. Payout Rupees ${payout}. Press 1 to accept. Press 2 to decline.`,
  };
  const text = texts[language] || texts.hi;
  return writeAudioFile(text, language, `booking_${bookingId}`, soundsDir);
}

/**
 * Generate a dynamic booking cancellation audio file for a specific booking.
 * File is named booking_cancel_{bookingId}.wav and stored in Asterisk sounds dir.
 * Incorporates:
 *  - Trade / Service category
 *  - Customer address / location
 *  - Cancellation time logic (within 5-min grace window vs after 5 min en route)
 *  - Cancellation reason
 *  - Confirmation of Online status restoration
 *
 * @param {object} opts
 * @param {string} opts.bookingId
 * @param {string} opts.trade
 * @param {string} opts.address
 * @param {string} opts.reason
 * @param {number|null} opts.elapsedMinutes
 * @param {string} opts.language
 * @param {string} opts.soundsDir
 * @returns {Promise<string|null>} - Path to generated wav file
 */
async function generateBookingCancelledAudio({
  bookingId,
  trade = "काम",
  address = "",
  reason = "कोई कारण नहीं बताया गया",
  elapsedMinutes = null,
  language = "hi",
  soundsDir = "/var/lib/asterisk/sounds/workgo",
}) {
  const isEnRoute = typeof elapsedMinutes === "number" && elapsedMinutes >= 5;
  const isWithinWindow = typeof elapsedMinutes === "number" && elapsedMinutes >= 0 && elapsedMinutes < 5;
  const mins = elapsedMinutes !== null && elapsedMinutes !== undefined ? Math.max(1, Math.round(elapsedMinutes)) : 0;
  const loc = address ? address : "ग्राहक का पता";

  const texts = {
    hi: isEnRoute
      ? `वर्कगो सूचना! ${loc} पर ${trade} का काम ग्राहक द्वारा रास्ते में ${mins} मिनट बाद रद्द कर दिया गया है। कारण: ${reason}। लेट कैंसलेशन नीति लागू होगी। आपकी स्थिति पुनः ऑनलाइन कर दी गई है।`
      : isWithinWindow
      ? `वर्कगो सूचना! ${loc} पर ${trade} का काम ग्राहक द्वारा स्वीकार के ${mins} मिनट के भीतर रद्द कर दिया गया है। कारण: ${reason}। आपकी स्थिति पुनः ऑनलाइन कर दी गई है।`
      : `वर्कगो सूचना! ${loc} पर ${trade} का काम ग्राहक द्वारा रद्द कर दिया गया है। कारण: ${reason}। आप अगले काम के लिए ऑनलाइन हैं।`,

    mr: isEnRoute
      ? `वर्कगो सूचना! ${loc} येथील ${trade} चे काम मार्गावर असताना ${mins} मिनिटांनंतर ग्राहकाने रद्द केले आहे. कारण: ${reason}. लेट कॅन्सलेशन भरपाई लागू होईल. तुमची स्थिती पुन्हा ऑनलाइन करण्यात आली आहे.`
      : isWithinWindow
      ? `वर्कगो सूचना! ${loc} येथील ${trade} चे काम स्वीकारल्यानंतर ${mins} मिनिटांच्या आत ग्राहकाने रद्द केले आहे. कारण: ${reason}. तुमची स्थिती पुन्हा ऑनलाइन करण्यात आली आहे.`
      : `वर्कगो सूचना! ${loc} येथील ${trade} चे काम ग्राहकाने रद्द केले आहे. कारण: ${reason}. तुम्ही पुढील कामासाठी ऑनलाइन आहात.`,

    ta: isEnRoute
      ? `வர்க்கோ அறிவிப்பு! ${loc}-இல் உள்ள ${trade} பணி பயணத்தில் ${mins} நிமிடங்களுக்குப் பிறகு வாடிக்கையாளரால் ரத்து செய்யப்பட்டது. காரணம்: ${reason}. பயண இழப்பீடு வழங்கப்படும். நீங்கள் மீண்டும் ஆன்லைனில் உள்ளீர்கள்.`
      : isWithinWindow
      ? `வர்க்கோ அறிவிப்பு! ${loc}-இல் உள்ள ${trade} பணி ஏற்கப்பட்ட ${mins} நிமிடங்களுக்குள் வாடிக்கையாளரால் ரத்து செய்யப்பட்டது. காரணம்: ${reason}. நீங்கள் மீண்டும் ஆன்லைனில் உள்ளீர்கள்.`
      : `வர்க்கோ அறிவிப்பு! ${loc}-இல் உள்ள ${trade} பணி வாடிக்கையாளரால் ரத்து செய்யப்பட்டது. காரணம்: ${reason}. நீங்கள் அடுத்த பணிக்கு தயாராக ஆன்லைனில் உள்ளீர்கள்.`,

    te: isEnRoute
      ? `వర్క్‌గో సమాచారం! ${loc} వద్ద ${trade} పని ప్రయాణంలో ${mins} నిమిషాల తర్వాత కస్టమర్ రద్దు చేశారు. కారణం: ${reason}. ఆలస్య రద్దు పరిహారం వర్తిస్తుంది. మీరు మళ్లీ ఆన్‌లైన్‌లో ఉన్నారు.`
      : isWithinWindow
      ? `వర్క్‌గో సమాచారం! ${loc} వద్ద ${trade} పని ఆమోదించిన ${mins} నిమిషాల లోపు కస్టమర్ రద్దు చేశారు. కారణం: ${reason}. మీరు మళ్లీ ఆన్‌లైన్‌లో ఉన్నారు.`
      : `వర్క్‌గో సమాచారం! ${loc} వద్ద ${trade} పని కస్టమర్ రద్దు చేశారు. కారణం: ${reason}. మీరు తదుపరి పని కోసం ఆన్‌లైన్‌లో ఉన్నారు.`,

    kn: isEnRoute
      ? `ವರ್ಕ್‌ಗೋ ಮಾಹಿತಿ! ${loc} ನಲ್ಲಿ ${trade} ಕೆಲಸವನ್ನು ಪ್ರಯಾಣದಲ್ಲಿ ${mins} ನಿಮಿಷಗಳ ನಂತರ ಗ್ರಾಹಕರು ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ. ಕಾರಣ: ${reason}. ಲೇಟ್ ರದ್ದತಿ ಪರಿಹಾರ ಅನ್ವಯಿಸುತ್ತದೆ. ನೀವು ಮತ್ತೆ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ.`
      : isWithinWindow
      ? `ವರ್ಕ್‌ಗೋ ಮಾಹಿತಿ! ${loc} ನಲ್ಲಿ ${trade} ಕೆಲಸವನ್ನು ಸ್ವೀಕರಿಸಿದ ${mins} ನಿಮಿಷಗಳ ಒಳಗೆ ಗ್ರಾಹಕರು ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ. ಕಾರಣ: ${reason}. ನೀವು ಮತ್ತೆ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ.`
      : `ವರ್ಕ್‌ಗೋ ಮಾಹಿತಿ! ${loc} ನಲ್ಲಿ ${trade} ಕೆಲಸವನ್ನು ಗ್ರಾಹಕರು ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ. ಕಾರಣ: ${reason}. ನೀವು ಮುಂದಿನ ಕೆಲಸಕ್ಕೆ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದೀರಿ.`,

    ml: isEnRoute
      ? `വർക്ക്‌ഗോ അറിയിപ്പ്! ${loc}-ൽ ${trade} ജോലി യാത്രയിൽ ${mins} മിനിറ്റിനു ശേഷം ഉപഭോക്താവ് റദ്ദാക്കി. കാരണം: ${reason}. ലേറ്റ് ക്യാൻസലേഷൻ നഷ്ടപരിഹാരം ലഭിക്കും. നിങ്ങൾ വീണ്ടും ഓൺലൈനിലാണ്.`
      : isWithinWindow
      ? `വർക്ക്‌ഗോ അറിയിപ്പ്! ${loc}-ൽ ${trade} ജോലി സ്വീകരിച്ച് ${mins} മിനിറ്റിനുള്ളിൽ ഉപഭോക്താവ് റദ്ദാക്കി. കാരണം: ${reason}. നിങ്ങൾ വീണ്ടും ഓൺലൈനിലാണ്.`
      : `വർക്ക്‌ഗോ അറിയിപ്പ്! ${loc}-ൽ ${trade} ജോലി ഉപഭോക്താവ് റദ്ദാക്കി. കാരണം: ${reason}. നിങ്ങൾ അടുത്ത ജോലിക്കായി ഓൺലൈനിലാണ്.`,

    bn: isEnRoute
      ? `ওয়ার্কগো বিজ্ঞপ্তি! ${loc}-এর ${trade} কাজ রাস্তায় ${mins} মিনিট পর গ্রাহক বাতিল করেছেন। কারণ: ${reason}। বিলম্বিত বাতিলের ক্ষতিপূরণ প্রযোজ্য। আপনি আবার অনলাইনে আছেন।`
      : isWithinWindow
      ? `ওয়ার্কগো বিজ্ঞপ্তি! ${loc}-এর ${trade} কাজ গ্রহণের ${mins} মিনিটের মধ্যে গ্রাহক বাতিল করেছেন। কারণ: ${reason}। আপনি আবার অনলাইনে আছেন।`
      : `ওয়ার্কগো বিজ্ঞপ্তি! ${loc}-এর ${trade} কাজ গ্রাহক বাতিল করেছেন। कारण: ${reason}। আপনি পরবর্তী কাজের জন্য অনলাইনে আছেন।`,

    gu: isEnRoute
      ? `વર્કગો સૂચના! ${loc} પર ${trade} કામ રસ્તામાં ${mins} મિનિટ પછી ગ્રાહકે રદ કર્યું છે. કારણ: ${reason}. મોડું રદ કરવાનું વળતર લાગુ થશે. તમે ફરી ઓનલાઇન છો.`
      : isWithinWindow
      ? `વર્કગો સૂચના! ${loc} પર ${trade} કામ સ્વીકાર્યાની ${mins} મિનિટમાં ગ્રાહકે રદ કર્યું છે. કારણ: ${reason}. તમે ફરી ઓનલાઇન છો.`
      : `વર્કગો સૂચના! ${loc} પર ${trade} કામ ગ્રાહકે રદ કર્યું છે. કારણ: ${reason}. તમે આગળના કામ માટે ઓનલાઇન છો.`,

    pa: isEnRoute
      ? `ਵਰਕਗੋ ਸੂਚਨਾ! ${loc} ਵਿਖੇ ${trade} ਦਾ ਕੰਮ ਰਸਤੇ ਵਿੱਚ ${mins} ਮਿੰਟ ਬਾਅਦ ਗਾਹਕ ਵੱਲੋਂ ਰੱਦ ਕਰ ਦਿੱਤਾ ਗਿਆ ਹੈ। ਕਾਰਨ: ${reason}। ਲੇਟ ਕੈਂਸਲੇਸ਼ਨ ਮੁਆਵਜ਼ਾ ਲਾਗੂ ਹੋਵੇਗਾ। ਤੁਸੀਂ ਦੁਬਾਰਾ ਆਨਲਾਈਨ ਹੋ।`
      : isWithinWindow
      ? `ਵਰਕਗੋ ਸੂਚਨਾ! ${loc} ਵਿਖੇ ${trade} ਦਾ ਕੰਮ ਸਵੀਕਾਰ ਕਰਨ ਦੇ ${mins} ਮਿੰਟਾਂ ਅੰਦਰ ਗਾਹਕ ਵੱਲੋਂ ਰੱਦ ਕਰ ਦਿੱਤਾ ਗਿਆ ਹੈ। ਕਾਰਨ: ${reason}। ਤੁਸੀਂ ਦੁਬਾਰਾ ਆਨਲਾਈਨ ਹੋ।`
      : `ਵਰਕਗੋ ਸੂਚਨਾ! ${loc} ਵਿਖੇ ${trade} ਦਾ ਕੰਮ ਗਾਹਕ ਵੱਲੋਂ ਰੱਦ ਕਰ ਦਿੱਤਾ ਗਿਆ ਹੈ। ਕਾਰਨ: ${reason}। ਤੁਸੀਂ ਅਗਲੇ ਕੰਮ ਲਈ ਆਨਲਾਈਨ ਹੋ।`,

    en: isEnRoute
      ? `WorkGo notice! The ${trade} job at ${loc} was cancelled by the customer after ${mins} minutes while you were en route. Reason: ${reason}. Late cancellation compensation applies. You are now back online.`
      : isWithinWindow
      ? `WorkGo notice! The ${trade} job at ${loc} was cancelled by the customer within ${mins} minutes of acceptance. Reason: ${reason}. You are now back online.`
      : `WorkGo notice! The ${trade} job at ${loc} was cancelled by the customer. Reason: ${reason}. You are now back online for new jobs.`,
  };

  const text = texts[language] || texts.hi;
  return writeAudioFile(text, language, `booking_cancel_${bookingId}`, soundsDir);
}

module.exports = {
  speechToText,
  textToSpeech,
  writeAudioFile,
  prebakeIvrPrompts,
  generateBookingAlertAudio,
  generateBookingCancelledAudio,
};

