import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/auth/screens/login_screen.dart';

void main() {
  runApp(const AquaEnLavadaApp());
}

class AquaEnLavadaApp extends StatelessWidget {
  const AquaEnLavadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aqua en Lavada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          surface: const Color(0xFFF6F8FB),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
