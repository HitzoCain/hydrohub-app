import 'package:aqua_in_laba_app/features/auth/screens/customer_email_otp_screen.dart';
import 'package:aqua_in_laba_app/features/auth/screens/customer_profile_completion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OTP screen distributes a pasted code across six fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerEmailOtpScreen(email: 'customer@example.com'),
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    await tester.enterText(fields.first, '123456');
    await tester.pump();

    final updatedFields = tester.widgetList<TextField>(fields).toList();
    expect(
      updatedFields.map((field) => field.controller!.text).join(),
      '123456',
    );
    expect(updatedFields.last.focusNode!.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('incomplete code displays a validation message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerEmailOtpScreen(email: 'customer@example.com'),
      ),
    );

    await tester.tap(find.text('Verify email'));
    await tester.pump();

    expect(
      find.text('Enter the 6-digit code from your email.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('profile onboarding requires a valid phone and address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileCompletionScreen(
          userId: 'user-id',
          initialName: 'Customer',
          email: 'customer@example.com',
          onCompleted: () => fail('Incomplete profile must not continue'),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '12345');
    await tester.enterText(fields.last, '');
    await tester.ensureVisible(find.text('Save and continue'));
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(
      find.text('Enter an 11-digit Philippine number starting with 09.'),
      findsOneWidget,
    );
    expect(find.text('Delivery address is required.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
