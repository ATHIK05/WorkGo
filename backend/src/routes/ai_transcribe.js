"use strict";

/**
 * WorkGo AI Speech-to-Text (ASR) Proxy — POST /api/ai/transcribe
 *
 * Dual-Engine Indian Vernacular Architecture:
 *   1. Bhashini Dhruva ASR (MeitY / AI4Bharat)
 *      - Activated automatically when BHASHINI_API_KEY + BHASHINI_USER_ID exist in env.
 *      - Native Indian model trained on 22 scheduled languages.
 *   2. Gemini 1.5 Flash Multimodal Audio (Default & Resilient Fallback)
 *      - Zero setup wait, token-billed, 99.9% uptime SLA.
 *      - Highly accurate on code-mixed speech (Tanglish, Hinglish, Manglish, etc.).
 *
 * Security: API keys reside strictly on Render server. Never exposed in mobile APK.
 */

const express = require("express");
const router = express.Router();
const https = require("https");

const GEMINI_MODEL = "gemini-1.5-flash";
const GEMINI_BASE = "generativelanguage.googleapis.com";
const GEMINI_TIMEOUT_MS = 10000;

const BHASHINI_BASE = "dhruva-api.bhashini.gov.in";
const BHASHINI_PATH = "/services/inference/pipeline";
const BHASHINI_TIMEOUT_MS = 6000;

/**
 * Raw HTTPS POST utility — avoids extra npm dependencies.
 */
function httpsPost(hostname, path, headers, body, timeoutMs) {
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
            reject(
              new Error(
                `Non-JSON response (HTTP ${res.statusCode}): ${raw.slice(0, 300)}`
              )
            );
          }
        });
      }
    );
    req.setTimeout(timeoutMs, () =>
      req.destroy(new Error(`Request timed out after ${timeoutMs}ms`))
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

/**
 * Call Bhashini Dhruva ASR Pipeline.
 * Returns transcribed text or throws error on failure.
 */
async function callBhashiniAsr(audioBase64, languageCode) {
  const apiKey = process.env.BHASHINI_API_KEY;
  const userId = process.env.BHASHINI_USER_ID;
  const pipelineId = process.env.BHASHINI_PIPELINE_ID;

  if (!apiKey || !userId) {
    throw new Error("BHASHINI_API_KEY or BHASHINI_USER_ID not configured");
  }

  const lang = (languageCode || "ta").toLowerCase().trim();

  const payload = {
    pipelineTasks: [
      {
        taskType: "asr",
        config: {
          language: {
            sourceLanguage: lang,
          },
          ...(pipelineId ? { serviceId: pipelineId } : {}),
        },
      },
    ],
    inputData: {
      audio: [
        {
          audioContent: audioBase64,
        },
      ],
    },
  };

  const headers = {
    Authorization: apiKey,
    ulcaApiKey: apiKey,
    userID: userId,
  };

  const { status, body } = await httpsPost(
    BHASHINI_BASE,
    BHASHINI_PATH,
    headers,
    payload,
    BHASHINI_TIMEOUT_MS
  );

  if (status >= 400) {
    throw new Error(`Bhashini HTTP ${status}: ${JSON.stringify(body).slice(0, 200)}`);
  }

  // Parse Bhashini Dhruva response structure
  const text =
    body?.pipelineResponse?.[0]?.output?.[0]?.source ||
    body?.output?.[0]?.source ||
    body?.text;

  if (!text || !text.trim()) {
    throw new Error("Bhashini returned empty transcription");
  }

  return text.trim();
}

/**
 * Call Gemini 1.5 Flash Multimodal Audio Transcription.
 * Returns transcribed text or throws error on failure.
 */
async function callGeminiAudioTranscription(audioBase64, mimeType, languageCode) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY not configured on server");

  const effectiveMime = mimeType || "audio/aac";
  const lang = (languageCode || "en").toLowerCase().trim();

  const prompt =
    `You are an expert Indian Speech-to-Text transcriber for the WorkGo home repair platform.\n` +
    `Transcribe the spoken audio recording verbatim.\n` +
    `- The customer is describing a household repair problem in an Indian language or dialect.\n` +
    `- Language hint: "${lang}" (e.g. Tamil 'ta', Hindi 'hi', Telugu 'te', Kannada 'kn', Malayalam 'ml', Marathi 'mr', Bengali 'bn', Gujarati 'gu', Punjabi 'pa', or Indian English/Tanglish/Hinglish).\n` +
    `- Output the exact spoken words in the speaker's language (in native script or colloquial form).\n` +
    `- Output ONLY valid JSON: {"text": "exact transcribed words"}.\n` +
    `- If the audio is silence or uninterpretable noise, output: {"text": ""}.`;

  const requestBody = {
    contents: [
      {
        parts: [
          {
            inlineData: {
              mimeType: effectiveMime,
              data: audioBase64,
            },
          },
          {
            text: prompt,
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0.1,
      maxOutputTokens: 256,
    },
  };

  const { status, body } = await httpsPost(
    GEMINI_BASE,
    `/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    {},
    requestBody,
    GEMINI_TIMEOUT_MS
  );

  if (status === 429) throw new Error("GEMINI_RATE_LIMITED");
  if (status >= 400) {
    const detail = body?.error?.message || JSON.stringify(body).slice(0, 200);
    throw new Error(`Gemini Audio API error HTTP ${status}: ${detail}`);
  }

  const rawText = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText || !rawText.trim()) throw new Error("Gemini returned empty audio response");

  const jsonText = rawText.trim().replace(/^```json\s*/i, "").replace(/```\s*$/, "");
  const parsed = JSON.parse(jsonText);
  return typeof parsed.text === "string" ? parsed.text.trim() : "";
}

/**
 * POST /api/ai/transcribe
 * Body: { audio: string (base64), mimeType?: string, languageCode?: string }
 */
router.post("/transcribe", async (req, res) => {
  try {
    const { audio, mimeType, languageCode } = req.body;

    if (!audio || typeof audio !== "string" || !audio.trim()) {
      return res.status(400).json({ error: "audio base64 string is required" });
    }

    const cleanBase64 = audio.trim().replace(/^data:audio\/[a-z0-9]+;base64,/i, "");
    const lang = typeof languageCode === "string" ? languageCode.trim().slice(0, 10) : "en";
    const mime = typeof mimeType === "string" ? mimeType.trim() : "audio/aac";

    let transcribedText = "";
    let engineUsed = "gemini";

    // 1. Attempt Bhashini if credentials exist
    if (process.env.BHASHINI_API_KEY && process.env.BHASHINI_USER_ID) {
      try {
        transcribedText = await callBhashiniAsr(cleanBase64, lang);
        engineUsed = "bhashini";
        console.log(`[ai_transcribe] Bhashini ASR success: "${transcribedText}" (${lang})`);
      } catch (bhashiniErr) {
        console.warn(`[ai_transcribe] Bhashini ASR failed, falling back to Gemini: ${bhashiniErr.message}`);
      }
    }

    // 2. Default or Fallback to Gemini 1.5 Flash Multimodal Audio
    if (!transcribedText) {
      transcribedText = await callGeminiAudioTranscription(cleanBase64, mime, lang);
      engineUsed = "gemini";
      console.log(`[ai_transcribe] Gemini Audio ASR success: "${transcribedText}" (${lang})`);
    }

    return res.json({
      text: transcribedText,
      engine: engineUsed,
      languageCode: lang,
    });
  } catch (err) {
    console.error("[ai_transcribe] Critical transcription failure:", err.message);
    return res.status(500).json({
      error: "Transcription failed",
      details: err.message,
    });
  }
});

module.exports = router;
