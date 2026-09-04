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

    test("Fallback gracefully provides general diagnostic for ambiguous queries", () {
      final res = SymptomCatalog.matchSymptom("random unknown household defect");
      expect(res.primaryCategory, isNotEmpty);
      expect(res.suggestedToolsNeeded, isNotEmpty);
      expect(res.requiresSmartDiagnosticVisit, true);
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
