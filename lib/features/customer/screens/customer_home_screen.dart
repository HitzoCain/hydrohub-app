import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/messages_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/order_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/orders_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/profile_screen.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF334155),
            ),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.settings_outlined, color: Color(0xFF334155)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          const _GreetingSection(),
          const SizedBox(height: 20),
          _OrderWaterCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const OrderScreen()),
              );
            },
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Active Orders'),
          const SizedBox(height: 12),
          const _ActiveOrdersList(),
          const SizedBox(height: 28),
          _RecentOrdersHeader(
            onSeeAllTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          const _RecentOrdersList(),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const OrderScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MessagesScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Messages',
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

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, Customer 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ready to restock your water?',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderWaterCard extends StatelessWidget {
  const _OrderWaterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x402563EB),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need water?',
                style: TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Order Water Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Place Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          'See all',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActiveOrdersList extends StatelessWidget {
  const _ActiveOrdersList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 175,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _ActiveOrderCard(status: 'On the way'),
          SizedBox(width: 12),
          _ActiveOrderCard(status: 'Preparing'),
          SizedBox(width: 12),
          _ActiveOrderCard(status: 'Driver Assigned'),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.status});

  final String status;

  int _stepFromStatus() {
    switch (status) {
      case 'Preparing':
        return 1;
      case 'On the way':
        return 2;
      case 'Delivered':
        return 3;
      default:
        return 0;
    }
  }

  Color _badgeColor() {
    switch (status) {
      case 'On the way':
        return const Color(0xFF15803D);
      case 'Preparing':
        return const Color(0xFFB45309);
      case 'Driver Assigned':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _badgeBg() {
    switch (status) {
      case 'On the way':
        return const Color(0xFFDCFCE7);
      case 'Preparing':
        return const Color(0xFFFEF3C7);
      case 'Driver Assigned':
        return const Color(0xFFDBEAFE);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A233455),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #00${_stepFromStatus() + 4}',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeBg(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _badgeColor(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '5 Gallons x2',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TrackOrderScreen(
                      status: status,
                      deliveryType: status == 'Preparing' ? 'scheduled' : 'now',
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE), width: 0.5),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Track →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _RecentOrderTile(orderId: 'Order #001', price: '₱250', date: 'Apr 11'),
        SizedBox(height: 8),
        _RecentOrderTile(orderId: 'Order #002', price: '₱180', date: 'Apr 10'),
        SizedBox(height: 8),
        _RecentOrderTile(orderId: 'Order #003', price: '₱320', date: 'Apr 08'),
      ],
    );
  }
}

class _RecentOrdersHeader extends StatelessWidget {
  const _RecentOrdersHeader({required this.onSeeAllTap});

  final VoidCallback onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Orders',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        GestureDetector(
          onTap: onSeeAllTap,
          child: Text(
            'See All →',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({
    required this.orderId,
    required this.price,
    required this.date,
  });

  final String orderId;
  final String price;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A233455),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.water_drop_outlined,
            color: Color(0xFF2563EB),
            size: 20,
          ),
        ),
        title: Text(
          orderId,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          date,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Delivered',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
