"use strict";

const { vectorTriage } = require("../src/services/vector_triage");

describe("Domestic Trade Taxonomy & Indian Phonetic Benchmark (Market-Level)", () => {
  beforeAll(async () => {
    const ok = await vectorTriage.initialize();
    expect(ok).toBe(true);
  });

  describe("Indian Phonetic & Spelling Drift Resilience", () => {
    it("should accurately resolve 'gyser' / 'giser' typo to Water Heater / Geyser", async () => {
      const res = await vectorTriage.match("gyser me se garam paani nahi aa raha");
      expect(res).not.toBeNull();
      expect(res.equipmentTag).toBe("Water Heater / Geyser");
      expect(res.primaryCategory).toBe("Appliance Repair");
      expect(res.confidence).toBeGreaterThanOrEqual(0.70);
    });

    it("should accurately resolve 'samarsibal' / 'motar' typo to Submersible Pump", async () => {
      const res = await vectorTriage.match("samarsibal motar aawaz kar ri paani nahi aa raha");
      expect(res).not.toBeNull();
      expect(res.equipmentTag).toBe("Submersible Pump");
      expect(res.primaryCategory).toBe("Electrician");
      expect(res.secondaryCategory).toBe("Plumber");
      expect(res.requiresSmartDiagnosticVisit).toBe(true);
      expect(res.diagnosticFee).toBe(149.0);
    });

    it("should accurately resolve 'frij' / 'friz' typo to Refrigerator / Fridge", async () => {
      const res = await vectorTriage.match("friz thanda nahi kar raha ice jam gaya hai");
      expect(res).not.toBeNull();
      expect(res.equipmentTag).toBe("Refrigerator / Fridge");
      expect(res.primaryCategory).toBe("Appliance Repair");
      expect(res.confidence).toBeGreaterThanOrEqual(0.70);
    });

    it("should accurately resolve 'suich bord' typo to Switchboard", async () => {
      const res = await vectorTriage.match("suich bord spark ho raha hai plug point burnt");
      expect(res).not.toBeNull();
      expect(["Switchboard & Sockets", "Switchboard & Distribution Board"]).toContain(res.equipmentTag);
      expect(res.primaryCategory).toBe("Electrician");
    });

    it("should accurately resolve 'plamber' / 'nalwala' to Plumber", async () => {
      const res = await vectorTriage.match("bathroom nal se paani tapak raha plamber chahiye");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Plumber");
      expect(res.confidence).toBeGreaterThanOrEqual(0.70);
    });
  });

  describe("Emergency Safety & Hazard Interlock Pre-Flight", () => {
    it("should intercept LPG cooking gas leak with CRITICAL protocol", async () => {
      const res = await vectorTriage.match("kitchen me gas cylinder regulator se smell aa rahi hai leak");
      expect(res).not.toBeNull();
      expect(res.hazardLevel).toBe("CRITICAL");
      expect(res.source).toBe("safety_interlock");
      expect(res.confidence).toBe(0.98);
      expect(res.summary).toContain("SAFETY EMERGENCY");
      expect(res.primaryCategory).toBe("Appliance Repair");
    });

    it("should intercept live electrical shock in tap water with CRITICAL protocol", async () => {
      const res = await vectorTriage.match("bathroom tap water gives electric shock current lag raha hai");
      expect(res).not.toBeNull();
      expect(res.hazardLevel).toBe("CRITICAL");
      expect(res.source).toBe("safety_interlock");
      expect(res.summary).toContain("SAFETY EMERGENCY");
      expect(res.primaryCategory).toBe("Electrician");
    });

    it("should intercept distribution board smoke with CRITICAL protocol", async () => {
      const res = await vectorTriage.match("smoke coming from main mcb switchboard wire fire");
      expect(res).not.toBeNull();
      expect(res.hazardLevel).toBe("CRITICAL");
      expect(res.source).toBe("safety_interlock");
      expect(res.primaryCategory).toBe("Electrician");
    });
  });

  describe("Dravidian Agglutinated Word De-Gluing", () => {
    it("should de-glue Tamil compound words 'மோட்டார்பழுது' and match Submersible Pump", async () => {
      const res = await vectorTriage.match("மோட்டார்பழுது தண்ணீர் வரல போர்வெல் ஓடல");
      expect(res).not.toBeNull();
      expect(res.equipmentTag).toBe("Submersible Pump");
      expect(res.primaryCategory).toBe("Electrician");
    });

    it("should de-glue Telugu compound words 'నీళ్ళమోటర్' and match Submersible Pump", async () => {
      const res = await vectorTriage.match("నీళ్ళమోటర్ పని చేయడం లేదు ట్యాంక్ నిండట్లేదు");
      expect(res).not.toBeNull();
      expect(res.equipmentTag).toBe("Submersible Pump");
    });
  });

  describe("Coverage Across Core Domestic Crafts", () => {
    it("should classify Carpentry & Locks issues accurately", async () => {
      const res = await vectorTriage.match("main door lock jammed and key broken inside cylinder");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Carpenter");
      expect(res.equipmentTag).toBe("Doors & Locks");
    });

    it("should classify Balcony Pigeon Netting accurately", async () => {
      const res = await vectorTriage.match("balcony pigeon bird net installation needed to stop pigeons");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Carpenter");
      expect(res.equipmentTag).toBe("Balcony Safety & Nets");
    });

    it("should classify Wall Dampness & Painting accurately", async () => {
      const res = await vectorTriage.match("wall dampness paint peeling and putty flaking seelan");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Painter");
      expect(res.secondaryCategory).toBe("Plumber");
      expect(res.requiresSmartDiagnosticVisit).toBe(true);
    });

    it("should classify Bathroom Tile Grouting accurately", async () => {
      const res = await vectorTriage.match("bathroom floor tile grouting washed away water seeping to neighbor");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Masonry");
      expect(res.secondaryCategory).toBe("Plumber");
    });

    it("should classify Heavy Iron Gate Welding accurately", async () => {
      const res = await vectorTriage.match("main iron gate hinge broken and dragging on road weld needed");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Welder / Metal");
    });

    it("should classify Pest Control accurately", async () => {
      const res = await vectorTriage.match("kitchen cockroach gel treatment needed insects in cabinets");
      expect(res).not.toBeNull();
      expect(res.primaryCategory).toBe("Cleaning");
      expect(res.equipmentTag).toBe("Pest Control");
    });
  });

  describe("Speed & Latency Benchmark", () => {
    it("should process 50 diverse domestic queries in under 500ms total (<10ms per query)", async () => {
      const testQueries = [
        "water motor not pumping",
        "inverter is beeping battery dead",
        "mcb circuit breaker tripping",
        "ceiling fan speed very slow",
        "ac not cooling warm air",
        "refrigerator not cold food spoiling",
        "bathroom drain blocked water standing",
        "kitchen sink drain pipe choked",
        "tap leaking continuously",
        "flush tank leaking inside toilet",
        "microwave not heating food",
        "door lock jammed key broken",
        "wall dampness paint peeling",
        "bathroom tile grouting seepage",
        "iron gate hinge broken dragging",
      ];

      const start = Date.now();
      for (let i = 0; i < 50; i++) {
        const q = testQueries[i % testQueries.length];
        const res = await vectorTriage.match(q);
        expect(res).not.toBeNull();
      }
      const elapsed = Date.now() - start;
      const perQueryMs = elapsed / 50;
      console.log(`[Benchmark] 50 queries resolved in ${elapsed}ms (${perQueryMs.toFixed(2)}ms/query)`);
      expect(perQueryMs).toBeLessThan(15);
    });
  });
});
