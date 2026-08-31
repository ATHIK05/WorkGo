const { admin } = require("firebase-admin");

/**
 * Nightly demand aggregation job.
 * Reads bookings from the past 30 days, computes per-region stats,
 * and writes to demandStats/{regionId_dateKey}.
 * 
 * Labeled as a STATISTICAL HEURISTIC — not a trained ML model.
 * See PRD v2 Section 4 + Section 7.4.
 */
async function runDemandAggregation(db) {
  try {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const snapshot = await db
      .collection("bookings")
      .where("status", "in", ["completed", "inProgress"])
      .where("scheduledAt", ">=", cutoff.toISOString())
      .get();

    const regionMap = {}; // regionId -> { count, serviceTypeCounts }

    snapshot.forEach((doc) => {
      const data = doc.data();
      const region = data.organizationId || "unknown";
      if (!regionMap[region]) regionMap[region] = { count: 0, serviceTypeCounts: {} };
      regionMap[region].count++;
      const st = data.serviceType || "unknown";
      regionMap[region].serviceTypeCounts[st] =
        (regionMap[region].serviceTypeCounts[st] || 0) + 1;
    });

    const batch = db.batch();
    const dateKey = new Date().toISOString().split("T")[0];

    for (const [regionId, stats] of Object.entries(regionMap)) {
      const topServiceType = Object.entries(stats.serviceTypeCounts).sort(
        (a, b) => b[1] - a[1]
      )[0]?.[0] || "unknown";

      const docId = `${regionId}_${dateKey}`;
      batch.set(db.collection("demandStats").doc(docId), {
        regionId,
        dateKey,
        bookingCount: stats.count,
        topServiceType,
        computedAt: new Date().toISOString(),
      });
    }

    await batch.commit();
    console.log(`[demand aggregation] Wrote stats for ${Object.keys(regionMap).length} regions.`);
  } catch (e) {
    console.error("[demand aggregation] Error:", e);
  }
}

module.exports = { runDemandAggregation };
