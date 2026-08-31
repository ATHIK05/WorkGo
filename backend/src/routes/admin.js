const express = require("express");
const router = express.Router();

// Middleware: admin-only
const adminOnly = async (req, res, next) => {
  const doc = await req.db.collection("users").doc(req.user.uid).get();
  if (!doc.exists || doc.data().role !== "admin") {
    return res.status(403).json({ error: "Admin access required" });
  }
  next();
};

// POST /api/admin/approve-worker
router.post("/approve-worker", adminOnly, async (req, res) => {
  try {
    const { workerId, approved } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId required" });
    await req.db.collection("workers").doc(workerId).update({
      verificationStatus: approved ? "approved" : "rejected",
      reviewedBy: req.user.uid,
      reviewedAt: new Date().toISOString(),
    });
    res.json({ success: true });
  } catch (e) {
    console.error("admin/approve-worker error:", e);
    res.status(500).json({ error: "Failed to update worker status" });
  }
});

// POST /api/admin/welfare
router.post("/welfare", adminOnly, async (req, res) => {
  try {
    const { workerId, insuranceStatus, welfareSchemeId } = req.body;
    if (!workerId) return res.status(400).json({ error: "workerId required" });
    await req.db.collection("workers").doc(workerId).update({
      insuranceStatus: !!insuranceStatus,
      welfareSchemeId: welfareSchemeId || null,
    });
    res.json({ success: true });
  } catch (e) {
    console.error("admin/welfare error:", e);
    res.status(500).json({ error: "Failed to update welfare status" });
  }
});

module.exports = router;
