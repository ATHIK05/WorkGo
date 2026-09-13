/**
 * Translates master en.json into Gujarati (gu) and writes:
 * 1. packages/workgo_core/assets/lang/gu.json
 * 2. backend/locales/gu.json
 * 3. Firestore document: locales/gu
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

function translateText(text, targetLang) {
  if (!text || typeof text !== "string" || text.trim() === "") {
    return Promise.resolve(text);
  }
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

async function main() {
  console.log("🚀 Translating en.json into Gujarati (gu)...");
  const enPath = path.resolve(__dirname, "../../packages/workgo_core/assets/lang/en.json");
  const enStrings = JSON.parse(fs.readFileSync(enPath, "utf-8"));

  const guStrings = {};
  const entries = Object.entries(enStrings);
  const BATCH_SIZE = 25;

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const promises = chunk.map(async ([k, v]) => {
      if (k.startsWith("_comment") || typeof v !== "string") {
        return [k, v];
      }
      const trans = await translateText(v, "gu");
      return [k, trans];
    });

    const translatedChunk = await Promise.all(promises);
    for (const [k, v] of translatedChunk) {
      guStrings[k] = v;
    }
    process.stdout.write(`\r[${Math.min(i + BATCH_SIZE, entries.length)} / ${entries.length}] translated...`);
    // Brief breather between batches
    await new Promise((r) => setTimeout(r, 60));
  }
  console.log("\n✅ Translation complete!");

  // Save to disk
  const coreGuPath = path.resolve(__dirname, "../../packages/workgo_core/assets/lang/gu.json");
  const backendGuPath = path.resolve(__dirname, "../locales/gu.json");
  fs.writeFileSync(coreGuPath, JSON.stringify(guStrings, null, 2), "utf-8");
  fs.writeFileSync(backendGuPath, JSON.stringify(guStrings, null, 2), "utf-8");
  console.log(`💾 Saved to ${coreGuPath} and ${backendGuPath}`);

  // Push to Firestore
  console.log("☁️ Uploading to Firestore 'locales/gu'...");
  await db.collection("locales").doc("gu").set({
    code: "gu",
    name: "Gujarati",
    nativeName: "ગુજરાતી",
    region: "West",
    strings: guStrings,
    totalKeys: Object.keys(guStrings).length,
    updatedAt: new Date().toISOString(),
  }, { merge: true });

  console.log("🎉 'locales/gu' successfully seeded into Firestore!");
  process.exit(0);
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
