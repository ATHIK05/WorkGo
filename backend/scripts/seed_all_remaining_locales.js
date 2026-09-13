/**
 * WorkGo Multilingual Seeder: All Remaining Scheduled Indian Languages
 *
 * Translates master `en.json` and pushes directly to Cloud Firestore `locales/{code}`:
 * 1. te (Telugu)
 * 2. kn (Kannada)
 * 3. ml (Malayalam)
 * 4. mr (Marathi)
 * 5. bn (Bengali)
 * 6. pa (Punjabi)
 * 7. ur (Urdu)
 * 8. or (Odia)
 * 9. as (Assamese)
 * 10. ne (Nepali)
 * 11. sa (Sanskrit)
 * 12. doi (Dogri)
 * 13. sd (Sindhi)
 * 14. mai (Maithili)
 * 15. sat (Santali)
 * 16. kok (Konkani)
 * 17. mni (Manipuri)
 * 18. ks (Kashmiri)
 * 19. brx (Bodo)
 */

const fs = require("fs");
const path = require("path");
const https = require("https");
const admin = require("firebase-admin");

// Init Firebase Admin
if (!admin.apps.length) {
  const sa = require("../serviceAccountKey.json");
  admin.initializeApp({
    credential: admin.credential.cert(sa),
    projectId: "workgo-sih2026",
  });
}
const db = admin.firestore();

// 22 Scheduled Indian Languages metadata
const ALL_LANGUAGES = [
  { code: "en", name: "English", nativeName: "English", region: "Pan-India" },
  { code: "hi", name: "Hindi", nativeName: "हिन्दी", region: "North" },
  { code: "ta", name: "Tamil", nativeName: "தமிழ்", region: "South" },
  { code: "gu", name: "Gujarati", nativeName: "ગુજરાતી", region: "West" },
  { code: "te", name: "Telugu", nativeName: "తెలుగు", region: "South" },
  { code: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ", region: "South" },
  { code: "ml", name: "Malayalam", nativeName: "മലയാളം", region: "South" },
  { code: "mr", name: "Marathi", nativeName: "मराठी", region: "West" },
  { code: "bn", name: "Bengali", nativeName: "বাংলা", region: "East" },
  { code: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ", region: "North" },
  { code: "ur", name: "Urdu", nativeName: "اردو", region: "North & Deccan" },
  { code: "or", name: "Odia", nativeName: "ଓଡ଼ିଆ", region: "East" },
  { code: "as", name: "Assamese", nativeName: "অসমীয়া", region: "Northeast" },
  { code: "ne", name: "Nepali", nativeName: "नेपाली", region: "East" },
  { code: "sa", name: "Sanskrit", nativeName: "संस्कृतम्", region: "Classical" },
  { code: "doi", name: "Dogri", nativeName: "डोगरी", region: "North" },
  { code: "sd", name: "Sindhi", nativeName: "سنڌي / सिंधी", region: "West" },
  { code: "mai", name: "Maithili", nativeName: "मैथिली", region: "East" },
  { code: "sat", name: "Santali", nativeName: "ᱥᱟᱱᱛᱟᱲᱤ", region: "East" },
  { code: "kok", name: "Konkani", nativeName: "कोंकणी", region: "West" },
  { code: "mni", name: "Manipuri", nativeName: "ꯃৈতꯩꯂꯣꯟ", region: "Northeast" },
  { code: "ks", name: "Kashmiri", nativeName: "کٲشُر / कश्मीरी", region: "North" },
  { code: "brx", name: "Bodo", nativeName: "बर'", region: "Northeast" },
];

// Target code mappings for Google Translate endpoint
const GOOGLE_TARGET_MAP = {
  mni: "mni-Mtei",
  kok: "gom",
  doi: "doi",
  mai: "mai",
  sat: "sat",
  ne: "ne",
  pa: "pa",
  mr: "mr",
  bn: "bn",
  as: "as",
  or: "or",
  te: "te",
  kn: "kn",
  ml: "ml",
  sa: "sa",
  ur: "ur",
  sd: "sd",
  ks: "hi", // Devanagari Hindi regional base
  brx: "as", // Bodo regional Assamese script base
};

function translateText(text, targetLang) {
  if (!text || typeof text !== "string" || text.trim() === "") {
    return Promise.resolve(text);
  }
  const masked = text.replace(/\{\}/g, "___VAR___");
  const actualTarget = GOOGLE_TARGET_MAP[targetLang] || targetLang;
  const url = `https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=${encodeURIComponent(
    actualTarget
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

async function translateDictionary(enStrings, langCode) {
  const result = {};
  const entries = Object.entries(enStrings);
  const BATCH_SIZE = 30;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const promises = chunk.map(async ([k, v]) => {
      if (k.startsWith("_comment") || typeof v !== "string") {
        return [k, v];
      }
      const trans = await translateText(v, langCode);
      return [k, trans];
    });

    const translatedChunk = await Promise.all(promises);
    for (const [k, v] of translatedChunk) {
      result[k] = v;
    }
    await new Promise((r) => setTimeout(r, 40));
  }
  return result;
}

async function main() {
  console.log("🚀 Starting Bulk Locales Seeder for All 22 Scheduled Indian Languages...");

  const enPath = path.resolve(__dirname, "../../packages/workgo_core/assets/lang/en.json");
  const enStrings = JSON.parse(fs.readFileSync(enPath, "utf-8"));
  console.log(`📖 Master en.json loaded: ${Object.keys(enStrings).length} keys.`);

  // Remaining languages to process (excluding already completed en, hi, ta, gu)
  const remainingLangs = [
    "te", // Telugu
    "kn", // Kannada
    "ml", // Malayalam
    "mr", // Marathi
    "bn", // Bengali
    "pa", // Punjabi
    "ur", // Urdu
    "or", // Odia
    "as", // Assamese
    "ne", // Nepali
    "sa", // Sanskrit
    "doi", // Dogri
    "sd", // Sindhi
    "mai", // Maithili
    "sat", // Santali
    "kok", // Konkani
    "mni", // Manipuri
    "ks", // Kashmiri
    "brx", // Bodo
  ];

  console.log(`📋 ${remainingLangs.length} languages queued for processing.`);

  const coreLangDir = path.resolve(__dirname, "../../packages/workgo_core/assets/lang");
  const backendLangDir = path.resolve(__dirname, "../locales");
  if (!fs.existsSync(backendLangDir)) fs.mkdirSync(backendLangDir, { recursive: true });

  for (let idx = 0; idx < remainingLangs.length; idx++) {
    const code = remainingLangs[idx];
    const meta = ALL_LANGUAGES.find((l) => l.code === code) || {
      code,
      name: code,
      nativeName: code,
      region: "India",
    };

    console.log(`\n──────────────────────────────────────────────────`);
    console.log(`[${idx + 1}/${remainingLangs.length}] Processing ${meta.name} (${meta.nativeName}) ['${code}']...`);

    // Check if already in Firestore
    const docRef = db.collection("locales").doc(code);
    const existingSnap = await docRef.get();
    if (existingSnap.exists && existingSnap.data().totalKeys > 900) {
      console.log(`⚡ Already cached in Firestore with ${existingSnap.data().totalKeys} keys. Skipping.`);
      continue;
    }

    const startTime = Date.now();
    const translatedStrings = await translateDictionary(enStrings, code);
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    // Write local backup JSON files
    const coreFilePath = path.join(coreLangDir, `${code}.json`);
    const backendFilePath = path.join(backendLangDir, `${code}.json`);
    fs.writeFileSync(coreFilePath, JSON.stringify(translatedStrings, null, 2), "utf-8");
    fs.writeFileSync(backendFilePath, JSON.stringify(translatedStrings, null, 2), "utf-8");

    // Write to Firestore
    await docRef.set({
      code,
      name: meta.name,
      nativeName: meta.nativeName,
      region: meta.region,
      strings: translatedStrings,
      totalKeys: Object.keys(translatedStrings).length,
      updatedAt: new Date().toISOString(),
    }, { merge: true });

    console.log(`✅ [${code}] ${meta.name} seeded: ${Object.keys(translatedStrings).length} keys in ${duration}s.`);
  }

  // Update _metadata
  console.log(`\n📝 Refreshing locales/_metadata...`);
  await db.collection("locales").doc("_metadata").set({
    languages: ALL_LANGUAGES,
    count: ALL_LANGUAGES.length,
    updatedAt: new Date().toISOString(),
  }, { merge: true });

  console.log(`\n🎉 All 22 Scheduled Indian Languages (+ English) successfully seeded into Firestore!`);
  process.exit(0);
}

main().catch((err) => {
  console.error("Bulk seeding error:", err);
  process.exit(1);
});
