const express = require("express");
const router = express.Router();
const fs = require("fs");
const path = require("path");
const https = require("https");

// 22 Official Indian Languages (+ English)
const ALL_SUPPORTED_LANGUAGES = [
  { code: "en", name: "English", nativeName: "English", region: "Pan-India" },
  { code: "hi", name: "Hindi", nativeName: "हिन्दी", region: "North" },
  { code: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ", region: "North" },
  { code: "gu", name: "Gujarati", nativeName: "ગુજરાતી", region: "West" },
  { code: "mr", name: "Marathi", nativeName: "मराठी", region: "West" },
  { code: "ks", name: "Kashmiri", nativeName: "کٲشُر / कश्मीरी", region: "North" },
  { code: "doi", name: "Dogri", nativeName: "डोगरी", region: "North" },
  { code: "sd", name: "Sindhi", nativeName: "سنڌي / सिंधी", region: "West" },
  { code: "bn", name: "Bengali", nativeName: "বাংলা", region: "East" },
  { code: "as", name: "Assamese", nativeName: "অসমীয়া", region: "Northeast" },
  { code: "or", name: "Odia", nativeName: "ଓଡ଼ିଆ", region: "East" },
  { code: "mai", name: "Maithili", nativeName: "मैथिली", region: "East" },
  { code: "sat", name: "Santali", nativeName: "ᱥᱟᱱᱛᱟᱲᱤ", region: "East" },
  { code: "brx", name: "Bodo", nativeName: "बर'", region: "Northeast" },
  { code: "mni", name: "Manipuri", nativeName: "মৈতৈলোন্", region: "Northeast" },
  { code: "ne", name: "Nepali", nativeName: "नेपाली", region: "East" },
  { code: "te", name: "Telugu", nativeName: "తెలుగు", region: "South" },
  { code: "ta", name: "Tamil", nativeName: "தமிழ்", region: "South" },
  { code: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ", region: "South" },
  { code: "ml", name: "Malayalam", nativeName: "മലയാളം", region: "South" },
  { code: "sa", name: "Sanskrit", nativeName: "संस्कृतम्", region: "Classical" },
  { code: "ur", name: "Urdu", nativeName: "اردو", region: "North & Deccan" },
  { code: "kok", name: "Konkani", nativeName: "कोंकणी", region: "West" },
];

/**
 * Translates a single text string using Google Translate GTX endpoint (Zero API key needed)
 * while strictly preserving easy_localization placeholders like `{}`.
 */
function translateText(text, targetLang) {
  if (!text || typeof text !== "string" || text.trim() === "") {
    return Promise.resolve(text);
  }

  // Mask {} placeholder
  const masked = text.replace(/\{\}/g, "___VAR___");
  const url = `https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=${encodeURIComponent(
    targetLang
  )}&q=${encodeURIComponent(masked)}`;

  return new Promise((resolve) => {
    https
      .get(url, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(body);
            let result = Array.isArray(parsed) ? parsed[0] : parsed;
            if (result && typeof result === "string") {
              result = result.replace(/___\s*VAR\s*___/g, "{}").replace(/___VAR___/g, "{}");
              return resolve(result);
            }
            resolve(text);
          } catch (_) {
            resolve(text);
          }
        });
      })
      .on("error", () => resolve(text));
  });
}

/**
 * Batches translation of a JSON dictionary with concurrency throttling.
 */
async function batchTranslateStrings(stringsMap, targetLang) {
  if (targetLang === "en") return stringsMap;

  const entries = Object.entries(stringsMap);
  const result = {};
  const BATCH_SIZE = 15;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const promises = chunk.map(async ([key, value]) => {
      if (key.startsWith("_comment") || typeof value !== "string") {
        return [key, value];
      }
      const translated = await translateText(value, targetLang);
      return [key, translated];
    });

    const translatedChunk = await Promise.all(promises);
    for (const [k, v] of translatedChunk) {
      result[k] = v;
    }
  }

  return result;
}

/**
 * GET /api/locales/supported
 * List all 22 official scheduled languages of India + English
 */
router.get("/supported", (_req, res) => {
  res.json({
    count: ALL_SUPPORTED_LANGUAGES.length,
    languages: ALL_SUPPORTED_LANGUAGES,
  });
});

/**
 * GET /api/locales/:langCode
 * Get cached strings for a language directly from Firestore
 */
router.get("/:langCode", async (req, res) => {
  const { langCode } = req.params;
  const db = req.db;

  try {
    const docSnap = await db.collection("locales").doc(langCode.toLowerCase()).get();
    if (!docSnap.exists) {
      return res.status(404).json({ error: `Language '${langCode}' not yet cached in Firestore` });
    }
    return res.json(docSnap.data());
  } catch (err) {
    return res.status(500).json({ error: "Failed to fetch locale", detail: err.message });
  }
});

/**
 * POST /api/locales/resolve
 * JIT on-demand translation cache builder.
 */
router.post("/resolve", async (req, res) => {
  const { langCode } = req.body;
  const db = req.db;

  if (!langCode) {
    return res.status(400).json({ error: "Missing required field: langCode" });
  }

  const target = langCode.toLowerCase();
  const langMatch = ALL_SUPPORTED_LANGUAGES.find((l) => l.code === target);
  if (!langMatch) {
    return res.status(400).json({ error: `Unsupported language code: ${langCode}` });
  }

  try {
    const docRef = db.collection("locales").doc(target);
    const docSnap = await docRef.get();

    // 1. If already cached in Firestore, return immediately in 0ms
    if (docSnap.exists) {
      const data = docSnap.data();
      return res.json({
        status: "cached",
        langCode: target,
        strings: data.strings || data,
      });
    }

    // 2. Check if a pre-bundled file exists (e.g. en.json, hi.json, ta.json)
    const candidateDirs = [
      path.resolve(__dirname, "../../locales"),
      path.resolve(__dirname, "../../../packages/workgo_core/assets/lang"),
    ];
    const langDir = candidateDirs.find((d) => fs.existsSync(d)) || candidateDirs[0];
    const bundledPath = path.join(langDir, `${target}.json`);
    let targetStrings = null;

    if (fs.existsSync(bundledPath)) {
      try {
        targetStrings = JSON.parse(fs.readFileSync(bundledPath, "utf-8"));
      } catch (e) {
        console.warn(`[locales.js] Failed to parse bundled ${target}.json:`, e.message);
      }
    }

    // 3. If not pre-bundled, load master en.json and translate values
    if (!targetStrings) {
      const enJsonPath = path.join(langDir, "en.json");
      let masterStrings = {};
      if (fs.existsSync(enJsonPath)) {
        try {
          masterStrings = JSON.parse(fs.readFileSync(enJsonPath, "utf-8"));
        } catch (e) {
          console.warn("[locales.js] Failed to parse en.json:", e.message);
        }
      }

      console.log(`[locales.js] JIT translating ${Object.keys(masterStrings).length} keys into '${target}'...`);
      targetStrings = await batchTranslateStrings(masterStrings, target);
    }

    // 4. Persist in Firestore so all future users load in 0ms with zero extra cost
    const payload = {
      code: langMatch.code,
      name: langMatch.name,
      nativeName: langMatch.nativeName,
      region: langMatch.region,
      strings: targetStrings,
      totalKeys: Object.keys(targetStrings).length,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await docRef.set(payload, { merge: true });

    return res.json({
      status: "resolved_and_cached",
      langCode: target,
      strings: payload.strings,
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to resolve locale", detail: err.message });
  }
});

/**
 * POST /api/locales/seed
 * Seeds metadata and baseline locales (en, hi, ta) into Firestore.
 */
router.post("/seed", async (req, res) => {
  const db = req.db;
  try {
    // 1. Seed Metadata
    await db.collection("locales").doc("_metadata").set(
      {
        languages: ALL_SUPPORTED_LANGUAGES,
        count: ALL_SUPPORTED_LANGUAGES.length,
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    // 2. Seed Baseline Locales
    const candidateDirs = [
      path.resolve(__dirname, "../../locales"),
      path.resolve(__dirname, "../../../packages/workgo_core/assets/lang"),
    ];
    const langDir = candidateDirs.find((d) => fs.existsSync(d)) || candidateDirs[0];
    const baselineCodes = ["en", "hi", "ta"];
    const seeded = [];

    for (const code of baselineCodes) {
      const filePath = path.join(langDir, `${code}.json`);
      if (fs.existsSync(filePath)) {
        const raw = fs.readFileSync(filePath, "utf-8");
        const strings = JSON.parse(raw);
        const meta = ALL_SUPPORTED_LANGUAGES.find((l) => l.code === code);

        await db.collection("locales").doc(code).set(
          {
            code,
            name: meta ? meta.name : code,
            nativeName: meta ? meta.nativeName : code,
            strings,
            totalKeys: Object.keys(strings).length,
            updatedAt: new Date().toISOString(),
          },
          { merge: true }
        );
        seeded.push({ code, keys: Object.keys(strings).length });
      }
    }

    return res.json({
      success: true,
      message: "Metadata and baseline locales seeded successfully",
      metadataCount: ALL_SUPPORTED_LANGUAGES.length,
      seeded,
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to seed locales", detail: err.message });
  }
});

module.exports = router;
