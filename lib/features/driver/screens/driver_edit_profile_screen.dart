import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverEditProfileScreen extends StatefulWidget {
  const DriverEditProfileScreen({super.key});

  @override
  State<DriverEditProfileScreen> createState() =>
      _DriverEditProfileScreenState();
}

class _DriverEditProfileScreenState extends State<DriverEditProfileScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  Map<String, dynamic>? _employee;
  String? _phoneColumn;
  String _driverId = '';
  String _avatarUrl = '';
  String? _loadError;
  DriverStatus _selectedStatus = DriverStatus.offline;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final session = await DriverSession.load();
      final driverId = session?.id.trim() ?? '';
      if (driverId.isEmpty) {
        throw StateError(
          'Driver session is unavailable. Please sign in again.',
        );
      }

      final employee = await Supabase.instance.client
          .from('employees')
          .select()
          .eq('id', driverId)
          .maybeSingle();
      if (employee == null) {
        throw StateError('Driver profile could not be found.');
      }

      final row = Map<String, dynamic>.from(employee);
      final name = _resolveName(row, fallback: session?.name ?? 'Driver');
      String? phoneColumn;
      for (final candidate in const [
        'phone',
        'phone_number',
        'mobile',
        'mobile_number',
        'contact_number',
      ]) {
        if (row.containsKey(candidate)) {
          phoneColumn = candidate;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _employee = row;
        _driverId = driverId;
        _phoneColumn = phoneColumn;
        _avatarUrl = row['profile_image_url']?.toString().trim() ?? '';
        _nameController.text = name;
        _phoneController.text = phoneColumn == null
            ? ''
            : row[phoneColumn]?.toString() ?? '';
        final status = row['driver_status']?.toString().toLowerCase();
        _selectedStatus = status == 'online' || status == 'active'
            ? DriverStatus.online
            : DriverStatus.offline;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load driver edit profile: $error');
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load your profile. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _resolveName(Map<String, dynamic> row, {required String fallback}) {
    for (final field in const ['full_name', 'name', 'driver_name']) {
      final value = row[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final firstName = row['first_name']?.toString().trim() ?? '';
    final lastName = row['last_name']?.toString().trim() ?? '';
    final combinedName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    return combinedName.isEmpty ? fallback : combinedName;
  }

  Future<void> _saveChanges() async {
    final employee = _employee;
    if (employee == null || _driverId.isEmpty) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updates = <String, dynamic>{};
      final name = _nameController.text.trim();
      var nameUpdated = false;
      for (final field in const ['full_name', 'name', 'driver_name']) {
        if (employee.containsKey(field)) {
          updates[field] = name;
          nameUpdated = true;
          break;
        }
      }
      if (!nameUpdated &&
          (employee.containsKey('first_name') ||
              employee.containsKey('last_name'))) {
        final parts = name.split(RegExp(r'\s+'));
        if (employee.containsKey('first_name')) {
          updates['first_name'] = parts.first;
        }
        if (employee.containsKey('last_name')) {
          updates['last_name'] = parts.length > 1
              ? parts.skip(1).join(' ')
              : '';
        }
        nameUpdated = true;
      }
      if (!nameUpdated) {
        throw StateError('No editable name field exists on this profile.');
      }

      final phoneColumn = _phoneColumn;
      if (phoneColumn != null) {
        updates[phoneColumn] = _phoneController.text.trim();
      }
      if (employee.containsKey('driver_status')) {
        updates['driver_status'] = _selectedStatus == DriverStatus.online
            ? 'online'
            : 'offline';
      }

      final savedEmployee = await Supabase.instance.client
          .from('employees')
          .update(updates)
          .eq('id', _driverId)
          .select('id')
          .maybeSingle();
      if (savedEmployee == null) {
        throw StateError('The profile could not be saved.');
      }

      await DriverSession.updateName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Failed to save driver edit profile: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to save your profile.')),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF475569)),
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
        borderSide: const BorderSide(color: _primaryBlue, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12233455),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage: _avatarUrl.isEmpty
                                ? null
                                : NetworkImage(_avatarUrl),
                            child: _avatarUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: _primaryBlue,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _nameController.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Delivery Driver',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        hint: 'Enter full name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      enabled: _phoneColumn != null,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration:
                          _inputDecoration(
                            label: 'Phone Number',
                            hint: 'Enter phone number',
                          ).copyWith(
                            helperText: _phoneColumn == null
                                ? 'No phone field is configured for this driver.'
                                : null,
                          ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<DriverStatus>(
                      initialValue: _selectedStatus,
                      borderRadius: BorderRadius.circular(12),
                      decoration: _inputDecoration(
                        label: 'Status',
                        hint: 'Select status',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DriverStatus.online,
                          child: Text('Online'),
                        ),
                        DropdownMenuItem(
                          value: DriverStatus.offline,
                          child: Text('Offline'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

enum DriverStatus { online, offline }
