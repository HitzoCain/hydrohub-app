import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import '../../../models/philippine_location.dart';
import '../../../utils/address_formatter.dart';
import '../../../widgets/address/cascading_address_form.dart';

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  String _loadingMessage = 'Please wait...';
  AddressFormData? _structuredAddress;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF94A3B8))
          : null,
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

  String? _validateEmail(String? value) {
    final requiredError = _validateRequired(value, 'Email is required');
    if (requiredError != null) {
      return requiredError;
    }
    final text = value!.trim();
    final emailPattern = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    if (!emailPattern.hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = _validateRequired(value, 'Password is required');
    if (requiredError != null) {
      return requiredError;
    }
    final text = value!;
    if (text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      return 'Password must include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(text)) {
      return 'Password must include at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(text)) {
      return 'Password must include at least one number';
    }
    return null;
  }

  String _passwordStrengthLabel(String value) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);

    if (value.length >= 8 && hasUppercase && hasLowercase && hasNumber) {
      return 'Strong';
    }
    if (value.length >= 8 && hasUppercase && hasLowercase) {
      return 'Medium';
    }
    return 'Weak';
  }

  Color _passwordStrengthColor(String value) {
    switch (_passwordStrengthLabel(value)) {
      case 'Strong':
        return const Color(0xFF16A34A);
      case 'Medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFDC2626);
    }
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _validateRequired(
      value,
      'Confirm password is required',
    );
    if (requiredError != null) {
      return requiredError;
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _validateRequired(value, 'Phone number is required');
    if (requiredError != null) {
      return requiredError;
    }
    final text = value!.trim();
    if (!RegExp(r'^09\d{9}$').hasMatch(text)) {
      return 'Use a valid Philippine mobile number like 09171234567';
    }
    return null;
  }

  bool get _canSubmit => !_isLoading && _acceptedTerms && _acceptedPrivacy;

  String _friendlySignupError(Object error) {
    final rawMessage = error.toString().toLowerCase();

    if (error is AuthException) {
      final authMessage = error.message.toLowerCase();

      if (authMessage.contains('already registered') ||
          authMessage.contains('user already registered')) {
        return 'Email already registered.';
      }
      if (authMessage.contains('weak') || authMessage.contains('password')) {
        return 'Weak password. Use at least 8 characters with uppercase, lowercase, and a number.';
      }
      if (authMessage.contains('network') ||
          authMessage.contains('fetch') ||
          authMessage.contains('socket') ||
          authMessage.contains('internet')) {
        return 'Internet connection lost. Please try again.';
      }
      if (authMessage.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }

      return 'Could not create your account. Please try again.';
    }

    if (error is SocketException ||
        error is TimeoutException ||
        rawMessage.contains('socket') ||
        rawMessage.contains('network') ||
        rawMessage.contains('fetch')) {
      return 'Internet connection lost. Please try again.';
    }

    return 'Could not create your account. Please try again.';
  }

  void _showFriendlyError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlySignupError(error))),
    );
  }

  Future<void> _showVerificationDialog(String email) async {
    var isResending = false;

    Future<void> resendVerificationEmail(StateSetter setDialogState) async {
      setDialogState(() {
        isResending = true;
      });

      try {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: 'io.supabase.flutter://login-callback',
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent again.')),
        );
      } on AuthException catch (error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlySignupError(error))),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to resend verification email. Please try again.'),
          ),
        );
      } finally {
        if (mounted) {
          setDialogState(() {
            isResending = false;
          });
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Verify your email'),
              content: Text(
                'A verification email has been sent to $email. Please verify your email before logging in.',
              ),
              actions: [
                TextButton(
                  onPressed: isResending
                      ? null
                      : () async {
                          await resendVerificationEmail(setDialogState);
                        },
                  child: isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resend Verification Email'),
                ),
                TextButton(
                  onPressed: isResending
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: const Text('Back to Login'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Call this method after the user's first verified login.
  // It must NOT run during signup because the account should only create the
  // customer_profiles record after email verification is complete.
  // Configure io.supabase.flutter://login-callback as a mobile deep link in
  // Android/iOS and add it to Supabase Authentication > URL Configuration >
  // Redirect URLs.
  // ignore: unused_element
  Future<void> _createCustomerProfileAfterVerification({
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String address,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('customer_profiles').insert({
        'user_id': userId,
        'name': name,
        'phone': phone.isEmpty ? null : phone,
        'address': address.isEmpty ? null : address,
        'email': email,
      });

      await CustomerSession.save(
        customerId: userId,
        customerName: name,
        customerPhone: phone,
        customerAddress: address,
      );
    } catch (profileError) {
      debugPrint('Profile save error: $profileError');
    }
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    if (!_acceptedTerms || !_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Privacy Policy'),
        ),
      );
      return;
    }

    if (_structuredAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your delivery address')),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Creating account...';
    });

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.supabase.flutter://login-callback',
        data: {'full_name': name},
      );

      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        setState(() {
          _loadingMessage = 'Sending verification email...';
        });

        // If a session is returned, sign it out so the user is not treated as
        // logged in before verifying the email address.
        if (response.session != null) {
          await supabase.auth.signOut();
        }

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        await _showVerificationDialog(email);
        return;
      }

      throw StateError('Signup completed without creating a user.');
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showFriendlyError(error);
    } on SocketException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Internet connection lost. Please try again.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFriendlyError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Please wait...';
        });
      }
    }
  }

  Widget _buildTermsRow({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF2563EB),
      visualDensity: VisualDensity.compact,
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF475569),
        ),
      ),
    );
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
                          'Aqua In Lavada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create Your Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Join us to start ordering water delivery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Full Name',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) =>
                              _validateRequired(value, 'Full name is required'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Email',
                            icon: Icons.email_outlined,
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            setState(() {});
                          },
                          decoration: _inputDecoration(
                            'Password',
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Password strength',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                _passwordStrengthLabel(_passwordController.text),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _passwordStrengthColor(
                                    _passwordController.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmPasswordVisible,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Confirm Password',
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _confirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setState(() {
                                  _confirmPasswordVisible =
                                      !_confirmPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Phone Number',
                            icon: Icons.phone_outlined,
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Delivery Address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CascadingAddressForm(
                          showMapPicker: false,
                          onPickLocation: () async => null,
                          onSave: (data, _) async {
                            final formatted = formatAddressParts(
                              region: data.region.name,
                              province: data.province.name,
                              cityMunicipality: data.cityMunicipality.name,
                              barangay: data.barangay.name,
                              street: data.street,
                              houseNumber: data.houseNumber,
                              landmark: data.landmark,
                            );
                            if (!mounted) return;
                            setState(() {
                              _structuredAddress = data;
                              _addressController.text = formatted;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Password must be at least 8 characters and include uppercase, lowercase, and a number.',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTermsRow(
                          value: _acceptedTerms,
                          label: 'I agree to the Terms and Conditions',
                          onChanged: (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                        ),
                        _buildTermsRow(
                          value: _acceptedPrivacy,
                          label: 'I agree to the Privacy Policy',
                          onChanged: (value) {
                            setState(() {
                              _acceptedPrivacy = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _handleSignup : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF93C5FD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _loadingMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
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
