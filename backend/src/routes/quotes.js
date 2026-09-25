/**
 * POST /api/quote/sign
 *
 * Server-side statutory fare calculation and HMAC-SHA256 signature.
 *
 * WHY THIS EXISTS:
 *   The CooperativePricingEngine normally runs on the Flutter client for instant UX.
 *   This endpoint provides a cryptographic guarantee that the floor price shown to the
 *   customer was computed by the server (not manipulated on-device) and cannot be
 *   tampered with before it is written to Firestore.
 *
 * Protocol:
 *   1. Client sends booking parameters: category, distanceKm, experienceYears, isEmergency, urgencyTip.
 *   2. Server computes fare using the same statutory floor logic as CooperativePricingEngine.
 *   3. Server builds a canonical payload string and signs it with HMAC-SHA256 over SERVER_QUOTE_SECRET.
 *   4. Client embeds quoteSignature + quoteExpiresAt in the fareBreakdown map before Firestore write.
 *   5. Firestore security rule enforces amount >= 149 (statutory floor).
 */

const express = require("express");
const crypto = require("crypto");
const router = express.Router();

// ── Statutory Floor Rates (mirrors CooperativePricingEngine._baseVisitFares) ───
const BASE_VISIT_FARES = {
  "Plumbing": 149.0,
  "Electrical": 149.0,
  "Carpentry": 199.0,
  "Cleaning": 249.0,
  "Painting": 299.0,
  "Appliance Repair": 199.0,
  "Masonry": 299.0,
  "Gardening": 179.0,
  "Sanitary Fittings": 149.0,
  "Solar Inverters": 249.0,
  "Welder / Metal": 249.0,
};

const TRANSIT_RATE_PER_KM = 12.0;
const EMERGENCY_SURCHARGE = 150.0;
const WELFARE_PERCENT = 2.0;
const QUOTE_TTL_MINUTES = 15;

function getBaseVisitFare(category) {
  if (!category || typeof category !== "string") return 149.0;
  // Case-insensitive match
  for (const [key, val] of Object.entries(BASE_VISIT_FARES)) {
    if (key.toLowerCase() === category.trim().toLowerCase()) return val;
  }
  return 149.0;
}

function getExperienceBonus(experienceYears) {
  const yrs = parseInt(experienceYears, 10) || 0;
  if (yrs >= 5) return 30.0;
  if (yrs >= 3) return 15.0;
  return 0.0;
}

// POST /api/quote/sign
router.post("/sign", async (req, res) => {
  try {
    const {
      category,
      distanceKm,
      experienceYears,
      isEmergency,
      urgencyTip,
      toolAllowance,
      temporalSurcharge,
    } = req.body;

    // Input validation
    if (!category || typeof category !== "string") {
      return res.status(400).json({ error: "category is required (string)" });
    }
    const dist = parseFloat(distanceKm) || 0.0;
    const tip = parseFloat(urgencyTip) || 0.0;
    const tools = parseFloat(toolAllowance) || 0.0;
    const temporal = parseFloat(temporalSurcharge) || 0.0;
    const emergency = isEmergency === true || isEmergency === "true";

    // ── Statutory fare computation ─────────────────────────────────────────
    const baseFare = getBaseVisitFare(category);
    const transitFare = Math.round(dist * TRANSIT_RATE_PER_KM);
    const experienceBonus = getExperienceBonus(experienceYears);
    const emergencyFee = emergency ? EMERGENCY_SURCHARGE : 0.0;

    const totalFare =
      baseFare + transitFare + experienceBonus + emergencyFee + tools + temporal + tip;

    const grossLabor = baseFare + experienceBonus + tools;
    const welfareFare = parseFloat(((grossLabor * WELFARE_PERCENT) / 100.0).toFixed(1));
    const workerTakeHome = parseFloat((totalFare - welfareFare).toFixed(1));

    // ── HMAC-SHA256 Signing ────────────────────────────────────────────────
    const secret = process.env.SERVER_QUOTE_SECRET;
    if (!secret) {
      // Degrade gracefully in dev: return fare without signature
      console.warn("[quotes/sign] SERVER_QUOTE_SECRET not set — returning unsigned quote");
      return res.json({
        category,
        baseVisitFare: baseFare,
        distanceKm: dist,
        transitFare,
        experienceBonus,
        emergencyFee,
        toolAllowance: tools,
        temporalSurcharge: temporal,
        urgencyTip: tip,
        totalEstimatedFare: totalFare,
        welfareFare,
        workerTakeHome,
        quoteSignature: null,
        quoteExpiresAt: null,
        isSignatureVerified: false,
      });
    }

    const expiresAt = new Date(Date.now() + QUOTE_TTL_MINUTES * 60 * 1000).toISOString();
    // Canonical payload: deterministic ordering, colon-separated
    const canonicalPayload = [
      category.trim(),
      dist.toFixed(2),
      baseFare.toFixed(2),
      totalFare.toFixed(2),
      expiresAt,
    ].join(":");

    const signature = crypto
      .createHmac("sha256", secret)
      .update(canonicalPayload)
      .digest("hex");

    return res.json({
      category,
      baseVisitFare: baseFare,
      distanceKm: dist,
      perKmRate: TRANSIT_RATE_PER_KM,
      distanceTransitFare: transitFare,
      experienceBonus,
      emergencySurcharge: emergencyFee,
      toolAllowance: tools,
      temporalSurcharge: temporal,
      urgencyTip: tip,
      totalEstimatedFare: totalFare,
      welfareContributionFare: welfareFare,
      welfareContributionPercent: WELFARE_PERCENT,
      workerTakeHomeFare: workerTakeHome,
      quoteSignature: signature,
      quoteExpiresAt: expiresAt,
      isSignatureVerified: true,
      canonicalPayload, // echo for client-side verification debug
    });
  } catch (e) {
    console.error("[quotes/sign] error:", e);
    return res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
