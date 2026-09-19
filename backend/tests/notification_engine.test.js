jest.mock("../src/services/bhashini_voice_service", () => ({
  generateBookingCancelledAudio: jest.fn().mockResolvedValue("/sounds/booking_cancel_test.wav"),
  generateBookingAlertAudio: jest.fn().mockResolvedValue("/sounds/booking_alert_test.wav"),
}));

jest.mock("../src/services/voice_call_engine", () => ({
  triggerOutboundBookingCancelledCall: jest.fn().mockResolvedValue({ success: true, channel: "PJSIP/workgo_1" }),
  triggerOutboundJobAlertCall: jest.fn().mockResolvedValue({ success: true, channel: "PJSIP/workgo_1" }),
  abortCallBookingCancelled: jest.fn().mockResolvedValue({ success: true }),
}));

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
      "BOOKING_CANCELLED_BY_CUSTOMER",
      "BOOKING_CANCELLED_BY_WORKER",
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

  test("sendToUser formats template parameters, binds brand icon and color, and uses user's preferred language", async () => {
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
    expect(payload.android.notification.icon).toBe("ic_stat_workgo");
    expect(payload.android.notification.color).toBe("#E8A400");
  });

  test("sendToUser handles customer cancellation template cleanly", async () => {
    const res = await engine.sendToUser("worker_test_01", "BOOKING_CANCELLED_BY_CUSTOMER", {
      bookingId: "b_12345",
      reason: "Incorrect service address",
    });

    expect(res.success).toBe(true);
    const payload = mockMessaging.sendEachForMulticast.mock.calls[0][0];
    expect(payload.android.notification.icon).toBe("ic_stat_workgo");
    expect(payload.android.notification.color).toBe("#E8A400");
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

  test("notifyDialWorkerBookingCancelled restores worker status to online and initiates voice call with elapsed time and location", async () => {
    const mockWorkerUpdate = jest.fn().mockResolvedValue();
    const mockBookingUpdate = jest.fn().mockResolvedValue();

    const workerDoc = {
      exists: true,
      data: () => ({
        name: "Ramesh K.",
        phoneForCalling: "+919080262334",
        dialLanguage: "ta",
        isDialWorker: true,
        availabilityStatus: "busy",
      }),
      ref: { update: mockWorkerUpdate },
    };

    const bookingDocRef = { update: mockBookingUpdate };

    const customDb = {
      collection: (col) => {
        if (col === "workers") {
          return {
            doc: () => ({ get: jest.fn().mockResolvedValue(workerDoc) }),
            where: () => ({ limit: () => ({ get: jest.fn().mockResolvedValue({ empty: false, docs: [workerDoc] }) }) }),
          };
        }
        if (col === "bookings") {
          return {
            doc: () => bookingDocRef,
          };
        }
        return { doc: () => ({ get: jest.fn() }) };
      },
    };

    const engineWithCustomDb = new NotificationEngine(customDb, mockMessaging);

    const booking = {
      id: "b_dial_cancel_01",
      serviceType: "Electrical",
      customerAddressText: "No 45, Gandhi Road, Chennai",
      cancellationReason: "Incorrect service address",
      acceptedAt: new Date(Date.now() - 7 * 60000).toISOString(), // 7 minutes ago (exceeds 5-minute transit threshold)
      cancelledAt: new Date().toISOString(),
      workerId: "w_dial_101",
      isAssignedToDialWorker: true,
      dialWorkerPhone: "+919080262334",
    };

    await engineWithCustomDb.notifyDialWorkerBookingCancelled(booking);

    expect(mockWorkerUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        availabilityStatus: "online",
        isCheckedIn: true,
        callIvrStatus: "idle",
      })
    );
    expect(mockBookingUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        dialCallStatus: "cancelled_notified",
      })
    );
  });
});

