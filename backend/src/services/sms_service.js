const https = require("https");

// In-memory cache for SMS gateway config with 5-minute TTL
let cachedConfig = null;
let cacheExpiry = 0;

/**
 * Fetch SMS Gateway configuration from Firestore `system_configs/sms_gateway`
 * Falls back to environment variable or active default credentials.
 */
async function getSmsConfig(db) {
  const now = Date.now();
  if (cachedConfig && now < cacheExpiry) {
    return cachedConfig;
  }

  const defaultConfig = {
    apiKey: process.env.TWOFACTOR_API_KEY || "ee7bbe44-ad30-11f1-90d7-0200cd936042",
    template: process.env.TWOFACTOR_TEMPLATE || "WORKGO_OTP_VERIFY",
    senderId: "WORKGO",
    enabled: true,
  };

  if (!db) {
    cachedConfig = defaultConfig;
    cacheExpiry = now + 300000;
    return cachedConfig;
  }

  try {
    const doc = await db.collection("system_configs").doc("sms_gateway").get();
    if (doc.exists) {
      const data = doc.data() || {};
      cachedConfig = {
        apiKey: data.apiKey || defaultConfig.apiKey,
        template: data.template || defaultConfig.template,
        senderId: data.senderId || defaultConfig.senderId,
        enabled: data.enabled !== undefined ? data.enabled : true,
      };
    } else {
      cachedConfig = defaultConfig;
    }
  } catch (err) {
    console.warn("[SmsService] Could not read system_configs/sms_gateway, using default:", err.message);
    cachedConfig = defaultConfig;
  }

  cacheExpiry = now + 300000; // 5 min TTL
  return cachedConfig;
}

/**
 * Helper to make HTTPS GET requests returning JSON
 */
function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let rawData = "";
        res.on("data", (chunk) => {
          rawData += chunk;
        });
        res.on("end", () => {
          try {
            const parsed = JSON.parse(rawData);
            resolve(parsed);
          } catch (e) {
            reject(new Error(`Failed to parse 2Factor response: ${rawData}`));
          }
        });
      })
      .on("error", (e) => reject(e));
  });
}

/**
 * Sanitize an Indian phone number to 10 digits
 */
function sanitizePhoneNumber(phone) {
  if (!phone || typeof phone !== "string") return "";
  const cleaned = phone.replace(/\D/g, "");
  if (cleaned.length === 12 && cleaned.startsWith("91")) {
    return cleaned.slice(2);
  }
  if (cleaned.length === 10) {
    return cleaned;
  }
  return cleaned;
}

/**
 * Send an OTP via 2Factor.in
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} rawPhone - 10-digit Indian phone number
 * @returns {Promise<{success: boolean, sessionId?: string, error?: string}>}
 */
async function sendOtp(db, rawPhone) {
  const phone = sanitizePhoneNumber(rawPhone);
  if (!phone || phone.length !== 10) {
    return { success: false, error: "Invalid 10-digit phone number" };
  }

  const config = await getSmsConfig(db);
  if (!config.enabled) {
    return { success: false, error: "SMS gateway is temporarily disabled" };
  }

  const url = `https://2factor.in/API/V1/${encodeURIComponent(config.apiKey)}/SMS/${phone}/AUTOGEN/${encodeURIComponent(config.template)}`;

  try {
    const response = await httpsGet(url);
    if (response && response.Status === "Success") {
      return {
        success: true,
        sessionId: response.Details, // The session token used for verification
      };
    }
    return {
      success: false,
      error: response ? response.Details : "Failed to dispatch OTP",
    };
  } catch (err) {
    console.error("[SmsService] sendOtp error:", err.message);
    return { success: false, error: err.message || "Network error while sending OTP" };
  }
}

/**
 * Verify an OTP via 2Factor.in
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} sessionId - 2Factor session token
 * @param {string} otpCode - 4 to 6 digit OTP entered by user
 * @returns {Promise<{success: boolean, error?: string}>}
 */
async function verifyOtp(db, sessionId, otpCode) {
  if (!sessionId || !otpCode) {
    return { success: false, error: "Missing session token or OTP code" };
  }

  const cleanOtp = String(otpCode).trim();
  const config = await getSmsConfig(db);

  const url = `https://2factor.in/API/V1/${encodeURIComponent(config.apiKey)}/SMS/VERIFY/${encodeURIComponent(sessionId)}/${encodeURIComponent(cleanOtp)}`;

  try {
    const response = await httpsGet(url);
    if (response && response.Status === "Success" && response.Details === "OTP Matched") {
      return { success: true };
    }
    return {
      success: false,
      error: response ? response.Details : "Invalid OTP code",
    };
  } catch (err) {
    console.error("[SmsService] verifyOtp error:", err.message);
    return { success: false, error: err.message || "Network error while verifying OTP" };
  }
}

module.exports = {
  getSmsConfig,
  sanitizePhoneNumber,
  sendOtp,
  verifyOtp,
  _clearCache: () => {
    cachedConfig = null;
    cacheExpiry = 0;
  },
};
