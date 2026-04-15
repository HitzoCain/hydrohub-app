import 'package:flutter/material.dart';

import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  static const Color _bg = Color(0xFFF0F4FA);
  static const Color _primary = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: const [
            _TopBar(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(height: 16),
                  _StatusPill(),
                  SizedBox(height: 16),
                  _StatsRow(),
                  SizedBox(height: 14),
                  _HeroActionCard(),
                  SizedBox(height: 14),
                  _RouteProgressCard(),
                  SizedBox(height: 14),
                  _ActiveDeliveriesCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        onTap: (index) {
          if (index == 1) {
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
              MaterialPageRoute<void>(
                builder: (_) => const DriverMapScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverProfileScreen(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1628),
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(text: 'Hello, John '),
                      TextSpan(text: '👋'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tuesday · 3 deliveries left today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7B8CA6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _NotificationBell(),
          const SizedBox(width: 10),
          const _Avatar(),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF334155),
            size: 22,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Online & Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '8',
            label: 'Deliveries Today',
            sub: '▲ 2 from yesterday',
            iconBg: Color(0xFFEFF6FF),
            icon: Icons.local_shipping_outlined,
            iconColor: Color(0xFF2563EB),
            valueColor: Color(0xFF0A1628),
            subColor: Color(0xFF16A34A),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '5',
            label: 'Completed',
            sub: '62.5% done',
            iconBg: Color(0xFFF0FDF4),
            icon: Icons.check_circle_outline_rounded,
            iconColor: Color(0xFF16A34A),
            valueColor: Color(0xFF16A34A),
            subColor: Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.sub,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    required this.subColor,
  });

  final String value;
  final String label;
  final String sub;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8898B0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 30,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.10),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF60A5FA),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View Your\nAssigned Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const DriverOrdersScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All Orders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteProgressCard extends StatelessWidget {
  const _RouteProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Route',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1628),
                ),
              ),
              Text(
                'ETA: 12 min',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7B8CA6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              value: 0.38,
              minHeight: 4,
              backgroundColor: Color(0xFFE8EDF5),
              valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RouteStop(label: 'Pickup', state: _StopState.done),
              _RouteStop(label: 'On Way', state: _StopState.active),
              _RouteStop(label: 'Arrive', state: _StopState.next),
              _RouteStop(label: 'Done', state: _StopState.next),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StopState { done, active, next }

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.label, required this.state});

  final String label;
  final _StopState state;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    List<BoxShadow> shadows = [];

    switch (state) {
      case _StopState.done:
        dotColor = const Color(0xFF2563EB);
        break;
      case _StopState.active:
        dotColor = const Color(0xFF2563EB);
        shadows = [
          const BoxShadow(
            color: Color(0x662563EB),
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ];
        break;
      case _StopState.next:
        dotColor = const Color(0xFFCBD5E1);
        break;
    }

    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: shadows,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8898B0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

enum _DeliveryStatus { onTheWay, delivered, pending }

class _DeliveryData {
  const _DeliveryData({
    required this.orderNum,
    required this.customer,
    required this.status,
  });

  final String orderNum;
  final String customer;
  final _DeliveryStatus status;
}

class _ActiveDeliveriesCard extends StatelessWidget {
  const _ActiveDeliveriesCard();

  static const _items = [
    _DeliveryData(
      orderNum: 'Order #001',
      customer: 'Juan Dela Cruz · Brgy. Lahug',
      status: _DeliveryStatus.onTheWay,
    ),
    _DeliveryData(
      orderNum: 'Order #002',
      customer: 'Maria Santos · IT Park',
      status: _DeliveryStatus.delivered,
    ),
    _DeliveryData(
      orderNum: 'Order #003',
      customer: 'Carlo Reyes · Ayala Center',
      status: _DeliveryStatus.pending,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5), width: 0.5),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1628),
                  ),
                ),
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, color: Color(0xFFF1F5FB)),
          ...List.generate(_items.length, (i) {
            return Column(
              children: [
                _DeliveryRow(item: _items[i]),
                if (i < _items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 0.5, color: Color(0xFFF1F5FB)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item});

  final _DeliveryData item;

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (item.status) {
      case _DeliveryStatus.onTheWay:
        iconBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFB45309);
        badgeLabel = 'On the way';
        break;
      case _DeliveryStatus.delivered:
        iconBg = const Color(0xFFF0FDF4);
        iconColor = const Color(0xFF16A34A);
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeLabel = 'Delivered';
        break;
      case _DeliveryStatus.pending:
        iconBg = const Color(0xFFF8FAFC);
        iconColor = const Color(0xFF94A3B8);
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        badgeLabel = 'Pending';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on_outlined, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.orderNum,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1628),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.customer,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B8CA6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

