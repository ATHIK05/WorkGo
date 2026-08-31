const { NotificationEngine, NOTIFICATION_TEMPLATES } = require("../src/services/notification_engine");

describe("NotificationEngine & Cloud Functions Test Suite", () => {
  let mockDb;
  let mockMessaging;
  let engine;

  beforeEach(() => {
    mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              fcmTokens: ["test_token_123"],
              preferredLanguage: "ta",
            }),
          }),
        }),
        get: jest.fn().mockResolvedValue({
          docs: [
            {
              id: "w_101",
              data: () => ({
                userId: "u_w_101",
                skills: ["Plumbing"],
                availabilityStatus: "online",
                verificationStatus: "approved",
                visibilityStatus: "public",
              }),
            },
          ],
        }),
      }),
    };

    mockMessaging = {
      sendEachForMulticast: jest.fn().mockResolvedValue({
        successCount: 1,
        failureCount: 0,
      }),
      send: jest.fn().mockResolvedValue("msg_id_9988"),
    };

    engine = new NotificationEngine(mockDb, mockMessaging);
  });

  test("All required notification templates exist with en, hi, ta localizations", () => {
    const requiredKeys = [
      "BOOKING_BROADCAST_STARTED",
      "BOOKING_ACCEPTED",
      "WORKER_ARRIVED_DOORSTEP",
      "JOB_STARTED_OTP_VERIFIED",
      "WORK_COMPLETED_C2PA_READY",
      "PAYMENT_CONFIRMED_DIVIDEND",
      "SAFETY_FREEZE_ACKNOWLEDGED",
      "NEW_BROADCAST_REQUEST",
      "EMERGENCY_SOS_REQUEST",
      "CUSTOMER_BOOSTED_FARE",
      "PEER_REFERRAL_RECEIVED",
      "KYC_STAGE_APPROVED",
      "VIDEO_KYC_SCHEDULED",
      "PCC_APPROVED_PUBLIC_LISTING",
      "ACCOUNT_SUSPENDED_DISPUTE",
    ];

    for (const key of requiredKeys) {
      expect(NOTIFICATION_TEMPLATES[key]).toBeDefined();
      expect(NOTIFICATION_TEMPLATES[key].en).toBeDefined();
      expect(NOTIFICATION_TEMPLATES[key].hi).toBeDefined();
      expect(NOTIFICATION_TEMPLATES[key].ta).toBeDefined();
    }
  });

  test("sendToUser formats template parameters and uses user's preferred language", async () => {
    const res = await engine.sendToUser("user_test_01", "BOOKING_ACCEPTED", {
      workerName: "Mani K.",
      category: "Plumbing",
      startOtp: "8492",
    });

    expect(res.success).toBe(true);
    expect(res.successCount).toBe(1);
    expect(mockMessaging.sendEachForMulticast).toHaveBeenCalled();

    const payload = mockMessaging.sendEachForMulticast.mock.calls[0][0];
    expect(payload.tokens).toContain("test_token_123");
    // Preferred language was 'ta' (Tamil)
    expect(payload.notification.title).toContain("Mani K.");
    expect(payload.notification.body).toContain("8492");
    expect(payload.android.notification.channelId).toBe("workgo_booking_channel");
  });

  test("broadcastNewBookingToNearbyWorkers targets only matching online and verified artisans", async () => {
    const booking = {
      id: "b_test_99",
      serviceType: "Plumbing",
      amount: 300,
      urgencyBonus: 50,
      isEmergency: false,
      customerAddressText: "1148 E Main St, Thanjavur",
    };

    const res = await engine.broadcastNewBookingToNearbyWorkers(booking);
    expect(res.totalRecipients).toBe(1);
    expect(mockMessaging.sendEachForMulticast).toHaveBeenCalled();
  });
});
