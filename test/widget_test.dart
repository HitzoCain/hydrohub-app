import 'package:aqua_in_laba_app/features/driver/screens/driver_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_in_laba_app/main.dart';

void main() {
  testWidgets('Launch screen renders branding and the first scene', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AquaEnLavadaApp());

    expect(find.text('Aqua en Lavada'), findsOneWidget);
    expect(find.text('Pure water'), findsOneWidget);
    expect(find.text('Fresh hydration for every drop'), findsOneWidget);
  });

  testWidgets('Driver chat prefers the real customer profile image', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverChatScreen(
          customerId: 'customer_123',
          customerName: 'Anthea Aban',
          customerAvatarUrl: 'https://example.com/customer-profile.png',
          orderId: 'order_123',
          status: 'Completed',
          conversationId: 'conversation_123',
          driverId: 'driver_123',
        ),
      ),
    );

    expect(find.text('Anthea Aban'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
