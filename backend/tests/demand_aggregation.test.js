const {
  computeHolidayMetrics,
  compute7DaySlope,
  calculateReplenishedFairness,
  replenishWorkerFairness,
  dispatchWorkerDemandAlerts,
} = require("../src/services/demand_aggregation");
const { getWeatherForecast } = require("../src/services/weather");

describe("Demand Aggregation & Feature Extraction", () => {
  describe("Holiday Feature Extraction", () => {
    test("detects national holiday on Independence Day 2026-08-15", () => {
      const res = computeHolidayMetrics("2026-08-15");
      expect(res.isNationalHoliday).toBe(true);
      expect(res.daysToNextHoliday).toBe(0);
    });

    test("computes correct daysToNextHoliday for pre-holiday date", () => {
      const res = computeHolidayMetrics("2026-08-10");
      expect(res.isNationalHoliday).toBe(false);
      expect(res.daysToNextHoliday).toBe(5); // 5 days to 2026-08-15
    });
  });

  describe("7-Day Trend Slope Calculation", () => {
    test("returns 0 for flat demand over 7 days", () => {
      const dailyCounts = {
        "2026-09-07": 10,
        "2026-09-08": 10,
        "2026-09-09": 10,
        "2026-09-10": 10,
        "2026-09-11": 10,
        "2026-09-12": 10,
        "2026-09-13": 10,
      };
      const slope = compute7DaySlope(dailyCounts, "2026-09-13");
      expect(slope).toBe(0);
    });

    test("returns +1.0 for daily increment of 1 booking/day", () => {
      const dailyCounts = {
        "2026-09-07": 1,
        "2026-09-08": 2,
        "2026-09-09": 3,
        "2026-09-10": 4,
        "2026-09-11": 5,
        "2026-09-12": 6,
        "2026-09-13": 7,
      };
      const slope = compute7DaySlope(dailyCounts, "2026-09-13");
      expect(slope).toBe(1.0);
    });

    test("returns negative slope for declining demand", () => {
      const dailyCounts = {
        "2026-09-07": 7,
        "2026-09-08": 6,
        "2026-09-09": 5,
        "2026-09-10": 4,
        "2026-09-11": 3,
        "2026-09-12": 2,
        "2026-09-13": 1,
      };
      const slope = compute7DaySlope(dailyCounts, "2026-09-13");
      expect(slope).toBe(-1.0);
    });
  });

  describe("Weather Service Fallback Pattern", () => {
    test("returns graceful fallback values when API key is unset", async () => {
      const origKey = process.env.OPENWEATHER_API_KEY;
      delete process.env.OPENWEATHER_API_KEY;
      delete process.env.WEATHER_API_KEY;

      const weather = await getWeatherForecast({
        organizationId: "org_delhi",
        dateKey: "2026-09-13",
      });

      expect(weather).toHaveProperty("rainForecastMM");
      expect(weather).toHaveProperty("tempC");
      expect(typeof weather.rainForecastMM).toBe("number");
      expect(typeof weather.tempC).toBe("number");

      process.env.OPENWEATHER_API_KEY = origKey;
    });
  });

  describe("ONNX Demand Model & Fallback Integration", () => {
    const {
      loadDemandModel,
      predictDemandResidual,
      computePredictedDemand,
    } = require("../src/services/demand_model");

    test("loads ONNX model and predicts residual", async () => {
      const loaded = await loadDemandModel();
      expect(loaded).toBe(true);

      const residual = await predictDemandResidual({
        daysToNextHoliday: 5,
        isNationalHoliday: false,
        hasLocalEvent: false,
        eventSeverity: "none",
        rainForecastMM: 0,
        tempC: 28,
        recentTrend: 0.5,
        dayOfWeek: 2,
      });

      expect(typeof residual).toBe("number");
      expect(isNaN(residual)).toBe(false);
    });

    test("computes total predicted demand with baseline", async () => {
      const total = await computePredictedDemand({
        baseline: 30,
        features: {
          daysToNextHoliday: 2,
          isNationalHoliday: false,
          hasLocalEvent: true,
          eventSeverity: "high",
          rainForecastMM: 0,
          tempC: 30,
          recentTrend: 1.2,
          dayOfWeek: 5,
        },
      });

      expect(typeof total).toBe("number");
      expect(total).toBeGreaterThanOrEqual(0);
    });
  });

  describe("Fairness Score Replenishment Mechanism", () => {
    test("replenishes +0.05 per idle day for unassigned worker (>= 24 hours)", () => {
      const initial = 0.70;
      const replenished = calculateReplenishedFairness(initial, 24.5);
      expect(replenished).toBe(0.75);
    });

    test("does NOT replenish if worker accepted a booking in the past 24 hours", () => {
      const initial = 0.70;
      const hoursSince = 6.0; // assigned 6 hours ago
      const replenished = calculateReplenishedFairness(initial, hoursSince);
      expect(replenished).toBe(0.70);
    });

    test("rises back toward 1.0 over consecutive idle days and strictly caps at 1.0", () => {
      let score = 0.82; // worker starts at 0.82 after recent bookings

      // Simulate 10 consecutive idle days
      const history = [score];
      for (let day = 1; day <= 10; day++) {
        score = calculateReplenishedFairness(score, 24.0);
        history.push(score);
      }

      // Day 1: 0.82 + 0.05 = 0.87
      expect(history[1]).toBe(0.87);
      // Day 2: 0.87 + 0.05 = 0.92
      expect(history[2]).toBe(0.92);
      // Day 3: 0.92 + 0.05 = 0.97
      expect(history[3]).toBe(0.97);
      // Day 4: 0.97 + 0.05 = 1.02 -> capped at 1.00
      expect(history[4]).toBe(1.0);
      // Days 5 to 10: must stay strictly at 1.0 and never exceed it
      for (let day = 5; day <= 10; day++) {
        expect(history[day]).toBe(1.0);
      }
    });

    test("handles unassigned worker with null lastAssignedAt gracefully", () => {
      const score = calculateReplenishedFairness(0.95, null);
      expect(score).toBe(1.0);

      // Subsequent day on null remains 1.0
      const capped = calculateReplenishedFairness(1.0, null);
      expect(capped).toBe(1.0);
    });

    test("chunks updates into batches of <= 500 ops and updates all workers when count > 500", async () => {
      const TOTAL_WORKERS = 650;
      const updatedDocs = new Map();
      const batches = [];

      const mockDb = {
        collection: (name) => {
          if (name === "workers") {
            return {
              get: async () => {
                const docs = [];
                for (let i = 0; i < TOTAL_WORKERS; i++) {
                  docs.push({
                    id: `worker_${i}`,
                    ref: { id: `worker_${i}` },
                    data: () => ({
                      fairnessScore: 0.70,
                      lastAssignedAt: new Date(Date.now() - 30 * 3600 * 1000), // 30h ago (idle)
                    }),
                  });
                }
                return {
                  empty: false,
                  forEach: (cb) => docs.forEach(cb),
                };
              },
            };
          }
        },
        batch: () => {
          const ops = [];
          batches.push(ops);
          return {
            update: (ref, fields) => {
              if (ops.length >= 500) {
                throw new Error(
                  `Firestore limit exceeded: WriteBatch cannot exceed 500 operations! Found ${ops.length + 1}`
                );
              }
              ops.push({ ref, fields });
            },
            commit: async () => {
              if (ops.length > 500) {
                throw new Error("Firestore 500-op limit exceeded on commit");
              }
              for (const op of ops) {
                updatedDocs.set(op.ref.id, op.fields.fairnessScore);
              }
            },
          };
        },
      };

      const updatedCount = await replenishWorkerFairness(mockDb);

      // Verify all 650 workers were updated
      expect(updatedCount).toBe(TOTAL_WORKERS);
      expect(updatedDocs.size).toBe(TOTAL_WORKERS);

      // Verify chunking: 650 updates must span exactly 2 batches (500 + 150)
      expect(batches.length).toBe(2);
      expect(batches[0].length).toBe(500);
      expect(batches[1].length).toBe(150);

      // Confirm values were incremented from 0.70 -> 0.75
      expect(updatedDocs.get("worker_0")).toBe(0.75);
      expect(updatedDocs.get("worker_499")).toBe(0.75);
      expect(updatedDocs.get("worker_500")).toBe(0.75);
      expect(updatedDocs.get("worker_649")).toBe(0.75);
    });
  });

  describe("Worker Demand Alerts Dispatch (Step 6)", () => {
    test("dispatches HIGH_DEMAND_ALERT to online workers matching trade in high demand regions", async () => {
      const targetDate = "2026-09-14";
      const sentAlerts = [];
      const updatedWorkers = [];

      const mockMessaging = {
        sendEachForMulticast: jest.fn().mockImplementation((payload) => {
          sentAlerts.push(payload);
          return Promise.resolve({ successCount: 1, failureCount: 0 });
        }),
      };

      const mockDb = {
        collection: (col) => {
          if (col === "demandStats") {
            return {
              where: () => ({
                get: async () => ({
                  empty: false,
                  forEach: (cb) => {
                    // Region with high demand (predictedDemand = 75 -> "high")
                    cb({
                      id: "org_jaipur_2026-09-14",
                      data: () => ({
                        regionId: "org_jaipur",
                        topServiceType: "Pottery",
                        predictedDemand: 75,
                        dateKey: targetDate,
                      }),
                    });
                    // Region with low demand (predictedDemand = 25 -> "low")
                    cb({
                      id: "org_delhi_2026-09-14",
                      data: () => ({
                        regionId: "org_delhi",
                        topServiceType: "Carpentry",
                        predictedDemand: 25,
                        dateKey: targetDate,
                      }),
                    });
                  },
                }),
              }),
            };
          }

          if (col === "users") {
            return {
              doc: (id) => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    fcmTokens: ["fcm_token_" + id],
                    preferredLanguage: "hi",
                  }),
                }),
              }),
            };
          }

          if (col === "workers") {
            return {
              where: (field, op, val) => ({
                where: () => ({
                  get: async () => {
                    if (val === "org_jaipur") {
                      return {
                        empty: false,
                        docs: [
                          // Worker 1: Online, matching trade, not alerted recently -> SHOULD ALERT
                          {
                            id: "w_potter_1",
                            ref: { id: "w_potter_1" },
                            data: () => ({
                              userId: "u_potter_1",
                              skills: ["Pottery"],
                              availabilityStatus: "online",
                              lastDemandAlertAt: null,
                            }),
                          },
                          // Worker 2: Online, matching trade, BUT alerted 3 hours ago -> RATE LIMITED
                          {
                            id: "w_potter_2",
                            ref: { id: "w_potter_2" },
                            data: () => ({
                              userId: "u_potter_2",
                              skills: ["Pottery"],
                              availabilityStatus: "online",
                              lastDemandAlertAt: new Date(Date.now() - 3 * 3600 * 1000).toISOString(),
                            }),
                          },
                          // Worker 3: Online, different trade -> SHOULD NOT ALERT
                          {
                            id: "w_carpenter_1",
                            ref: { id: "w_carpenter_1" },
                            data: () => ({
                              userId: "u_carpenter_1",
                              skills: ["Carpentry"],
                              availabilityStatus: "online",
                              lastDemandAlertAt: null,
                            }),
                          },
                        ],
                      };
                    }
                    return { empty: true, docs: [] };
                  },
                }),
              }),
            };
          }
        },
        batch: () => ({
          update: (ref, fields) => updatedWorkers.push({ ref, fields }),
          commit: async () => {},
        }),
      };

      const dispatchedCount = await dispatchWorkerDemandAlerts(mockDb, mockMessaging, targetDate);

      // Only w_potter_1 should receive the alert
      expect(dispatchedCount).toBe(1);
      expect(sentAlerts.length).toBe(1);
      expect(sentAlerts[0].tokens).toContain("fcm_token_u_potter_1");
      expect(sentAlerts[0].notification.title).toBe("आज उच्च मांग की उम्मीद");
      expect(sentAlerts[0].notification.body).toContain("org_jaipur");
      expect(sentAlerts[0].notification.body).toContain("Pottery");

      // w_potter_1 must have lastDemandAlertAt updated
      expect(updatedWorkers.length).toBe(1);
      expect(updatedWorkers[0].ref.id).toBe("w_potter_1");
      expect(updatedWorkers[0].fields).toHaveProperty("lastDemandAlertAt");
    });
  });
});
