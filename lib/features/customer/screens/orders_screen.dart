import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  final SupabaseClient supabase = Supabase.instance.client;

  int _selectedFilterIndex = 0;
  String? _cancellingOrderId;
  final Set<String> _hiddenOrderIds = <String>{};
  List<Map<String, dynamic>> myOrders = <Map<String, dynamic>>[];
  bool _isLoadingOrders = true;

  static const List<String> _filters = [
    'All',
    'Pending',
    'Active',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    loadOrders();
    CustomerNavController.instance.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    CustomerNavController.instance.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (CustomerNavController.instance.index == 2) {
      loadOrders();
    }
  }

  String get selectedTab => _filters[_selectedFilterIndex];

  String _normalizeStatusValue(dynamic status) {
    return status.toString().trim().toLowerCase().replaceAll(' ', '_');
  }

  Future<void> loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoadingOrders = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint('No logged-in user');
        if (!mounted) return;
        setState(() {
          myOrders = <Map<String, dynamic>>[];
          _isLoadingOrders = false;
        });
        return;
      }

      debugPrint('Logged in user: ${user.id}');

      final response = await supabase
          .from('orders')
          .select('*')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      debugPrint('Orders fetched: $response');

      final allOrders = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> orders = allOrders
          .where((o) => _normalizeStatusValue(o['status']) != 'cancelled')
          .toList();

      // FILTER BASED ON TAB
      if (selectedTab == 'Pending') {
        orders = orders
            .where((o) => _normalizeStatusValue(o['status']) == 'pending')
            .toList();
      } else if (selectedTab == 'Active') {
        orders = orders
            .where(
              (o) =>
                  _normalizeStatusValue(o['status']) == 'accepted' ||
                  _normalizeStatusValue(o['status']) == 'assigned' ||
                  _normalizeStatusValue(o['status']) == 'on_the_way' ||
                  _normalizeStatusValue(o['status']) == 'delivering' ||
                  _normalizeStatusValue(o['status']) == 'preparing',
            )
            .toList();
      } else if (selectedTab == 'Completed') {
        orders = orders
            .where(
              (o) =>
                  _normalizeStatusValue(o['status']) == 'delivered' ||
                  _normalizeStatusValue(o['status']) == 'completed',
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        myOrders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (!mounted) return;
      setState(() {
        myOrders = <Map<String, dynamic>>[];
        _isLoadingOrders = false;
      });
    }
  }

  String _normalizedStatus(Map<String, dynamic> order) {
    return '${order['status'] ?? ''}'.trim().toLowerCase().replaceAll(' ', '_');
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> orders) {
    if (_selectedFilterIndex == 1) {
      return orders.where((order) {
        final status = _normalizedStatus(order);
        return status == 'pending';
      }).toList();
    }

    if (_selectedFilterIndex == 2) {
      return orders.where((order) {
        final status = _normalizedStatus(order);
        return status == 'assigned' ||
            status == 'on_the_way' ||
            status == 'preparing';
      }).toList();
    }

    if (_selectedFilterIndex == 3) {
      return orders.where((order) {
        final status = _normalizedStatus(order);
        return status == 'delivered' || status == 'completed';
      }).toList();
    }

    return orders;
  }

  String _orderId(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? 'unknown';
    return 'Order #${id.length >= 6 ? id.substring(0, 6) : id}';
  }

  String _gallons(Map<String, dynamic> order) =>
      '${order['gallons'] ?? ''} Gallons';

  String _price(Map<String, dynamic> order) => '₱${order['total_price'] ?? ''}';

  String _status(Map<String, dynamic> order) => '${order['status'] ?? ''}';

  bool _isPending(Map<String, dynamic> order) =>
      _normalizedStatus(order) == 'pending';

  Future<void> cancelOrder(String orderId) async {
    if (_cancellingOrderId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: const Text('Are you sure you want to cancel this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _cancellingOrderId = orderId;
    });

    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully')),
      );

      setState(() {
        _hiddenOrderIds.add(orderId);
      });

      loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrderId = null;
        });
      }
    }
  }

  String _statusLabel(Map<String, dynamic> order) {
    switch (_normalizedStatus(order)) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Driver Assigned';
      case 'on_the_way':
        return 'Driver is on the way';
      case 'delivering':
        return 'Driver is on the way';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Delivered';
      default:
        return _status(order);
    }
  }

  Color _statusColor(Map<String, dynamic> order) {
    switch (_normalizedStatus(order)) {
      case 'pending':
        return const Color(0xFFCA8A04);
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'on_the_way':
      case 'delivering':
        return const Color(0xFFEA580C);
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBackground(Map<String, dynamic> order) {
    switch (_normalizedStatus(order)) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'assigned':
        return const Color(0xFFDBEAFE);
      case 'on_the_way':
      case 'delivering':
        return const Color(0xFFFFEDD5);
      case 'delivered':
      case 'completed':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String _deliveryType(Map<String, dynamic> order) =>
      '${order['delivery_type'] ?? 'now'}';

  DateTime? _scheduledDate(Map<String, dynamic> order) {
    final rawDate = order['scheduled_date'];
    if (rawDate == null) return null;
    return DateTime.tryParse(rawDate.toString());
  }

  TimeOfDay? _scheduledTime(Map<String, dynamic> order) {
    final rawTime = order['scheduled_time']?.toString();
    if (rawTime == null || rawTime.isEmpty) return null;
    final parts = rawTime.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget buildOrderCard(Map<String, dynamic> order) {
    final scheduledDate = _scheduledDate(order);
    final scheduledTime = _scheduledTime(order);
    Color deliveryTypeColor() {
      return _deliveryType(order) == 'scheduled'
          ? const Color(0xFF7C3AED)
          : const Color(0xFF0369A1);
    }

    Color deliveryTypeBackground() {
      return _deliveryType(order) == 'scheduled'
          ? const Color(0xFFEDE9FE)
          : const Color(0xFFE0F2FE);
    }

    String deliveryTypeLabel() {
      return _deliveryType(order) == 'scheduled' ? 'Scheduled' : 'On Demand';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Builder(
        builder: (context) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerTrackOrderScreen(order: order),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F233455),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _orderId(order),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _gallons(order),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _price(order),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: deliveryTypeBackground(),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              deliveryTypeLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: deliveryTypeColor(),
                              ),
                            ),
                          ),
                          if (scheduledDate != null &&
                              scheduledTime != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              '${_formatDate(scheduledDate)} • ${scheduledTime.format(context)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBackground(order),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _statusColor(
                                order,
                              ).withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _statusLabel(order),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(order),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 118,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CustomerTrackOrderScreen(order: order),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              backgroundColor: const Color(0xFFF8FBFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Track Order',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_isPending(order)) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 118,
                            child: ElevatedButton(
                              onPressed: _cancellingOrderId == order['id']
                                  ? null
                                  : () => cancelOrder(
                                      order['id']?.toString() ?? '',
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                minimumSize: const Size.fromHeight(36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _cancellingOrderId == order['id']
                                    ? 'Cancelling...'
                                    : 'Cancel Order',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Orders'),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List<Widget>.generate(_filters.length, (index) {
                  final isSelected = index == _selectedFilterIndex;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < _filters.length - 1 ? 8 : 0,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                          loadOrders();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            _filters[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Builder(
                builder: (context) {
                  final user = supabase.auth.currentUser;
                  if (user == null) {
                    return const _EmptyState(message: 'Please login');
                  }

                  if (_isLoadingOrders) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final visibleOrders = myOrders
                      .where(
                        (order) =>
                            !_hiddenOrderIds.contains(order['id']?.toString()),
                      )
                      .toList();

                  if (visibleOrders.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: visibleOrders.length,
                    itemBuilder: (context, index) {
                      final order = visibleOrders[index];
                      return buildOrderCard(order);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message = 'No orders yet'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F233455),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
