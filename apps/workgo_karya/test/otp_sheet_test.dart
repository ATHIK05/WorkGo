import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_karya/src/widgets/karya_start_otp_sheet.dart';

void main() {
  testWidgets('KaryaStartOtpSheet renders with high-contrast text and 4 input boxes', (tester) async {
    bool verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KaryaStartOtpSheet(
            bookingId: 'test_booking_123',
            onSuccess: () => verified = true,
          ),
        ),
      ),
    );

    // Verify header and title (supports both localized and mock key fallback)
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data == "Enter Customer Start OTP" || w.data == "otp_sheet_title")),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data == "Ask the customer for the 4-digit code shown on their screen" || w.data == "otp_sheet_sub")),
      findsOneWidget,
    );

    // Verify 4 input boxes are present
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4));

    // Verify text style has high-contrast dark color (#0F172A), NOT white
    final firstField = tester.widget<TextField>(textFields.first);
    expect(firstField.style?.color, const Color(0xFF0F172A));
    expect(firstField.decoration?.fillColor, Colors.transparent);

    // Verify action button is present and not verified initially
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data == "Verify & Start Service" || w.data == "otp_sheet_verify_btn")),
      findsOneWidget,
    );
    expect(verified, isFalse);
  });
}
