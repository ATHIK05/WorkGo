const express = require("express");
const crypto = require("crypto");
const router = express.Router();

// POST /api/payments/verify — Razorpay webhook verification
router.post("/verify", express.raw({ type: "application/json" }), (req, res) => {
  try {
    const secret = process.env.RAZORPAY_KEY_SECRET;
    const signature = req.headers["x-razorpay-signature"];
    const body = req.body.toString();

    const expectedSig = crypto
      .createHmac("sha256", secret)
      .update(body)
      .digest("hex");

    if (expectedSig !== signature) {
      return res.status(400).json({ error: "Invalid signature" });
    }
    const event = JSON.parse(body);
    // TODO: Handle payment.captured, payment.failed events — update bookings/{id} paymentStatus
    console.log("Razorpay event:", event.event);
    res.json({ success: true });
  } catch (e) {
    console.error("payments/verify error:", e);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
