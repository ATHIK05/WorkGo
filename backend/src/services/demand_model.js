/**
 * WorkGo ONNX Runtime Demand Residual Predictor.
 * SIH Problem Statement 26089: AI-based Demand Forecasting & Workforce Allocation.
 *
 * Implements ultra-low-latency server-side ML inference:
 * Loads `models/demand_model.onnx` into memory at server startup.
 * Predicts the demand residual on top of the seasonal/trend baseline.
 *
 * Graceful Degradation Philosophy:
 * If the model file is missing or inference encounters an error, it silently
 * falls back to baseline-only prediction (residual = 0) without throwing.
 */

const path = require("path");
const fs = require("fs");

let ort = null;
try {
  ort = require("onnxruntime-node");
  const commonDir = path.dirname(require.resolve("onnxruntime-common"));
  const mapping = require(path.join(commonDir, "tensor-impl-type-mapping.js"));
  class CrossRealmFloat32Array extends Float32Array {
    static [Symbol.hasInstance](instance) {
      return (
        instance instanceof Float32Array ||
        Object.prototype.toString.call(instance) === "[object Float32Array]"
      );
    }
  }
  mapping.NUMERIC_TENSOR_TYPE_TO_TYPEDARRAY_MAP.set("float32", CrossRealmFloat32Array);
} catch (e) {
  console.warn("[demand_model] onnxruntime-node initialization notice:", e.message);
}

let session = null;
let isLoaded = false;

const FEATURE_NAMES = [
  "daysToNextHoliday",
  "isNationalHoliday",
  "hasLocalEvent",
  "eventSeverity",
  "rainForecastMM",
  "tempC",
  "recentTrend",
  "dayOfWeek",
];

const SEVERITY_MAP = {
  none: 0.0,
  low: 1.0,
  medium: 2.0,
  high: 3.0,
};

/**
 * Initialize and load the ONNX model into memory once at startup.
 *
 * @param {string} [customPath]
 * @returns {Promise<boolean>} True if loaded, false if fallback mode active
 */
async function loadDemandModel(customPath) {
  const modelPath =
    customPath || path.resolve(__dirname, "../../models/demand_model.onnx");

  if (!ort) {
    isLoaded = false;
    return false;
  }

  try {
    if (!fs.existsSync(modelPath)) {
      console.warn(
        `[demand_model] Model file not found at ${modelPath}. Running in baseline-only fallback mode.`
      );
      isLoaded = false;
      return false;
    }

    session = await ort.InferenceSession.create(modelPath);
    isLoaded = true;
    console.log(`[demand_model] Successfully loaded ONNX demand model from ${modelPath}`);
    return true;
  } catch (err) {
    console.warn(`[demand_model] Failed to load ONNX model: ${err.message}. Baseline fallback active.`);
    session = null;
    isLoaded = false;
    return false;
  }
}

/**
 * Check if the ONNX model is currently loaded.
 */
function isModelLoaded() {
  return isLoaded && session !== null;
}

/**
 * Run inference to predict demand residual.
 *
 * @param {Object} features
 * @param {number} features.daysToNextHoliday
 * @param {boolean|number} features.isNationalHoliday
 * @param {boolean|number} features.hasLocalEvent
 * @param {string|number} features.eventSeverity - "none" | "low" | "medium" | "high" or number
 * @param {number} features.rainForecastMM
 * @param {number} features.tempC
 * @param {number} features.recentTrend
 * @param {number} [features.dayOfWeek] - 0 (Mon) to 6 (Sun). If omitted, inferred from date
 * @returns {Promise<number>} Predicted residual demand (positive = surge, negative = dip)
 */
async function predictDemandResidual(features) {
  if (!isModelLoaded()) {
    return 0.0;
  }

  try {
    const sevValue =
      typeof features.eventSeverity === "string"
        ? SEVERITY_MAP[features.eventSeverity.toLowerCase()] ?? 0.0
        : Number(features.eventSeverity || 0);

    // CRITICAL DAY-OF-WEEK CONVENTION ALIGNMENT:
    // Python/pandas datetime.dayofweek uses: Monday=0, Tuesday=1, ..., Sunday=6.
    // JavaScript Date.prototype.getUTCDay() uses: Sunday=0, Monday=1, ..., Saturday=6.
    // Conversion Formula: (jsDay + 6) % 7
    //   - JS Sun (0) -> (0 + 6) % 7 = 6 (Python Sun)
    //   - JS Mon (1) -> (1 + 6) % 7 = 0 (Python Mon)
    //   - JS Sat (6) -> (6 + 6) % 7 = 5 (Python Sat)
    const rawJsDow =
      features.dayOfWeek !== undefined
        ? Number(features.dayOfWeek)
        : new Date().getUTCDay();
    const dow = (rawJsDow + 6) % 7;

    // CRITICAL: Feature order MUST match backend/ml_training/train.py FEATURE_NAMES exactly:
    // [0] daysToNextHoliday (number)
    // [1] isNationalHoliday (0.0 or 1.0)
    // [2] hasLocalEvent (0.0 or 1.0)
    // [3] eventSeverity (0.0=none, 1.0=low, 2.0=medium, 3.0=high)
    // [4] rainForecastMM (number)
    // [5] tempC (number)
    // [6] recentTrend (number)
    // [7] dayOfWeek (0.0=Mon ... 6.0=Sun, converted from JS convention above)
    // DO NOT reorder or alter positions without re-training and re-exporting demand_model.onnx.
    const inputValues = [
      Number(features.daysToNextHoliday || 0),
      features.isNationalHoliday ? 1.0 : 0.0,
      features.hasLocalEvent ? 1.0 : 0.0,
      sevValue,
      Number(features.rainForecastMM || 0),
      Number(features.tempC || 28),
      Number(features.recentTrend || 0),
      dow,
    ];

    const inputTensor = new ort.Tensor("float32", inputValues, [1, 8]);
    const feeds = { [session.inputNames[0]]: inputTensor };
    const results = await session.run(feeds);
    const outputData = results[session.outputNames[0]].data;

    const residual = Number(outputData[0]);
    return isNaN(residual) ? 0.0 : residual;
  } catch (err) {
    console.warn(`[demand_model] Inference error: ${err.message}. Defaulting residual to 0.`);
    return 0.0;
  }
}

/**
 * Predict total demand by adding AI residual to the baseline booking volume.
 *
 * @param {Object} params
 * @param {number} params.baseline - Baseline booking volume (moving average / trend)
 * @param {Object} params.features - Contextual features dictionary
 * @returns {Promise<number>} Predicted total bookings (non-negative integer)
 */
async function computePredictedDemand({ baseline, features }) {
  const safeBaseline = Math.max(0, Number(baseline || 0));
  try {
    const residual = await predictDemandResidual(features);
    return Math.max(0, Math.round(safeBaseline + residual));
  } catch (_) {
    return Math.max(0, Math.round(safeBaseline));
  }
}

module.exports = {
  loadDemandModel,
  isModelLoaded,
  predictDemandResidual,
  computePredictedDemand,
  FEATURE_NAMES,
  SEVERITY_MAP,
};
