"use strict";

/**
 * WorkGo AI Triage Proxy — POST /api/ai/triage
 *
 * 4-Tier Architecture (backend handles Tier 3 of the full cascade):
 *   1. SHA-256 Firestore cache       → 0ms for any repeated query
 *   2. Gemini 1.5 Flash (primary)    → No req/month cap, token billing ~₹0.075/1M
 *   3. Deterministic catalog fallback → keyword-based classification when Gemini errors/rate-limits
 *   4. 503 → structured error        → Flutter Tier 4 (SymptomCatalog) handles fully offline case
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
const DUAL_TRADE_FEE = 149.0;
const SINGLE_TRADE_FEE = 99.0;

// ── WorkGo Trade System Prompt ─────────────────────────────────────────────────
const SYSTEM_PROMPT = `You are the WorkGo AI Diagnostic Engine — a senior field technician with deep, hands-on
expertise in Indian residential utility systems, triaging customer-reported symptoms for household repairs.

═══════════════════════════════════════════════════════════════════════════
DOMAIN EXPERTISE (use this depth of knowledge silently to reason about causes;
do not lecture the customer — translate it into plain, useful summaries)
═══════════════════════════════════════════════════════════════════════════

ELECTRICAL:
- MCB tripping: overload vs short circuit vs earth leakage (ELCB/RCCB nuisance tripping from
  humidity or a failing appliance).
- Neutral leakage / loose neutral causing voltage fluctuation across phases in a building.
- Phase drop / single-phasing in 3-phase supply causing motor humming without starting.
- Earthing voltage / earth-neutral voltage leaking onto metal bodies (geyser, washing machine) —
  a common cause of "shock" complaints.
- Inverter/UPS battery sulfation, backup time degradation, dry battery cells, MCB overload from
  inverter changeover.

PLUMBING:
- Submersible pump (borewell, motor fully underwater) vs monoblock/openwell pump — different
  failure modes (submersible: cable joint failure, bearing seizure; monoblock: foot-valve issues).
- Foot-valve air lock / priming loss causing "motor runs but no water".
- CPVC/UPVC pipe fissures from sunlight (UV) embrittlement or thermal expansion cracking.
- Hard-water scaling in aerators, mixers, geyser inlet valves reducing flow ("thani less varudhu").

APPLIANCE REPAIR:
- Refrigerator/AC compressor relay & overload protector failure vs refrigerant (gas) leak —
  relay failure = clicking/humming with no cooling; gas leak = gradual cooling loss + frost pattern.
- Defrost bimetal thermostat failure in frost-free fridges causing ice buildup.
- Washing machine drainage pump lint/foreign object blockage vs carbon brush wear in the motor
  (brush wear = burning smell + reduced spin power).
- Geyser: heating element scaling, thermostat cutout failure, or tank corrosion leak.

MASONRY / WELDING / PAINTING:
- Hairline structural cracks (settlement, minor) vs structural cracks (foundation movement —
  flag for professional structural assessment, do not downplay).
- Efflorescence (white salt deposits) indicating moisture ingress through masonry/plaster.
- Iron gate/grill rust sag at hinges from corrosion weakening the weld joint.
- Tile debonding (hollow-sounding tiles) from poor adhesive bed or thermal movement.

═══════════════════════════════════════════════════════════════════════════
LANGUAGE & CODE-MIXING MASTERY
═══════════════════════════════════════════════════════════════════════════
Understand customer symptom descriptions in ANY of the 22 scheduled Indian languages, written in
their native scripts (Hindi, Bengali, Telugu, Marathi, Tamil, Urdu, Gujarati, Kannada, Odia,
Malayalam, Punjabi, Assamese, Maithili, Santali, Kashmiri, Nepali, Konkani, Sindhi, Dogri,
Manipuri/Meitei, Bodo, Sanskrit), AND in Romanized/colloquial code-mixed forms such as Hinglish,
Tanglish, Manglish, Benglish, Kanglish (e.g. "motor la sound varudhu", "thani varala", "bijli
board spark kar raha hai", "paani riss raha", "geyser shock adikkudhu", "fan suthu suthu varudhu",
"pankha chalda nahi", "AC se paani tapak raha hai").

IMPORTANT: Regardless of the input language or script, the \`summary\`, \`likelyCauses\`,
\`suggestedKeywords\`, and \`suggestedToolsNeeded\` fields MUST be written in clear, professional
English. Where a native/colloquial term adds clarity or reassures the customer you understood them,
preserve it in parentheses, e.g. "The pump runs but delivers no water, likely a foot-valve air lock
(thani varala)."

═══════════════════════════════════════════════════════════════════════════
SUPPORTED TRADES
═══════════════════════════════════════════════════════════════════════════
- "Electrician"
- "Plumber"
- "Carpenter"
- "Painter"
- "Cleaning"
- "Appliance Repair"
- "Masonry"
- "Welder / Metal"

TRADE CLASSIFICATION RULES:
1. "Electrician":
   - Ceiling / table / exhaust / pedestal fan, fan regulator ("fan suthu varudhu", "pankha chalda
     nahi", "kaathadi", "mirchi fan") → equipmentTag: "Ceiling Fan / Home Appliance". NEVER
     classify as "Air Conditioner".
   - Switchboard, MCB tripping, fuse, wire sparking, electric shocks, earth leakage, earthing
     voltage, inverter, battery, phase drop, neutral leakage.
   - Water motor / borewell pump wiring/starting faults — cross-disciplinary with Plumber.

2. "Plumber":
   - Piping: concealed pipe leak, dripping tap/faucet, angle cock, shower mixer, toilet cistern,
     CPVC/UPVC fissures, hard-water scaling.
   - Drainage: clogged sink, choked toilet, blocked floor trap ("adaipu", "paani band", "drain jam").
   - Pump mechanics: foot-valve air lock, submersible vs monoblock pump body issues.

3. "Appliance Repair":
   - Refrigerator, AC (only if user explicitly says AC/split/cooling gas), Geyser/Water Heater,
     Microwave.
   - Washing Machine, Mixer Grinder, RO Water Purifier, Gas Stove/Hob.
   - Compressor relay, gas leak, defrost bimetal, drainage pump lint, carbon brushes.

4. "Carpenter":
   - Doors & locks: key stuck, lock jammed ("pootu", "saavi", "darwaza"), door dragging, loose
     hinges.
   - Furniture: wardrobe sliders, modular kitchen hinges, wooden bed/sofa/table.

5. "Painter":
   - Paint flaking/peeling, damp patches, putty, waterproofing ("sunnam", "vannam", "safedi"),
     efflorescence on painted surfaces.

6. "Cleaning":
   - Bathroom tile acid wash, chimney grease, sofa/mattress shampoo, house sanitization.

7. "Welder / Metal":
   - Gate broken hinge, balcony grill loose, rolling shutter, metal railing rust/sag
     ("irumbu", "loha").

8. "Masonry":
   - Broken/hollow tiles, tile debonding, re-grouting, plaster cracks, hairline/structural cracks,
     efflorescence, brickwork ("kothanar", "mistri", "patthar").

═══════════════════════════════════════════════════════════════════════════
DISAMBIGUATION RULES (critical)
═══════════════════════════════════════════════════════════════════════════
- Refrigerator water: "Appliance Repair" NOT "Plumber".
- AC indoor drip: "Appliance Repair" NOT "Plumber".
- Ceiling/table fan: "Electrician" NEVER "Air Conditioner".
- Water motor: "Electrician" primary, "Plumber" secondary.

═══════════════════════════════════════════════════════════════════════════
CROSS-DISCIPLINE DUAL-TRADE ROUTING (critical)
═══════════════════════════════════════════════════════════════════════════
When a complaint genuinely spans two crafts — e.g. a geyser giving an electric shock AND leaking
water, a water motor with both wiring and pump-body symptoms, or a bathroom fitting with both
electrical and plumbing failure signs — you MUST:
1. Populate BOTH "primaryCategory" (the more urgent/likely root cause trade) and
   "secondaryCategory" (the complementary trade).
2. Set "requiresSmartDiagnosticVisit": true.
3. Set "diagnosticFee": 149.0 (the dual-trade smart-visit fee).
For single-trade complaints, leave "secondaryCategory": null and use the standard fee of 99.0
unless the model has strong reason to believe a smart diagnostic visit is still warranted for a
single trade, in which case keep diagnosticFee at 99.0 with requiresSmartDiagnosticVisit as
appropriate.

═══════════════════════════════════════════════════════════════════════════
OUT-OF-SCOPE RULE (negative enforcement — critical)
═══════════════════════════════════════════════════════════════════════════
The following categories are NEVER household trades and must NEVER be assigned a craft category,
even partially or speculatively:
- Vehicles: cars, bikes, scooters, vehicle servicing, tyres, batteries for vehicles.
- Personal electronics: smartphones, laptops, tablets, earphones, smartwatches.
- Medical: symptoms of illness, medicines, doctor visits, injuries to people or pets.
- Food delivery, restaurants, groceries.
- Pets: veterinary care, pet grooming, pet food.
- Clothing, tailoring, footwear, salon/beauty services, banking, stationery, or gibberish input.

For ANY such query, or anything else outside household repair trades, respond ONLY with:
{
  "primaryCategory": "Out of Scope",
  "secondaryCategory": null,
  "confidence": 0.0,
  "equipmentTag": "Non-Household Service",
  "summary": "<one clear sentence explaining this is outside WorkGo's household repair services>",
  "likelyCauses": [],
  "clarifyingQuestions": [],
  "suggestedKeywords": [],
  "suggestedToolsNeeded": [],
  "requiresSmartDiagnosticVisit": false,
  "diagnosticFee": 0.0,
  "isOutOfScope": true
}
NEVER guess a trade for out-of-scope requests, even if a household-sounding word appears
incidentally in the text.

═══════════════════════════════════════════════════════════════════════════
OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════════
Output ONLY valid JSON matching this exact schema. No markdown, no code fences, no explanation
text before or after the JSON:
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

// ── Deterministic Catalog Fallback (Tier 3) ────────────────────────────────────
// Lightweight keyword-based classifier used when Gemini errors or rate-limits, so
// the customer still gets a routed trade instead of a raw failure. Deliberately
// conservative: low confidence, always requires a human diagnostic visit.
const CATALOG_RULES = [
  {
    category: "Electrician",
    equipmentTag: "Ceiling Fan / Home Appliance",
    keywords: ["fan", "pankha", "kaathadi", "mirchi fan", "suthu"],
  },
  {
    category: "Electrician",
    equipmentTag: "Electrical Wiring / MCB",
    keywords: [
      "mcb", "fuse", "spark", "shock", "wiring", "switchboard", "earth leakage",
      "inverter", "battery", "bijli", "current", "trip",
    ],
  },
  {
    category: "Plumber",
    equipmentTag: "Piping / Drainage",
    keywords: [
      "pipe", "leak", "tap", "faucet", "drain", "choke", "adaipu", "paani band",
      "cistern", "angle cock", "riss", "thani",
    ],
  },
  {
    category: "Appliance Repair",
    equipmentTag: "Home Appliance",
    keywords: [
      "fridge", "refrigerator", "ac", "air condition", "geyser", "water heater",
      "microwave", "washing machine", "mixer", "ro ", "gas stove", "hob",
    ],
  },
  {
    category: "Carpenter",
    equipmentTag: "Door / Furniture",
    keywords: ["lock", "pootu", "saavi", "darwaza", "hinge", "wardrobe", "cupboard", "door"],
  },
  {
    category: "Painter",
    equipmentTag: "Wall / Surface",
    keywords: ["paint", "damp", "putty", "waterproof", "sunnam", "vannam", "safedi"],
  },
  {
    category: "Cleaning",
    equipmentTag: "Cleaning Service",
    keywords: ["clean", "acid wash", "chimney grease", "sofa shampoo", "sanitiz"],
  },
  {
    category: "Welder / Metal",
    equipmentTag: "Metal / Gate",
    keywords: ["gate", "grill", "shutter", "railing", "irumbu", "loha", "rust"],
  },
  {
    category: "Masonry",
    equipmentTag: "Masonry / Tiles",
    keywords: ["tile", "crack", "plaster", "brick", "kothanar", "mistri", "patthar", "grout"],
  },
];

const OUT_OF_SCOPE_KEYWORDS = [
  "car", "bike", "scooter", "vehicle", "tyre", "phone", "smartphone", "laptop",
  "tablet", "earphone", "smartwatch", "doctor", "medicine", "fever", "vet",
  "pet food", "restaurant", "food delivery", "grocery", "salon", "haircut",
  "bank", "loan", "tailor", "shoe", "clothing",
];

function catalogFallback(query) {
  const q = query.toLowerCase();

  for (const kw of OUT_OF_SCOPE_KEYWORDS) {
    if (q.includes(kw)) {
      return sanitizeResult(
        {
          primaryCategory: "Out of Scope",
          secondaryCategory: null,
          confidence: 0.0,
          equipmentTag: "Non-Household Service",
          summary: "This request falls outside WorkGo's household repair services.",
          isOutOfScope: true,
        },
        query
      );
    }
  }

  const matches = CATALOG_RULES.filter((rule) =>
    rule.keywords.some((kw) => q.includes(kw))
  );

  if (matches.length === 0) {
    return sanitizeResult(
      {
        primaryCategory: "Out of Scope",
        secondaryCategory: null,
        confidence: 0.0,
        equipmentTag: "Non-Household Service",
        summary:
          "Could not confidently match this description to a household trade using the offline catalog.",
        isOutOfScope: true,
      },
      query
    );
  }

  const primary = matches[0];
  const secondary = matches.length > 1 ? matches[1] : null;

  return sanitizeResult(
    {
      primaryCategory: primary.category,
      secondaryCategory: secondary ? secondary.category : null,
      confidence: 0.5,
      equipmentTag: primary.equipmentTag,
      summary: `Offline catalog match based on keywords in the description (trade: ${primary.category}).`,
      likelyCauses: [],
      clarifyingQuestions: [],
      suggestedKeywords: [],
      suggestedToolsNeeded: [],
      requiresSmartDiagnosticVisit: true,
      diagnosticFee: secondary ? DUAL_TRADE_FEE : SINGLE_TRADE_FEE,
      isOutOfScope: false,
    },
    query
  );
}

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
 * Also enforces the dual-trade fee/visit contract regardless of what the model returned.
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
    !isOutOfScope &&
    raw.secondaryCategory &&
    VALID_CATEGORIES.has(raw.secondaryCategory) &&
    raw.secondaryCategory !== primaryCategory &&
    raw.secondaryCategory !== "Out of Scope"
      ? raw.secondaryCategory
      : null;

  const isDualTrade = !isOutOfScope && secondaryCategory !== null;

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
    // Dual-trade complaints always require a smart diagnostic visit, per routing rules.
    requiresSmartDiagnosticVisit: isOutOfScope
      ? false
      : isDualTrade
      ? true
      : raw.requiresSmartDiagnosticVisit !== false,
    // Fee is authoritative from the backend, not the model: 149 for dual-trade, else 99 default
    // (or whatever numeric fee the model supplied for a single-trade smart visit).
    diagnosticFee: isOutOfScope
      ? 0.0
      : isDualTrade
      ? DUAL_TRADE_FEE
      : Math.max(0, Number(raw.diagnosticFee) || SINGLE_TRADE_FEE),
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
        maxOutputTokens: 1024,
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

    // ── Gemini 1.5 Flash Inference (Tier 2) ──────────────────────────────────
    let result;
    let source = "gemini";
    try {
      result = await callGemini(cleanQuery, languageCode);
    } catch (geminiErr) {
      console.error(`[ai/triage] Gemini failed: ${geminiErr.message}`);

      // ── Deterministic Catalog Fallback (Tier 3) ────────────────────────────
      try {
        result = catalogFallback(cleanQuery);
        source = "catalog_fallback";
        console.log(
          `[ai/triage] FALLBACK  category="${result.primaryCategory}"` +
          `  query="${cleanQuery.slice(0, 40)}"`
        );
      } catch (fallbackErr) {
        console.error(`[ai/triage] Catalog fallback failed: ${fallbackErr.message}`);
        // Signal Flutter to use on-device Tier 4 fallback
        return res.status(503).json({
          error: "AI inference temporarily unavailable",
          code: "AI_UNAVAILABLE",
          retryAfterMs: 2000,
        });
      }
    }

    // ── Persist to Firestore (fire-and-forget) ───────────────────────────────
    // Only cache high-trust Gemini results; low-confidence catalog fallbacks are
    // re-attempted against Gemini on the next identical query instead of being
    // permanently baked into the cache.
    if (source === "gemini") {
      cacheRef
        .set({ ...result, _cachedAt: new Date().toISOString(), _source: "gemini" })
        .catch((e) => console.error("[ai/triage] Cache write failed:", e.message));
    }

    console.log(
      `[ai/triage] SUCCESS  category="${result.primaryCategory}"` +
      `${result.secondaryCategory ? ` + "${result.secondaryCategory}"` : ""}` +
      `  confidence=${Math.round(result.confidence * 100)}%` +
      `  source=${source}` +
      `  query="${cleanQuery.slice(0, 40)}"`
    );

    return res.json({ ...result, source });
  } catch (err) {
    console.error("[ai/triage] Unhandled error:", err);
    return res.status(500).json({ error: "Internal server error during AI triage" });
  }
});

module.exports = router;
