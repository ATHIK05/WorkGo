const express = require("express");
const router = express.Router();

/**
 * Classify demand volume into operational tiers based on empirical percentiles
 * of the 400-day training data distribution (median ~51, Q1=45, Q3=65, 90th pct=88):
 * - Low:    < 45 bookings/day (bottom 25% — below Q1)
 * - Medium: 45 - 64 bookings/day (middle 50% — Interquartile Range Q1 to Q3)
 * - High:   65 - 84 bookings/day (elevated activity — 75th to 90th percentile)
 * - Surge:  >= 85 bookings/day (top 10% peak festival & weather shocks)
 */
function classifyDemandLevel(predictedDemand) {
  const val = Number(predictedDemand || 0);
  if (val >= 85) return "surge";
  if (val >= 65) return "high";
  if (val >= 45) return "medium";
  return "low";
}

/**
 * Extract human-interpretable demand driver signals for cooperative admins.
 */
function extractContributingFactors(stat) {
  const factors = [];
  const district = stat.district || null;
  const locSuffix = district ? ` in ${district}` : "";

  // 1. Local event / festival signals (e.g. Pongal/Diwali -> Painting & Cleaning surge)
  if (stat.hasLocalEvent || (stat.eventSeverity && stat.eventSeverity !== "none")) {
    const sev = stat.eventSeverity || "high";
    factors.push(`Active local festival/event (${sev} severity${locSuffix})`);
  }

  // 2. National & regional holiday signals
  if (stat.isNationalHoliday) {
    factors.push(`National or gazetted public holiday${locSuffix}`);
  } else if (
    stat.daysToNextHoliday !== undefined &&
    stat.daysToNextHoliday > 0 &&
    stat.daysToNextHoliday <= 3
  ) {
    factors.push(
      `Pre-festival preparation surge (holiday in ${stat.daysToNextHoliday} day${
        stat.daysToNextHoliday > 1 ? "s" : ""
      }${locSuffix})`
    );
  }

  // 3. Weather impact factors (e.g. Chennai rains -> Plumbing/Electrical, Erode heat -> Electrical/Cooling)
  if (Number(stat.rainForecastMM) >= 10) {
    factors.push(`Heavy rain forecast (${stat.rainForecastMM}mm${locSuffix})`);
  } else if (Number(stat.rainForecastMM) > 0) {
    factors.push(`Rain forecast (${stat.rainForecastMM}mm${locSuffix})`);
  }

  if (Number(stat.tempC) >= 36) {
    factors.push(`High temperature wave (${stat.tempC}°C${locSuffix})`);
  }

  // 4. Trend momentum
  if (Number(stat.recentTrend) >= 1.0) {
    factors.push(`Accelerating 7-day booking momentum (+${stat.recentTrend}/day)`);
  } else if (Number(stat.recentTrend) <= -1.0) {
    factors.push(`Cooling 7-day booking trend (${stat.recentTrend}/day)`);
  }

  return factors.length > 0 ? factors : ["Standard seasonal baseline activity"];
}

/**
 * Derive specific high-demand artisan trades from meteorological shock signals
 * and cooperative admin local event registrations.
 *
 * Domain Heuristics (IMD Regional Shock Baselines):
 * - Rain >= 10mm (moderate-to-heavy localized precipitation): Triggers Plumbing
 *   (drainage blockages, sump dewatering, pipeline leaks) and Electrician
 *   (short-circuits, wet wire tripping, inverter restoration).
 * - Temp >= 36°C (interior Tamil Nadu heatwave threshold): Triggers Electrician
 *   (AC/cooler servicing, fan rewinding, phase overload) and Painting
 *   (heat-reflective roof coatings, thermal sealants).
 * - Admin Local Events: Appends any expectedDemandTags explicitly registered
 *   for the event.
 *
 * @param {Object} stat - Historical or speculative demand telemetry
 * @returns {string[]} Deduplicated list of high-demand trades
 */
function deriveHighDemandTrades(stat = {}) {
  const trades = new Set();

  // 1. Meteorological Rain Shock (IMD >= 10mm)
  if (Number(stat.rainForecastMM) >= 10) {
    trades.add("Plumbing");
    trades.add("Electrician");
  }

  // 2. Meteorological Heatwave Shock (Regional >= 36°C)
  if (Number(stat.tempC) >= 36) {
    trades.add("Electrician");
    trades.add("Painting");
  }

  // 3. Admin-entered local festival / event tags
  if (Array.isArray(stat.expectedDemandTags)) {
    stat.expectedDemandTags.forEach((t) => trades.add(t));
  } else if (Array.isArray(stat.highDemandTrades)) {
    stat.highDemandTrades.forEach((t) => trades.add(t));
  }

  return Array.from(trades);
}

const { computeHolidayMetrics } = require("../services/demand_aggregation");
const { getWeatherForecast, REGIONAL_CLUSTERS } = require("../services/weather");
const { computePredictedDemand, loadDemandModel } = require("../services/demand_model");

/**
 * Handler for GET /api/insights and GET /api/insights/demand
 * Supports:
 * - ?regionId=<organizationId> filtering
 * - ?forecastDate=YYYY-MM-DD for on-demand forward-looking demand forecasting
 */
async function handleGetDemandInsights(req, res) {
  try {
    const { regionId, organizationId, forecastDate, date } = req.query;
    const targetOrg = regionId || organizationId || null;
    const requestedDate = forecastDate || date || null;
    const todayKey = new Date().toISOString().split("T")[0];

    // 1. Query historical demandStats for trend baseline & history
    let query = req.db.collection("demandStats").orderBy("computedAt", "desc").limit(30);
    if (targetOrg && targetOrg !== "all") {
      query = req.db
        .collection("demandStats")
        .where("regionId", "==", targetOrg)
        .orderBy("computedAt", "desc")
        .limit(30);
    }

    let snapshot;
    try {
      snapshot = await query.get();
    } catch (_) {
      // Fallback if index on regionId+computedAt is missing
      const fallbackQuery = targetOrg && targetOrg !== "all"
        ? req.db.collection("demandStats").where("regionId", "==", targetOrg).limit(30)
        : req.db.collection("demandStats").limit(30);
      snapshot = await fallbackQuery.get();
    }

    const stats = [];
    if (snapshot && typeof snapshot.forEach === "function") {
      snapshot.forEach((doc) => {
        const data = doc.data();
        const predictedDemand =
          data.predictedDemand !== undefined
            ? Number(data.predictedDemand)
            : Math.max(1, Math.round((data.bookingCount || 30) / 30));

        const demandLevel = classifyDemandLevel(predictedDemand);
        const contributingFactors = extractContributingFactors(data);

        stats.push({
          id: doc.id,
          ...data,
          predictedDemand,
          demandLevel,
          contributingFactors,
        });
      });
    }

    const latest = stats[0] || {};
    const effectiveRegion = targetOrg || latest.regionId || null;

    if (!effectiveRegion) {
      return res.status(400).json({
        error: "Missing required parameter: regionId or organizationId must be provided when no historical records exist.",
      });
    }

    // 2. If NO specific future date requested (or today's date requested) AND we have today's record:
    const isTodayOrPast = !requestedDate || requestedDate <= todayKey;
    if (isTodayOrPast && stats.length > 0 && stats[0].dateKey === (requestedDate || todayKey)) {
      return res.json({
        regionId: effectiveRegion,
        forecastDate: stats[0].dateKey || todayKey,
        predictedDemand: stats[0].predictedDemand ?? 0,
        demandLevel: stats[0].demandLevel ?? "low",
        topServiceType: stats[0].topServiceType || "General",
        contributingFactors: stats[0].contributingFactors ?? [
          "Standard seasonal baseline activity",
        ],
        highDemandTrades: deriveHighDemandTrades(stats[0]),
        isSpeculativeFutureForecast: false,
        stats,
      });
    }

    // 3. SPECULATIVE FUTURE FORECAST (or on-demand calculation for requestedDate)
    const targetDateKey = requestedDate || todayKey;
    const todayMs = new Date(todayKey + "T00:00:00Z").getTime();
    const targetMs = new Date(targetDateKey + "T00:00:00Z").getTime();
    const diffDays = Math.round((targetMs - todayMs) / (1000 * 60 * 60 * 24));

    // A. Compute holiday features for THAT specific date
    const { isNationalHoliday, daysToNextHoliday } = computeHolidayMetrics(targetDateKey);

    // B. Query local_events for organizationId + that specific future date
    let hasLocalEvent = false;
    let eventSeverity = "none";
    const expectedDemandTags = [];
    try {
      let eventsQuery = req.db
        .collection("local_events")
        .where("date", "==", targetDateKey);

      if (effectiveRegion && effectiveRegion !== "all") {
        eventsQuery = eventsQuery.where("organizationId", "==", effectiveRegion);
      }

      const eventsSnap = await eventsQuery.get();
      if (eventsSnap && !eventsSnap.empty) {
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
      console.warn(`[insights] Failed to query local_events for future date ${targetDateKey}:`, e.message);
    }

    // C. Weather: OpenWeatherMap free tier only covers ~7-14 days.
    // If forecastDate is beyond that range, explicitly return rain/temp as null with explicit note.
    let rainForecastMM = null;
    let tempC = null;
    let weatherNote = null;

    if (diffDays > 14 || diffDays < 0) {
      rainForecastMM = null;
      tempC = null;
      weatherNote = "weather unavailable this far ahead";
    } else {
      try {
        const w = await getWeatherForecast({
          organizationId: effectiveRegion,
          dateKey: targetDateKey,
          db: req.db,
        });
        rainForecastMM = w.rainForecastMM;
        tempC = w.tempC;
      } catch (_) {
        rainForecastMM = null;
        tempC = null;
        weatherNote = "weather unavailable this far ahead";
      }
    }

    // D. Baseline: recent 7-day trend from demandStats history
    const baseline = latest.predictedDemand || (latest.bookingCount ? Math.round(latest.bookingCount / 30) : 50);
    const recentTrend = latest.recentTrend !== undefined ? Number(latest.recentTrend) : 0.0;
    const rawJsDow = new Date(targetDateKey + "T00:00:00Z").getUTCDay();

    // ONNX tensor input: substitute defaults if weather is null so inference doesn't produce NaN
    const tensorRain = rainForecastMM != null ? Number(rainForecastMM) : 0.0;
    const tensorTemp = tempC != null ? Number(tempC) : 28.0;

    await loadDemandModel();
    const predictedDemand = await computePredictedDemand({
      baseline,
      features: {
        daysToNextHoliday,
        isNationalHoliday,
        hasLocalEvent,
        eventSeverity,
        rainForecastMM: tensorRain,
        tempC: tensorTemp,
        recentTrend,
        dayOfWeek: rawJsDow,
      },
    });

    const demandLevel = classifyDemandLevel(predictedDemand);

    // E. Build contextual contributing factors
    const clusterDistrict =
      (REGIONAL_CLUSTERS && REGIONAL_CLUSTERS[effectiveRegion]?.district) ||
      (REGIONAL_CLUSTERS &&
        Object.entries(REGIONAL_CLUSTERS).find(([key]) =>
          effectiveRegion && effectiveRegion.toLowerCase().includes(key)
        )?.[1]?.district) ||
      latest.district ||
      null;

    const statData = {
      regionId: effectiveRegion,
      district: clusterDistrict,
      dateKey: targetDateKey,
      daysToNextHoliday,
      isNationalHoliday,
      hasLocalEvent,
      eventSeverity,
      rainForecastMM,
      tempC,
      recentTrend,
      expectedDemandTags,
    };
    const contributingFactors = extractContributingFactors(statData);
    if (weatherNote) {
      contributingFactors.push(`Weather signal: ${weatherNote}`);
    }
    const highDemandTrades = deriveHighDemandTrades(statData);

    // F. Return speculative future forecast directly without writing to demandStats
    return res.json({
      regionId: effectiveRegion,
      district: clusterDistrict,
      forecastDate: targetDateKey,
      predictedDemand,
      demandLevel,
      topServiceType: latest.topServiceType || (expectedDemandTags[0] || "General"),
      contributingFactors,
      highDemandTrades,
      isSpeculativeFutureForecast: true,
      weather: {
        rainForecastMM,
        tempC,
        note: weatherNote,
      },
      stats,
    });
  } catch (e) {
    console.error("insights/demand error:", e);
    res.status(500).json({ error: "Failed to fetch demand insights" });
  }
}

router.get("/", handleGetDemandInsights);
router.get("/demand", handleGetDemandInsights);

router.classifyDemandLevel = classifyDemandLevel;
router.extractContributingFactors = extractContributingFactors;
router.deriveHighDemandTrades = deriveHighDemandTrades;
router.handleGetDemandInsights = handleGetDemandInsights;

module.exports = router;
