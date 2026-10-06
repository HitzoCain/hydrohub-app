import 'dart:ui' show ImageFilter;

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
  Future<Map<String, int>> _orderStatusCountsFuture =
      Future<Map<String, int>>.value(const <String, int>{
        'live': 0,
        'cancelled': 0,
        'completed': 0,
      });
  Future<String> _headerSubtitleFuture = Future<String>.value('');
  Future<String> _driverAvatarFuture = Future<String>.value('');
  Future<List<_DeliveryData>> _activeOrdersFuture =
      Future<List<_DeliveryData>>.value(const <_DeliveryData>[]);

  late DriverLocationService _locationService;

  static const Color _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
    _driverAvatarFuture = _loadDriverAvatar();
    loadDashboard();
  }

  Future<String> _loadDriverAvatar() async {
    final widgetDriverId = widget.driverId?.trim();
    final driverId = widgetDriverId?.isNotEmpty == true
        ? widgetDriverId!
        : (await DriverSession.getDriverId())?.trim() ?? '';
    if (driverId.isEmpty) return '';

    try {
      final profile = await Supabase.instance.client
          .from('employees')
          .select('profile_image_url')
          .eq('id', driverId)
          .maybeSingle();
      return profile?['profile_image_url']?.toString().trim() ?? '';
    } catch (error) {
      debugPrint('Failed to load driver dashboard photo: $error');
      return '';
    }
  }

  Future<List<String>> _currentDriverIds() async {
    final ids = <String>{};

    final sessionId = await DriverSession.getDriverId();
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      ids.add(sessionId.trim());
    }

    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authUserId != null && authUserId.trim().isNotEmpty) {
      ids.add(authUserId.trim());
    }

    return ids.toList(growable: false);
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
    final orderStatusCountsFuture = _fetchOrderStatusCounts();

    setState(() {
      _orderStatusCountsFuture = orderStatusCountsFuture;
      _headerSubtitleFuture = _fetchHeaderSubtitle();
      _activeOrdersFuture = activeOrdersFuture;
    });
  }

  Future<Map<String, int>> _fetchOrderStatusCounts() async {
    final driverIds = await _currentDriverIds();
    final counts = <String, int>{'live': 0, 'cancelled': 0, 'completed': 0};
    if (driverIds.isEmpty) return counts;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month).toUtc().toIso8601String();
    final nextMonthStart = DateTime(
      now.year,
      now.month + 1,
    ).toUtc().toIso8601String();

    final orders = await Supabase.instance.client
        .from('orders')
        .select('status')
        .inFilter('driver_id', driverIds)
        .gte('created_at', monthStart)
        .lt('created_at', nextMonthStart);

    for (final order in orders.whereType<Map<String, dynamic>>()) {
      final status = order['status']?.toString().toLowerCase().trim() ?? '';
      if (status == 'assigned' ||
          status == 'in_progress' ||
          status == 'on_the_way') {
        counts['live'] = counts['live']! + 1;
      } else if (status == 'cancelled' || status == 'canceled') {
        counts['cancelled'] = counts['cancelled']! + 1;
      } else if (status == 'delivered' || status == 'completed') {
        counts['completed'] = counts['completed']! + 1;
      }
    }

    return counts;
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
    final driverIds = await _currentDriverIds();
    if (driverIds.isEmpty) {
      return const <_DeliveryData>[];
    }

    final activeOrdersQuery = Supabase.instance.client
        .from('orders')
        .select()
        .inFilter('status', ['assigned', 'in_progress', 'on_the_way']);

    final activeOrders = driverIds.length == 1
        ? await activeOrdersQuery.eq('driver_id', driverIds.first)
        : await activeOrdersQuery.inFilter('driver_id', driverIds);

    final customerIds = activeOrders
        .whereType<Map<String, dynamic>>()
        .map((order) => order['customer_id']?.toString().trim() ?? '')
        .where((customerId) => customerId.isNotEmpty)
        .toSet()
        .toList();
    final customerAvatarUrls = <String, String>{};
    if (customerIds.isNotEmpty) {
      try {
        final profiles = await Supabase.instance.client
            .from('customer_profiles')
            .select('user_id, avatar_url')
            .inFilter('user_id', customerIds);
        for (final profile in profiles.whereType<Map<String, dynamic>>()) {
          final userId = profile['user_id']?.toString().trim() ?? '';
          final avatarUrl = profile['avatar_url']?.toString().trim() ?? '';
          if (userId.isNotEmpty && avatarUrl.isNotEmpty) {
            customerAvatarUrls[userId] = avatarUrl;
          }
        }
      } catch (error) {
        debugPrint('Failed to load active delivery customer photos: $error');
      }
    }

    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return fallback;
      return text;
    }

    String statusOf(dynamic value) {
      final status = value?.toString().toLowerCase().trim() ?? '';
      if (status == 'in_progress') {
        return 'on_the_way';
      }
      if (status == 'assigned' ||
          status == 'on_the_way' ||
          status == 'delivered') {
        return status;
      }
      return 'assigned';
    }

    return activeOrders.whereType<Map<String, dynamic>>().map((order) {
      final customerName = textOf(order['customer_name'], fallback: 'Customer');
      final createdAt = DateTime.tryParse(
        order['created_at']?.toString() ?? '',
      );
      final deliveryDate = createdAt == null
          ? 'Date unavailable'
          : DateFormat('MMM d').format(createdAt.toLocal());

      return _DeliveryData(
        customerName: customerName,
        avatarUrl:
            customerAvatarUrls[order['customer_id']?.toString().trim()] ?? '',
        date: deliveryDate,
        status: statusOf(order['status']),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
              child: Image.asset(
                'assets/images/background.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const ColoredBox(color: Color(0x22081D35)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  driverName: widget.driverName ?? DriverSession.name,
                  subtitleFuture: _headerSubtitleFuture,
                  avatarUrlFuture: _driverAvatarFuture,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
                        const _StatusPill(),
                        const SizedBox(height: 14),
                        _StatsRow(statusCountsFuture: _orderStatusCountsFuture),
                        const SizedBox(height: 14),
                        const _HeroActionCard(),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _ActiveDeliveriesCard(
                            activeOrdersFuture: _activeOrdersFuture,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  const _TopBar({
    this.driverName,
    required this.subtitleFuture,
    required this.avatarUrlFuture,
  });

  final String? driverName;
  final Future<String> subtitleFuture;
  final Future<String> avatarUrlFuture;

  @override
  Widget build(BuildContext context) {
    final resolvedName = (driverName == null || driverName!.trim().isEmpty)
        ? 'Driver'
        : driverName!.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1220), Color(0xFF172033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: FutureBuilder<String>(
                future: avatarUrlFuture,
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data?.trim() ?? '';
                  if (avatarUrl.isEmpty) {
                    return const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    );
                  }
                  return Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  resolvedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<String>(
                  future: subtitleFuture,
                  builder: (context, snapshot) {
                    final subtitle =
                        (snapshot.data == null || snapshot.data!.trim().isEmpty)
                        ? DateFormat('EEEE').format(DateTime.now())
                        : snapshot.data!;

                    return Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCBD5E1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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
  const _StatsRow({required this.statusCountsFuture});

  final Future<Map<String, int>> statusCountsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: statusCountsFuture,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const <String, int>{};
        final liveCount = counts['live'] ?? 0;
        final cancelledCount = counts['cancelled'] ?? 0;
        final completedCount = counts['completed'] ?? 0;
        final totalCount = liveCount + cancelledCount + completedCount;

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatusGauge(
                      value: liveCount,
                      progress: totalCount == 0 ? 0 : liveCount / totalCount,
                      label: 'Live Orders',
                      color: const Color(0xFF168FC4),
                    ),
                  ),
                  Expanded(
                    child: _StatusGauge(
                      value: cancelledCount,
                      progress: totalCount == 0
                          ? 0
                          : cancelledCount / totalCount,
                      label: 'Cancelled',
                      color: const Color(0xFFE45C57),
                      monthLabel: DateFormat(
                        'MMMM yyyy',
                      ).format(DateTime.now()),
                    ),
                  ),
                  Expanded(
                    child: _StatusGauge(
                      value: completedCount,
                      progress: totalCount == 0
                          ? 0
                          : completedCount / totalCount,
                      label: 'Completed',
                      color: const Color(0xFF55A936),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusGauge extends StatelessWidget {
  const _StatusGauge({
    required this.value,
    required this.progress,
    required this.label,
    required this.color,
    this.monthLabel,
  });

  final int value;
  final double progress;
  final String label;
  final Color color;
  final String? monthLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: monthLabel == null
              ? null
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      monthLabel!,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
        ),
        SizedBox(
          width: 78,
          height: 78,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: constraints.maxWidth * 0.58,
                  child: Image.asset(
                    'assets/images/driverdesigndashboard.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF0F172A),
                          const Color(0xFF0F172A).withValues(alpha: 0.96),
                          const Color(0xFF0F172A).withValues(alpha: 0.45),
                          const Color(0xFF0F172A).withValues(alpha: 0),
                        ],
                        stops: const [0, 0.28, 0.55, 0.9],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.62,
                    ),
                    child: Column(
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
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeliveryData {
  const _DeliveryData({
    required this.customerName,
    required this.avatarUrl,
    required this.date,
    required this.status,
  });

  final String customerName;
  final String avatarUrl;
  final String? date;
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
          Expanded(
            child: FutureBuilder<List<_DeliveryData>>(
              future: activeOrdersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
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
                  return const Center(
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

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _DeliveryRow(item: items[index]),
                  separatorBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 0.5, color: Color(0xFFF1F5FB)),
                  ),
                );
              },
            ),
          ),
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
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: item.avatarUrl.isEmpty
                ? Icon(Icons.person_outline_rounded, color: iconColor, size: 20)
                : Image.network(
                    item.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_outline_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1628),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.date ?? 'Date unavailable',
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
