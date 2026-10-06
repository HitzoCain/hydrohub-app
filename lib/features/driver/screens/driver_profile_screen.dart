import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:aqua_in_laba_app/features/auth/services/logout_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_dashboard_screen.dart';
import 'driver_edit_profile_screen.dart';
import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_support_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  late Future<_DriverProfileData> _profileFuture;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  Future<void> _changeProfilePhoto() async {
    final driverId = await DriverSession.getDriverId();
    if (driverId == null || driverId.trim().isEmpty) {
      _showPhotoError('Driver session not found. Please sign in again.');
      return;
    }
    String? accessCode;
    try {
      accessCode = await DriverSession.getAccessCode();
    } catch (error) {
      debugPrint('Unable to read the saved driver access code: $error');
      _showPhotoError(
        'Please close and reopen the app before changing your photo.',
      );
      return;
    }
    if (accessCode == null || accessCode.isEmpty) {
      _showPhotoError(
        'Please sign out and sign in again to update your photo.',
      );
      return;
    }
    if (!mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showPhotoError('Choose an image smaller than 5 MB.');
        return;
      }
      if (!mounted) return;

      final contentType = image.mimeType == 'image/png'
          ? 'image/png'
          : image.mimeType == 'image/webp'
          ? 'image/webp'
          : 'image/jpeg';

      setState(() => _isUploadingPhoto = true);
      final response = await Supabase.instance.client.functions.invoke(
        'driver-profile-photo',
        body: {
          'driver_id': driverId,
          'access_code': accessCode,
          'image_base64': base64Encode(bytes),
          'content_type': contentType,
        },
      );
      final responseData = response.data;
      if (responseData is! Map || responseData['avatar_url'] == null) {
        throw Exception('The upload service returned an invalid response.');
      }

      if (!mounted) return;
      setState(() {
        _profileFuture = _loadProfileData();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      _showPhotoError('Unable to upload profile photo: $error');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_DriverProfileData> _loadProfileData() async {
    final session = await DriverSession.load();
    final authUser = Supabase.instance.client.auth.currentUser;

    String name = session == null
        ? (DriverSession.name?.trim() ?? '')
        : session.name.trim();
    String email = authUser?.email?.trim() ?? '';
    String employeeId = session == null
        ? (DriverSession.id?.trim() ?? '')
        : session.id.trim();
    var avatarUrl = '';

    if (employeeId.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('employees')
            .select()
            .eq('id', employeeId)
            .maybeSingle();

        if (response != null) {
          final profileName = _firstNonEmptyString(
            response['full_name'],
            response['name'],
            response['driver_name'],
          );
          final profileEmail = _firstNonEmptyString(
            response['email'],
            response['work_email'],
          );
          final profileEmployeeId = _firstNonEmptyString(
            response['employee_id'],
            response['id'],
          );

          if (profileName.isNotEmpty) {
            name = profileName;
          }
          if (profileEmail.isNotEmpty) {
            email = profileEmail;
          }
          if (profileEmployeeId.isNotEmpty) {
            employeeId = profileEmployeeId;
          }
          avatarUrl = _firstNonEmptyString(response['profile_image_url']);
        }
      } catch (error) {
        debugPrint('Failed to load driver profile data: $error');
      }
    }

    if (name.isEmpty) {
      name = 'Driver';
    }

    final driverIds = <String>{};
    if (session?.id.trim().isNotEmpty == true) {
      driverIds.add(session!.id.trim());
    }
    if (DriverSession.id?.trim().isNotEmpty == true) {
      driverIds.add(DriverSession.id!.trim());
    }
    if (authUser?.id.trim().isNotEmpty == true) {
      driverIds.add(authUser!.id.trim());
    }

    var deliveriesToday = 0;
    var totalCompleted = 0;

    if (driverIds.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        final today = DateTime.now().toIso8601String().split('T')[0];

        final todayOrders = driverIds.length == 1
            ? await supabase
                  .from('orders')
                  .select('status')
                  .eq('driver_id', driverIds.first)
                  .gte('created_at', today)
            : await supabase
                  .from('orders')
                  .select('status')
                  .inFilter('driver_id', driverIds.toList(growable: false))
                  .gte('created_at', today);

        deliveriesToday = List<Map<String, dynamic>>.from(todayOrders).length;

        final completedOrders = driverIds.length == 1
            ? await supabase
                  .from('orders')
                  .select('status')
                  .eq('driver_id', driverIds.first)
            : await supabase
                  .from('orders')
                  .select('status')
                  .inFilter('driver_id', driverIds.toList(growable: false));

        totalCompleted = List<Map<String, dynamic>>.from(completedOrders).where(
          (row) {
            final status =
                (row['status']?.toString().trim().toLowerCase() ?? '')
                    .replaceAll(' ', '_');
            return status == 'delivered' || status == 'completed';
          },
        ).length;
      } catch (error) {
        debugPrint('Failed to load driver profile stats: $error');
      }
    }

    return _DriverProfileData(
      name: name,
      email: email,
      employeeId: employeeId.isEmpty ? 'Not available' : employeeId,
      avatarUrl: avatarUrl,
      deliveriesToday: deliveriesToday,
      totalCompleted: totalCompleted,
    );
  }

  String _firstNonEmptyString(dynamic first, [dynamic second, dynamic third]) {
    final values = [first, second, third];
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
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
        child: FutureBuilder<_DriverProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final profile =
                snapshot.data ??
                const _DriverProfileData(
                  name: 'Driver',
                  email: '',
                  employeeId: 'Not available',
                  avatarUrl: '',
                  deliveriesToday: 0,
                  totalCompleted: 0,
                );

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ProfileHeader(
                        name: profile.name,
                        email: profile.email,
                        avatarUrl: profile.avatarUrl,
                        isUploadingPhoto: _isUploadingPhoto,
                        onChangePhoto: _changeProfilePhoto,
                      ),
                      const SizedBox(height: 16),
                      const _DriverAvailabilityCard(),
                      const SizedBox(height: 16),
                      _DriverInfoCard(employeeId: profile.employeeId),
                      const SizedBox(height: 16),
                      _QuickStatsCard(
                        deliveriesToday: profile.deliveriesToday,
                        totalCompleted: profile.totalCompleted,
                      ),
                      const SizedBox(height: 16),
                      const _ActionsSection(),
                      const SizedBox(height: 16),
                      const _LogoutButton(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverDashboardScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverOrdersScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverMessagesScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const DriverMapScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.near_me_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isUploadingPhoto,
    required this.onChangePhoto,
  });

  final String name;
  final String email;
  final String avatarUrl;
  final bool isUploadingPhoto;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            radius: 40,
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
            child: avatarUrl.isEmpty
                ? const Icon(
                    Icons.local_shipping_rounded,
                    size: 34,
                    color: Color(0xFF2563EB),
                  )
                : null,
          ),
          TextButton.icon(
            onPressed: isUploadingPhoto ? null : onChangePhoto,
            icon: isUploadingPhoto
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(
              isUploadingPhoto ? 'Uploading photo...' : 'Change photo',
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : 'Delivery Driver',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: _InfoRow(label: 'Employee ID', value: employeeId),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({
    required this.deliveriesToday,
    required this.totalCompleted,
  });

  final int deliveriesToday;
  final int totalCompleted;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              value: '$deliveriesToday',
              label: 'Deliveries Today',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(value: '$totalCompleted', label: 'Total Completed'),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.edit_outlined,
            iconColor: Color(0xFF2563EB),
            title: 'Edit Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DriverEditProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.support_agent_rounded,
            iconColor: Color(0xFF2563EB),
            title: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DriverSupportScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  Future<void> _handleLogout(BuildContext context) async {
    final driverId = await DriverSession.getDriverId();
    if (driverId != null && driverId.trim().isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('employees')
            .update({'driver_status': 'offline'})
            .eq('id', driverId);
      } catch (error) {
        debugPrint('Unable to set driver offline during logout: $error');
      }
    }

    if (!context.mounted) return;
    await logoutAndRedirectToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _DriverAvailabilityCard extends StatefulWidget {
  const _DriverAvailabilityCard();

  @override
  State<_DriverAvailabilityCard> createState() =>
      _DriverAvailabilityCardState();
}

class _DriverAvailabilityCardState extends State<_DriverAvailabilityCard> {
  bool _isOnline = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final driverId = await DriverSession.getDriverId();
      if (driverId == null || driverId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isOnline = false;
          _isInitialized = true;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('employees')
          .select('driver_status')
          .eq('id', driverId)
          .maybeSingle();

      final rawStatus = response?['driver_status']?.toString().toLowerCase();
      if (!mounted) return;
      setState(() {
        _isOnline = rawStatus == 'online';
        _isInitialized = true;
      });
    } catch (error) {
      debugPrint('Failed to load driver availability: $error');
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final driverId = await DriverSession.getDriverId();
      if (driverId == null || driverId.trim().isEmpty) {
        throw Exception('Driver ID not found');
      }

      await Supabase.instance.client
          .from('employees')
          .update({'driver_status': value ? 'online' : 'offline'})
          .eq('id', driverId);

      if (!mounted) return;
      setState(() {
        _isOnline = value;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'You are now Online' : 'You are now Offline'),
          backgroundColor: value
              ? const Color(0xFF16A34A)
              : const Color(0xFF64748B),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update availability: $error'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isOnline ? 'Online' : 'Offline';
    final statusColor = _isOnline
        ? const Color(0xFF15803D)
        : const Color(0xFF475569);
    final statusBackground = _isOnline
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFE2E8F0);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Driver Status',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: (!_isInitialized || _isLoading)
                    ? null
                    : _toggleAvailability,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DriverProfileData {
  const _DriverProfileData({
    required this.name,
    required this.email,
    required this.employeeId,
    required this.avatarUrl,
    required this.deliveriesToday,
    required this.totalCompleted,
  });

  final String name;
  final String email;
  final String employeeId;
  final String avatarUrl;
  final int deliveriesToday;
  final int totalCompleted;
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
