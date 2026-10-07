import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareAppScreen extends StatelessWidget {
  const ShareAppScreen({super.key});

  static const downloadUrl =
      'https://github.com/HitzoCain/hydrohub-app/releases/latest/download/aqua-in-lavada.apk';
  static const _background = Color(0xFFF6F8FB);
  static const _primaryBlue = Color(0xFF2563EB);

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: downloadUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Download link copied.')));
  }

  Future<void> _shareLink(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Download Aqua In Lavada for Android: $downloadUrl',
      subject: 'Aqua In Lavada app',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Share App'),
        backgroundColor: _background,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Aqua In Lavada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan to download the Android app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12233455),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: downloadUrl,
                    version: QrVersions.auto,
                    size: 248,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _shareLink(context),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share link'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
