import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/auth/screens/customer_signup_screen.dart';
import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_shell.dart';
import 'package:aqua_in_laba_app/features/driver/screens/driver_dashboard_screen.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';

enum UserRole { customer, driver }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _googleRedirectTo =
  'io.supabase.flutter://login-callback';

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isNavigatingAfterAuth = false;

  @override
  void initState() {
    super.initState();
    _listenForAuthStateChanges();
    _checkCustomerSessionOnStart();
    _restoreDriverSession();
  }

  void _listenForAuthStateChanges() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final session = data.session;
          if (session == null || _isNavigatingAfterAuth || !mounted) {
            return;
          }

          debugPrint('Logged in: ${session.user.email}');
          _isNavigatingAfterAuth = true;

          final user = session.user;

          try {
            await DriverSession.clear();
            await createOrUpdateProfile(user);

            final profile = await Supabase.instance.client
                .from('customer_profiles')
                .select()
                .eq('user_id', user.id)
                .single();

            await CustomerSession.save(
              customerId: user.id,
              customerName: profile['name'] ?? '',
              customerPhone: profile['phone'],
              customerAddress: profile['address'],
            );
          } catch (e) {
            debugPrint('Post Google-login session sync error: $e');
          }

          if (!mounted) {
            return;
          }

          Future.microtask(() {
            if (!mounted) {
              return;
            }

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerNavShell(),
              ),
              (route) => false,
            );
          });
        });
  }

  void _checkCustomerSessionOnStart() {
    final session = Supabase.instance.client.auth.currentSession;
    debugPrint('Current auth session on start: $session');

    if (session == null || _isNavigatingAfterAuth || !mounted) {
      return;
    }

    _isNavigatingAfterAuth = true;

    Future.microtask(() {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const CustomerNavShell(),
        ),
        (route) => false,
      );
    });
  }

  Future<void> createOrUpdateProfile(User user) async {
    final supabase = Supabase.instance.client;

    try {
      // Check if profile exists
      final existing = await supabase
          .from('customer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing == null) {
        // Insert new profile
        await supabase.from('customer_profiles').insert({
          'user_id': user.id,
          'name':
              user.userMetadata?['full_name']?.toString().trim().isNotEmpty ==
                  true
              ? user.userMetadata!['full_name'].toString().trim()
              : 'New User',
          'phone': '',
          'address': '',
        });

        debugPrint('Profile created for user: ${user.id}');
      } else {
        debugPrint('Profile already exists for user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Profile error: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _googleRedirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      debugPrint('Google login auth error: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google login failed: ${e.message}')),
      );
    } catch (e) {
      debugPrint('Google login error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google login error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreDriverSession() async {
    final session = await DriverSession.load();
    if (session == null || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DriverDashboardScreen(
            driverId: session.id,
            driverName: session.name,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedRole == UserRole.customer) {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        final supabase = Supabase.instance.client;

        // Pre-flight check helps separate connectivity issues from auth issues.
        await _testSupabaseConnection();

        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        debugPrint('Login success: ${res.user?.id}');

        final user = supabase.auth.currentUser;
        debugPrint('Logged in user id: ${user?.id}');

        await DriverSession.clear();

        // Load customer profile
        if (user != null) {
          try {
            await createOrUpdateProfile(user);

            final profile = await supabase
                .from('customer_profiles')
                .select()
                .eq('user_id', user.id)
                .single();

            await CustomerSession.save(
              customerId: user.id,
              customerName: profile['name'] ?? '',
              customerPhone: profile['phone'],
              customerAddress: profile['address'],
            );
          } catch (profileError) {
            debugPrint('Profile load error: $profileError');
            // Continue with partial data if profile fetch fails
          }
        }

        if (!mounted) {
          return;
        }

        // Navigate to dashboard (auth gate will also pick up the change)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const CustomerNavShell(),
          ),
          (route) => false,
        );

      } else {
        final inputCode = _secretCodeController.text.trim();
        final supabase = Supabase.instance.client;
        String? loggedInDriverId;
        String? loggedInDriverName;

        try {
          final response = await supabase
              .from('employees')
              .select()
              .eq('access_code', inputCode)
              .eq('role', 'driver')
              .single();

          final Map<String, dynamic> driver = response;

          String? cleanString(dynamic value) {
            if (value == null) {
              return null;
            }
            final text = value.toString().trim();
            return text.isEmpty ? null : text;
          }

          final driverId = cleanString(driver['id']);
          if (driverId == null || driverId.isEmpty) {
            throw Exception('Driver ID not found');
          }

          final fullName = cleanString(driver['full_name']);
          final name = cleanString(driver['name']);
          final firstName = cleanString(driver['first_name']);
          final lastName = cleanString(driver['last_name']);

          final nameParts = <String>[
            if (firstName != null) firstName,
            if (lastName != null) lastName,
          ];

          final resolvedName =
              fullName ??
              name ??
              (nameParts.isNotEmpty ? nameParts.join(' ') : 'Driver');

          final driverName = resolvedName;
          loggedInDriverId = driverId;
          loggedInDriverName = driverName;

          await DriverSession.save(driverId: driverId, driverName: driverName);
        } on PostgrestException {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid access code')));
          return;
        }

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DriverDashboardScreen(
              driverId: loggedInDriverId ?? DriverSession.id,
              driverName: loggedInDriverName ?? DriverSession.name,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      debugPrint('Login auth error: ${e.message}');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.message}')));
    } on SocketException catch (e) {
      if (!mounted) {
        return;
      }

      debugPrint('Login socket error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Network/DNS issue. Please switch Wi-Fi/mobile data and try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e.toString();
      debugPrint('Login error: $message');

      if (message.toLowerCase().contains('failed host lookup')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot resolve Supabase host. Check DNS/network and retry.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testSupabaseConnection() async {
    try {
      await Supabase.instance.client.from('orders').select('id').limit(1);
      debugPrint('Supabase connection OK');
    } catch (e) {
      debugPrint('Supabase connection ERROR: $e');
      rethrow;
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
      ),
    );
  }

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFFFDFEFE),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A1F2937),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0x1A2563EB),
                          child: Icon(
                            Icons.water_drop_rounded,
                            size: 32,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aqua en Lavada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Water Refilling & Delivery System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _RoleSwitch(
                          selectedRole: _selectedRole,
                          onChanged: (role) {
                            if (_selectedRole == role) {
                              return;
                            }
                            setState(() {
                              _selectedRole = role;
                            });
                            _formKey.currentState?.reset();
                          },
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _selectedRole == UserRole.customer
                              ? _CustomerLoginForm(
                                  key: const ValueKey('customerForm'),
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  isLoading: _isLoading,
                                  inputDecoration: _inputDecoration,
                                  validateRequired: _validateRequired,
                                  onLoginPressed: _handleLogin,
                                  onSignupPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const CustomerSignupScreen(),
                                            ),
                                          );
                                        },
                                  onGooglePressed: _isLoading
                                      ? null
                                      : signInWithGoogle,
                                )
                              : _DriverLoginForm(
                                  key: const ValueKey('driverForm'),
                                  secretCodeController: _secretCodeController,
                                  isLoading: _isLoading,
                                  inputDecoration: _inputDecoration,
                                  validateRequired: _validateRequired,
                                  onLoginPressed: _handleLogin,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.selectedRole, required this.onChanged});

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _RoleOption(
            label: 'Customer',
            isSelected: selectedRole == UserRole.customer,
            onTap: () => onChanged(UserRole.customer),
          ),
          const SizedBox(width: 6),
          _RoleOption(
            label: 'Driver (Staff)',
            isSelected: selectedRole == UserRole.driver,
            onTap: () => onChanged(UserRole.driver),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x262563EB),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerLoginForm extends StatelessWidget {
  const _CustomerLoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.inputDecoration,
    required this.validateRequired,
    required this.onLoginPressed,
    required this.onSignupPressed,
    required this.onGooglePressed,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final InputDecoration Function(String hint) inputDecoration;
  final String? Function(String?, String) validateRequired;
  final Future<void> Function() onLoginPressed;
  final VoidCallback? onSignupPressed;
  final VoidCallback? onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome back! Please login to continue',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: inputDecoration('Email'),
          validator: (value) {
            final requiredError = validateRequired(value, 'Email is required');
            if (requiredError != null) {
              return requiredError;
            }
            final text = value!.trim();
            if (!text.contains('@') || !text.contains('.')) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          decoration: inputDecoration('Password'),
          validator: (value) => validateRequired(value, 'Password is required'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF93C5FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onGooglePressed,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onSignupPressed,
            icon: const Icon(Icons.person_add_outlined, size: 22),
            label: const Text('Create Account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverLoginForm extends StatelessWidget {
  const _DriverLoginForm({
    super.key,
    required this.secretCodeController,
    required this.isLoading,
    required this.inputDecoration,
    required this.validateRequired,
    required this.onLoginPressed,
  });

  final TextEditingController secretCodeController;
  final bool isLoading;
  final InputDecoration Function(String hint) inputDecoration;
  final String? Function(String?, String) validateRequired;
  final Future<void> Function() onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: secretCodeController,
          decoration: inputDecoration('Enter Access Code'),
          validator: (value) =>
              validateRequired(value, 'Access code is required'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enter the access code provided by admin',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF93C5FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}
