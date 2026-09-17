import "package:flutter_test/flutter_test.dart";
import "package:workgo_core/workgo_core.dart";

void main() {
  group("Universal Payment Switchboard Catalog Tests", () {
    test("All 12 payment providers are registered in catalog with valid metadata", () {
      expect(PaymentProviderMetadata.catalog.length, 12);

      for (final providerId in PaymentProviderId.values) {
        final meta = PaymentProviderMetadata.getById(providerId);
        expect(meta.id, providerId);
        expect(meta.name.isNotEmpty, true);
        expect(meta.shortCode.isNotEmpty, true);
        expect(meta.supportedRails.isNotEmpty, true);
        expect(meta.description.isNotEmpty, true);
      }
    });

    test("Default config initializes to Direct Sovereign UPI with zero gateway requirement", () {
      final config = PaymentGatewayConfig.defaults();
      expect(config.activePrimaryProvider, PaymentProviderId.directUpi);
      expect(config.isLiveMode, false);
      expect(config.allowDirectUpiFallback, true);
      expect(config.allowCashHandover, false);
      expect(config.platformFeePercent, 0.0);
      expect(config.welfareFundPercent, 0.0);
      expect(config.cooperativeUpiVpa, "workgo@upi");
      expect(config.isProviderConfigured, true);
    });

    test("PaymentGatewayConfig serializes and deserializes cleanly", () {
      final original = PaymentGatewayConfig(
        activePrimaryProvider: PaymentProviderId.razorpay,
        isLiveMode: true,
        allowDirectUpiFallback: true,
        allowCashHandover: false,
        platformFeePercent: 4.5,
        welfareFundPercent: 2.5,
        cooperativeUpiVpa: "coop@okaxis",
        cooperativePayeeName: "Tamil Nadu Worker Federation",
        credentials: {
          "razorpay": {
            "key_id": "rzp_test_12345",
            "key_secret": "secret_abc",
          },
        },
        gstPercent: 18.0,
        invoiceWebsite: "workgo.in",
        invoicePhone: "1800-419-WORK",
        invoiceEmail: "support@workgo.in",
        invoiceTerms: "Payment is final upon completion.",
        invoiceAuthorisedSignatory: "WorkGo Trust",
        updatedAt: DateTime(2026, 9, 6, 12, 0),
        updatedBy: "superadmin@workgo.coop",
      );

      final map = original.toMap();
      final restored = PaymentGatewayConfig.fromMap(map);

      expect(restored.activePrimaryProvider, PaymentProviderId.razorpay);
      expect(restored.isLiveMode, true);
      expect(restored.allowDirectUpiFallback, true);
      expect(restored.allowCashHandover, false);
      expect(restored.platformFeePercent, 4.5);
      expect(restored.welfareFundPercent, 2.5);
      expect(restored.gstPercent, 18.0);
      expect(restored.invoiceWebsite, "workgo.in");
      expect(restored.invoicePhone, "1800-419-WORK");
      expect(restored.invoiceEmail, "support@workgo.in");
      expect(restored.invoiceTerms, "Payment is final upon completion.");
      expect(restored.invoiceAuthorisedSignatory, "WorkGo Trust");
      expect(restored.cooperativeUpiVpa, "coop@okaxis");
      expect(restored.cooperativePayeeName, "Tamil Nadu Worker Federation");
      expect(restored.getCredential(PaymentProviderId.razorpay, "key_id"), "rzp_test_12345");
      expect(restored.isProviderConfigured, true);
    });

    test("PaymentGatewayConfig omits invoice fields when null or empty", () {
      final config = PaymentGatewayConfig.defaults().copyWith(
        gstPercent: null,
        invoiceWebsite: null,
        invoicePhone: null,
        invoiceEmail: null,
        invoiceTerms: null,
        invoiceAuthorisedSignatory: null,
      );

      final map = config.toMap();
      expect(map.containsKey("gstPercent"), false);
      expect(map.containsKey("invoiceWebsite"), false);
      expect(map.containsKey("invoicePhone"), false);
      expect(map.containsKey("invoiceEmail"), false);
      expect(map.containsKey("invoiceTerms"), false);
      expect(map.containsKey("invoiceAuthorisedSignatory"), false);

      final restored = PaymentGatewayConfig.fromMap(map);
      expect(restored.gstPercent, isNull);
      expect(restored.invoiceWebsite, isNull);
      expect(restored.invoicePhone, isNull);
      expect(restored.invoiceEmail, isNull);
      expect(restored.invoiceTerms, isNull);
      expect(restored.invoiceAuthorisedSignatory, isNull);
    });

    test("NPCI standard UPI URI generator creates compliant deep links", () {
      final uri = PaymentService.instance.generateUpiUri(
        vpa: "workgo@coop",
        payeeName: "WorkGo Federation",
        amount: 450.0,
        note: "Booking #BK12345",
        transactionRef: "TXN98765",
      );

      expect(uri.scheme, "upi");
      expect(uri.host, "pay");
      expect(uri.queryParameters["pa"], "workgo@coop");
      expect(uri.queryParameters["pn"], "WorkGo Federation");
      expect(uri.queryParameters["am"], "450.00");
      expect(uri.queryParameters["cu"], "INR");
      expect(uri.queryParameters["tn"], "Booking #BK12345");
      expect(uri.queryParameters["tr"], "TXN98765");
    });

    test("PhonePe and GPay deep link generators produce dedicated intent schemes", () {
      final phonePeUri = PaymentService.instance.generatePhonePeUri(
        vpa: "artisan@ybl",
        payeeName: "Ramesh Kumar",
        amount: 500.0,
        note: "WorkGo BK-999",
      );
      expect(phonePeUri.scheme, "phonepe");
      expect(phonePeUri.host, "pay");
      expect(phonePeUri.queryParameters["pa"], "artisan@ybl");
      expect(phonePeUri.queryParameters["pn"], "Ramesh Kumar");
      expect(phonePeUri.queryParameters["am"], "500.00");

      final gPayUri = PaymentService.instance.generateGPayUri(
        vpa: "artisan@okaxis",
        payeeName: "Ramesh Kumar",
        amount: 500.0,
        note: "WorkGo BK-999",
      );
      expect(gPayUri.scheme, "tez");
      expect(gPayUri.host, "upi");
      expect(gPayUri.path, "/pay");
      expect(gPayUri.queryParameters["pa"], "artisan@okaxis");
      expect(gPayUri.queryParameters["pn"], "Ramesh Kumar");
      expect(gPayUri.queryParameters["am"], "500.00");
    });
  });
}
