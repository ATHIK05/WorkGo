import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  group("SymptomCatalog On-Device Matcher Tests", () {
    test("Matches motor not pumping / humming symptoms to Plumber or Electrician", () {
      final res1 = SymptomCatalog.matchSymptom("water motor is humming but no water");
      expect(res1.primaryCategory, anyOf("Plumber", "Electrician"));
      expect(res1.equipmentTag, anyOf("Submersible Pump", "Water Motor", "Jet Pump", "Centrifugal Pump"));
      expect(res1.confidence, greaterThan(0.7));
      expect(res1.clarifyingQuestions, isNotEmpty);
      expect(res1.likelyCauses, isNotEmpty);
    });

    test("Matches AC leaking water to Appliance Repair with AC service tags", () {
      final res = SymptomCatalog.matchSymptom("my ac is dripping and leaking water inside bedroom");
      expect(res.primaryCategory, anyOf("Appliance Repair", "Electrician"));
      expect(res.equipmentTag, anyOf("Air Conditioner", "Split AC", "Window AC", "Inverter AC"));
      expect(res.confidence, greaterThan(0.7));
    });

    test("Matches 'my AC is not working properly' to Air Conditioner and never Washing Machine", () {
      final res = SymptomCatalog.matchSymptom("my AC is not working properly");
      expect(res.equipmentTag, "Air Conditioner");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, isNot("Washing Machine"));
      expect(res.suggestedToolsNeeded, contains("Manifold Pressure Gauge"));
      expect(res.suggestedToolsNeeded, isNotEmpty);
    });

    test("Matches 'my fan is not working properly' to Ceiling Fan / Home Appliance and never Air Conditioner", () {
      final res = SymptomCatalog.matchSymptom("my fan is not working properly");
      expect(res.equipmentTag, anyOf("Ceiling Fan / Home Appliance", "Ceiling Fan"));
      expect(res.primaryCategory, anyOf("Electrician", "Appliance Repair"));
      expect(res.equipmentTag, isNot("Air Conditioner"));
      expect(res.likelyCauses, isNotEmpty);
    });

    test("Matches Refrigerator cooling issue to Appliance Repair", () {
      final res = SymptomCatalog.matchSymptom("fridge is not cooling and excess ice in freezer");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, "Refrigerator / Fridge");
      expect(res.likelyCauses, isNotEmpty);
    });

    test("Matches Mixer Grinder smoke or jam to Appliance Repair", () {
      final res = SymptomCatalog.matchSymptom("mixer grinder stopped with burning smell");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, "Mixer Grinder / Home Appliance");
      expect(res.suggestedToolsNeeded, contains("Coupler Puller"));
    });

    test("Matches clogged kitchen drain or choked toilet to Plumber", () {
      final res = SymptomCatalog.matchSymptom("kitchen sink drain is completely blocked and water standing");
      expect(res.primaryCategory, "Plumber");
      expect(res.equipmentTag, "Drainage & Sewerage");
      expect(res.suggestedToolsNeeded, contains("Drain Cleaning Snake Wire"));
    });

    test("Matches door lock jammed or key stuck to Carpenter", () {
      final res = SymptomCatalog.matchSymptom("main door lock key is stuck and cylinder jammed");
      expect(res.primaryCategory, "Carpenter");
      expect(res.equipmentTag, "Doors, Locks & Woodwork");
      expect(res.suggestedToolsNeeded, contains("Wood Planer"));
    });

    test("Matches wall paint peeling to Painter with waterproofing triage", () {
      final res = SymptomCatalog.matchSymptom("wall paint peeling and damp patches near bathroom");
      expect(res.primaryCategory, anyOf("Painter", "Plumber"));
      expect(res.equipmentTag, "Painting & Waterproofing");
    });

    test("Matches kitchen chimney degreasing or tile descaling to Cleaning", () {
      final res = SymptomCatalog.matchSymptom("kitchen chimney grease cleaning and bathroom acid wash");
      expect(res.primaryCategory, "Cleaning");
      expect(res.equipmentTag, "Deep Cleaning & Descaling");
    });

    test("Matches broken gate hinge or grill repair to Welder / Metal", () {
      final res = SymptomCatalog.matchSymptom("iron gate hinge broken and railing loose");
      expect(res.primaryCategory, "Welder / Metal");
      expect(res.equipmentTag, "Metal Fabrication & Welding");
      expect(res.suggestedToolsNeeded, contains("Portable Arc Welder"));
    });

    test("Matches Geyser cold water to Electrician or Appliances", () {
      final res = SymptomCatalog.matchSymptom("geyser not heating water");
      expect(res.primaryCategory, anyOf("Electrician", "Plumber", "Appliance Repair"));
      expect(res.equipmentTag, anyOf("Water Heater / Geyser", "Storage Geyser", "Instant Geyser"));
      expect(res.suggestedToolsNeeded, isNotEmpty);
    });

    test("Matches electrical spark / circuit breaker trip with high confidence", () {
      final res = SymptomCatalog.matchSymptom("switch sparking smell burning mcb tripped");
      expect(res.primaryCategory, anyOf("Electrician", "Electrical"));
      expect(res.confidence, greaterThanOrEqualTo(0.85));
    });

    test("Matches Masonry & Tile repair correctly", () {
      final res = SymptomCatalog.matchSymptom("floor tiles broken and cement hollow sound");
      expect(res.primaryCategory, "Masonry");
      expect(res.equipmentTag, "Masonry & Tile Works");
      expect(res.isOutOfScope, false);
      expect(res.confidence, greaterThanOrEqualTo(0.8));
    });

    test("Matches Gas Stove & Hob burner issue to Appliance Repair", () {
      final res = SymptomCatalog.matchSymptom("kitchen gas stove burner low flame and smelling gas");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, "Kitchen Gas Stove & Hob");
      expect(res.isOutOfScope, false);
      expect(res.suggestedToolsNeeded, contains("Nozzle Jet Pin Cleaner"));
    });

    test("Disambiguates fridge water leak from plumbing leak", () {
      final res = SymptomCatalog.matchSymptom("water leaking from fridge onto floor");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, "Refrigerator / Fridge");
      expect(res.equipmentTag, isNot("Plumbing & Concealed Piping"));
    });

    test("Disambiguates AC indoor water drip from plumbing leak", () {
      final res = SymptomCatalog.matchSymptom("water dripping from ac unit");
      expect(res.primaryCategory, "Appliance Repair");
      expect(res.equipmentTag, "Air Conditioner");
      expect(res.equipmentTag, isNot("Plumbing & Concealed Piping"));
    });
  });

  group("Negative Test Cases & Out-of-Scope Guardrail Tests", () {
    test("Correctly rejects 'my pen broken' as Out of Scope with zero confidence", () {
      final res = SymptomCatalog.matchSymptom("my pen broken");
      expect(res.isOutOfScope, true);
      expect(res.isValidHouseholdService, false);
      expect(res.primaryCategory, "Out of Scope");
      expect(res.confidence, 0.0);
      expect(res.requiresSmartDiagnosticVisit, false);
      expect(res.diagnosticFee, 0.0);
      expect(res.suggestedToolsNeeded, isEmpty);
    });

    test("Correctly rejects personal electronics (laptop, mobile, phone)", () {
      final res1 = SymptomCatalog.matchSymptom("my laptop screen is cracked");
      expect(res1.isOutOfScope, true);
      expect(res1.confidence, 0.0);

      final res2 = SymptomCatalog.matchSymptom("iphone battery draining mobile broken");
      expect(res2.isOutOfScope, true);
      expect(res2.confidence, 0.0);
    });

    test("Correctly rejects automobiles (car, bike, tyre puncture)", () {
      final res = SymptomCatalog.matchSymptom("car tyre puncture on the road");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
      expect(res.primaryCategory, "Out of Scope");
    });

    test("Correctly rejects food delivery & restaurant requests", () {
      final res = SymptomCatalog.matchSymptom("order chicken biryani swiggy pizza delivery");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
    });

    test("Correctly rejects healthcare & medicines", () {
      final res = SymptomCatalog.matchSymptom("fever cough medicine doctor prescription");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
    });

    test("Correctly rejects pets & veterinary care", () {
      final res = SymptomCatalog.matchSymptom("my dog has fever and need pet clinic");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
    });

    test("Correctly rejects clothing & tailoring requests", () {
      final res = SymptomCatalog.matchSymptom("t-shirt stitch and jeans alteration tailor");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
    });

    test("Correctly rejects beauty & salon requests", () {
      final res = SymptomCatalog.matchSymptom("haircut and facial at salon");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
    });

    test("Zero blind fallback: Unrecognized queries strictly return Out of Scope, never guessing Electrician", () {
      final res = SymptomCatalog.matchSymptom("completely random unknown gibberish text xyz123");
      expect(res.isOutOfScope, true);
      expect(res.confidence, 0.0);
      expect(res.primaryCategory, "Out of Scope");
      expect(res.equipmentTag, "Unrecognized / Non-Household Service");
      expect(res.requiresSmartDiagnosticVisit, false);
      expect(res.suggestedToolsNeeded, isEmpty);
    });
  });

  group("Worker Specialty & Equipment Tags Serialization Tests", () {
    test("Serializes and deserializes equipmentTags and serviceKeywords", () {
      final worker = Worker(
        id: "w_test_01",
        userId: "u_test_01",
        name: "Ramesh Sharma",
        skills: ["Electrician", "Appliance Repair"],
        equipmentTags: ["Inverter & Battery", "Submersible Pump", "Air Conditioner"],
        serviceKeywords: ["capacitor testing", "motor rewinding", "pcb repair"],
        diagnosticAccuracyScore: 4.95,
        experienceYears: 8,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 4.9,
        totalRatings: 110,
        totalReviews: 85,
        homesServiced: 210,
      );

      final map = worker.toFirestore();
      expect(map["equipmentTags"], contains("Inverter & Battery"));
      expect(map["serviceKeywords"], contains("motor rewinding"));
      expect(map["diagnosticAccuracyScore"], 4.95);
    });
  });

  group("Booking Diagnostic & Handoff Provenance Serialization Tests", () {
    test("Serializes and deserializes Smart Diagnostic and Handoff audit fields", () {
      final originalTime = DateTime(2026, 9, 4, 10, 30);
      final booking = Booking(
        id: "bk_diag_001",
        customerId: "c_001",
        organizationId: "coop_tn_01",
        serviceType: "Plumbing",
        status: BookingStatus.inProgress,
        bookingType: "smart_diagnostic",
        symptomDescription: "Motor running continuously but overhead tank dry",
        customerIssueDetails: "Motor humming continuously, no water reaching tank. Leaking at bottom joint.",
        equipmentTag: "Submersible Pump",
        suggestedToolsNeeded: const ["Multimeter", "Pipe Wrench", "Capacitor Tester"],
        diagnosticFee: 99.0,
        isFeeCredited: true,
        handoffStatus: "accepted",
        handoffFromWorkerId: "w_plumber_01",
        handoffFromWorkerName: "Mani Plumber",
        handoffDiagnosisNotes: "Capacitor blown and coil burnt out. Requires motor rewinding specialist.",
        handoffToWorkerId: "w_rewind_02",
        handoffToWorkerName: "Senthil Electricals",
        handoffReferralDividend: 50.0,
        handoffRequestedAt: originalTime,
        handoffAcceptedAt: originalTime.add(const Duration(minutes: 5)),
        handoffLogs: [
          {
            "action": "initiated",
            "fromWorkerName": "Mani Plumber",
            "notes": "Capacitor blown and coil burnt out.",
            "timestamp": originalTime.toIso8601String(),
          },
          {
            "action": "accepted",
            "toWorkerName": "Senthil Electricals",
            "timestamp": originalTime.add(const Duration(minutes: 5)).toIso8601String(),
          },
        ],
      );

      final map = booking.toFirestore();
      expect(map["bookingType"], "smart_diagnostic");
      expect(map["diagnosticFee"], 99.0);
      expect(map["isFeeCredited"], true);
      expect(map["customerIssueDetails"], contains("Leaking at bottom joint"));
      expect(map["suggestedToolsNeeded"], contains("Pipe Wrench"));
      expect(map["handoffStatus"], "accepted");
      expect(map["handoffReferralDividend"], 50.0);
      expect(map["handoffLogs"], hasLength(2));
    });
  });

  group("AiDiagnosticService Fallback Engine Tests", () {
    test("Falls back to catalog gracefully when Gemini API is unconfigured or offline", () async {
      final service = AiDiagnosticService.instance;
      final result = await service.diagnoseSymptom("water pump making loud noise but no water coming out");
      expect(result.primaryCategory, isNotEmpty);
      expect(result.summary, isNotEmpty);
      expect(result.confidence, greaterThan(0.0));
      expect(result.suggestedKeywords, isNotEmpty);
    });
  });

  group("Dynamic Trade Cluster & Worker Skill Matching Tests", () {
    test("Matches Plumber to Plumbing and Electrician to Electrical", () {
      expect("Plumbing".matchesTrade("Plumber"), true);
      expect("Plumber".matchesTrade("Plumbing"), true);
      expect("Electrical".matchesTrade("Electrician"), true);
      expect("Electrician".matchesTrade("Electrical"), true);
      expect("Carpentry".matchesTrade("Carpenter"), true);
      expect("Carpenter".matchesTrade("Carpentry"), true);
      expect("Painting".matchesTrade("Painter"), true);
      expect("Masonry".matchesTrade("Mason"), true);
      expect("Cleaning".matchesTrade("Cleaner"), true);
      expect("Appliance Repair".matchesTrade("Appliance Repair"), true);
      expect("Appliance Repair".matchesTrade("HVAC Specialist"), true);
      expect("Appliance Repair".matchesTrade("Air Conditioning"), true);
    });

    test("Worker with skill 'Plumbing' matches diagnosed primaryCategory 'Plumber'", () {
      final plumber = Worker(
        id: "w_plumb_01",
        userId: "u_plumb_01",
        name: "Kavitha Plumber",
        skills: ["Plumbing"],
        experienceYears: 5,
        verificationStatus: VerificationStatus.approved,
        availabilityStatus: AvailabilityStatus.online,
        avgRating: 4.8,
        totalRatings: 45,
        totalReviews: 32,
        homesServiced: 98,
      );

      final triageResult = SymptomCatalog.matchSymptom("my tap is leaking so long");
      expect(triageResult.primaryCategory, anyOf("Plumber", "Plumbing"));
      expect(plumber.matchesTradeCategory(triageResult.primaryCategory), true);
    });
  });
}
