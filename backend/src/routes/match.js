const express = require("express");
const router = express.Router();
const { distanceBetween } = require("../services/geo_utils");

/**
 * Fair Workforce Allocation: Standby Scoring Engine
 * SIH Problem Statement 26089: AI-based Demand Forecasting & Workforce Allocation.
 *
 * FORMULA:
 * standbyScore = (1 / max(0.5, distanceKm)) * W1
 *              + fairnessScore * W2
 *              + (avgRating / 5.0) * W3
 *              - recentlyAssignedPenalty * W4
 *
 * WEIGHT RATIONALE (Total potential ~100 points):
 * - W1 = 30.0 (Proximity): Operational dispatch feasibility (15–30 pts for 1-2 km).
 * - W2 = 40.0 (Fairness): The primary weight for rotating opportunity among artisans (4–40 pts).
 * - W3 = 20.0 (Quality Rating): Maintains service standards (12–20 pts for 3-5 star artisans).
 * - W4 = 25.0 (Recency Penalty): Heavily penalizes workers who JUST accepted a job within the
 *        last few hours, giving idle artisans a decisive advantage.
 *
 * RECENTLY ASSIGNED PENALTY:
 * Exponential decay over time: recentlyAssignedPenalty = exp(-hoursSinceLastAssigned / 6.0)
 * - 0 hours ago (just assigned): penalty = 1.0 (-25 pts)
 * - 3 hours ago: penalty = 0.60 (-15 pts)
 * - 6 hours ago: penalty = 0.37 (-9.2 pts)
 * - 12 hours ago: penalty = 0.13 (-3.4 pts)
 * - > 24 hours or null (never assigned): penalty = 0.0 (0 pts)
 */
function calculateStandbyScore(worker, distanceKm = null) {
  const W1 = 30.0;
  const W2 = 40.0;
  const W3 = 20.0;
  const W4 = 25.0;

  // 1. Proximity component (1 / max(0.5, distanceKm)) * 30
  // When distanceKm is null/omitted (e.g. in GET /api/match/standby pre-shift regional allocation
  // where no customer booking coordinate exists yet), the proximity component is omitted (0.0 pts)
  // rather than introducing an arbitrary synthetic distance bias across the cooperative.
  let proxComponent = 0.0;
  if (distanceKm != null && !isNaN(Number(distanceKm))) {
    const safeDist = Math.max(0.5, Number(distanceKm));
    proxComponent = (1.0 / safeDist) * W1;
  }

  // 2. Fairness component [0.1 .. 1.0] * 40
  const rawFairness =
    worker.fairnessScore !== undefined ? Number(worker.fairnessScore) : 1.0;
  const fairness = Math.max(0.1, Math.min(1.0, isNaN(rawFairness) ? 1.0 : rawFairness));
  const fairComponent = fairness * W2;

  // 3. Rating component (avgRating / 5.0) * 20
  const rawRating = worker.avgRating !== undefined ? Number(worker.avgRating) : 4.0;
  const rating = Math.max(1.0, Math.min(5.0, isNaN(rawRating) ? 4.0 : rawRating));
  const ratingComponent = (rating / 5.0) * W3;

  // 4. Recency penalty: exp(-hours / 6) * 25
  let recencyPenalty = 0.0;
  if (worker.lastAssignedAt) {
    try {
      const assignedTime =
        typeof worker.lastAssignedAt.toDate === "function"
          ? worker.lastAssignedAt.toDate()
          : new Date(worker.lastAssignedAt);
      const hoursSince = Math.max(
        0,
        (Date.now() - assignedTime.getTime()) / (1000 * 60 * 60)
      );
      recencyPenalty = Math.exp(-hoursSince / 6.0);
    } catch (_) {
      recencyPenalty = 0.0;
    }
  }
  const penaltyComponent = recencyPenalty * W4;

  const rawScore = proxComponent + fairComponent + ratingComponent - penaltyComponent;
  return Math.round(Math.max(0.0, rawScore) * 10) / 10;
}

/**
 * Handler for POST /api/match/workers and POST /api/match/find-workers
 * Body: { serviceType, latitude, longitude, radiusKm }
 * Returns ranked list of available workers within radius with standbyScore attached.
 */
async function handleFindWorkers(req, res) {
  try {
    const { serviceType, latitude, longitude, radiusKm = 5 } = req.body;
    if (!serviceType || latitude == null || longitude == null) {
      return res
        .status(400)
        .json({ error: "serviceType, latitude, longitude required" });
    }

    const db = req.db;
    const snapshot = await db
      .collection("workers")
      .where("availabilityStatus", "==", "online")
      .where("skills", "array-contains", serviceType)
      .get();

    const results = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.location && data.location.latitude && data.location.longitude) {
        const dist = distanceBetween(
          { lat: latitude, lng: longitude },
          { lat: data.location.latitude, lng: data.location.longitude }
        );
        const maxDist = data.serviceRadiusKm || radiusKm;
        if (dist <= maxDist) {
          const roundedDist = Math.round(dist * 10) / 10;
          const standbyScore = calculateStandbyScore(data, roundedDist);
          results.push({
            id: doc.id,
            ...data,
            distanceKm: roundedDist,
            standbyScore,
          });
        }
      }
    });

    // Sort by rating descending, distance ascending (preserves existing logic)
    results.sort((a, b) => {
      if (b.avgRating !== a.avgRating) return b.avgRating - a.avgRating;
      return a.distanceKm - b.distanceKm;
    });

    res.json({ workers: results });
  } catch (e) {
    console.error("match/workers error:", e);
    res.status(500).json({ error: "Internal server error" });
  }
}

router.post("/workers", handleFindWorkers);
router.post("/find-workers", handleFindWorkers);

/**
 * GET /api/match/standby?regionId=X&serviceType=Y&limit=10
 * Returns top-K workers ranked by standbyScore to recommend standby staffing
 * ahead of forecasted high demand.
 */
router.get("/standby", async (req, res) => {
  try {
    // Accepts either regionId or organizationId (synonymous in WorkGo cooperative context)
    const targetOrg = req.query.organizationId || req.query.regionId;
    const { serviceType, limit = 10 } = req.query;
    const db = req.db;

    let query = db.collection("workers").where("availabilityStatus", "==", "online");

    // Filter workers by organizationId in Firestore
    if (targetOrg) {
      query = query.where("organizationId", "==", targetOrg);
    }
    if (serviceType) {
      query = query.where("skills", "array-contains", serviceType);
    }

    const snapshot = await query.get();
    const results = [];

    snapshot.forEach((doc) => {
      const data = doc.data();
      // Standby staffing is regional pre-shift allocation ahead of forecasted demand.
      // Because there is no customer booking location at this pre-shift stage, proximity
      // is omitted (distanceKm = null) so ranking is purely merit- and fairness-driven
      // without introducing an arbitrary distance constant across the cooperative.
      const standbyScore = calculateStandbyScore(data, null);

      results.push({
        id: doc.id,
        name: data.name || data.displayName || "Co-op Artisan",
        skills: data.skills || [],
        organizationId: data.organizationId || "unknown",
        avgRating: data.avgRating || 4.0,
        fairnessScore: data.fairnessScore !== undefined ? data.fairnessScore : 1.0,
        lastAssignedAt: data.lastAssignedAt || null,
        standbyScore,
      });
    });

    // Sort descending by standbyScore (highest opportunity rotation & readiness first)
    results.sort((a, b) => b.standbyScore - a.standbyScore);

    res.json({
      organizationId: targetOrg || "all",
      regionId: targetOrg || "all",
      serviceType: serviceType || "all",
      workers: results.slice(0, Number(limit || 10)),
    });
  } catch (e) {
    console.error("match/standby error:", e);
    res.status(500).json({ error: "Failed to fetch standby worker allocation" });
  }
});

router.calculateStandbyScore = calculateStandbyScore;

module.exports = router;
