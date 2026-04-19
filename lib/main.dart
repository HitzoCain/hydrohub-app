import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/auth/screens/login_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cnkxnwdzvamruxefmzvq.supabase.co',
    anonKey: 'sb_publishable_bJKWR5p2qC97h3OJSec6Iw_ErFkrwuF',
  );

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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    final currentSession = Supabase.instance.client.auth.currentSession;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        return const CustomerNavShell();
      },
    );
  }
}
