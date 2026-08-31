const express = require("express");
const router = express.Router();

// POST /api/bookings/:id/notify — trigger FCM push on status change
router.post("/:id/notify", async (req, res) => {
  try {
    const { id } = req.params;
    const { status, targetFcmToken } = req.body;
    if (!targetFcmToken) return res.status(400).json({ error: "targetFcmToken required" });

    const message = {
      token: targetFcmToken,
      notification: {
        title: "WorkGo Update",
        body: `Your booking status changed to: ${status}`,
      },
      data: { bookingId: id, status: status || "" },
    };
    const result = await req.messaging.send(message);
    res.json({ success: true, messageId: result });
  } catch (e) {
    console.error("bookings/notify error:", e);
    res.status(500).json({ error: "Failed to send notification" });
  }
});

module.exports = router;
