const express = require("express");
const router = express.Router();

// GET /api/insights/demand?regionId=<id>
router.get("/demand", async (req, res) => {
  try {
    const { regionId } = req.query;
    let query = req.db.collection("demandStats").orderBy("computedAt", "desc").limit(30);
    if (regionId) {
      query = req.db.collection("demandStats")
        .where("regionId", "==", regionId)
        .orderBy("computedAt", "desc")
        .limit(30);
    }
    const snapshot = await query.get();
    const stats = [];
    snapshot.forEach((doc) => stats.push({ id: doc.id, ...doc.data() }));
    res.json({ stats });
  } catch (e) {
    console.error("insights/demand error:", e);
    res.status(500).json({ error: "Failed to fetch demand stats" });
  }
});

module.exports = router;
