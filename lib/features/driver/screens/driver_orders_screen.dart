import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<List<_DeliveryItemData>> _fetchActiveOrders() async {
    final driverIds = await _currentDriverIds();

    if (driverIds.isEmpty) {
      return [];
    }

    final orders = driverIds.length == 1
        ? await Supabase.instance.client
              .from('orders')
              .select()
              .eq('driver_id', driverIds.first)
              .inFilter('status', ['assigned', 'in_progress', 'on_the_way'])
        : await Supabase.instance.client
              .from('orders')
              .select()
              .inFilter('driver_id', driverIds)
              .inFilter('status', ['assigned', 'in_progress', 'on_the_way']);

    final orderRows = orders.whereType<Map<String, dynamic>>().toList();
    final avatarUrls = await _fetchCustomerAvatarUrls(orderRows);

    return orderRows
        .map(
          (order) => _mapActiveOrder(
            order,
            avatarUrl: avatarUrls[order['customer_id']?.toString() ?? ''] ?? '',
          ),
        )
        .toList();
  }

  Future<List<_DeliveryItemData>> _fetchCompletedOrders() async {
    final driverIds = await _currentDriverIds();

    if (driverIds.isEmpty) {
      return [];
    }

    final orders = driverIds.length == 1
        ? await Supabase.instance.client
              .from('orders')
              .select()
              .eq('driver_id', driverIds.first)
              .inFilter('status', ['delivered', 'completed'])
              .order('created_at', ascending: false)
        : await Supabase.instance.client
              .from('orders')
              .select()
              .inFilter('driver_id', driverIds)
              .inFilter('status', ['delivered', 'completed'])
              .order('created_at', ascending: false);

    final orderRows = orders.whereType<Map<String, dynamic>>().toList();
    final avatarUrls = await _fetchCustomerAvatarUrls(orderRows);

    return orderRows
        .map(
          (order) => _mapCompletedOrder(
            order,
            avatarUrl: avatarUrls[order['customer_id']?.toString() ?? ''] ?? '',
          ),
        )
        .toList();
  }

  Future<Map<String, String>> _fetchCustomerAvatarUrls(
    List<Map<String, dynamic>> orders,
  ) async {
    final customerIds = orders
        .map((order) => order['customer_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (customerIds.isEmpty) return {};

    try {
      final profiles = await Supabase.instance.client
          .from('customer_profiles')
          .select('user_id, avatar_url')
          .inFilter('user_id', customerIds);
      final avatarUrls = <String, String>{};
      for (final profile in profiles.whereType<Map<String, dynamic>>()) {
        final userId = profile['user_id']?.toString().trim() ?? '';
        final avatarUrl = profile['avatar_url']?.toString().trim() ?? '';
        if (userId.isNotEmpty && avatarUrl.isNotEmpty) {
          avatarUrls[userId] = avatarUrl;
        }
      }
      return avatarUrls;
    } catch (error) {
      debugPrint('Failed to load delivery customer photos: $error');
      return {};
    }
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

  String _formatOrderDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Unknown date';
    return DateFormat('MMM d').format(date.toLocal());
  }

  _DeliveryItemData _mapActiveOrder(
    Map<String, dynamic> order, {
    required String avatarUrl,
  }) {
    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return fallback;
      }
      return text;
    }

    double? toDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    String displayAddressOf(Map<String, dynamic> row) {
      final addressText = row['address_text']?.toString().trim();
      if (addressText != null && addressText.isNotEmpty) {
        return addressText;
      }

      final lat = toDouble(row['latitude']);
      final lng = toDouble(row['longitude']);
      if (lat != null && lng != null) {
        return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
      }

      return textOf(row['address'], fallback: 'No address provided');
    }

    int gallonsOf(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final orderId = textOf(order['id'], fallback: 'Unknown');
    final customerName = textOf(order['customer_name'], fallback: 'Customer');
    final address = displayAddressOf(order);
    final gallons = gallonsOf(order['gallons']);
    final rawStatus = textOf(
      order['status'],
      fallback: 'assigned',
    ).toLowerCase();
    final status = rawStatus == 'in_progress'
        ? 'on_the_way'
        : (rawStatus == 'on_the_way' || rawStatus == 'delivered'
              ? rawStatus
              : 'assigned');

    return _DeliveryItemData(
      orderId: 'Order #$orderId',
      customerName: customerName,
      avatarUrl: avatarUrl,
      address: address,
      orderDate: _formatOrderDate(order['created_at']),
      gallons: gallons,
      status: status,
      rawOrder: Map<String, dynamic>.from(order),
    );
  }

  _DeliveryItemData _mapCompletedOrder(
    Map<String, dynamic> order, {
    required String avatarUrl,
  }) {
    String textOf(dynamic value, {required String fallback}) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return fallback;
      }
      return text;
    }

    double? toDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    String displayAddressOf(Map<String, dynamic> row) {
      final addressText = row['address_text']?.toString().trim();
      if (addressText != null && addressText.isNotEmpty) {
        return addressText;
      }

      final lat = toDouble(row['latitude']);
      final lng = toDouble(row['longitude']);
      if (lat != null && lng != null) {
        return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
      }

      return textOf(row['address'], fallback: 'No address provided');
    }

    int gallonsOf(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final orderId = textOf(order['id'], fallback: 'Unknown');
    final customerName = textOf(order['customer_name'], fallback: 'Customer');
    final address = displayAddressOf(order);
    final gallons = gallonsOf(order['gallons']);
    final deliveredDate = _formatDate(
      order['delivered_at'] ?? order['updated_at'] ?? order['created_at'],
    );

    return _DeliveryItemData(
      orderId: 'Order #$orderId',
      customerName: customerName,
      avatarUrl: avatarUrl,
      address: address,
      orderDate: _formatOrderDate(order['created_at']),
      gallons: gallons,
      status: 'delivered',
      deliveredDate: deliveredDate,
      rawOrder: Map<String, dynamic>.from(order),
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
                          status: delivery.status,
                          contactNumber: '+63 912 345 6789',
                          address: delivery.address,
                          totalGallons: delivery.gallons,
                          initialOrder: delivery.rawOrder,
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DriverOrderDetailsScreen(
                          customerName: delivery.customerName,
                          orderId: delivery.orderId,
                          status: delivery.status,
                          contactNumber: '+63 912 345 6789',
                          address: delivery.address,
                          totalGallons: delivery.gallons,
                          initialOrder: delivery.rawOrder,
                        ),
                      ),
                    );
                  },
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

  @override
  Widget build(BuildContext context) {
    final statusTheme = _statusTheme(delivery.status);
    final avatarUrl = delivery.avatarUrl;
    final deliveryInstructions =
        delivery.rawOrder?['delivery_instructions']?.toString().trim() ?? '';

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      )
                    : Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
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
                      '${delivery.gallons} Containers',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (deliveryInstructions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              deliveryInstructions,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      _statusLabel(delivery.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusTheme.foreground,
                      ),
                    ),
                  ),
                  if (isReadOnly && delivery.deliveredDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      delivery.deliveredDate!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (!isReadOnly && delivery.orderDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      delivery.orderDate!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
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
    this.avatarUrl = '',
    required this.address,
    this.orderDate,
    required this.gallons,
    required this.status,
    this.rawOrder,
    this.deliveredDate,
  });

  final String orderId;
  final String customerName;
  final String? avatarUrl;
  final String address;
  final String? orderDate;
  final int gallons;
  final String status;
  final Map<String, dynamic>? rawOrder;
  final String? deliveredDate;
}

class _StatusTheme {
  const _StatusTheme({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

String _statusLabel(String status) {
  switch (status) {
    case 'assigned':
      return 'Assigned';
    case 'on_the_way':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    default:
      return status;
  }
}

_StatusTheme _statusTheme(String status) {
  switch (status) {
    case 'assigned':
      return const _StatusTheme(
        foreground: Color(0xFFB45309),
        background: Color(0xFFFEF3C7),
      );
    case 'on_the_way':
      return const _StatusTheme(
        foreground: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case 'delivered':
      return const _StatusTheme(
        foreground: Color(0xFF15803D),
        background: Color(0xFFDCFCE7),
      );
    default:
      return const _StatusTheme(
        foreground: Color(0xFF475569),
        background: Color(0xFFE2E8F0),
      );
  }
}
