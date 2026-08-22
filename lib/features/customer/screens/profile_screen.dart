import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/edit_profile_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/address_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/support_screen.dart';
import 'package:aqua_in_laba_app/features/auth/services/logout_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _background = Color(0xFFF6F8FB);

  late Future<_ProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload can keep previously shaped objects in memory.
    // Refresh future to avoid stale _ProfileData instances.
    _refreshProfile();
  }

  Future<_ProfileData> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const _ProfileData(
        name: 'Customer',
        email: 'No email',
        totalOrders: 0,
        activeOrders: 0,
      );
    }

    var name = (user.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = (user.email ?? '').trim().isNotEmpty
        ? (user.email ?? '').trim()
        : 'No email';

    try {
      final profile = await Supabase.instance.client
          .from('customer_profiles')
          .select('name')
          .eq('user_id', user.id)
          .maybeSingle();

      final profileName = profile?['name']?.toString().trim() ?? '';
      if (profileName.isNotEmpty) {
        name = profileName;
      }
    } catch (e) {
      debugPrint('Failed to load customer profile name: $e');
    }

    if (name.isEmpty) {
      name = 'Customer';
    }

    var totalOrders = 0;
    var activeOrders = 0;

    try {
      final orderRows = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('customer_id', user.id);

      final orders = List<Map<String, dynamic>>.from(orderRows);
      final nonCancelled = orders.where((row) {
        final status = (row['status']?.toString().trim().toLowerCase() ?? '')
            .replaceAll(' ', '_');
        return status != 'cancelled';
      }).toList();

      totalOrders = nonCancelled.length;

      const activeStatuses = <String>{
        'accepted',
        'assigned',
        'on_the_way',
        'delivering',
        'preparing',
        'in_progress',
      };

      activeOrders = nonCancelled.where((row) {
        final status = (row['status']?.toString().trim().toLowerCase() ?? '')
            .replaceAll(' ', '_');
        return activeStatuses.contains(status);
      }).length;
    } catch (e) {
      debugPrint('Failed to load profile order stats: $e');
    }

    return _ProfileData(
      name: name,
      email: email,
      totalOrders: totalOrders,
      activeOrders: activeOrders,
    );
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data ??
                const _ProfileData(
                  name: 'Customer',
                  email: 'No email',
                  totalOrders: 0,
                  activeOrders: 0,
                );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(name: profile.name, email: profile.email),
                const SizedBox(height: 16),
                _QuickInfoSection(
                  totalOrders: profile.totalOrders,
                  activeOrders: profile.activeOrders,
                ),
                const SizedBox(height: 16),
                _AccountOptionsSection(onProfileUpdated: _refreshProfile),
                const SizedBox(height: 20),
                const _LogoutButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12233455),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFEFF4FF),
            child: Icon(Icons.person, color: Color(0xFF2563EB), size: 42),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _QuickInfoSection extends StatelessWidget {
  const _QuickInfoSection({
    required this.totalOrders,
    required this.activeOrders,
  });

  final int totalOrders;
  final int activeOrders;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            label: 'Total Orders',
            value: '$totalOrders',
            icon: Icons.receipt_long,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            label: 'Active Orders',
            value: '$activeOrders',
            icon: Icons.local_shipping_outlined,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12233455),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _AccountOptionsSection extends StatelessWidget {
  const _AccountOptionsSection({required this.onProfileUpdated});

  final VoidCallback onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12233455),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Name',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
              onProfileUpdated();
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _OptionTile(
            icon: Icons.location_on_outlined,
            label: 'Delivery Address',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AddressScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _OptionTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SupportScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.name,
    required this.email,
    required this.totalOrders,
    required this.activeOrders,
  });

  final String name;
  final String email;
  final int totalOrders;
  final int activeOrders;
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => logoutAndRedirectToLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Logout',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
