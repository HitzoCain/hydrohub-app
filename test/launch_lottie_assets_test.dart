import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:aqua_in_laba_app/main.dart' show AquaEnLavadaApp;

void main() {
  const animationAssets = [
    'assets/animations/water_drop.json',
    'assets/animations/delivery_bike.json',
    'assets/animations/map_route.json',
  ];

  for (final asset in animationAssets) {
    testWidgets('loads $asset as a Lottie animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Lottie.asset(asset, animate: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Lottie), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps each splash scene visible for a full animation cycle', (
    tester,
  ) async {
    final supabaseReady = Completer<void>();
    await tester.pumpWidget(
      AquaEnLavadaApp(supabaseReady: supabaseReady.future),
    );

    expect(find.text('Pure water'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2199));
    expect(find.text('Pure water'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Fast delivery'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('Track live'), findsOneWidget);
  });
}
