import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../customer/customer_session.dart';

class CustomerProfileCompletionScreen extends StatefulWidget {
  const CustomerProfileCompletionScreen({
    required this.userId,
    required this.initialName,
    required this.email,
    required this.onCompleted,
    super.key,
  });

  final String userId;
  final String initialName;
  final String email;
  final VoidCallback onCompleted;

  @override
  State<CustomerProfileCompletionScreen> createState() =>
      _CustomerProfileCompletionScreenState();
}

class _CustomerProfileCompletionScreenState
    extends State<CustomerProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      return 'Enter an 11-digit Philippine number starting with 09.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Delivery address is required.';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    try {
      await Supabase.instance.client
          .from('customer_profiles')
          .update({'phone': phone, 'address': address})
          .eq('user_id', widget.userId)
          .select('user_id')
          .single();

      await CustomerSession.save(
        customerId: widget.userId,
        customerName: widget.initialName,
        customerPhone: phone,
        customerAddress: address,
      );

      if (mounted) widget.onCompleted();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save your profile: ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not save your profile. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF2563EB),
                      size: 42,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Complete your profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your contact number and delivery address to continue, ${widget.initialName.isEmpty ? widget.email : widget.initialName}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: _decoration(
                        'Mobile number (09XXXXXXXXX)',
                        Icons.phone_outlined,
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          _decoration(
                            'Complete delivery address',
                            Icons.location_on_outlined,
                          ).copyWith(
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 48),
                              child: Icon(Icons.location_on_outlined),
                            ),
                            hintText:
                                'House/street, barangay, city or municipality, province',
                          ),
                      validator: _validateAddress,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save and continue',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
