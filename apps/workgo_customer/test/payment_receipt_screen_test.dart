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
    bool isRated = false,
    double? rating,
    String? reviewComment,
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
      isRated: isRated,
      rating: rating,
      reviewComment: reviewComment,
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

  testWidgets('PaymentReceiptScreen requires payment and renders payment form when unpaid even if isReceiptOnly is passed', (tester) async {
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

    // Should render payment form elements because booking is unpaid
    expect(find.byIcon(Icons.qr_code_2_rounded), findsWidgets);
    expect(find.byIcon(Icons.payments_rounded), findsWidgets);
    // Should NOT render success checkmark when unpaid
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('PaymentReceiptScreen displays dynamic Direct UPI and Cash options when unpaid', (tester) async {
    final booking = createBooking(paymentStatus: PaymentStatus.unpaid);

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Plumbing Specialist',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render payment form elements
    expect(find.text('₹180'), findsWidgets);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsWidgets);
    expect(find.byIcon(Icons.payments_rounded), findsWidgets);
    // Should NOT have hardcoded "Pay via Razorpay"
    expect(find.textContaining('Pay via Razorpay'), findsNothing);
  });

  testWidgets('PaymentReceiptScreen displays Rate button when booking is not rated', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final booking = createBooking(
      paymentStatus: PaymentStatus.paid,
      invoiceId: 'TXN-1788625675505',
      isRated: false,
    );

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Plumbing Specialist',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkGoButton), findsOneWidget);
    expect(find.text('rate_service'), findsOneWidget);
    expect(find.text('experience_rated_title'), findsNothing);
  });

  testWidgets('PaymentReceiptScreen displays Experience Rated card when booking is already rated', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final booking = createBooking(
      paymentStatus: PaymentStatus.paid,
      invoiceId: 'TXN-1788625675505',
      isRated: true,
      rating: 5.0,
      reviewComment: 'Outstanding plumbing work, fixed the pipe leak swiftly!',
    );

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Plumbing Specialist',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rate button must NOT be shown
    expect(find.text('rate_service'), findsNothing);

    // Experience Rated card MUST be shown
    expect(find.text('experience_rated_title'), findsOneWidget);
    expect(find.text('5.0 / 5.0'), findsOneWidget);
    expect(
      find.text('"Outstanding plumbing work, fixed the pipe leak swiftly!"'),
      findsOneWidget,
    );
    expect(find.text('edit_rating'), findsOneWidget);
  });

  testWidgets('PaymentReceiptScreen displays genuine artisan name instead of generic specialist role', (tester) async {
    final booking = createBooking(
      paymentStatus: PaymentStatus.paid,
      invoiceId: 'TXN-1788625675505',
    ).copyWith(acceptedWorkerName: 'Ramesh Kumar');

    await tester.pumpWidget(
      createTestWidget(
        PaymentReceiptScreen(
          booking: booking,
          workerName: 'Ramesh Kumar',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Kumar'), findsWidgets);
    expect(find.text('Plumbing Specialist'), findsNothing);
  });
}
