import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:aqua_in_laba_app/features/driver/services/driver_location_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key, this.driverId, this.driverName});

  final String? driverId;
  final String? driverName;

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  Future<int> _deliveriesTodayFuture = Future<int>.value(0);
  Future<int> _completedDeliveriesFuture = Future<int>.value(0);
  Future<String> _headerSubtitleFuture = Future<String>.value('');
  Future<List<_DeliveryData>> _activeOrdersFuture =
      Future<List<_DeliveryData>>.value(const <_DeliveryData>[]);
  List<_DeliveryData> _activeOrders = const <_DeliveryData>[];

  late DriverLocationService _locationService;

  static const Color _bg = Color(0xFFF0F4FA);
  static const Color _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
    loadDashboard();
  }

  Future<void> _initializeLocationService() async {
    final driverId = widget.driverId ?? await DriverSession.getDriverId();
    if (driverId != null && driverId.isNotEmpty) {
      _locationService = DriverLocationService(driverId: driverId);
      // Start tracking with 5-second interval
      await _locationService.startTracking(intervalSeconds: 5);
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  void loadDashboard() {
    final activeOrdersFuture = _fetchActiveOrders();

    setState(() {
      _deliveriesTodayFuture = _fetchDeliveriesToday();
      _completedDeliveriesFuture = _fetchCompletedDeliveries();
      _headerSubtitleFuture = _fetchHeaderSubtitle();
      _activeOrdersFuture = activeOrdersFuture;
    });

    activeOrdersFuture.then((response) {
      if (!mounted) return;
      setState(() {
        _activeOrders = response;
      });
    });
  }

  Future<int> _fetchDeliveriesToday() async {
    final driverId = await DriverSession.getDriverId();
    if (driverId == null || driverId.trim().isEmpty) {
      return 0;
    }

    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .gte('created_at', today);

    return response.length;
  }

  Future<int> _fetchCompletedDeliveries() async {
    final driverId = await DriverSession.getDriverId();
    if (driverId == null || driverId.trim().isEmpty) {
      return 0;
    }

    final response = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'delivered');

    return response.length;
  }

  Future<String> _fetchHeaderSubtitle() async {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);

    final driverId = await DriverSession.getDriverId();
    if (driverId == null || driverId.trim().isEmpty) {
      return '$dayName • No deliveries left today';
    }

    final today = now.toIso8601String().split('T')[0];

    final response = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .gte('created_at', today);

    final remaining = response
        .whereType<Map<String, dynamic>>()
        .where(
          (order) => order['status']?.toString().toLowerCase() != 'delivered',
        )
        .length;

    if (remaining == 0) {
      return '$dayName • No deliveries left today';
    }

    return '$dayName • $remaining deliveries left today';
  }

  Future<List<_DeliveryData>> _fetchActiveOrders() async {
    final driverId = await DriverSession.getDriverId();
    if (driverId == null || driverId.trim().isEmpty) {
      return const <_DeliveryData>[];
    }

    final activeOrders = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['assigned', 'on_the_way']);

    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return fallback;
      return text;
    }

    String statusOf(dynamic value) {
      final status = value?.toString().toLowerCase().trim() ?? '';
      if (status == 'assigned' ||
          status == 'on_the_way' ||
          status == 'delivered') {
        return status;
      }
      return 'assigned';
    }

    return activeOrders.whereType<Map<String, dynamic>>().map((order) {
      final orderId = textOf(order['id'], fallback: 'Unknown');
      final customerName = textOf(order['customer_name'], fallback: 'Customer');
      final address = textOf(order['address'], fallback: 'No address provided');

      return _DeliveryData(
        orderId: orderId,
        customerName: customerName,
        address: address,
        status: statusOf(order['status']),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _TopBar(
              driverName: widget.driverName ?? DriverSession.name,
              subtitleFuture: _headerSubtitleFuture,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _StatusPill(),
                  const SizedBox(height: 16),
                  _StatsRow(
                    deliveriesTodayFuture: _deliveriesTodayFuture,
                    completedDeliveriesFuture: _completedDeliveriesFuture,
                  ),
                  const SizedBox(height: 14),
                  const _HeroActionCard(),
                  const SizedBox(height: 14),
                  _activeOrders.isNotEmpty
                      ? const _RouteProgressCard()
                      : const _NoActiveRouteCard(),
                  const SizedBox(height: 14),
                  _ActiveDeliveriesCard(
                    activeOrdersFuture: _activeOrdersFuture,
                  ),
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
              MaterialPageRoute<void>(builder: (_) => const DriverMapScreen()),
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
  const _TopBar({this.driverName, required this.subtitleFuture});

  final String? driverName;
  final Future<String> subtitleFuture;

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
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1628),
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Hello, ${(driverName == null || driverName!.trim().isEmpty) ? 'Driver' : driverName!.trim()} ',
                      ),
                      const TextSpan(text: '👋'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FutureBuilder<String>(
                  future: subtitleFuture,
                  builder: (context, snapshot) {
                    final subtitle =
                        (snapshot.data == null || snapshot.data!.trim().isEmpty)
                        ? DateFormat('EEEE').format(DateTime.now())
                        : snapshot.data!;

                    return Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7B8CA6),
                      ),
                    );
                  },
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
  const _StatsRow({
    required this.deliveriesTodayFuture,
    required this.completedDeliveriesFuture,
  });

  final Future<int> deliveriesTodayFuture;
  final Future<int> completedDeliveriesFuture;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FutureBuilder<int>(
            future: deliveriesTodayFuture,
            builder: (context, snapshot) {
              final value = snapshot.data ?? 0;
              return _StatCard(
                value: '$value',
                label: 'Deliveries Today',
                sub: 'Live from orders',
                iconBg: const Color(0xFFEFF6FF),
                icon: Icons.local_shipping_outlined,
                iconColor: const Color(0xFF2563EB),
                valueColor: const Color(0xFF0A1628),
                subColor: const Color(0xFF16A34A),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FutureBuilder<int>(
            future: completedDeliveriesFuture,
            builder: (context, snapshot) {
              final completedCount = snapshot.data ?? 0;
              return _StatCard(
                value: '$completedCount',
                label: 'Completed',
                sub: 'Live delivered count',
                iconBg: const Color(0xFFF0FDF4),
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF16A34A),
                valueColor: const Color(0xFF16A34A),
                subColor: const Color(0xFF16A34A),
              );
            },
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
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
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
                  color: Colors.blue.withValues(alpha: 0.12),
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
                  color: Colors.blue.withValues(alpha: 0.10),
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

class _NoActiveRouteCard extends StatelessWidget {
  const _NoActiveRouteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5), width: 0.5),
      ),
      child: const Text(
        'No active delivery',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7B8CA6),
        ),
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

class _DeliveryData {
  const _DeliveryData({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.status,
  });

  final String orderId;
  final String customerName;
  final String address;
  final String status;
}

class _ActiveDeliveriesCard extends StatelessWidget {
  const _ActiveDeliveriesCard({required this.activeOrdersFuture});

  final Future<List<_DeliveryData>> activeOrdersFuture;

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
          FutureBuilder<List<_DeliveryData>>(
            future: activeOrdersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Failed to load active deliveries',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7B8CA6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <_DeliveryData>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No active deliveries.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7B8CA6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    children: [
                      _DeliveryRow(item: item),
                      if (index < items.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 0.5, color: Color(0xFFF1F5FB)),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item});

  final _DeliveryData item;

  String _shortOrderNum(String value) {
    const prefix = 'Order #';
    final raw = value.startsWith(prefix)
        ? value.substring(prefix.length)
        : value;
    if (raw.length <= 12) {
      return '$prefix$raw';
    }
    return '$prefix${raw.substring(0, 4)}...${raw.substring(raw.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (item.status) {
      case 'assigned':
        iconBg = const Color(0xFFF8FAFC);
        iconColor = const Color(0xFF94A3B8);
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        badgeLabel = 'Pending';
        break;
      case 'delivered':
        iconBg = const Color(0xFFF0FDF4);
        iconColor = const Color(0xFF16A34A);
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeLabel = 'Delivered';
        break;
      case 'on_the_way':
      default:
        iconBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFB45309);
        badgeLabel = 'On the way';
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
                  _shortOrderNum(item.orderId),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1628),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.customerName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B8CA6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.address,
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
