import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/auth/screens/customer_profile_completion_screen.dart';
import 'package:aqua_in_laba_app/features/auth/screens/login_screen.dart';
import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_shell.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';

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
      title: 'Aqua In Lavada',
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
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        if (authState != null) {
          debugPrint(
            'Auth gate: ${authState.event}, session present: ${authState.session != null}',
          );
        }
        final session = authState == null
            ? auth.currentSession
            : authState.session;

        if (session == null) {
          return const LoginScreen();
        }

        return _CustomerAccessGate(
          key: ValueKey(session.user.id),
          user: session.user,
        );
      },
    );
  }
}

class _CustomerAccessGate extends StatefulWidget {
  const _CustomerAccessGate({required this.user, super.key});

  final User user;

  @override
  State<_CustomerAccessGate> createState() => _CustomerAccessGateState();
}

class _CustomerAccessGateState extends State<_CustomerAccessGate> {
  late Future<Map<String, dynamic>> _profileFuture;
  bool _profileCompleted = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    await DriverSession.clear();
    await CustomerSession.clear();

    final supabase = Supabase.instance.client;
    final existing = await supabase
        .from('customer_profiles')
        .select('name,email,phone,address')
        .eq('user_id', widget.user.id)
        .maybeSingle();

    final Map<String, dynamic> profile;
    if (existing == null) {
      final metadata = widget.user.userMetadata ?? const <String, dynamic>{};
      final name = (metadata['full_name'] ?? metadata['name'] ?? '')
          .toString()
          .trim();
      profile = Map<String, dynamic>.from(
        await supabase
            .from('customer_profiles')
            .insert({
              'user_id': widget.user.id,
              'name': name,
              'email': widget.user.email ?? '',
              'phone': null,
              'address': null,
            })
            .select('name,email,phone,address')
            .single(),
      );
    } else {
      profile = Map<String, dynamic>.from(existing);
    }

    final phone = profile['phone']?.toString().trim() ?? '';
    final address = profile['address']?.toString().trim() ?? '';
    if (phone.isNotEmpty && address.isNotEmpty) {
      await CustomerSession.save(
        customerId: widget.user.id,
        customerName: profile['name']?.toString() ?? '',
        customerPhone: phone,
        customerAddress: address,
      );
    }

    return profile;
  }

  void _retryProfileLoad() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profileCompleted) {
      return const CustomerNavShell();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'We could not load your profile. Please try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retryProfileLoad,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data!;
        final phone = profile['phone']?.toString().trim() ?? '';
        final address = profile['address']?.toString().trim() ?? '';
        if (phone.isEmpty || address.isEmpty) {
          return CustomerProfileCompletionScreen(
            userId: widget.user.id,
            initialName: profile['name']?.toString() ?? '',
            email: widget.user.email ?? '',
            onCompleted: () {
              if (mounted) setState(() => _profileCompleted = true);
            },
          );
        }

        return const CustomerNavShell();
      },
    );
  }
}
