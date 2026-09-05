import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workgo_core/workgo_core.dart';
import 'package:workgo_customer/src/screens/payment_receipt_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  Booking createBooking({
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
    String? invoiceId,
  }) {
    return Booking(
      id: 'bk_1w6f4hqc',
      customerId: 'cust_123',
      organizationId: 'org_123',
      serviceType: 'plumbing',
      isEmergency: false,
      status: BookingStatus.completed,
      paymentStatus: paymentStatus,
      amount: 180.0,
      urgencyBonus: 0.0,
      broadcastRadiusKm: 10.0,
      bookingType: 'direct',
      diagnosticFee: 0.0,
      isFeeCredited: false,
      handoffLogs: const [],
      suggestedToolsNeeded: const [],
      invoiceId: invoiceId,
      acceptedWorkerName: 'Plumbing Specialist',
    );
  }

  Widget createTestWidget(PaymentReceiptScreen screen) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'packages/workgo_core/assets/lang',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: MaterialApp(
        home: screen,
      ),
    );
  }

  testWidgets('PaymentReceiptScreen opens Invoice & Receipt directly when paid', (tester) async {
    final booking = createBooking(paymentStatus: PaymentStatus.paid, invoiceId: 'TXN-1788625675505');

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Plumbing Specialist',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render receipt elements
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    expect(find.textContaining('TXN-1788625675505'), findsOneWidget);
  });

  testWidgets('PaymentReceiptScreen opens Receipt when isReceiptOnly is true even if unpaid status in memory', (tester) async {
    final booking = createBooking(paymentStatus: PaymentStatus.unpaid);

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Plumbing Specialist',
          isReceiptOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render receipt view
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
  });
}
