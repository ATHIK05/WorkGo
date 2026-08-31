const express = require("express");
const router = express.Router();

// POST /api/match/workers
// Body: { serviceType, latitude, longitude, radiusKm }
// Returns ranked list of available workers within radius
router.post("/workers", async (req, res) => {
  try {
    const { serviceType, latitude, longitude, radiusKm = 5 } = req.body;
    if (!serviceType || latitude == null || longitude == null) {
      return res.status(400).json({ error: "serviceType, latitude, longitude required" });
    }
    const db = req.db;
    // NOTE: Production geo-query should use GeoFirestore or a GeoHash approach.
    // For MVP: fetch all online workers with matching skill and filter by distance.
    const snapshot = await db
      .collection("workers")
      .where("availabilityStatus", "==", "online")
      .where("skills", "array-contains", serviceType)
      .get();

    const { distanceBetween } = require("../services/geo_utils");
    const results = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.location) {
        const dist = distanceBetween(
          { lat: latitude, lng: longitude },
          { lat: data.location.latitude, lng: data.location.longitude }
        );
        if (dist <= (data.serviceRadiusKm || radiusKm)) {
          results.push({
            id: doc.id,
            ...data,
            distanceKm: Math.round(dist * 10) / 10,
          });
        }
      }
    });

    // Sort by rating descending, distance ascending
    results.sort((a, b) => {
      if (b.avgRating !== a.avgRating) return b.avgRating - a.avgRating;
      return a.distanceKm - b.distanceKm;
    });

    res.json({ workers: results });
  } catch (e) {
    console.error("match/workers error:", e);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
