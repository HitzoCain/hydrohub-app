import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_in_laba_app/main.dart';

void main() {
  testWidgets('Login screen renders branding and role options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AquaEnLavadaApp());

    expect(find.text('Aqua en Lavada'), findsOneWidget);
    expect(find.text('Water Refilling & Delivery System'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Driver (Staff)'), findsOneWidget);
  });
}
