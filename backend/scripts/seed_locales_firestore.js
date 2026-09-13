/**
 * Firestore Locale Seeder for WorkGo 360 Multilingual System
 *
 * Seeds:
 * 1. `locales/en` with master English strings
 * 2. `locales/hi` with Hindi strings
 * 3. `locales/ta` with Tamil strings
 * 4. `locales/_metadata` with all 22 Official Scheduled Indian Languages
 */

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
    ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
    : fs.existsSync(path.resolve(__dirname, "../serviceAccountKey.json"))
    ? require("../serviceAccountKey.json")
    : null;

  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || "workgo-sih2026",
    });
  } else {
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || "workgo-sih2026",
    });
  }
}

const db = admin.firestore();

const ALL_LANGUAGES = [
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
  { code: "sat", name: "Santali", nativeName: "ᱥᱟᱱཏᱟᱲᱤ", region: "East" },
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

async function seed() {
  console.log("🚀 Starting Firestore Locales Seeder...");

  // 1. Seed Metadata
  console.log("📝 Writing `locales/_metadata` (22 official Indian languages)...");
  await db.collection("locales").doc("_metadata").set({
    languages: ALL_LANGUAGES,
    count: ALL_LANGUAGES.length,
    updatedAt: new Date().toISOString(),
  }, { merge: true });

  // 2. Seed Baseline Locales: en, hi, ta
  const langDir = path.resolve(__dirname, "../../packages/workgo_core/assets/lang");
  const baselineCodes = ["en", "hi", "ta"];

  for (const code of baselineCodes) {
    const filePath = path.join(langDir, `${code}.json`);
    if (fs.existsSync(filePath)) {
      console.log(`📦 Seeding 'locales/${code}' from ${filePath}...`);
      const raw = fs.readFileSync(filePath, "utf-8");
      const strings = JSON.parse(raw);
      const meta = ALL_LANGUAGES.find((l) => l.code === code);

      await db.collection("locales").doc(code).set({
        code,
        name: meta ? meta.name : code,
        nativeName: meta ? meta.nativeName : code,
        strings,
        totalKeys: Object.keys(strings).length,
        updatedAt: new Date().toISOString(),
      }, { merge: true });

      console.log(`✅ 'locales/${code}' seeded with ${Object.keys(strings).length} keys.`);
    } else {
      console.warn(`⚠️ Asset file not found: ${filePath}`);
    }
  }

  console.log("🎉 Locales seeding completed successfully!");
}

if (require.main === module) {
  seed()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("❌ Seeding failed:", err);
      process.exit(1);
    });
}

module.exports = { seed };
