import 'package:aqua_in_laba_app/widgets/share_app_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('shows a QR code for the latest Android release', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShareAppScreen()));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Scan to download the Android app'), findsOneWidget);
    expect(find.text(ShareAppScreen.downloadUrl), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });
}
