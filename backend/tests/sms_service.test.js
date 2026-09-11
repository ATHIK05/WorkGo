const { sanitizePhoneNumber, getSmsConfig, _clearCache } = require("../src/services/sms_service");

describe("SMS Service & 2Factor Gateway Integration", () => {
  beforeEach(() => {
    _clearCache();
  });

  describe("sanitizePhoneNumber", () => {
    test("cleans 10-digit Indian phone number", () => {
      expect(sanitizePhoneNumber("9876543210")).toBe("9876543210");
    });

    test("strips +91 prefix and formatting characters", () => {
      expect(sanitizePhoneNumber("+91 98765-43210")).toBe("9876543210");
      expect(sanitizePhoneNumber("919876543210")).toBe("9876543210");
      expect(sanitizePhoneNumber("+91 (987) 654-3210")).toBe("9876543210");
    });

    test("handles edge cases and invalid inputs", () => {
      expect(sanitizePhoneNumber("")).toBe("");
      expect(sanitizePhoneNumber(null)).toBe("");
      expect(sanitizePhoneNumber(undefined)).toBe("");
      expect(sanitizePhoneNumber("123")).toBe("123");
    });
  });

  describe("getSmsConfig", () => {
    test("returns default 2Factor configuration when Firestore has no record", async () => {
      const mockDb = {
        collection: () => ({
          doc: () => ({
            get: async () => ({ exists: false, data: () => null }),
          }),
        }),
      };

      const config = await getSmsConfig(mockDb);
      expect(config.apiKey).toBe("ee7bbe44-ad30-11f1-90d7-0200cd936042");
      expect(config.template).toBe("WORKGO_OTP_VERIFY");
      expect(config.senderId).toBe("WORKGO");
      expect(config.enabled).toBe(true);
    });

    test("reads configuration from Firestore system_configs/sms_gateway", async () => {
      const mockDb = {
        collection: () => ({
          doc: () => ({
            get: async () => ({
              exists: true,
              data: () => ({
                apiKey: "custom-api-key-test",
                template: "CUSTOM_TEMPLATE",
                senderId: "WRKGOX",
                enabled: true,
              }),
            }),
          }),
        }),
      };

      const config = await getSmsConfig(mockDb);
      expect(config.apiKey).toBe("custom-api-key-test");
      expect(config.template).toBe("CUSTOM_TEMPLATE");
      expect(config.senderId).toBe("WRKGOX");
    });
  });
});
