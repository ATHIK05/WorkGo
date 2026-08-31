import "dart:typed_data";
import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  test("WorkGoColors primary is defined", () {
    expect(WorkGoColors.primary.toARGB32(), isNonZero);
  });

  test("WorkGoSpacing values are correct", () {
    expect(WorkGoSpacing.xs, 4.0);
    expect(WorkGoSpacing.sm, 8.0);
    expect(WorkGoSpacing.md, 16.0);
    expect(WorkGoSpacing.lg, 24.0);
    expect(WorkGoSpacing.xl, 32.0);
  });

  test("UserRole enum has all required roles", () {
    expect(UserRole.values.map((r) => r.name), containsAll(["customer", "worker", "admin"]));
  });

  test("WorkGoLocale has 3 supported locales", () {
    expect(WorkGoLocale.supported.length, 3);
    final codes = WorkGoLocale.supported.map((l) => l.languageCode).toList();
    expect(codes, containsAll(["en", "hi", "ta"]));
  });

  test("WorkGoLocale fallback is English", () {
    expect(WorkGoLocale.fallback.languageCode, "en");
  });

  test("Worker model has name, homesServiced, and verification checks", () {
    final worker = Worker(
      id: "w_test_01",
      userId: "u_test_01",
      name: "Karthik Raja",
      skills: ["Plumbing"],
      experienceYears: 6,
      verificationStatus: VerificationStatus.approved,
      availabilityStatus: AvailabilityStatus.online,
      avgRating: 4.9,
      totalRatings: 94,
      totalReviews: 76,
      homesServiced: 128,
      distanceKm: 2.4,
    );

    expect(worker.name, "Karthik Raja");
    expect(worker.isApproved, true);
    expect(worker.homesServiced, 128);
    expect(worker.totalReviews, 76);
    expect(worker.distanceKm, 2.4);
  });

  test("CooperativePricingEngine calculates Rapido-style dynamic fare accurately", () {
    final pricing = CooperativePricingEngine.instance;

    // Standard Plumbing (2.0 km, 3 yrs exp, no emergency)
    final fare1 = pricing.calculateFare(
      category: "Plumbing",
      distanceKm: 2.0,
      experienceYears: 3,
      isEmergency: false,
    );
    // Base 149 + Distance (2.0 * 12 = 24) + Exp (15) = 188
    expect(fare1.baseVisitFare, 149.0);
    expect(fare1.distanceTransitFare, 24.0);
    expect(fare1.experienceBonus, 15.0);
    expect(fare1.totalEstimatedFare, 188.0);

    // Master Carpenter (3.0 km, 6 yrs exp, emergency = true)
    final fare2 = pricing.calculateFare(
      category: "Carpentry",
      distanceKm: 3.0,
      experienceYears: 6,
      isEmergency: true,
      urgencyTip: 50.0,
    );
    // Base 199 + Distance (3.0 * 12 = 36) + Exp (30) + Emergency (150) + Tip (50) = 465
    expect(fare2.baseVisitFare, 199.0);
    expect(fare2.distanceTransitFare, 36.0);
    expect(fare2.experienceBonus, 30.0);
    expect(fare2.emergencySurcharge, 150.0);
    expect(fare2.totalEstimatedFare, 465.0);
  });

  test("UserAddress model serializes and formats correctly", () {
    final addr = UserAddress(
      id: "addr_123",
      label: AddressLabel.home,
      flatBuilding: "Flat 304, Sapphire Block",
      streetArea: "15, Anna Main Road, T. Nagar",
      landmark: "Near Panagal Park",
      city: "Chennai",
      state: "Tamil Nadu",
      pincode: "600017",
      formattedAddress: "Flat 304, Sapphire Block, 15, Anna Main Road, T. Nagar, Chennai, Tamil Nadu 600017",
      latitude: 13.0418,
      longitude: 80.2341,
      isDefault: true,
      createdAt: DateTime.parse("2026-08-30T10:00:00.000Z"),
    );

    expect(addr.displayTitle, "Home");
    expect(addr.shortSummary, "15, Anna Main Road, T. Nagar, Chennai");
    expect(addr.isDefault, true);

    final map = addr.toMap();
    expect(map["label"], "home");
    expect(map["pincode"], "600017");

    final deserialized = UserAddress.fromMap(map);
    expect(deserialized.id, "addr_123");
    expect(deserialized.label, AddressLabel.home);
    expect(deserialized.latitude, 13.0418);
    expect(deserialized.longitude, 80.2341);
  });

  test("LocationService calculates Haversine distance correctly", () {
    final locationService = LocationService.instance;
    // T. Nagar (13.0418, 80.2341) to Marina Beach (13.0500, 80.2824) is approx 5.3 km
    final dist = locationService.calculateDistanceKm(13.0418, 80.2341, 13.0500, 80.2824);
    expect(dist, greaterThan(4.0));
    expect(dist, lessThan(7.0));
  });

  test("Worker verification stages and visibility status defaults", () {
    final worker = Worker(
      id: "w_verify_01",
      userId: "u_verify_01",
      name: "Murugan S.",
      skills: ["Plumbing"],
      experienceYears: 5,
      verificationStatus: VerificationStatus.approved,
      visibilityStatus: VisibilityStatus.public,
      verificationStage: VerificationStage.approved,
      availabilityStatus: AvailabilityStatus.online,
      verificationDetails: const VerificationDetails(
        aadhaarVerifiedName: "Murugan Shanmugam",
        aadhaarMaskedNumber: "XXXXXXXX9842",
        livenessScore: 0.985,
        videoCallPhrase: "VIOLET-892-SUN",
        pccDocumentId: "pcc_doc_112233",
      ),
    );

    expect(worker.isApproved, true);
    expect(worker.isPubliclyVisible, true);
    expect(worker.verificationStage, VerificationStage.approved);
    expect(worker.verificationDetails?.aadhaarVerifiedName, "Murugan Shanmugam");
    expect(worker.verificationDetails?.videoCallPhrase, "VIOLET-892-SUN");
  });

  test("C2paService computes accurate SHA-256 hash on raw bytes", () {
    final c2paService = C2paService();
    final rawBytes = Uint8List.fromList("workgo_test_image_bytes".codeUnits);
    final hash = c2paService.computeSha256(rawBytes);

    expect(hash.length, 64);
    expect(hash, isNotEmpty);
  });

  test("VerificationAuditLog and VideoKycBooking models serialize properly", () {
    final log = VerificationAuditLog(
      id: "val_test_01",
      workerId: "w_123",
      fromStage: "liveVideoVerification",
      toStage: "pccUpload",
      action: "VIDEO_CALL_PASSED",
      actorId: "admin_01",
      actorRole: "coop_admin",
      reason: "Artisan matched ID photo and repeated challenge phrase",
      timestamp: DateTime.parse("2026-08-31T12:00:00.000Z"),
    );

    expect(log.action, "VIDEO_CALL_PASSED");
    expect(log.actorRole, "coop_admin");

    final booking = VideoKycBooking(
      id: "vcall_test_01",
      workerId: "w_123",
      slotTime: DateTime.parse("2026-09-01T10:30:00.000Z"),
      status: VideoKycStatus.scheduled,
      roomName: "workgo_kyc_w_123",
      randomPhrase: "VIOLET-892-SUN",
      createdAt: DateTime.parse("2026-08-31T12:00:00.000Z"),
    );

    expect(booking.status, VideoKycStatus.scheduled);
    expect(booking.randomPhrase, "VIOLET-892-SUN");
  });

  test("Booking model preserves startOtp and live worker coordinates", () {
    final booking = Booking(
      id: "b_test_otp_01",
      customerId: "cust_123",
      organizationId: "coop_tn_01",
      serviceType: "Plumbing",
      status: BookingStatus.accepted,
      amount: 299.0,
      startOtp: "8492",
      customerAddressText: "1148 E Main St, Thanjavur",
      customerLatitude: 10.7870,
      customerLongitude: 79.1378,
      workerLatitude: 10.7850,
      workerLongitude: 79.1360,
    );

    expect(booking.startOtp, "8492");
    expect(booking.customerAddressText, "1148 E Main St, Thanjavur");
    expect(booking.workerLatitude, 10.7850);

    final map = booking.toFirestore();
    expect(map["startOtp"], "8492");
    expect(map["customerAddressText"], "1148 E Main St, Thanjavur");
  });
}



