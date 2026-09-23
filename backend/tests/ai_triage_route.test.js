"use strict";

const triageRouter = require("../src/routes/ai_triage");
const { vectorTriage } = require("../src/services/vector_triage");

describe("AI Triage Route & Customer App Wire Test (POST /api/ai/triage)", () => {
  beforeAll(async () => {
    await vectorTriage.initialize();
  });

  function createMockReqRes(body) {
    const req = {
      body,
      db: {
        collection: () => ({
          doc: () => ({
            get: async () => ({ exists: false }),
            set: async () => {},
          }),
        }),
      },
    };

    let statusCode = 200;
    let jsonPayload = null;

    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(payload) {
        jsonPayload = payload;
        return this;
      },
    };

    return { req, res, getStatus: () => statusCode, getJson: () => jsonPayload };
  }

  it("should wire customer water motor query directly to Vector Triage and return valid DiagnosticResult JSON", async () => {
    // Find the POST /triage route handler
    const postRoute = triageRouter.stack.find(
      (layer) => layer.route && layer.route.path === "/triage" && layer.route.methods.post
    );
    expect(postRoute).toBeDefined();

    const { req, res, getStatus, getJson } = createMockReqRes({
      query: "samarsibal motar aawaz kar ri paani nahi aa raha",
      language: "hi",
    });

    await postRoute.route.stack[0].handle(req, res);

    expect(getStatus()).toBe(200);
    const result = getJson();
    expect(result).not.toBeNull();

    // Verify all fields expected by Flutter's DiagnosticResult.fromMap
    expect(result.symptomQuery).toBe("samarsibal motar aawaz kar ri paani nahi aa raha");
    expect(result.primaryCategory).toBe("Electrician");
    expect(result.secondaryCategory).toBe("Plumber");
    expect(result.equipmentTag).toBe("Submersible Pump");
    expect(result.confidence).toBeGreaterThanOrEqual(0.65);
    expect(result.requiresSmartDiagnosticVisit).toBe(true);
    expect(result.diagnosticFee).toBe(149.0);
    expect(Array.isArray(result.likelyCauses)).toBe(true);
    expect(Array.isArray(result.clarifyingQuestions)).toBe(true);
    expect(result.isAiGenerated).toBe(true);
    expect(result.isOutOfScope).toBe(false);
    expect(result.source).toBe("vector_search");
  });

  it("should wire emergency gas leak query directly to safety interlock", async () => {
    const postRoute = triageRouter.stack.find(
      (layer) => layer.route && layer.route.path === "/triage" && layer.route.methods.post
    );

    const { req, res, getStatus, getJson } = createMockReqRes({
      query: "gas cylinder smell in kitchen leak",
      language: "en",
    });

    await postRoute.route.stack[0].handle(req, res);

    expect(getStatus()).toBe(200);
    const result = getJson();
    expect(result.hazardLevel).toBe("CRITICAL");
    expect(result.source).toBe("safety_interlock");
    expect(result.summary).toContain("SAFETY EMERGENCY");
  });

  it("should reject out-of-scope query cleanly with 200 and isOutOfScope: true", async () => {
    const postRoute = triageRouter.stack.find(
      (layer) => layer.route && layer.route.path === "/triage" && layer.route.methods.post
    );

    const { req, res, getStatus, getJson } = createMockReqRes({
      query: "car tyre puncture and engine oil change",
      language: "en",
    });

    await postRoute.route.stack[0].handle(req, res);

    expect(getStatus()).toBe(200);
    const result = getJson();
    expect(result.isOutOfScope).toBe(true);
    expect(result.primaryCategory).toBe("Out of Scope");
    expect(result.confidence).toBe(0.0);
  });
});
