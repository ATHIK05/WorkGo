const holidays = require("../data/india_holidays.json");
const { getWeatherForecast } = require("./weather");
const { computePredictedDemand } = require("./demand_model");

/**
 * Nightly Demand Aggregation & Contextual Feature Extraction Job.
 *
 * ARCHITECTURAL CONTEXT (SIH Problem Statement 26089 - AI Demand Forecasting):
 * 1. Server-Side Compute Only: WorkGo artisans operate low-to-mid range Android
 *    devices. All feature aggregation, contextual extraction, and inference run
 *    server-side, exposing clean REST insights for mobile consumption.
 * 2. Cooperative Granularity: Operates at the organizationId level (the cooperative
 *    administrative unit). No geohash abstraction is introduced.
 * 3. Cooperative-Admin Local Events: Local Indian festivals and melas are entered
 *    directly by cooperative admins into `local_events` rather than scraped,
 *    providing authentic, verified ground-truth demand drivers.
 * 4. In-Place Extension: Extends `demandStats/{regionId_dateKey}` schema with
 *    features (holidays, events, weather, trend) for consumption by the ML layer.
 */

/**
 * Compute holiday features for a given dateKey ("YYYY-MM-DD")
 */
function computeHolidayMetrics(dateKey) {
  const isHoliday = holidays.some((h) => h.date === dateKey);

  const target = new Date(dateKey + "T00:00:00Z");
  let daysToNext = 30; // sensible fallback upper bound

  // Filter future or current holidays, sort chronologically
  const upcoming = holidays
    .filter((h) => h.date >= dateKey)
    .sort((a, b) => a.date.localeCompare(b.date));

  if (upcoming.length > 0) {
    const nextDate = new Date(upcoming[0].date + "T00:00:00Z");
    const diffMs = nextDate.getTime() - target.getTime();
    daysToNext = Math.max(0, Math.round(diffMs / (1000 * 60 * 60 * 24)));
  }

  return {
    isNationalHoliday: isHoliday,
    daysToNextHoliday: daysToNext,
  };
}

/**
 * Computes 7-day linear regression slope (recentTrend) of daily booking counts.
 * Uses closed-form Ordinary Least Squares for x = [0..6], denominator = 28.
 *
 * @param {Object.<string, number>} dailyCounts - Map of "YYYY-MM-DD" -> count
 * @param {string} targetDateKey - "YYYY-MM-DD"
 * @returns {number} Slope rounded to 2 decimal places (positive = accelerating demand)
 */
function compute7DaySlope(dailyCounts, targetDateKey) {
  const targetDate = new Date(targetDateKey + "T00:00:00Z");
  const y = [];

  for (let i = 6; i >= 0; i--) {
    const d = new Date(targetDate);
    d.setUTCDate(d.getUTCDate() - i);
    const key = d.toISOString().split("T")[0];
    y.push(dailyCounts[key] || 0);
  }

  // OLS slope = Sum_{i=0..6} (i - 3) * y[i] / 28
  let weightedSum = 0;
  for (let i = 0; i < 7; i++) {
    weightedSum += (i - 3) * y[i];
  }

  const slope = weightedSum / 28;
  return Math.round(slope * 100) / 100;
}

/**
 * Execute demand aggregation across all organizations.
 *
 * @param {FirebaseFirestore.Firestore} db
 */
async function runDemandAggregation(db, messaging = null) {
  try {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    // Query bookings from the past 30 days
    let snapshot;
    try {
      snapshot = await db
        .collection("bookings")
        .where("status", "in", ["completed", "inProgress", "in_progress"])
        .where("scheduledAt", ">=", cutoff.toISOString())
        .get();
    } catch (_) {
      // Fallback for setups where scheduledAt index or enum differs
      snapshot = await db
        .collection("bookings")
        .where("status", "in", ["completed", "inProgress", "in_progress"])
        .get();
    }

    const regionMap = {}; // regionId -> { count, serviceTypeCounts, dailyCounts }

    snapshot.forEach((doc) => {
      const data = doc.data();
      const region = data.organizationId || "unknown";

      if (!regionMap[region]) {
        regionMap[region] = {
          count: 0,
          serviceTypeCounts: {},
          dailyCounts: {},
        };
      }

      regionMap[region].count++;

      const st = data.serviceType || "unknown";
      regionMap[region].serviceTypeCounts[st] =
        (regionMap[region].serviceTypeCounts[st] || 0) + 1;

      // Extract booking date for daily trend calculation
      let bDateKey = null;
      if (data.scheduledAt) {
        if (typeof data.scheduledAt.toDate === "function") {
          bDateKey = data.scheduledAt.toDate().toISOString().split("T")[0];
        } else {
          try {
            bDateKey = new Date(data.scheduledAt).toISOString().split("T")[0];
          } catch (_) {}
        }
      }

      if (bDateKey) {
        regionMap[region].dailyCounts[bDateKey] =
          (regionMap[region].dailyCounts[bDateKey] || 0) + 1;
      }
    });

    const batch = db.batch();
    const dateKey = new Date().toISOString().split("T")[0];

    // Compute holiday metrics for today
    const { isNationalHoliday, daysToNextHoliday } = computeHolidayMetrics(dateKey);

    for (const [regionId, stats] of Object.entries(regionMap)) {
      const topServiceType =
        Object.entries(stats.serviceTypeCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ||
        "unknown";

      // 1. Local Events Query (cooperative admin-entered festivals)
      let hasLocalEvent = false;
      let eventSeverity = "none";
      const expectedDemandTags = [];
      try {
        const eventsSnap = await db
          .collection("local_events")
          .where("organizationId", "==", regionId)
          .where("date", "==", dateKey)
          .get();

        if (!eventsSnap.empty) {
          hasLocalEvent = true;
          const severityRank = { none: 0, low: 1, medium: 2, high: 3 };
          let highestSeverity = "low";
          let highestRank = 0;

          eventsSnap.forEach((eDoc) => {
            const ev = eDoc.data();
            const rank = severityRank[ev.severity] || 1;
            if (rank > highestRank) {
              highestRank = rank;
              highestSeverity = ev.severity || "medium";
            }
            if (Array.isArray(ev.expectedDemandTags)) {
              expectedDemandTags.push(...ev.expectedDemandTags);
            }
          });
          eventSeverity = highestSeverity;
        }
      } catch (e) {
        console.warn(`[demand aggregation] Failed to query local_events for ${regionId}:`, e.message);
      }

      // 2. Weather Forecast (Node 18 native fetch to OpenWeatherMap)
      const weather = await getWeatherForecast({
        organizationId: regionId,
        dateKey,
        db,
      });

      // 3. Recent 7-day booking slope
      const recentTrend = compute7DaySlope(stats.dailyCounts, dateKey);

      // 4. ML Demand Prediction: Baseline + LightGBM Residual (gated behind graceful fallback)
      let predictedDemand = stats.count;
      try {
        let sevenDayTotal = 0;
        for (let i = 6; i >= 0; i--) {
          const d = new Date(dateKey + "T00:00:00Z");
          d.setUTCDate(d.getUTCDate() - i);
          const key = d.toISOString().split("T")[0];
          sevenDayTotal += stats.dailyCounts[key] || 0;
        }
        const dailyBaseline = Math.max(1, Math.round((sevenDayTotal / 7) + recentTrend));
        const dayOfWeek = new Date(dateKey + "T00:00:00Z").getUTCDay();

        predictedDemand = await computePredictedDemand({
          baseline: dailyBaseline,
          features: {
            daysToNextHoliday,
            isNationalHoliday,
            hasLocalEvent,
            eventSeverity,
            rainForecastMM: weather.rainForecastMM,
            tempC: weather.tempC,
            recentTrend,
            dayOfWeek,
          },
        });
      } catch (err) {
        console.warn(`[demand aggregation] Prediction fallback for ${regionId}:`, err.message);
        predictedDemand = Math.max(1, Math.round(stats.count / 30));
      }

      // Derive high demand trades from weather shocks and admin local events
      const shockTrades = [];
      if (Number(weather.rainForecastMM) >= 10) {
        shockTrades.push("Plumbing", "Electrician");
      }
      if (Number(weather.tempC) >= 36) {
        shockTrades.push("Electrician", "Painting");
      }
      if (expectedDemandTags.length > 0) {
        shockTrades.push(...expectedDemandTags);
      }
      const highDemandTrades = Array.from(new Set(shockTrades));

      // 5. Persist to demandStats/{regionId_dateKey}
      const docId = `${regionId}_${dateKey}`;
      batch.set(
        db.collection("demandStats").doc(docId),
        {
          regionId,
          dateKey,
          district: weather.district || null,
          bookingCount: stats.count,
          topServiceType,
          highDemandTrades,
          isNationalHoliday,
          daysToNextHoliday,
          hasLocalEvent,
          eventSeverity,
          rainForecastMM: weather.rainForecastMM,
          tempC: weather.tempC,
          recentTrend,
          predictedDemand,
          computedAt: new Date().toISOString(),
        },
        { merge: true }
      );
    }

    await batch.commit();
    console.log(
      `[demand aggregation] Wrote extended demandStats for ${Object.keys(regionMap).length} regions.`
    );

    // 6. Nightly Fairness Replenishment:
    // Every worker unassigned for >= 24h (or never assigned) recovers +0.05/day up to 1.0 cap.
    await replenishWorkerFairness(db);

    // 7. Worker Demand Alerts (Step 6):
    // Alert online artisans belonging to cooperatives where predicted demand is high or surge.
    if (messaging) {
      await dispatchWorkerDemandAlerts(db, messaging, dateKey);
    }
  } catch (e) {
    console.error("[demand aggregation] Error:", e);
  }
}

/**
 * Computes single replenishment step for a worker's fairness score.
 * Idle workers (unassigned for >= 24 hours or never assigned) regain +0.05
 * fairness per day, strictly capped at 1.0.
 *
 * @param {number} currentScore - Current worker fairnessScore (0.10 .. 1.0)
 * @param {number|null} hoursSinceLastAssigned - Hours since last job accepted, or null
 * @param {number} [step=0.05] - Replenishment step per idle day
 * @param {number} [cap=1.0] - Maximum fairness score cap
 * @returns {number} Updated fairnessScore rounded to 2 decimal places
 */
function calculateReplenishedFairness(
  currentScore = 1.0,
  hoursSinceLastAssigned = null,
  step = 0.05,
  cap = 1.0
) {
  const raw = isNaN(Number(currentScore)) ? 1.0 : Number(currentScore);
  const score = Math.max(0.1, Math.min(cap, raw));

  // Eligible only if unassigned for at least 24 hours or never assigned
  const isEligible =
    hoursSinceLastAssigned == null || hoursSinceLastAssigned >= 24.0;

  if (!isEligible) {
    return Math.round(score * 100) / 100;
  }

  const updated = Math.min(cap, score + step);
  return Math.round(updated * 100) / 100;
}

/**
 * Replenishes fairnessScore in Firestore for all workers who have not been
 * assigned a booking in the past 24 hours. Executed nightly with aggregation.
 *
 * NOTE ON FIRESTORE BATCH LIMIT:
 * Firestore WriteBatch strictly enforces a maximum of 500 write operations
 * per batch. Attempting to commit 501+ operations in a single WriteBatch throws
 * an exception ("Cannot modify more than 500 entities in a single batch").
 * To scale reliably across thousands of artisans, eligible updates are chunked
 * into slices of <= 500 operations each and committed sequentially.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @returns {Promise<number>} Count of workers replenished
 */
async function replenishWorkerFairness(db) {
  if (!db || typeof db.collection !== "function") return 0;
  try {
    const workersSnap = await db.collection("workers").get();
    if (!workersSnap || workersSnap.empty) return 0;

    const now = Date.now();
    const updates = [];

    workersSnap.forEach((doc) => {
      const data = doc.data();
      const currentScore =
        data.fairnessScore !== undefined ? Number(data.fairnessScore) : 1.0;

      // Skip workers already at the maximum fairness cap
      if (currentScore >= 1.0) return;

      let hoursSince = null;
      if (data.lastAssignedAt) {
        try {
          const assignedTime =
            typeof data.lastAssignedAt.toDate === "function"
              ? data.lastAssignedAt.toDate()
              : new Date(data.lastAssignedAt);
          hoursSince = Math.max(0, (now - assignedTime.getTime()) / (1000 * 60 * 60));
        } catch (_) {
          hoursSince = null;
        }
      }

      const newScore = calculateReplenishedFairness(currentScore, hoursSince, 0.05, 1.0);
      if (newScore > currentScore) {
        updates.push({ ref: doc.ref, newScore });
      }
    });

    if (updates.length === 0) return 0;

    // Firestore batch limit: chunk eligible updates into batches of at most 500
    const BATCH_LIMIT = 500;
    for (let i = 0; i < updates.length; i += BATCH_LIMIT) {
      const chunk = updates.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const item of chunk) {
        batch.update(item.ref, { fairnessScore: item.newScore });
      }
      await batch.commit();
    }

    console.log(
      `[fairness replenishment] Replenished fairness score for ${updates.length} idle workers across ${Math.ceil(updates.length / BATCH_LIMIT)} batch(es).`
    );
    return updates.length;
  } catch (err) {
    console.error("[fairness replenishment] Error replenishing fairness:", err);
    return 0;
  }
}

/**
 * Dispatches high demand push alerts to online workers in regions where
 * tomorrow's predicted demand is classified as "high" or "surge".
 *
 * RATE-LIMITING & CHUNKING CONSTRAINTS:
 * - Rate-limits to at most one demand alert per worker per 24 hours via `lastDemandAlertAt`.
 * - Worker doc timestamp updates are chunked into batches of <= 500 operations to respect Firestore's limit.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {admin.messaging.Messaging} messaging
 * @param {string} dateKey - "YYYY-MM-DD"
 * @returns {Promise<number>} Number of alert notifications dispatched
 */
async function dispatchWorkerDemandAlerts(db, messaging, dateKey) {
  if (!db || typeof db.collection !== "function") return 0;
  try {
    const { NotificationEngine } = require("./notification_engine");
    const { classifyDemandLevel } = require("../routes/insights");
    const engine = new NotificationEngine(db, messaging);

    // 1. Query demandStats records for target date
    const statsSnap = await db
      .collection("demandStats")
      .where("dateKey", "==", dateKey)
      .get();

    if (!statsSnap || statsSnap.empty) return 0;

    const highDemandRegions = [];
    statsSnap.forEach((doc) => {
      const data = doc.data();
      const level = classifyDemandLevel(data.predictedDemand || 0);
      if (level === "high" || level === "surge") {
        highDemandRegions.push({
          regionId: data.regionId || doc.id.split("_")[0],
          trade: data.topServiceType || "General",
          predictedDemand: data.predictedDemand,
          level,
        });
      }
    });

    if (highDemandRegions.length === 0) {
      return 0;
    }

    const now = Date.now();
    let totalDispatched = 0;
    const workerUpdates = [];

    for (const region of highDemandRegions) {
      // 2. Query online workers belonging to that cooperative (organizationId)
      const workersSnap = await db
        .collection("workers")
        .where("organizationId", "==", region.regionId)
        .where("availabilityStatus", "==", "online")
        .get();

      if (!workersSnap || workersSnap.empty) continue;

      const docs = workersSnap.docs || [];
      for (const wDoc of docs) {
        const worker = typeof wDoc.data === "function" ? wDoc.data() : wDoc;

        // 3. Match worker trade skills
        const skills = worker.skills || [];
        const matchesTrade =
          skills.includes(region.trade) ||
          skills.some((s) => String(s).toLowerCase() === String(region.trade).toLowerCase());

        if (!matchesTrade) continue;

        // 4. Rate-limit check: at most 1 alert per 24 hours
        if (worker.lastDemandAlertAt) {
          try {
            const lastTime =
              typeof worker.lastDemandAlertAt.toDate === "function"
                ? worker.lastDemandAlertAt.toDate()
                : new Date(worker.lastDemandAlertAt);
            const hoursSince = (now - lastTime.getTime()) / (1000 * 60 * 60);
            if (hoursSince < 24.0) {
              continue; // Skip worker alerted within 24 hours
            }
          } catch (_) {}
        }

        // 5. Send alert via NotificationEngine
        const userId = worker.userId || wDoc.id;
        try {
          const res = await engine.sendToUser(userId, "HIGH_DEMAND_ALERT", {
            region: region.regionId,
            trade: region.trade,
          });

          if (res && res.success) {
            totalDispatched++;
            workerUpdates.push({
              ref: wDoc.ref,
              lastDemandAlertAt: new Date().toISOString(),
            });
          }
        } catch (sendErr) {
          console.warn(`[demand alerts] Failed to alert worker ${userId}:`, sendErr.message);
        }
      }
    }

    // 6. Chunk worker document updates into batches of <= 500 operations
    const BATCH_LIMIT = 500;
    for (let i = 0; i < workerUpdates.length; i += BATCH_LIMIT) {
      const chunk = workerUpdates.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      for (const item of chunk) {
        if (item.ref) {
          batch.update(item.ref, { lastDemandAlertAt: item.lastDemandAlertAt });
        }
      }
      await batch.commit();
    }

    console.log(
      `[demand alerts] Dispatched ${totalDispatched} high demand alerts across ${highDemandRegions.length} high/surge region(s).`
    );
    return totalDispatched;
  } catch (err) {
    console.error("[demand alerts] Error in dispatchWorkerDemandAlerts:", err);
    return 0;
  }
}

module.exports = {
  runDemandAggregation,
  computeHolidayMetrics,
  compute7DaySlope,
  calculateReplenishedFairness,
  replenishWorkerFairness,
  dispatchWorkerDemandAlerts,
};
