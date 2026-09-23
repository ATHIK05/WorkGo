"use strict";

const { vectorTriage, VectorTriageService } = require("../src/services/vector_triage");

describe("Vector & Multilingual Triage Service (Tier 1.5)", () => {
  beforeAll(async () => {
    const ok = await vectorTriage.initialize();
    expect(ok).toBe(true);
  });

  describe("Initialization & Catalog Integrity", () => {
    it("should load 45 centroid vectors with 384 dimensions each", () => {
      expect(vectorTriage.isLoaded).toBe(true);
      expect(vectorTriage.catalogVectors.size).toBe(45);

      for (const [id, item] of vectorTriage.catalogVectors.entries()) {
        expect(item.vector).toBeInstanceOf(Float32Array);
        expect(item.vector.length).toBe(384);
        expect(item.equipmentTag).toBeTruthy();
        expect(item.trade).toBeTruthy();
      }
    });

    it("should load 45 base catalog items with 15 multilingual texts each (675 phrasings total)", () => {
      expect(vectorTriage.catalogItems.size).toBeGreaterThanOrEqual(45);
      const baseItems = Array.from(vectorTriage.catalogItems.values()).filter(
        (item) => item.isBaseCatalog === true
      );
      expect(baseItems.length).toBe(45);
      let totalPhrasings = 0;

      for (const item of baseItems) {
        expect(item.texts.length).toBe(15);
        totalPhrasings += item.texts.length;
      }

      expect(totalPhrasings).toBe(675);
      expect(vectorTriage.vocab.size).toBeGreaterThan(1000);
      expect(vectorTriage.idfMap.size).toBeGreaterThan(1000);
    });
  });

  describe("Symptom Matching across Core Trades", () => {
    it("should match English water motor symptom to Submersible Pump & Electrician + Plumber", async () => {
      const result = await vectorTriage.match("water motor not pumping overhead tank dry");
      expect(result).not.toBeNull();
      expect(result.primaryCategory).toBe("Electrician");
      expect(result.secondaryCategory).toBe("Plumber");
      expect(result.equipmentTag).toBe("Submersible Pump");
      expect(result.requiresSmartDiagnosticVisit).toBe(true);
      expect(result.diagnosticFee).toBe(149.0);
      expect(result.confidence).toBeGreaterThanOrEqual(0.65);
      expect(result.source).toBe("vector_search");
    });

    it("should match inverter battery symptom with cross-disciplinary trade", async () => {
      const result = await vectorTriage.match("inverter is beeping battery dead no backup during power cut");
      expect(result).not.toBeNull();
      expect(result.primaryCategory).toBe("Electrician");
      expect(result.secondaryCategory).toBe("Appliance Repair");
      expect(result.equipmentTag).toBe("Inverter & Battery");
      expect(result.requiresSmartDiagnosticVisit).toBe(true);
      expect(result.diagnosticFee).toBe(149.0);
    });

    it("should match geyser heating issue", async () => {
      const result = await vectorTriage.match("geyser not heating water thermostat tripped");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Water Heater / Geyser");
      expect(result.confidence).toBeGreaterThanOrEqual(0.65);
    });

    it("should match clogged drain symptom to Plumber", async () => {
      const result = await vectorTriage.match("bathroom drain blocked floor trap clogged sewage backup");
      expect(result).not.toBeNull();
      expect(result.primaryCategory).toBe("Plumber");
      expect(result.equipmentTag).toBe("Drainage & Sewerage");
      expect(result.confidence).toBeGreaterThanOrEqual(0.65);
    });

    it("should match ceiling fan issues", async () => {
      const result = await vectorTriage.match("ceiling fan running very slow capacitor problem");
      expect(result).not.toBeNull();
      expect(result.primaryCategory).toBe("Electrician");
      expect(result.confidence).toBeGreaterThanOrEqual(0.65);
    });
  });

  describe("Multilingual & Vernacular Script Matching", () => {
    it("should match Hindi Devanagari query", async () => {
      const result = await vectorTriage.match("मोटर चल रहा है पर पानी नहीं आ रहा बोरवेल पंप बंद");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
      expect(result.primaryCategory).toBe("Electrician");
    });

    it("should match Tamil query", async () => {
      const result = await vectorTriage.match("மோட்டார் ஓடல தண்ணீர் வரல பம்ப் வேலை செய்யல");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
      expect(result.primaryCategory).toBe("Electrician");
    });

    it("should match Telugu query", async () => {
      const result = await vectorTriage.match("నీళ్ళ మోటర్ నడుస్తోంది కానీ నీళ్ళు రావడం లేదు ట్యాంక్ నిండట్లేదు");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
      expect(result.primaryCategory).toBe("Electrician");
    });

    it("should match Tanglish / Hinglish colloquial query", async () => {
      const result = await vectorTriage.match("motor la sound varudhu thani varala");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
    });

    it("should match Bengali query", async () => {
      const result = await vectorTriage.match("মোটর চলছে কিন্তু জল আসছে না বোরওয়েল পাম্প খারাপ");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
    });

    it("should match Marathi query", async () => {
      const result = await vectorTriage.match("सबमर्सिबल मोटर चालू आहे पण पाणी येत नाही पाण्याची टाकी भरत नाही");
      expect(result).not.toBeNull();
      expect(result.equipmentTag).toBe("Submersible Pump");
    });
  });

  describe("Negative Guardrails & Out-of-Scope Detection", () => {
    it("should reject automotive requests as Out of Scope", async () => {
      const result = await vectorTriage.match("my car tyre puncture and bike engine oil change");
      expect(result).not.toBeNull();
      expect(result.isOutOfScope).toBe(true);
      expect(result.primaryCategory).toBe("Out of Scope");
      expect(result.confidence).toBe(0.0);
    });

    it("should reject electronics / laptop repair requests as Out of Scope", async () => {
      const result = await vectorTriage.match("smartphone screen cracked and laptop battery issue");
      expect(result).not.toBeNull();
      expect(result.isOutOfScope).toBe(true);
      expect(result.primaryCategory).toBe("Out of Scope");
    });

    it("should reject medical requests as Out of Scope", async () => {
      const result = await vectorTriage.match("need doctor medicine for severe fever hospital appointment");
      expect(result).not.toBeNull();
      expect(result.isOutOfScope).toBe(true);
      expect(result.primaryCategory).toBe("Out of Scope");
    });
  });

  describe("Fallback Behavior for Ambiguous / Vague Queries", () => {
    it("should return null for greetings or vague words so Gemini can reason", async () => {
      const result = await vectorTriage.match("hello good morning how are you");
      expect(result).toBeNull();
    });

    it("should return null for empty or non-string query", async () => {
      expect(await vectorTriage.match("")).toBeNull();
      expect(await vectorTriage.match("   ")).toBeNull();
      expect(await vectorTriage.match(null)).toBeNull();
    });
  });

  describe("Centroid Vector Nearest-Neighbor Search", () => {
    it("should find exact match when given a catalog centroid vector", () => {
      const targetItem = vectorTriage.catalogVectors.get("water_motor_failure");
      expect(targetItem).toBeDefined();

      const match = vectorTriage.findNearestCentroid(targetItem.vector);
      expect(match).not.toBeNull();
      expect(match.id).toBe("water_motor_failure");
      expect(match.similarity).toBeCloseTo(1.0, 3);
      expect(match.equipmentTag).toBe("Submersible Pump");
      expect(match.trade).toBe("Electrician");
    });

    it("should find closest centroid for a slightly perturbed vector", () => {
      const targetItem = vectorTriage.catalogVectors.get("inverter_backup_failure");
      const perturbed = new Float32Array(targetItem.vector);
      // Add small noise
      for (let i = 0; i < perturbed.length; i++) {
        perturbed[i] += (Math.random() - 0.5) * 0.01;
      }

      const match = vectorTriage.findNearestCentroid(perturbed);
      expect(match).not.toBeNull();
      expect(match.id).toBe("inverter_backup_failure");
      expect(match.similarity).toBeGreaterThan(0.95);
    });
  });
});
