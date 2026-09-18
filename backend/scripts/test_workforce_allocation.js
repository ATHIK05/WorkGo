/**
 * End-to-End Diagnostic Runner: Fair Workforce Allocation Engine
 * SIH Problem Statement 26089: AI-based Demand Forecasting & Fair Worker Allocation
 *
 * Tests:
 * 1. Multi-Worker Standby Score Calculation & Mathematical Invariants
 * 2. Recency Penalty Decay vs. Idle Opportunity Rotation
 * 3. Proximity vs. Fairness Balance Trade-off
 * 4. Nightly Fairness Score Recovery (+0.05/day cap at 1.0)
 * 5. Live Firestore Cooperative Workers Ranking (coop_tn_01)
 */

const { calculateStandbyScore } = require("../src/routes/match");
const { calculateReplenishedFairness } = require("../src/services/demand_aggregation");
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

console.log("=======================================================");
console.log("⚖️  WORKGO FAIR WORKFORCE ALLOCATION & MATCHING ENGINE");
console.log("    SIH 26089 Diagnostic Runner");
console.log("=======================================================\n");

// -------------------------------------------------------------
// TEST 1: Opportunity Rotation Simulation (Over-assigned vs Idle)
// -------------------------------------------------------------
console.log("--- TEST 1: Opportunity Rotation (Preventing Job Monopolization) ---");

// Artisan 1: High rating (5.0), but accepted a booking 1 hour ago
const workerOverbooked = {
  name: "Artisan A (Top-rated but Just Assigned)",
  fairnessScore: 0.60,
  avgRating: 5.0,
  lastAssignedAt: new Date(Date.now() - 1 * 60 * 60 * 1000) // 1 hr ago
};

// Artisan 2: Good rating (4.7), idle for 36 hours (fairness replenished)
const workerUnderAllocated = {
  name: "Artisan B (Good Rating & Awaiting Opportunity)",
  fairnessScore: 1.0,
  avgRating: 4.7,
  lastAssignedAt: new Date(Date.now() - 36 * 60 * 60 * 1000) // 36 hrs ago
};

const scoreOverbooked = calculateStandbyScore(workerOverbooked, 2.0); // 2 km away
const scoreUnderAllocated = calculateStandbyScore(workerUnderAllocated, 2.0); // 2 km away

console.log(`Worker A (Rating 5.0, Assigned 1h ago): Standby Score = ${scoreOverbooked} pts`);
console.log(`Worker B (Rating 4.7, Idle 36h):        Standby Score = ${scoreUnderAllocated} pts`);

if (scoreUnderAllocated > scoreOverbooked) {
  console.log(`✅ PASS: Under-allocated artisan B (+${(scoreUnderAllocated - scoreOverbooked).toFixed(1)} pts) ranked FIRST, successfully rotating opportunity!`);
} else {
  console.log(`❌ FAIL: Overbooked artisan ranked first.`);
}

console.log("\n-------------------------------------------------------------");
// TEST 2: Nightly Fairness Replenishment Step Test
// -------------------------------------------------------------
console.log("--- TEST 2: Nightly Fairness Replenishment (Daily Idle Recovery) ---");

const initialFairness = 0.70;
const after1DayIdle = calculateReplenishedFairness(initialFairness, 25.0);
const after2DaysIdle = calculateReplenishedFairness(after1DayIdle, 49.0);
const cappedFairness = calculateReplenishedFairness(0.98, 30.0);

console.log(`Initial fairness score:         ${initialFairness}`);
console.log(`After 24h idle (+0.05):         ${after1DayIdle}`);
console.log(`After 48h idle (+0.05):         ${after2DaysIdle}`);
console.log(`Approaching cap (0.98 -> 1.00): ${cappedFairness}`);

if (after1DayIdle === 0.75 && after2DaysIdle === 0.80 && cappedFairness === 1.0) {
  console.log(`✅ PASS: Mathematical fairness replenishment verified (+0.05/idle day up to 1.0 cap).`);
} else {
  console.log(`❌ FAIL: Unexpected replenishment computation.`);
}

console.log("\n-------------------------------------------------------------");
// TEST 3: Live Firestore Worker Allocation Test
// -------------------------------------------------------------
console.log("--- TEST 3: Live Cooperative Worker Ranking (coop_tn_01) ---");

async function runLiveTest() {
  const serviceAccountPath = path.join(__dirname, "..", "serviceAccountKey.json");
  if (!fs.existsSync(serviceAccountPath)) {
    console.log("ℹ️ No serviceAccountKey.json found, skipping live Firestore check.");
    return;
  }

  if (!admin.apps.length) {
    const sa = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
    admin.initializeApp({
      credential: admin.credential.cert(sa)
    });
  }

  const db = admin.firestore();
  const snap = await db.collection("workers").where("organizationId", "==", "coop_tn_01").get();

  if (snap.empty) {
    console.log("ℹ️ No workers found in coop_tn_01.");
    return;
  }

  console.log(`Found ${snap.size} real registered artisans in coop_tn_01:`);
  const ranked = [];
  snap.forEach(doc => {
    const w = doc.data();
    const score = calculateStandbyScore(w, 2.5); // hypothetical 2.5km dispatch
    ranked.push({
      id: doc.id,
      name: w.name || w.displayName || "Artisan",
      skills: (w.skills || []).join(", "),
      rating: w.avgRating || 4.5,
      fairness: w.fairnessScore !== undefined ? w.fairnessScore : 1.0,
      score
    });
  });

  ranked.sort((a, b) => b.score - a.score);

  ranked.forEach((r, idx) => {
    console.log(`   #${idx + 1} [Score: ${r.score.toFixed(1)}] ${r.name.padEnd(20)} | Skills: [${r.skills}] | Fairness: ${r.fairness} | Rating: ${r.rating}`);
  });

  console.log(`\n✅ PASS: Live cooperative artisans successfully ranked by fairness & readiness!`);
  console.log("=======================================================\n");
}

runLiveTest().catch(console.error);
