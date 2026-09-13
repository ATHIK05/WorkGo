"use strict";

/**
 * WorkGo AI Triage Proxy — POST /api/ai/triage
 *
 * 4-Tier Architecture (backend handles Tier 3 of the full cascade):
 *   1. SHA-256 Firestore cache       → 0ms for any repeated query
 *   2. Gemini 1.5 Flash (primary)    → No req/month cap, token billing ~₹0.075/1M
 *   3. 503 → structured error        → Flutter Tier 4 (SymptomCatalog) handles offline
 *
 * Security: GEMINI_API_KEY is server-side ONLY on Render. Never in APK.
 */

const express = require("express");
const router = express.Router();
const crypto = require("crypto");
const https = require("https");

// ── Constants ──────────────────────────────────────────────────────────────────
const GEMINI_MODEL = "gemini-1.5-flash";
const GEMINI_BASE = "generativelanguage.googleapis.com";
const GEMINI_TIMEOUT_MS = 8000;
const CACHE_COLLECTION = "ai_triage_cache";

// ── WorkGo Trade System Prompt ─────────────────────────────────────────────────
const SYSTEM_PROMPT = `You are the WorkGo AI Diagnostic Engine for Indian household repairs.
Analyze customer symptom descriptions in ANY language or dialect:
- Indian English, Hinglish, Tanglish, Manglish, Benglish
- Native scripts: Tamil, Hindi, Telugu, Kannada, Malayalam, Bengali, Gujarati, Marathi, Odia, Punjabi, Urdu, Assamese
- Romanized colloquial: "motor la sound varudhu", "thani varala", "bijli board spark kar raha hai", "paani riss raha", "geyser shock adikkudhu", "fan suthu suthu varudhu"

Supported craft trades:
- "Electrician"
- "Plumber"
- "Carpenter"
- "Painter"
- "Cleaning"
- "Appliance Repair"
- "Masonry"
- "Welder / Metal"

Trade Classification Rules:
1. "Electrician":
   - Ceiling / table / exhaust / pedestal fan, fan regulator ("fan suthu varudhu", "pankha chalda nahi", "kaathadi", "mirchi fan") → equipmentTag: "Ceiling Fan / Home Appliance". NEVER classify as "Air Conditioner".
   - Switchboard, MCB tripping, fuse, wire sparking, electric shocks, earth leakage, inverter, battery.
   - Water motor / borewell pump — cross-disciplinary with Plumber.

2. "Plumber":
   - Piping: concealed pipe leak, dripping tap/faucet, angle cock, shower mixer, toilet cistern.
   - Drainage: clogged sink, choked toilet, blocked floor trap ("adaipu", "paani band", "drain jam").

3. "Appliance Repair":
   - Refrigerator, AC (only if user explicitly says AC/split/cooling gas), Geyser/Water Heater, Microwave.
   - Washing Machine, Mixer Grinder, RO Water Purifier, Gas Stove/Hob.

4. "Carpenter":
   - Doors & locks: key stuck, lock jammed ("pootu", "saavi", "darwaza"), door dragging, loose hinges.
   - Furniture: wardrobe sliders, modular kitchen hinges, wooden bed/sofa/table.

5. "Painter":
   - Paint flaking/peeling, damp patches, putty, waterproofing ("sunnam", "vannam", "safedi").

6. "Cleaning":
   - Bathroom tile acid wash, chimney grease, sofa/mattress shampoo, house sanitization.

7. "Welder / Metal":
   - Gate broken hinge, balcony grill loose, rolling shutter, metal railing ("irumbu", "loha").

8. "Masonry":
   - Broken/hollow tiles, re-grouting, plaster cracks, brickwork ("kothanar", "mistri", "patthar").

Disambiguation Rules (critical):
- Refrigerator water: "Appliance Repair" NOT "Plumber".
- AC indoor drip: "Appliance Repair" NOT "Plumber".
- Ceiling/table fan: "Electrician" NEVER "Air Conditioner".
- Water motor: "Electrician" primary, "Plumber" secondary.

Out-of-Scope Rule:
Non-household queries (stationery, personal electronics, vehicles, food, medicine, salon, banking, gibberish):
→ "primaryCategory": "Out of Scope", "confidence": 0.0, "equipmentTag": "Non-Household Service", "isOutOfScope": true.
NEVER guess a trade for out-of-scope requests.

Output ONLY valid JSON. No markdown, no code fences, no explanation text:
{
  "primaryCategory": string,
  "secondaryCategory": string or null,
  "confidence": number 0.0-0.98,
  "equipmentTag": string,
  "summary": string,
  "likelyCauses": [string],
  "clarifyingQuestions": [
    {
      "id": "q1",
      "questionText": string,
      "options": [{"label": string, "probableCategory": string, "likelyCause": string}]
    }
  ],
  "suggestedKeywords": [string],
  "suggestedToolsNeeded": [string],
  "requiresSmartDiagnosticVisit": boolean,
  "diagnosticFee": number,
  "isOutOfScope": boolean
}`;

// ── Helpers ────────────────────────────────────────────────────────────────────

/** SHA-256 hash of normalized query for Firestore cache key. */
function queryHash(query) {
  const normalized = query.trim().toLowerCase().replace(/\s+/g, " ");
  return crypto.createHash("sha256").update(normalized, "utf8").digest("hex");
}

/**
 * Raw HTTPS POST utility — avoids adding npm packages.
 * Returns { status: number, body: object }
 */
function httpsPost(hostname, path, headers, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
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
 * Validates and normalises AI model output into a clean DiagnosticResult object.
 * Guards against hallucinated categories, missing fields, and type errors.
 */
function sanitizeResult(raw, query) {
  if (!raw || typeof raw !== "object") {
    throw new Error("AI returned non-object payload");
  }

  const VALID_CATEGORIES = new Set([
    "Electrician", "Plumber", "Carpenter", "Painter",
    "Cleaning", "Appliance Repair", "Masonry", "Welder / Metal", "Out of Scope",
  ]);

  const isOutOfScope =
    raw.isOutOfScope === true || raw.primaryCategory === "Out of Scope";

  const primaryCategory = VALID_CATEGORIES.has(raw.primaryCategory)
    ? raw.primaryCategory
    : "Out of Scope";

  const secondaryCategory =
    raw.secondaryCategory && VALID_CATEGORIES.has(raw.secondaryCategory)
      ? raw.secondaryCategory
      : null;

  return {
    symptomQuery: query,
    primaryCategory,
    secondaryCategory,
    confidence: isOutOfScope
      ? 0.0
      : Math.min(0.98, Math.max(0.0, Number(raw.confidence) || 0.82)),
    equipmentTag:
      typeof raw.equipmentTag === "string" && raw.equipmentTag.trim()
        ? raw.equipmentTag.trim()
        : isOutOfScope
        ? "Non-Household Service"
        : "Home Appliance",
    summary:
      typeof raw.summary === "string" && raw.summary.trim()
        ? raw.summary.trim()
        : "WorkGo AI diagnostic analysis completed.",
    likelyCauses: Array.isArray(raw.likelyCauses)
      ? raw.likelyCauses.filter((s) => typeof s === "string").slice(0, 5)
      : [],
    clarifyingQuestions: Array.isArray(raw.clarifyingQuestions)
      ? raw.clarifyingQuestions
          .filter((q) => q && typeof q.questionText === "string")
          .map((q) => ({
            id: String(q.id || "q1"),
            questionText: q.questionText,
            options: Array.isArray(q.options)
              ? q.options
                  .filter((o) => o && typeof o.label === "string")
                  .map((o) => ({
                    label: o.label,
                    probableCategory: String(o.probableCategory || primaryCategory),
                    likelyCause: String(o.likelyCause || ""),
                  }))
              : [],
          }))
          .slice(0, 2)
      : [],
    suggestedKeywords: Array.isArray(raw.suggestedKeywords)
      ? raw.suggestedKeywords.filter((s) => typeof s === "string").slice(0, 5)
      : [],
    suggestedToolsNeeded: Array.isArray(raw.suggestedToolsNeeded)
      ? raw.suggestedToolsNeeded.filter((s) => typeof s === "string").slice(0, 5)
      : [],
    requiresSmartDiagnosticVisit: isOutOfScope
      ? false
      : raw.requiresSmartDiagnosticVisit !== false,
    diagnosticFee: isOutOfScope ? 0.0 : Math.max(0, Number(raw.diagnosticFee) || 99.0),
    isAiGenerated: true,
    isOutOfScope,
  };
}

/**
 * Calls Gemini 1.5 Flash via raw HTTPS — no npm SDK needed.
 * Uses responseMimeType: "application/json" to guarantee structured output.
 */
async function callGemini(query, languageCode) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY not configured on server");

  const langHint =
    languageCode && languageCode !== "en"
      ? ` (Customer's language code: ${languageCode}. Understand the query even if it is in that language's native script or Romanized form.)`
      : "";

  const prompt = `${SYSTEM_PROMPT}\n\nDiagnose this household symptom${langHint}: "${query}"`;

  const { status, body } = await httpsPost(
    GEMINI_BASE,
    `/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
    {},
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.15,
        maxOutputTokens: 512,
      },
    },
    GEMINI_TIMEOUT_MS
  );

  if (status === 429) throw new Error("GEMINI_RATE_LIMITED");
  if (status >= 400) {
    const detail = body?.error?.message || JSON.stringify(body).slice(0, 200);
    throw new Error(`Gemini API error HTTP ${status}: ${detail}`);
  }

  const rawText = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText || !rawText.trim()) throw new Error("Gemini returned empty content");

  // Gemini with application/json MIME type returns clean JSON, but guard anyway
  const jsonText = rawText.trim().replace(/^```json\s*/i, "").replace(/```\s*$/, "");
  const parsed = JSON.parse(jsonText);
  return sanitizeResult(parsed, query);
}

// ── Route ──────────────────────────────────────────────────────────────────────

/**
 * POST /api/ai/triage
 * Body: { query: string, language?: string }
 *
 * Authentication: Optional — WorkGoApiClient attaches Bearer token when logged in.
 * Guest usage permitted (protected by global rate limiter: 200 req/15 min).
 */
router.post("/triage", async (req, res) => {
  try {
    const { query, language } = req.body;

    // ── Validation ───────────────────────────────────────────────────────────
    if (!query || typeof query !== "string" || !query.trim()) {
      return res
        .status(400)
        .json({ error: "query is required and must be a non-empty string" });
    }
    const cleanQuery = query.trim();
    if (cleanQuery.length > 500) {
      return res
        .status(400)
        .json({ error: "query must not exceed 500 characters" });
    }
    const languageCode =
      typeof language === "string" ? language.trim().slice(0, 10) : "en";

    const db = req.db;

    // ── Firestore Cache Check (Tier 0 — 0ms on hit) ──────────────────────────
    const hash = queryHash(cleanQuery);
    const cacheRef = db.collection(CACHE_COLLECTION).doc(hash);
    const cacheSnap = await cacheRef.get();

    if (cacheSnap.exists) {
      const cached = cacheSnap.data();
      console.log(`[ai/triage] CACHE HIT  hash=${hash.slice(0, 12)} query="${cleanQuery.slice(0, 40)}"`);
      // Strip internal cache metadata before returning to client
      const { _cachedAt, _source, ...clientPayload } = cached;
      return res.json({ ...clientPayload, source: "cache" });
    }

    console.log(`[ai/triage] CACHE MISS  query="${cleanQuery.slice(0, 60)}"`);

    // ── Gemini 1.5 Flash Inference ───────────────────────────────────────────
    let result;
    try {
      result = await callGemini(cleanQuery, languageCode);
    } catch (geminiErr) {
      console.error(`[ai/triage] Gemini failed: ${geminiErr.message}`);
      // Signal Flutter to use on-device Tier 4 fallback
      return res.status(503).json({
        error: "AI inference temporarily unavailable",
        code: "AI_UNAVAILABLE",
        retryAfterMs: 2000,
      });
    }

    // ── Persist to Firestore (fire-and-forget) ───────────────────────────────
    cacheRef
      .set({ ...result, _cachedAt: new Date().toISOString(), _source: "gemini" })
      .catch((e) => console.error("[ai/triage] Cache write failed:", e.message));

    console.log(
      `[ai/triage] SUCCESS  category="${result.primaryCategory}"` +
      `  confidence=${Math.round(result.confidence * 100)}%` +
      `  query="${cleanQuery.slice(0, 40)}"`
    );

    return res.json({ ...result, source: "gemini" });
  } catch (err) {
    console.error("[ai/triage] Unhandled error:", err);
    return res.status(500).json({ error: "Internal server error during AI triage" });
  }
});

module.exports = router;
