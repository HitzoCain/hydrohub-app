import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';

import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_order_details_screen.dart';
import 'driver_profile_screen.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  Future<List<_DeliveryItemData>> _activeOrdersFuture =
      Future<List<_DeliveryItemData>>.value(const <_DeliveryItemData>[]);
  Future<List<_DeliveryItemData>> _completedOrdersFuture =
      Future<List<_DeliveryItemData>>.value(const <_DeliveryItemData>[]);
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeOrdersFuture = _fetchActiveOrders();
    _completedOrdersFuture = _fetchCompletedOrders();
  }

  Future<List<_DeliveryItemData>> _fetchActiveOrders() async {
    final driverId = await DriverSession.getDriverId();

    if (driverId == null || driverId.trim().isEmpty) {
      return [];
    }

    final orders = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['assigned', 'on_the_way']);

    return orders
        .whereType<Map<String, dynamic>>()
        .map(_mapActiveOrder)
        .toList();
  }

  Future<List<_DeliveryItemData>> _fetchCompletedOrders() async {
    final driverId = await DriverSession.getDriverId();

    if (driverId == null || driverId.trim().isEmpty) {
      return [];
    }

    final orders = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'delivered')
        .order('created_at', ascending: false);

    return orders
        .whereType<Map<String, dynamic>>()
        .map(_mapCompletedOrder)
        .toList();
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return 'Unknown date';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    final date = parsed.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  _DeliveryItemData _mapActiveOrder(Map<String, dynamic> order) {
    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return fallback;
      }
      return text;
    }

    int gallonsOf(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final orderId = textOf(order['id'], fallback: 'Unknown');
    final customerName = textOf(order['customer_name'], fallback: 'Customer');
    final address = textOf(order['address'], fallback: 'No address provided');
    final gallons = gallonsOf(order['gallons']);

    return _DeliveryItemData(
      orderId: 'Order #$orderId',
      customerName: customerName,
      address: address,
      gallons: gallons,
      status: _DeliveryStatus.delivering,
    );
  }

  _DeliveryItemData _mapCompletedOrder(Map<String, dynamic> order) {
    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return fallback;
      }
      return text;
    }

    int gallonsOf(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final orderId = textOf(order['id'], fallback: 'Unknown');
    final customerName = textOf(order['customer_name'], fallback: 'Customer');
    final address = textOf(order['address'], fallback: 'No address provided');
    final gallons = gallonsOf(order['gallons']);
    final deliveredDate = _formatDate(
      order['delivered_at'] ?? order['updated_at'] ?? order['created_at'],
    );

    return _DeliveryItemData(
      orderId: 'Order #$orderId',
      customerName: customerName,
      address: address,
      gallons: gallons,
      status: _DeliveryStatus.completed,
      deliveredDate: deliveredDate,
    );
  }

  void _refreshOrders() {
    setState(() {
      _activeOrdersFuture = _fetchActiveOrders();
      _completedOrdersFuture = _fetchCompletedOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'My Deliveries',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _OrdersTabBar(
                selectedIndex: _selectedTabIndex,
                onChanged: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
              ),
            ),
            Expanded(
              child: _selectedTabIndex == 0
                  ? _ActiveOrdersList(
                      ordersFuture: _activeOrdersFuture,
                      onRefresh: () async {
                        _refreshOrders();
                        await _activeOrdersFuture;
                      },
                      onOrderCompleted: _refreshOrders,
                    )
                  : _CompletedOrdersList(
                      ordersFuture: _completedOrdersFuture,
                      onRefresh: () async {
                        _refreshOrders();
                        await _completedOrdersFuture;
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
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

class _OrdersTabBar extends StatelessWidget {
  const _OrdersTabBar({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Active Orders',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Completed Orders',
            isSelected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x142563EB),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? const Color(0xFF1E3A8A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrdersList extends StatelessWidget {
  const _ActiveOrdersList({
    required this.ordersFuture,
    required this.onRefresh,
    required this.onOrderCompleted,
  });

  final Future<List<_DeliveryItemData>> ordersFuture;
  final Future<void> Function() onRefresh;
  final VoidCallback onOrderCompleted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_DeliveryItemData>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load active deliveries: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final deliveries = snapshot.data ?? const <_DeliveryItemData>[];
        if (deliveries.isEmpty) {
          return const _EmptyState(message: 'No active deliveries yet');
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == deliveries.length - 1 ? 0 : 12,
                ),
                child: _DeliveryCard(
                  delivery: delivery,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DriverOrderDetailsScreen(
                          customerName: delivery.customerName,
                          orderId: delivery.orderId,
                          status: delivery.status.label,
                          contactNumber: '+63 912 345 6789',
                          address: delivery.address,
                          totalGallons: delivery.gallons,
                          exchangeContainers: 3,
                          newContainers: 2,
                          onOrderCompleted: onOrderCompleted,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CompletedOrdersList extends StatelessWidget {
  const _CompletedOrdersList({
    required this.ordersFuture,
    required this.onRefresh,
  });

  final Future<List<_DeliveryItemData>> ordersFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_DeliveryItemData>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load completed deliveries: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final deliveries = snapshot.data ?? const <_DeliveryItemData>[];
        if (deliveries.isEmpty) {
          return const _EmptyState(message: 'No completed deliveries yet');
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == deliveries.length - 1 ? 0 : 12,
                ),
                child: _DeliveryCard(
                  delivery: delivery,
                  onTap: null,
                  isReadOnly: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    this.onTap,
    this.isReadOnly = false,
  });

  final _DeliveryItemData delivery;
  final VoidCallback? onTap;
  final bool isReadOnly;

  String _shortOrderId(String value) {
    const prefix = 'Order #';
    final rawId = value.startsWith(prefix)
        ? value.substring(prefix.length)
        : value;

    if (rawId.length <= 12) {
      return value;
    }

    return '$prefix${rawId.substring(0, 4)}...${rawId.substring(rawId.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final statusTheme = _statusTheme(delivery.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12233455),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${delivery.gallons} Gallons',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shortOrderId(delivery.orderId),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isReadOnly && delivery.deliveredDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Delivered: ${delivery.deliveredDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusTheme.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  delivery.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusTheme.foreground,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12233455),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_late_outlined,
              color: Color(0xFF94A3B8),
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryItemData {
  const _DeliveryItemData({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.gallons,
    required this.status,
    this.deliveredDate,
  });

  final String orderId;
  final String customerName;
  final String address;
  final int gallons;
  final _DeliveryStatus status;
  final String? deliveredDate;
}

class _StatusTheme {
  const _StatusTheme({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

enum _DeliveryStatus {
  delivering('Delivering'),
  completed('Completed');

  const _DeliveryStatus(this.label);
  final String label;
}

_StatusTheme _statusTheme(_DeliveryStatus status) {
  switch (status) {
    case _DeliveryStatus.delivering:
      return const _StatusTheme(
        foreground: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case _DeliveryStatus.completed:
      return const _StatusTheme(
        foreground: Color(0xFF15803D),
        background: Color(0xFFDCFCE7),
      );
  }
}
