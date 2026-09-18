/**
 * OpenWeatherMap Integration for WorkGo AI Demand Forecasting.
 * Uses Node 18 native fetch to retrieve weather features (rainForecastMM, tempC).
 *
 * Implements graceful degradation: if OPENWEATHER_API_KEY is missing, rate-limited,
 * or offline, falls back to seasonal default metrics without interrupting aggregation.
 */

// Regional coordinates and district metadata for Indian cooperative clusters
const REGIONAL_CLUSTERS = {
  coop_tn_01: { latitude: 11.3410, longitude: 77.7172, district: "Erode, Tamil Nadu" },
  erode: { latitude: 11.3410, longitude: 77.7172, district: "Erode, Tamil Nadu" },
  chennai: { latitude: 13.0827, longitude: 80.2707, district: "Chennai, Tamil Nadu" },
  coop_chennai: { latitude: 13.0827, longitude: 80.2707, district: "Chennai, Tamil Nadu" },
  coimbatore: { latitude: 11.0168, longitude: 76.9558, district: "Coimbatore, Tamil Nadu" },
  madurai: { latitude: 9.9252, longitude: 78.1198, district: "Madurai, Tamil Nadu" },
  delhi: { latitude: 28.6139, longitude: 77.2090, district: "New Delhi NCR" },
  jaipur: { latitude: 26.9124, longitude: 75.7873, district: "Jaipur, Rajasthan" },
  mumbai: { latitude: 19.0760, longitude: 72.8777, district: "Mumbai, Maharashtra" },
  bengaluru: { latitude: 12.9716, longitude: 77.5946, district: "Bengaluru, Karnataka" },
};

const DEFAULT_COORDINATES = REGIONAL_CLUSTERS.coop_tn_01;

/**
 * Fetch weather forecast for an organization on a given target date.
 *
 * @param {Object} params
 * @param {string} params.organizationId
 * @param {string} params.dateKey - "YYYY-MM-DD"
 * @param {FirebaseFirestore.Firestore} [params.db]
 * @returns {Promise<{ rainForecastMM: number, tempC: number, district: string }>}
 */
async function getWeatherForecast({ organizationId, dateKey, db }) {
  const apiKey = process.env.OPENWEATHER_API_KEY || process.env.WEATHER_API_KEY;

  // Resolve district cluster
  const cluster = REGIONAL_CLUSTERS[organizationId] ||
    Object.entries(REGIONAL_CLUSTERS).find(([key]) =>
      organizationId && organizationId.toLowerCase().includes(key)
    )?.[1] ||
    DEFAULT_COORDINATES;

  let lat = cluster.latitude;
  let lon = cluster.longitude;
  let district = cluster.district;

  if (!apiKey) {
    // Offline / unconfigured graceful fallback
    return { rainForecastMM: 0.0, tempC: 28.0, district };
  }

  // Attempt to read specific organization geographical coordinates if available
  if (db && organizationId && organizationId !== "unknown") {
    try {
      const orgDoc = await db.collection("organizations").doc(organizationId).get();
      if (orgDoc.exists) {
        const data = orgDoc.data();
        if (data.latitude && data.longitude) {
          lat = Number(data.latitude);
          lon = Number(data.longitude);
        } else if (data.coordinates?.latitude && data.coordinates?.longitude) {
          lat = Number(data.coordinates.latitude);
          lon = Number(data.coordinates.longitude);
        }
        if (data.name || data.city || data.district) {
          district = data.city || data.district || data.name;
        }
      }
    } catch (_) {
      // Non-fatal, use default coordinates
    }
  }

  try {
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&units=metric&appid=${apiKey}`;
    const response = await fetch(url);

    if (!response.ok) {
      console.warn(`[weather] OpenWeatherMap returned status ${response.status} for org ${organizationId}. Using fallback.`);
      return { rainForecastMM: 0.0, tempC: 28.0, district };
    }

    const data = await response.json();
    const list = data.list || [];

    // Filter forecast slices corresponding to target dateKey (format: "YYYY-MM-DD")
    const daySlices = list.filter((item) => item.dt_txt && item.dt_txt.startsWith(dateKey));

    if (daySlices.length > 0) {
      let totalRain = 0;
      let totalTemp = 0;

      for (const slice of daySlices) {
        if (slice.rain && slice.rain["3h"]) {
          totalRain += Number(slice.rain["3h"]) || 0;
        }
        totalTemp += Number(slice.main?.temp) || 28.0;
      }

      const avgTemp = totalTemp / daySlices.length;
      return {
        rainForecastMM: Math.round(totalRain * 10) / 10,
        tempC: Math.round(avgTemp * 10) / 10,
        district,
      };
    }

    // If target date is beyond 5-day window or today slice unavailable, use current entry
    const first = list[0];
    const rain = (first?.rain && first.rain["3h"]) ? Number(first.rain["3h"]) : 0.0;
    const temp = first?.main?.temp ? Number(first.main.temp) : 28.0;

    return {
      rainForecastMM: Math.round(rain * 10) / 10,
      tempC: Math.round(temp * 10) / 10,
      district,
    };
  } catch (err) {
    console.warn(`[weather] Fetch failed for org ${organizationId}:`, err.message);
    return { rainForecastMM: 0.0, tempC: 28.0, district };
  }
}

module.exports = {
  getWeatherForecast,
  REGIONAL_CLUSTERS,
};
