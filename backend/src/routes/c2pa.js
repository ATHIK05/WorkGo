const express = require("express");
const router = express.Router();
const { generateAndSignC2paManifest, verifyManifestById } = require("../services/c2pa_signer");

// POST /api/c2pa/sign — Authenticated worker signing endpoint
router.post("/sign", async (req, res) => {
  try {
    const {
      workerId,
      artisanName,
      trade,
      assetSha256,
      base64Data,
      attestationToken,
      capturedAt,
    } = req.body;

    if (!workerId || !assetSha256) {
      return res.status(400).json({ error: "workerId and assetSha256 are required" });
    }

    const manifestRecord = await generateAndSignC2paManifest(
      {
        workerId,
        artisanName,
        trade,
        assetSha256,
        base64Data,
        attestationToken,
        capturedAt,
      },
      req.db
    );

    res.json(manifestRecord);
  } catch (e) {
    console.error("c2pa/sign error:", e);
    res.status(400).json({ error: "C2PA manifest signing failed", detail: e.message });
  }
});

// GET /api/c2pa/verify/:manifestId — Public manifest verification endpoint
router.get("/verify/:manifestId", async (req, res) => {
  try {
    const { manifestId } = req.params;
    const result = await verifyManifestById(manifestId, req.db);
    res.json(result);
  } catch (e) {
    console.error("c2pa/verify error:", e);
    res.status(404).json({ error: "Manifest not found or verification error", detail: e.message });
  }
});

module.exports = router;
