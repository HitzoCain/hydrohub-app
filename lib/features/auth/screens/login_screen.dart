import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_home_screen.dart';
import 'package:aqua_in_laba_app/features/driver/screens/driver_dashboard_screen.dart';

enum UserRole { customer, driver }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;

  @override
  void dispose() {
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

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    final destination = _selectedRole == UserRole.customer
        ? const CustomerHomeScreen()
        : const DriverDashboardScreen();

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => destination),
    );
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
                                  onGooglePressed: _isLoading
                                      ? null
                                      : () {
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Google login is UI only.',
                                                ),
                                              ),
                                            );
                                        },
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
    required this.onGooglePressed,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final InputDecoration Function(String hint) inputDecoration;
  final String? Function(String?, String) validateRequired;
  final Future<void> Function() onLoginPressed;
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
            label: const Text('Login with Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
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
          decoration: inputDecoration('Enter Secret Code'),
          validator: (value) =>
              validateRequired(value, 'Secret code is required'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enter the code provided by admin',
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
