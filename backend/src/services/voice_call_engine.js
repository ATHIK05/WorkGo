"use strict";

/**
 * WorkGo Voice Call Engine
 * Controls Asterisk PBX via Asterisk Manager Interface (AMI) to:
 *  1. Trigger outbound robocalls to dial workers when a new booking arrives.
 *  2. Abort an active robocall mid-audio when another worker claims the booking first.
 *  3. Maintain a live registry of active AMI channels so race conditions can be handled
 *     from the backend without the caller hanging.
 *
 * AMI Credentials (set in backend .env):
 *   ASTERISK_AMI_HOST    — e.g. 127.0.0.1  (WSL2: 127.0.0.1, Oracle Cloud: server IP)
 *   ASTERISK_AMI_PORT    — e.g. 5038
 *   ASTERISK_AMI_USER    — workgo_node  (from manager.conf)
 *   ASTERISK_AMI_SECRET  — nodeSecret123 (from manager.conf)
 *
 * Sounds directory (Asterisk):
 *   ASTERISK_SOUNDS_DIR  — default: /var/lib/asterisk/sounds/workgo
 */

const net = require("net");
const EventEmitter = require("events");
const { execSync } = require("child_process");

function getWslIp() {
  try {
    const stdout = execSync("wsl hostname -I", { encoding: "utf8" }).trim();
    const ip = stdout.split(/\s+/)[0];
    if (ip && ip.includes(".")) return ip;
  } catch (_) {}
  return "172.31.173.133";
}

/**
 * Transcode a WAV file (any format) to PCM 16-bit 8kHz mono using WSL ffmpeg,
 * copy it to /var/lib/asterisk/sounds/workgo/, and return the relative
 * Asterisk path "workgo/<name>" suitable for Playback().
 *
 * Falls back to fallbackName if anything goes wrong.
 */
function toWslPath(windowsFilePath) {
  if (!windowsFilePath) return "";
  let norm = windowsFilePath.replace(/\\/g, "/");
  if (norm.startsWith("/mnt/")) return norm;
  const m = norm.match(/^([A-Za-z]):\/(.*)/);
  if (m) {
    return `/mnt/${m[1].toLowerCase()}/${m[2]}`;
  }
  const m2 = norm.match(/^\/([A-Za-z])\/(.*)/);
  if (m2) {
    return `/mnt/${m2[1].toLowerCase()}/${m2[2]}`;
  }
  return norm;
}

/**
 * Transcode a WAV file (any format) to PCM 16-bit 8kHz mono using WSL ffmpeg,
 * copy it to /var/lib/asterisk/sounds/workgo/, and return the relative
 * Asterisk path "workgo/<name>" suitable for Playback().
 *
 * Falls back to fallbackName if anything goes wrong.
 */
function copyToAsteriskSounds(windowsFilePath, baseName) {
  try {
    const path = require("path");
    const fs   = require("fs");

    const ast   = `/var/lib/asterisk/sounds/workgo`;
    const dest  = `${ast}/${baseName}.wav`;

    const wslSrc = toWslPath(windowsFilePath);

    // Ensure destination directory exists
    execSync(`wsl -u root mkdir -p ${ast}`);

    // Transcode to PCM 16-bit 8kHz mono (Asterisk requirement)
    execSync(
      `wsl -u root ffmpeg -y -i "${wslSrc}" -ar 8000 -ac 1 -acodec pcm_s16le "${dest}" -loglevel quiet`,
      { timeout: 15000 }
    );

    console.log(`[VoiceEngine] Audio transcoded and installed: workgo/${baseName}`);
    return `workgo/${baseName}`;
  } catch (err) {
    console.error(`[VoiceEngine] copyToAsteriskSounds failed for ${baseName}:`, err.message);
    return `workgo/${baseName}`; // still return the path — Asterisk will warn if missing
  }
}

// ── AMI Connection Pool ───────────────────────────────────────────────────────

class AmiClient extends EventEmitter {
  constructor() {
    super();
    this._socket = null;
    this._connected = false;
    this._buffer = "";
    this._pending = new Map(); // actionId -> { resolve, reject }
    this._actionCounter = 0;
  }

  connect() {
    return new Promise((resolve, reject) => {
      if (this._connected) return resolve();

      let host = process.env.ASTERISK_AMI_HOST;
      if (!host || host === "127.0.0.1") {
        host = getWslIp();
      }
      const port = parseInt(process.env.ASTERISK_AMI_PORT || "5038", 10);
      const user = process.env.ASTERISK_AMI_USER || "workgo_node";
      const secret = process.env.ASTERISK_AMI_SECRET || "nodeSecret123";

      let settled = false;
      const connectTimer = setTimeout(() => {
        if (!settled) {
          settled = true;
          this._connected = false;
          reject(new Error("AMI connection timeout"));
        }
      }, 10000);

      const tryConnect = (targetHost, isRetry = false) => {
        const socket = net.createConnection({ host: targetHost, port }, () => {
          this._socket = socket;
          this._socket.write(
            `Action: Login\r\nUsername: ${user}\r\nSecret: ${secret}\r\n\r\n`
          );
        });

        socket.on("data", (data) => {
          this._buffer += data.toString();
          const blocks = this._buffer.split("\r\n\r\n");
          this._buffer = blocks.pop() || "";

          for (const block of blocks) {
            const parsed = this._parseBlock(block);
            if (parsed.Response === "Success" && !this._connected) {
              this._connected = true;
              if (!settled) {
                settled = true;
                clearTimeout(connectTimer);
                resolve();
              }
              console.log(`[VoiceEngine] AMI connected to Asterisk at ${targetHost}:${port}.`);
            } else if (parsed.Response === "Error" && !this._connected) {
              if (!settled) {
                settled = true;
                clearTimeout(connectTimer);
                reject(new Error(`AMI Login failed: ${parsed.Message}`));
              }
            }

            if (parsed.ActionID && this._pending.has(parsed.ActionID)) {
              const { resolve: res } = this._pending.get(parsed.ActionID);
              this._pending.delete(parsed.ActionID);
              res(parsed);
            }

            this.emit("event", parsed);
          }
        });

        socket.on("error", (err) => {
          try { socket.destroy(); } catch (_) {}
          if (!isRetry && targetHost !== "127.0.0.1") {
            console.warn(`[VoiceEngine] AMI socket error (${targetHost}), trying 127.0.0.1:`, err.message);
            tryConnect("127.0.0.1", true);
          } else {
            console.error(`[VoiceEngine] AMI socket error (${targetHost}):`, err.message);
            this._connected = false;
            if (!settled) {
              settled = true;
              clearTimeout(connectTimer);
              reject(err);
            }
          }
        });
      };

      tryConnect(host);
    });
  }

  _parseBlock(block) {
    const result = {};
    for (const line of block.split("\r\n")) {
      const idx = line.indexOf(": ");
      if (idx !== -1) {
        result[line.slice(0, idx)] = line.slice(idx + 2);
      }
    }
    return result;
  }

  async sendAction(action) {
    if (!this._connected) {
      await this.connect();
    }
    return new Promise((resolve, reject) => {
      const actionId = `workgo_${Date.now()}_${++this._actionCounter}`;
      action.ActionID = actionId;
      this._pending.set(actionId, { resolve, reject });

      let raw = "";
      for (const [key, value] of Object.entries(action)) {
        // Arrays (e.g. Variable) emit one AMI line per element
        if (Array.isArray(value)) {
          for (const item of value) {
            raw += `${key}: ${item}\r\n`;
          }
        } else {
          raw += `${key}: ${value}\r\n`;
        }
      }
      raw += "\r\n";
      this._socket.write(raw);

      setTimeout(() => {
        if (this._pending.has(actionId)) {
          this._pending.delete(actionId);
          reject(new Error(`AMI action timeout: ${action.Action}`));
        }
      }, 8000);
    });
  }

  disconnect() {
    if (this._socket) {
      this._socket.write("Action: Logoff\r\n\r\n");
      this._socket.destroy();
      this._connected = false;
    }
  }
}

// Singleton AMI client
const amiClient = new AmiClient();

// ── Active Call Registry ──────────────────────────────────────────────────────
// Maps bookingId -> { channel, workerPhone, startedAt }
// Used to abort in-progress robocalls when booking is claimed by someone else.
const activeCallRegistry = new Map();

// ── Public API ────────────────────────────────────────────────────────────────

const GATEWAY_CALLER_ID =
  process.env.ASTERISK_GATEWAY_NUMBER ||
  process.env.DIAL_KARYA_GATEWAY_NUMBER ||
  '+919080262334';

/**
 * Trigger an outbound robocall to a dial worker for a new booking alert.
 * The call plays the booking alert audio and waits for the worker to press 1 (accept) or 2 (decline).
 *
 * @param {object} opts
 * @param {string} opts.workerPhone   - E.164 format, e.g. "+919080262334"
 * @param {string} opts.bookingId     - Firestore booking document ID
 * @param {string} opts.trade         - e.g. "Plumber"
 * @param {string} opts.address       - Customer address text
 * @param {number} opts.payout        - Worker payout amount in INR
 * @param {string} opts.language      - 'hi' | 'mr' | 'ta'
 * @param {string} opts.audioFile     - Full path to pre-generated .wav alert audio
 * @returns {Promise<{ success: boolean, channel?: string, error?: string }>}
 */
async function triggerOutboundJobAlertCall({
  workerPhone,
  bookingId,
  trade,
  address,
  payout,
  language = "hi",
  audioFile,
}) {
  // Transcode and install audio into Asterisk sounds dir, return "workgo/<name>"
  const audioBaseName = `booking_${bookingId}`;
  const asteriskAudioPath = audioFile
    ? copyToAsteriskSounds(audioFile, audioBaseName)
    : `workgo/${audioBaseName}`;

  // Determine WSL gateway IP for Asterisk → backend HTTP callbacks
  const wslGateway = (() => {
    try {
      const out = execSync("wsl ip route", { encoding: "utf8" });
      const m = out.match(/default via ([0-9.]+)/);
      return m ? m[1] : "172.31.160.1";
    } catch (_) { return "172.31.160.1"; }
  })();
  const backendUrl = `http://${wslGateway}:3000`;

  // Normalize phone: strip leading + for SIP channel
  const dialNumber = workerPhone.replace(/^\+/, "");

  const isInternalSip = dialNumber.startsWith("workgo_") || /^\d{3,4}$/.test(dialNumber);
  const targetChannel = isInternalSip
    ? `PJSIP/${dialNumber}`
    : `PJSIP/${dialNumber}@gateway-phone`;

  try {
    const result = await amiClient.sendAction({
      Action: "Originate",
      Channel: targetChannel,
      Context: "workgo-booking-alert",
      Exten: "s",
      Priority: "1",
      Timeout: "30000",
      CallerID: `"WorkGo Karya" <${GATEWAY_CALLER_ID}>`,
      // Variable MUST be an array — sendAction emits one "Variable:" line per entry
      Variable: [
        `BOOKING_ID=${bookingId}`,
        `BOOKING_AUDIO=${asteriskAudioPath}`,
        `WORKER_PHONE=${workerPhone}`,
        `WORKER_LANG=${language || "hi"}`,
        `BACKEND_URL=${backendUrl}`,
      ],
      Async: "true",
    });

    if (result.Response === "Success" || result.Response === "Queued") {
      const channel = targetChannel;
      activeCallRegistry.set(bookingId, {
        channel,
        workerPhone,
        startedAt: new Date().toISOString(),
      });
      console.log(
        `[VoiceEngine] Outbound call initiated to ${workerPhone} for booking ${bookingId}`
      );
      return { success: true, channel };
    } else {
      console.error("[VoiceEngine] Originate failed:", result);
      return { success: false, error: result.Message || "Originate failed" };
    }
  } catch (err) {
    console.error("[VoiceEngine] triggerOutboundJobAlertCall error:", err.message);
    return { success: false, error: err.message };
  }
}

/**
 * Abort an active robocall to a dial worker because another worker claimed the booking.
 * Plays the "booking taken" message before hanging up — the worker gets a polite explanation.
 *
 * @param {string} bookingId - The booking ID whose active alert call should be aborted
 * @param {string} language  - Language for "taken" message ('hi' | 'mr' | 'ta')
 * @returns {Promise<{ success: boolean }>}
 */
async function abortCallBookingTaken(bookingId, language = "hi") {
  const callInfo = activeCallRegistry.get(bookingId);
  if (!callInfo) {
    // No active call for this booking — nothing to abort
    return { success: true };
  }

  const { channel } = callInfo;
  const takenAudio = `workgo/booking_taken_${language}`;

  try {
    // Redirect the active channel to the "taken" context which plays the message and hangs up
    await amiClient.sendAction({
      Action: "Redirect",
      Channel: channel,
      Context: "workgo-booking-taken",
      Exten: "s",
      Priority: "1",
      ExtraChannel: "",
    });

    activeCallRegistry.delete(bookingId);
    console.log(
      `[VoiceEngine] Aborted alert call for booking ${bookingId} (booking taken).`
    );
    return { success: true };
  } catch (err) {
    // Fallback: try Hangup if Redirect fails
    try {
      await amiClient.sendAction({ Action: "Hangup", Channel: channel, Cause: "16" });
    } catch (_) {}
    activeCallRegistry.delete(bookingId);
    console.warn(`[VoiceEngine] Redirect failed, used Hangup for booking ${bookingId}:`, err.message);
    return { success: true };
  }
}

/**
 * Abort an active robocall to a dial worker because the customer cancelled the booking.
 * Redirects to the "workgo-booking-cancelled" context which plays the cancellation audio and hangs up.
 *
 * @param {string} bookingId - The booking ID whose active alert call should be aborted
 * @param {string} language  - Language for cancellation message ('hi' | 'mr' | 'ta' | etc.)
 * @returns {Promise<{ success: boolean }>}
 */
async function abortCallBookingCancelled(bookingId, language = "hi") {
  const callInfo = activeCallRegistry.get(bookingId);
  if (!callInfo) {
    return { success: true };
  }

  const { channel } = callInfo;

  try {
    await amiClient.sendAction({
      Action: "Redirect",
      Channel: channel,
      Context: "workgo-booking-cancelled",
      Exten: "s",
      Priority: "1",
      ExtraChannel: "",
    });

    activeCallRegistry.delete(bookingId);
    console.log(
      `[VoiceEngine] Aborted alert call for booking ${bookingId} (customer cancelled).`
    );
    return { success: true };
  } catch (err) {
    try {
      await amiClient.sendAction({ Action: "Hangup", Channel: channel, Cause: "16" });
    } catch (_) {}
    activeCallRegistry.delete(bookingId);
    console.warn(`[VoiceEngine] Redirect failed on cancel, hung up booking ${bookingId}:`, err.message);
    return { success: true };
  }
}

/**
 * Trigger a short flash-call to a dial worker's phone to deliver a 4-digit handshake OTP
 * spoken by Bhashini TTS. Used during Peer KYC handshake verification step.
 *
 * @param {string} workerPhone  - E.164 format
 * @param {string} otpCode      - 4-digit code, e.g. "8392"
 * @param {string} language     - 'hi' | 'mr' | 'ta'
 * @returns {Promise<{ success: boolean }>}
 */
async function triggerOtpFlashCall(workerPhone, otpCode, language = "hi") {
  const dialNumber = workerPhone.replace(/^\+/, "");
  const digits = otpCode.split("").join(" "); // "8 3 9 2" for clear speech

  const texts = {
    hi: `आपका वेरिफिकेशन कोड है: ${digits}। दोहराते हैं: ${digits}।`,
    mr: `तुमचा पडताळणी कोड आहे: ${digits}। पुन्हा: ${digits}।`,
    ta: `உங்கள் சரிபார்ப்பு குறியீடு: ${digits}. மீண்டும்: ${digits}.`,
  };
  const text = texts[language] || texts.hi;

  // Write audio file
  const { writeAudioFile } = require("./bhashini_voice_service");
  const soundsDir = process.env.ASTERISK_SOUNDS_DIR || null;
  const filename = `otp_${workerPhone.replace(/\D/g, "")}_${otpCode}`;
  await writeAudioFile(text, language, filename, soundsDir);

  const isInternalSip = dialNumber.startsWith("workgo_") || /^\d{3,4}$/.test(dialNumber);
  const targetChannel = isInternalSip
    ? `PJSIP/${dialNumber}`
    : `PJSIP/${dialNumber}@gateway-phone`;

  try {
    const result = await amiClient.sendAction({
      Action: "Originate",
      Channel: targetChannel,
      Context: "workgo-otp-flash",
      Exten: "s",
      Priority: "1",
      Timeout: "20000",
      CallerID: `"WorkGo KYC" <${GATEWAY_CALLER_ID}>`,
      Variable: `OTP_AUDIO=workgo/${filename}`,
      Async: "true",
    });

    return { success: result.Response === "Success" || result.Response === "Queued" };
  } catch (err) {
    console.error("[VoiceEngine] triggerOtpFlashCall error:", err.message);
    return { success: false, error: err.message };
  }
}

/**
 * Trigger an outbound robocall to a dial worker to notify them that a booking was cancelled by the customer.
 * Informs them of the cancellation, trade, customer location, elapsed time (5-minute transit window),
 * reason, and confirms their status is restored to Online.
 *
 * @param {object} opts
 * @param {string} opts.workerPhone   - E.164 format or internal SIP user
 * @param {string} opts.bookingId     - Firestore booking document ID
 * @param {string} opts.trade         - Service category, e.g. "plumbing"
 * @param {string} opts.address       - Customer address / location text
 * @param {string} opts.reason        - Customer cancellation reason
 * @param {number|null} opts.elapsedMinutes - Elapsed minutes since acceptance
 * @param {string} opts.language      - Language code
 * @param {string} opts.audioFile     - Full path to pre-generated .wav cancellation audio
 * @returns {Promise<{ success: boolean, channel?: string, error?: string }>}
 */
async function triggerOutboundBookingCancelledCall({
  workerPhone,
  bookingId,
  trade,
  address,
  reason,
  elapsedMinutes,
  language = "hi",
  audioFile,
}) {
  const audioBaseName = `booking_cancel_${bookingId}`;
  const asteriskAudioPath = audioFile
    ? copyToAsteriskSounds(audioFile, audioBaseName)
    : `workgo/${audioBaseName}`;

  const dialNumber = workerPhone.replace(/^\+/, "");
  const isInternalSip = dialNumber.startsWith("workgo_") || /^\d{3,4}$/.test(dialNumber);
  const targetChannel = isInternalSip
    ? `PJSIP/${dialNumber}`
    : `PJSIP/${dialNumber}@gateway-phone`;

  try {
    const result = await amiClient.sendAction({
      Action: "Originate",
      Channel: targetChannel,
      Context: "workgo-booking-cancelled",
      Exten: "s",
      Priority: "1",
      Timeout: "30000",
      CallerID: `"WorkGo Cancellation" <${GATEWAY_CALLER_ID}>`,
      Variable: [
        `BOOKING_ID=${bookingId}`,
        `CANCEL_AUDIO=${asteriskAudioPath}`,
        `WORKER_PHONE=${workerPhone}`,
        `WORKER_LANG=${language || "hi"}`,
      ],
      Async: "true",
    });

    if (result.Response === "Success" || result.Response === "Queued") {
      console.log(
        `[VoiceEngine] Outbound cancellation call initiated to ${workerPhone} for booking ${bookingId}`
      );
      return { success: true, channel: targetChannel };
    } else {
      console.error("[VoiceEngine] Originate cancellation failed:", result);
      return { success: false, error: result.Message || "Originate cancellation failed" };
    }
  } catch (err) {
    console.error("[VoiceEngine] triggerOutboundBookingCancelledCall error:", err.message);
    return { success: false, error: err.message };
  }
}

/**
 * Attempt to connect AMI on startup. Non-fatal if Asterisk isn't running yet.
 */
async function initVoiceEngine() {
  if (!process.env.ASTERISK_AMI_HOST) {
    // Asterisk PBX is not configured in this environment.
    // Telephony calls run via Android SIM Gateway (MacroDroid HTTP webhook).
    return;
  }
  try {
    await amiClient.connect();
    console.log("[VoiceEngine] Ready. Asterisk AMI connected.");
  } catch (err) {
    console.warn(
      "[VoiceEngine] Asterisk AMI not available at startup. Will retry on first call.",
      err.message
    );
  }
}

module.exports = {
  initVoiceEngine,
  triggerOutboundJobAlertCall,
  abortCallBookingTaken,
  abortCallBookingCancelled,
  triggerOutboundBookingCancelledCall,
  triggerOtpFlashCall,
  activeCallRegistry,
};

