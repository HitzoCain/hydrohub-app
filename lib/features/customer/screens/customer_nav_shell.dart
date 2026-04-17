import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_home_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/messages_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/order_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/orders_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/profile_screen.dart';
import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerNavShell extends StatefulWidget {
  const CustomerNavShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerNavShell> createState() => _CustomerNavShellState();
}

class _CustomerNavShellState extends State<CustomerNavShell> {
  static const Color _primaryBlue = Color(0xFF2563EB);

  late int _currentIndex;

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    OrderScreen(),
    OrdersScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
    CustomerNavController.instance.addListener(_handleExternalTabChange);
    _loadCustomerProfile();
  }

  Future<void> _loadCustomerProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

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
      debugPrint('Failed to load customer profile: $e');
    }
  }

  @override
  void dispose() {
    CustomerNavController.instance.removeListener(_handleExternalTabChange);
    super.dispose();
  }

  void _handleExternalTabChange() {
    final nextIndex = CustomerNavController.instance.index;
    if (!mounted || _currentIndex == nextIndex) return;
    setState(() {
      _currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (index) {
          if (_currentIndex == index) return;
          CustomerNavController.instance.goTo(index);
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            label: 'Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
