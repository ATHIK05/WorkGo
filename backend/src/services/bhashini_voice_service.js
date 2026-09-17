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
  if (customDir && customDir !== "/var/lib/asterisk/sounds/workgo") {
    return customDir;
  }
  if (process.env.ASTERISK_SOUNDS_DIR) {
    return process.env.ASTERISK_SOUNDS_DIR;
  }
  const fs = require("fs");
  const path = require("path");
  const os = require("os");
  try {
    if (fs.existsSync("/var/lib/asterisk/sounds")) {
      const candidate = "/var/lib/asterisk/sounds/workgo";
      if (!fs.existsSync(candidate)) {
        fs.mkdirSync(candidate, { recursive: true });
      }
      return candidate;
    }
  } catch (_) {
    // EACCES on cloud unprivileged containers -> fallback to safe local dir
  }
  const localDir = path.join(process.cwd(), "sounds");
  try {
    if (!fs.existsSync(localDir)) {
      fs.mkdirSync(localDir, { recursive: true });
    }
    return localDir;
  } catch (_) {
    return os.tmpdir();
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
  const targetDir = getSoundsDir(soundsDir);

  const audioBase64 = await textToSpeech(text, language);
  if (!audioBase64) return null;

  try {
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    const filePath = path.join(targetDir, `${filename}.wav`);
    fs.writeFileSync(filePath, Buffer.from(audioBase64, "base64"));
    console.log(`[BhashiniVoice] Audio written: ${filePath}`);
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
    return; // Skip mass batch TTS generation on server startup to avoid rate limits
  }
  const fs = require("fs");
  const path = require("path");
  const targetDir = getSoundsDir(soundsDir);

  const prompts = [
    // Onboarding
    { file: "welcome_hi", lang: "hi", text: "वर्कगो कार्या में आपका स्वागत है। कृपया अपना पूरा नाम बताएं।" },
    { file: "ask_trade_hi", lang: "hi", text: "आप क्या काम करते हैं? प्लम्बर के लिए 1 दबाएं, इलेक्ट्रीशियन के लिए 2, कारपेंटर के लिए 3, या अपना काम बोलें।" },
    { file: "ask_pincode_hi", lang: "hi", text: "अपने इलाके का 6 अंकों का पिनकोड डायल करें।" },
    { file: "registration_done_hi", lang: "hi", text: "आपका पंजीकरण दर्ज हो गया है। एक करिया मित्र जल्द ही आपसे verification के लिए मिलेंगे।" },
    // Online / Offline Toggle
    { file: "toggle_menu_hi", lang: "hi", text: "ऑनलाइन होने के लिए 1 दबाएं। ऑफलाइन होने के लिए 2 दबाएं।" },
    { file: "now_online_hi", lang: "hi", text: "आप अब ऑनलाइन हैं। नया काम आने पर आपको कॉल आएगा।" },
    { file: "now_offline_hi", lang: "hi", text: "आप अब ऑफलाइन हैं। काम शुरू करने के लिए दोबारा कॉल करें।" },
    // Booking Alert
    { file: "booking_taken_hi", lang: "hi", text: "यह काम किसी दूसरे आर्टिसन ने ले लिया है। अगले काम के लिए तैयार रहें। धन्यवाद।" },
    { file: "booking_confirmed_hi", lang: "hi", text: "बधाई हो! काम आपको मिल गया है। ग्राहक का पता अब आपको भेजा जाएगा।" },
    // Marathi variants
    { file: "welcome_mr", lang: "mr", text: "वर्कगो कार्यामध्ये आपले स्वागत आहे. कृपया आपले पूर्ण नाव सांगा." },
    { file: "toggle_menu_mr", lang: "mr", text: "ऑनलाइन होण्यासाठी 1 दाबा. ऑफलाइन होण्यासाठी 2 दाबा." },
    { file: "now_online_mr", lang: "mr", text: "तुम्ही आता ऑनलाइन आहात. नवीन काम आल्यावर तुम्हाला कॉल येईल." },
    { file: "booking_taken_mr", lang: "mr", text: "हे काम दुसऱ्या कामगाराने घेतले आहे. पुढील कामासाठी तयार राहा." },
    // Tamil variants
    { file: "welcome_ta", lang: "ta", text: "வர்க்கோ கார்யாவில் உங்களை வரவேற்கிறோம். தயவுசெய்து உங்கள் முழு பெயரை சொல்லுங்கள்." },
    { file: "toggle_menu_ta", lang: "ta", text: "ஆன்லைனில் இருக்க 1 அழுத்துங்கள். ஆஃப்லைனில் இருக்க 2 அழுத்துங்கள்." },
    { file: "now_online_ta", lang: "ta", text: "நீங்கள் இப்போது ஆன்லைனில் இருக்கிறீர்கள். புதிய வேலை வரும்போது உங்களுக்கு அழைப்பு வரும்." },
    { file: "booking_taken_ta", lang: "ta", text: "இந்த வேலையை வேறொரு தொழிலாளி எடுத்துவிட்டார். அடுத்த வேலைக்கு தயாராக இருங்கள்." },
  ];

  let generated = 0;
  for (const p of prompts) {
    const filePath = path.join(targetDir, `${p.file}.wav`);
    if (!fs.existsSync(filePath)) {
      const result = await writeAudioFile(p.text, p.lang, p.file, targetDir);
      if (result) generated++;
    }
  }
  console.log(`[BhashiniVoice] Pre-baked ${generated} new IVR prompt(s).`);
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
  const texts = {
    hi: `वर्कगो अलर्ट! नया ${trade} का काम। ${address}। पेआउट ₹${payout}। यह काम लेने के लिए 1 दबाएं। छोड़ने के लिए 2 दबाएं।`,
    mr: `वर्कगो अलर्ट! नवीन ${trade} काम. ${address}. पेआउट ₹${payout}. हे काम घेण्यासाठी 1 दाबा. सोडण्यासाठी 2 दाबा.`,
    ta: `வர்க்கோ அலர்ட்! புதிய ${trade} வேலை. ${address}. கட்டணம் ₹${payout}. வேலை எடுக்க 1 அழுத்துங்கள். விட 2 அழுத்துங்கள்.`,
  };
  const text = texts[language] || texts.hi;
  return writeAudioFile(text, language, `booking_${bookingId}`, soundsDir);
}

module.exports = {
  speechToText,
  textToSpeech,
  writeAudioFile,
  prebakeIvrPrompts,
  generateBookingAlertAudio,
};
