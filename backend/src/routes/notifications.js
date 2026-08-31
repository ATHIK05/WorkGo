const express = require("express");
const router = express.Router();
const { NotificationEngine } = require("../services/notification_engine");

/**
 * Register or update FCM Token for a user
 * POST /api/notifications/register-token
 * Body: { userId, fcmToken, preferredLanguage, platform }
 */
router.post("/register-token", async (req, res) => {
  const { userId, fcmToken, preferredLanguage, platform } = req.body;
  if (!userId || !fcmToken) {
    return res.status(400).json({ error: "Missing required fields: userId and fcmToken" });
  }

  try {
    const userRef = req.db.collection("users").doc(userId);
    const doc = await userRef.get();

    if (!doc.exists) {
      // Create user stub if not yet populated
      await userRef.set({
        fcmTokens: [fcmToken],
        preferredLanguage: preferredLanguage || "en",
        platform: platform || "android",
        updatedAt: new Date(),
      }, { merge: true });
    } else {
      const data = doc.data() || {};
      const tokens = new Set(data.fcmTokens || []);
      tokens.add(fcmToken);

      await userRef.update({
        fcmTokens: Array.from(tokens),
        preferredLanguage: preferredLanguage || data.preferredLanguage || "en",
        platform: platform || data.platform || "android",
        lastTokenUpdate: new Date(),
      });
    }

    return res.json({ success: true, message: "FCM token registered successfully" });
  } catch (error) {
    console.error("[Notifications API] Token registration error:", error);
    return res.status(500).json({ error: "Failed to register token", detail: error.message });
  }
});

/**
 * Test or send direct push notification
 * POST /api/notifications/send-direct
 * Body: { userId, eventKey, params }
 */
router.post("/send-direct", async (req, res) => {
  const { userId, eventKey, params } = req.body;
  if (!userId || !eventKey) {
    return res.status(400).json({ error: "Missing userId or eventKey" });
  }

  try {
    const engine = new NotificationEngine(req.db, req.messaging);
    const result = await engine.sendToUser(userId, eventKey, params || {});
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ error: "Direct send failed", detail: error.message });
  }
});

/**
 * Test broadcast to nearby workers
 * POST /api/notifications/test-broadcast
 * Body: { serviceType, amount, urgencyBonus, address }
 */
router.post("/test-broadcast", async (req, res) => {
  try {
    const engine = new NotificationEngine(req.db, req.messaging);
    const result = await engine.broadcastNewBookingToNearbyWorkers({
      id: `test_b_${Date.now()}`,
      serviceType: req.body.serviceType || "Plumbing",
      amount: req.body.amount || 299,
      urgencyBonus: req.body.urgencyBonus || 50,
      isEmergency: req.body.isEmergency || false,
      customerAddressText: req.body.address || "1148 E Main St, Thanjavur",
    });
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ error: "Test broadcast failed", detail: error.message });
  }
});

module.exports = router;
