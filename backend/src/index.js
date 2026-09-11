require("dotenv").config();
const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");

// ── Firebase Admin Init ──────────────────────────────────────────────────────
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
  : require("../serviceAccountKey.json"); // local dev fallback (never commit this file)

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID || "workgo-sih2026",
});

const db = admin.firestore();
const messaging = admin.messaging();

// ── Express App ──────────────────────────────────────────────────────────────
const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "10mb" }));

// Global rate limit
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// ── Middleware: Auth Token Verification ──────────────────────────────────────
const verifyToken = async (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or invalid Authorization header" });
  }
  try {
    const token = auth.split(" ")[1];
    req.user = await admin.auth().verifyIdToken(token);
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token", detail: e.message });
  }
};

// Make db + messaging available on req
app.use((req, _res, next) => {
  req.db = db;
  req.messaging = messaging;
  next();
});

// ── Routes ───────────────────────────────────────────────────────────────────
app.get("/api/health", (_req, res) => res.json({ status: "ok", project: "workgo-sih2026" }));

app.use("/api/auth", require("./routes/auth_otp"));
app.use("/api/match", verifyToken, require("./routes/match"));
app.use("/api/bookings", verifyToken, require("./routes/bookings"));
app.use("/api/payments", require("./routes/payments")); // webhook — no token, Razorpay signed
app.use("/api/documents", verifyToken, require("./routes/documents"));
app.use("/api/insights", verifyToken, require("./routes/insights"));
app.use("/api/admin", verifyToken, require("./routes/admin"));
app.use("/api/verification", verifyToken, require("./routes/verification"));
app.use("/api/verification", verifyToken, require("./routes/aadhaar_qr"));
app.use("/api/c2pa", require("./routes/c2pa")); // /api/c2pa/sign validates token or accepts payload; /api/c2pa/verify is public
app.use("/api/notifications", require("./routes/notifications"));

// ── Notification Cloud Functions Daemon (for Render background triggers) ────
const { initFirestoreNotificationListeners } = require("./cloud_functions");
if (process.env.NODE_ENV !== "test") {
  initFirestoreNotificationListeners(db, messaging);
}

// ── Demand Aggregation Cron (nightly) ────────────────────────────────────────
const cron = require("node-cron");
const { runDemandAggregation } = require("./services/demand_aggregation");
cron.schedule("0 2 * * *", async () => {
  console.log("[cron] Running nightly demand aggregation...");
  await runDemandAggregation(db);
});

// Self-ping to prevent Render cold starts (every 10 min)
if (process.env.SELF_PING_URL) {
  cron.schedule("*/10 * * * *", async () => {
    try {
      const http = require("http");
      const https = require("https");
      const url = new URL(process.env.SELF_PING_URL);
      const client = url.protocol === "https:" ? https : http;
      client.get(process.env.SELF_PING_URL, () => {});
    } catch (_) {}
  });
}

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`WorkGo API running on port ${PORT}`));
module.exports = app;
