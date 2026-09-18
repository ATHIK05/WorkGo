const insightsRouter = require("../src/routes/insights");
const { classifyDemandLevel, extractContributingFactors } = insightsRouter;

describe("Insights Route - Demand Classification & Factor Attribution", () => {
  describe("classifyDemandLevel", () => {
    test("classifies volume < 45 as low", () => {
      expect(classifyDemandLevel(20)).toBe("low");
      expect(classifyDemandLevel(44)).toBe("low");
    });

    test("classifies volume 45-64 as medium", () => {
      expect(classifyDemandLevel(45)).toBe("medium");
      expect(classifyDemandLevel(55)).toBe("medium");
      expect(classifyDemandLevel(64)).toBe("medium");
    });

    test("classifies volume 65-84 as high", () => {
      expect(classifyDemandLevel(65)).toBe("high");
      expect(classifyDemandLevel(75)).toBe("high");
      expect(classifyDemandLevel(84)).toBe("high");
    });

    test("classifies volume >= 85 as surge", () => {
      expect(classifyDemandLevel(85)).toBe("surge");
      expect(classifyDemandLevel(120)).toBe("surge");
    });
  });

  describe("extractContributingFactors", () => {
    test("detects active local festival with severity", () => {
      const factors = extractContributingFactors({
        hasLocalEvent: true,
        eventSeverity: "high",
      });
      expect(factors.some((f) => f.includes("Active local festival/event") && f.includes("high"))).toBe(true);
    });

    test("detects national holiday", () => {
      const factors = extractContributingFactors({
        isNationalHoliday: true,
      });
      expect(factors.some((f) => f.includes("National or gazetted public holiday"))).toBe(true);
    });

    test("detects pre-festival preparation window", () => {
      const factors = extractContributingFactors({
        daysToNextHoliday: 2,
        isNationalHoliday: false,
      });
      expect(factors.some((f) => f.includes("Pre-festival preparation surge"))).toBe(true);
    });

    test("detects heavy rain forecast", () => {
      const factors = extractContributingFactors({
        rainForecastMM: 15.5,
      });
      expect(factors.some((f) => f.includes("Heavy rain forecast"))).toBe(true);
    });

    test("detects extreme heat wave", () => {
      const factors = extractContributingFactors({
        tempC: 41.0,
      });
      expect(factors.some((f) => f.includes("High temperature wave"))).toBe(true);
    });

    test("detects accelerating 7-day momentum", () => {
      const factors = extractContributingFactors({
        recentTrend: 1.8,
      });
      expect(factors.some((f) => f.includes("Accelerating 7-day booking momentum"))).toBe(true);
    });

    test("returns standard baseline message when no shock features exist", () => {
      const factors = extractContributingFactors({});
      expect(factors).toEqual(["Standard seasonal baseline activity"]);
    });
  });

  describe("deriveHighDemandTrades (Meteorological Shocks & Festival Attribution)", () => {
    test("triggers Plumbing and Electrician when heavy rain >= 10mm", () => {
      const trades = insightsRouter.deriveHighDemandTrades({
        rainForecastMM: 15.0,
        tempC: 28.0,
      });
      expect(trades).toContain("Plumbing");
      expect(trades).toContain("Electrician");
      expect(trades).not.toContain("Painting");
    });

    test("triggers Electrician and Painting during extreme heatwave >= 36°C", () => {
      const trades = insightsRouter.deriveHighDemandTrades({
        rainForecastMM: 0.0,
        tempC: 38.5,
      });
      expect(trades).toContain("Electrician");
      expect(trades).toContain("Painting");
      expect(trades).not.toContain("Plumbing");
    });

    test("unions meteorological shock trades with admin-entered local event tags", () => {
      const trades = insightsRouter.deriveHighDemandTrades({
        rainForecastMM: 22.0,
        tempC: 27.0,
        expectedDemandTags: ["Cleaning", "Carpentry"],
      });
      expect(trades).toEqual(
        expect.arrayContaining(["Plumbing", "Electrician", "Cleaning", "Carpentry"])
      );
    });

    test("returns empty array when no shocks or event tags are present", () => {
      const trades = insightsRouter.deriveHighDemandTrades({
        rainForecastMM: 2.0,
        tempC: 30.0,
      });
      expect(trades).toEqual([]);
    });
  });

  describe("Forward-Looking Speculative Forecasting (?forecastDate=YYYY-MM-DD)", () => {
    test("forecasts demand 60 days out with pre-registered local_event without running nightly cron", async () => {
      const d = new Date();
      d.setUTCDate(d.getUTCDate() + 60);
      const futureDateKey = d.toISOString().split("T")[0];

      let demandStatsWrites = 0;

      const preRegisteredEvent = {
        organizationId: "coop_tn_01",
        date: futureDateKey,
        name: "Annual Pongal Cultural Mela & Artisan Fair",
        severity: "high",
        expectedDemandTags: ["Painting", "Cleaning", "Plumbing"],
      };

      const mockDb = {
        collection: (col) => {
          if (col === "demandStats") {
            return {
              orderBy: () => ({
                limit: () => ({
                  get: async () => ({
                    forEach: (cb) => {
                      // Return historical 7-day baseline record (NOT the future date)
                      cb({
                        id: "coop_tn_01_2026-09-13",
                        data: () => ({
                          regionId: "coop_tn_01",
                          dateKey: "2026-09-13",
                          predictedDemand: 55,
                          bookingCount: 50,
                          recentTrend: 1.0,
                          topServiceType: "Plumbing",
                        }),
                      });
                    },
                  }),
                }),
              }),
              where: () => ({
                orderBy: () => ({
                  limit: () => ({
                    get: async () => ({
                      forEach: (cb) => {
                        cb({
                          id: "coop_tn_01_2026-09-13",
                          data: () => ({
                            regionId: "coop_tn_01",
                            dateKey: "2026-09-13",
                            predictedDemand: 55,
                            bookingCount: 50,
                            recentTrend: 1.0,
                            topServiceType: "Plumbing",
                          }),
                        });
                      },
                    }),
                  }),
                }),
              }),
              add: async () => {
                demandStatsWrites++;
              },
              doc: () => ({
                set: async () => {
                  demandStatsWrites++;
                },
              }),
            };
          }

          if (col === "local_events") {
            return {
              where: (field, op, val) => {
                let queryDate = null;
                let queryOrg = null;
                if (field === "date") queryDate = val;
                if (field === "organizationId") queryOrg = val;

                const chain = {
                  where: (f2, op2, val2) => {
                    if (f2 === "date") queryDate = val2;
                    if (f2 === "organizationId") queryOrg = val2;
                    return chain;
                  },
                  get: async () => {
                    if (queryDate === futureDateKey) {
                      return {
                        empty: false,
                        forEach: (cb) => cb({ data: () => preRegisteredEvent }),
                      };
                    }
                    return { empty: true, forEach: () => {} };
                  },
                };
                return chain;
              },
            };
          }

          return { get: async () => ({ empty: true, forEach: () => {} }) };
        },
      };

      let responsePayload = null;
      const req = {
        query: {
          regionId: "coop_tn_01",
          forecastDate: futureDateKey,
        },
        db: mockDb,
      };

      const res = {
        json: (data) => {
          responsePayload = data;
        },
        status: () => res,
      };

      await insightsRouter.handleGetDemandInsights(req, res);

      expect(responsePayload).not.toBeNull();
      expect(responsePayload.forecastDate).toBe(futureDateKey);
      expect(responsePayload.isSpeculativeFutureForecast).toBe(true);

      // Event signal is reflected in demand level & factors
      expect(["high", "surge", "medium"]).toContain(responsePayload.demandLevel);
      expect(
        responsePayload.contributingFactors.some(
          (f) => f.includes("Active local festival/event") && f.includes("high")
        )
      ).toBe(true);
      expect(responsePayload.highDemandTrades).toEqual(
        expect.arrayContaining(["Painting", "Cleaning", "Plumbing"])
      );

      // Weather beyond 14 days is explicitly null with descriptive note
      expect(responsePayload.weather.rainForecastMM).toBeNull();
      expect(responsePayload.weather.tempC).toBeNull();
      expect(responsePayload.weather.note).toBe("weather unavailable this far ahead");
      expect(
        responsePayload.contributingFactors.some((f) =>
          f.includes("weather unavailable this far ahead")
        )
      ).toBe(true);

      // Strict guarantee: speculative future forecast is NEVER written to demandStats
      expect(demandStatsWrites).toBe(0);
    });

    test("returns today's precomputed record without recomputation (dateKey match)", async () => {
      const todayKey = new Date().toISOString().split("T")[0];
      const precomputedToday = {
        regionId: "coop_tn_01",
        dateKey: todayKey,
        predictedDemand: 42,
        bookingCount: 40,
        demandLevel: "low",
        topServiceType: "Carpentry",
        contributingFactors: ["Standard seasonal baseline activity"],
        highDemandTrades: ["Carpentry"],
      };

      const mockDb = {
        collection: (col) => {
          if (col === "demandStats") {
            const chain = {
              limit: () => ({
                get: async () => ({
                  forEach: (cb) => {
                    cb({
                      id: `coop_tn_01_${todayKey}`,
                      data: () => precomputedToday,
                    });
                  },
                }),
              }),
            };
            return {
              orderBy: () => chain,
              where: () => ({
                orderBy: () => chain,
                limit: () => chain.limit(),
              }),
            };
          }
          return { get: async () => ({ empty: true, forEach: () => {} }) };
        },
      };

      let responsePayload = null;
      const req = {
        query: {
          regionId: "coop_tn_01",
        },
        db: mockDb,
      };

      const res = {
        json: (data) => {
          responsePayload = data;
        },
        status: () => res,
      };

      await insightsRouter.handleGetDemandInsights(req, res);

      expect(responsePayload).not.toBeNull();
      expect(responsePayload.isSpeculativeFutureForecast).toBe(false);
      expect(responsePayload.forecastDate).toBe(todayKey);
      expect(responsePayload.predictedDemand).toBe(42);
    });

    test("returns explicit 400 error when no regionId is provided and no history exists", async () => {
      const mockEmptyDb = {
        collection: () => ({
          orderBy: () => ({
            limit: () => ({
              get: async () => ({
                forEach: () => {},
              }),
            }),
          }),
        }),
      };

      let statusCode = 200;
      let errorPayload = null;
      const req = {
        query: {},
        db: mockEmptyDb,
      };
      const res = {
        status: (code) => {
          statusCode = code;
          return {
            json: (data) => {
              errorPayload = data;
            },
          };
        },
        json: (data) => {
          errorPayload = data;
        },
      };

      await insightsRouter.handleGetDemandInsights(req, res);

      expect(statusCode).toBe(400);
      expect(errorPayload).toHaveProperty("error");
      expect(errorPayload.error).toContain("Missing required parameter: regionId");
    });
  });
});


