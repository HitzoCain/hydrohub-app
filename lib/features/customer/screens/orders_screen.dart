import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFFF6F8FB);

  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> myOrders = <Map<String, dynamic>>[];
  final List<String> _filters = const ['All', 'Pending', 'Active', 'Completed'];
  final Set<String> _hiddenOrderIds = <String>{};

  Timer? _refreshTimer;
  String? _cancellingOrderId;
  bool _isRefreshing = false;
  bool _isLoadingOrders = false;
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    CustomerNavController.instance.addListener(_handleTabChange);
    loadOrders(showLoading: false);
  }

  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _refreshTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    CustomerNavController.instance.removeListener(_handleTabChange);

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================
  //
  // When the customer leaves the app and comes back,
  // immediately refresh the orders.
  //

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        loadOrders(showLoading: false);
      }
    }
  }

  // ============================================================
  // NAVIGATION TAB CHANGE
  // ============================================================

  void _handleTabChange() {
    if (!mounted) return;

    if (CustomerNavController.instance.index == 2) {
      loadOrders(showLoading: false);
    }
  }

  // ============================================================
  // SELECTED TAB
  // ============================================================

  String get selectedTab => _filters[_selectedFilterIndex];

  // ============================================================
  // NORMALIZE ORDER STATUS
  // ============================================================

  String _normalizeStatusValue(dynamic status) {
    return status.toString().trim().toLowerCase().replaceAll(' ', '_');
  }

  // ============================================================
  // NORMALIZE PAYMENT STATUS
  // ============================================================

  String _normalizePaymentStatus(dynamic paymentStatus) {
    return paymentStatus.toString().trim().toLowerCase().replaceAll(' ', '_');
  }

  // ============================================================
  // CHECK IF PAYMENT IS REJECTED
  // ============================================================

  bool _isPaymentRejected(Map<String, dynamic> order) {
    final paymentStatus = _normalizePaymentStatus(order['payment_status']);

    return paymentStatus == 'rejected' || paymentStatus == 'declined';
  }

  // ============================================================
  // CHECK IF ORDER IS CANCELLED
  // ============================================================

  bool _isOrderCancelled(Map<String, dynamic> order) {
    final status = _normalizeStatusValue(order['status']);

    return status == 'cancelled' || status == 'canceled';
  }

  // ============================================================
  // LOAD ORDERS
  // ============================================================

  Future<void> loadOrders({bool showLoading = true}) async {
    // Prevent multiple refresh requests at the same time.
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

    if (mounted && showLoading) {
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

      debugPrint('Loading orders for customer: ${user.id}');

      // --------------------------------------------------------
      // GET CURRENT ORDERS FROM SUPABASE
      // --------------------------------------------------------

      final response = await supabase
          .from('orders')
          .select('*')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      debugPrint('Orders fetched: ${response.length}');

      final allOrders = List<Map<String, dynamic>>.from(response);

      // --------------------------------------------------------
      // REMOVE ORDERS THAT SHOULD NOT APPEAR
      // --------------------------------------------------------
      //
      // IMPORTANT:
      //
      // Admin rejection changes:
      //
      // payment_status = "Rejected"
      //
      // It does NOT necessarily change:
      //
      // status = "cancelled"
      //
      // Therefore we MUST check payment_status here.
      //

      List<Map<String, dynamic>> orders = allOrders.where((order) {
        // Hide cancelled orders.
        if (_isOrderCancelled(order)) {
          return false;
        }

        // Hide rejected GCash/payment orders.
        if (_isPaymentRejected(order)) {
          return false;
        }

        return true;
      }).toList();

      orders = _applyFilter(orders);

      if (!mounted) return;

      setState(() {
        myOrders = orders;
        _isLoadingOrders = false;
      });

      debugPrint('Visible customer orders: ${orders.length}');
    } catch (e) {
      debugPrint('Error loading orders: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingOrders = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  // ============================================================
  // NORMALIZED STATUS
  // ============================================================

  String _normalizedStatus(Map<String, dynamic> order) {
    return '${order['status'] ?? ''}'.trim().toLowerCase().replaceAll(' ', '_');
  }

  // ============================================================
  // FILTER ORDERS
  // ============================================================

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> orders) {
    // ----------------------------------------------------------
    // PENDING
    // ----------------------------------------------------------

    if (_selectedFilterIndex == 1) {
      return orders.where((order) {
        final status = _normalizedStatus(order);

        return status == 'pending';
      }).toList();
    }

    // ----------------------------------------------------------
    // ACTIVE
    // ----------------------------------------------------------

    if (_selectedFilterIndex == 2) {
      return orders.where((order) {
        final status = _normalizedStatus(order);

        return status == 'assigned' ||
            status == 'on_the_way' ||
            status == 'preparing' ||
            status == 'delivering';
      }).toList();
    }

    // ----------------------------------------------------------
    // COMPLETED
    // ----------------------------------------------------------

    if (_selectedFilterIndex == 3) {
      return orders.where((order) {
        final status = _normalizedStatus(order);

        return status == 'delivered' || status == 'completed';
      }).toList();
    }

    // ----------------------------------------------------------
    // ALL
    // ----------------------------------------------------------

    return orders;
  }

  // ============================================================
  // CONTAINER QUANTITY
  // ============================================================

  String _gallons(Map<String, dynamic> order) {
    return '${order['gallons'] ?? ''} Containers';
  }

  // ============================================================
  // PRICE
  // ============================================================

  String _price(Map<String, dynamic> order) {
    return '₱${order['total_price'] ?? ''}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _status(Map<String, dynamic> order) {
    return '${order['status'] ?? ''}';
  }

  // ============================================================
  // IS PENDING
  // ============================================================

  bool _isPending(Map<String, dynamic> order) {
    return _normalizedStatus(order) == 'pending';
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  Future<void> cancelOrder(String orderId) async {
    if (_cancellingOrderId != null) {
      return;
    }

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
      await supabase
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

      // Immediately refresh.
      await loadOrders(showLoading: false);
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

  // ============================================================
  // STATUS LABEL
  // ============================================================

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

  // ============================================================
  // STATUS COLOR
  // ============================================================

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

  // ============================================================
  // STATUS BACKGROUND
  // ============================================================

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

  // ============================================================
  // DELIVERY TYPE
  // ============================================================

  String _deliveryType(Map<String, dynamic> order) {
    return '${order['delivery_type'] ?? 'now'}';
  }

  // ============================================================
  // SCHEDULED DATE
  // ============================================================

  DateTime? _scheduledDate(Map<String, dynamic> order) {
    final rawDate = order['scheduled_date'];

    if (rawDate == null) {
      return null;
    }

    return DateTime.tryParse(rawDate.toString());
  }

  // ============================================================
  // SCHEDULED TIME
  // ============================================================

  TimeOfDay? _scheduledTime(Map<String, dynamic> order) {
    final rawTime = order['scheduled_time']?.toString();

    if (rawTime == null || rawTime.isEmpty) {
      return null;
    }

    final parts = rawTime.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

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

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  // ============================================================
  // BUILD ORDER CARD
  // ============================================================

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),

              // ------------------------------------------------
              // TRACK ORDER
              // ------------------------------------------------
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerTrackOrderScreen(order: order),
                  ),
                );
              },

              child: Container(
                padding: const EdgeInsets.all(12),
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
                              '${_formatDate(scheduledDate)}'
                              ' • '
                              '${scheduledTime.format(context)}',
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

                    const SizedBox(width: 8),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // --------------------------------------
                        // STATUS
                        // --------------------------------------
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

                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        CustomerTrackOrderScreen(order: order),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.local_shipping_outlined,
                                size: 15,
                              ),
                              label: const Text(
                                'Track',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_isPending(order))
                              TextButton.icon(
                                onPressed: _cancellingOrderId == order['id']
                                    ? null
                                    : () => cancelOrder(
                                        order['id']?.toString() ?? '',
                                      ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: _cancellingOrderId == order['id']
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.close_rounded, size: 15),
                                label: Text(
                                  _cancellingOrderId == order['id']
                                      ? 'Cancelling'
                                      : 'Cancel',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'My Orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ==================================================
            // FILTER TABS
            // ==================================================
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

                          loadOrders(showLoading: false);
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

            // ==================================================
            // ORDERS
            // ==================================================
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

                  // ------------------------------------------------
                  // HIDE ORDERS THAT WERE LOCALLY CANCELLED
                  // ------------------------------------------------

                  final visibleOrders = myOrders.where((order) {
                    return !_hiddenOrderIds.contains(order['id']?.toString());
                  }).toList();

                  // ------------------------------------------------
                  // EXTRA SAFETY CHECK
                  // ------------------------------------------------
                  //
                  // Even if a rejected order somehow exists
                  // in memory, do not display it.
                  //

                  final safeOrders = visibleOrders.where((order) {
                    return !_isPaymentRejected(order) &&
                        !_isOrderCancelled(order);
                  }).toList();

                  if (safeOrders.isEmpty) {
                    return const _EmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () => loadOrders(showLoading: false),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: safeOrders.length,
                      itemBuilder: (context, index) {
                        final order = safeOrders[index];

                        return buildOrderCard(order);
                      },
                    ),
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

// ================================================================
// EMPTY STATE
// ================================================================

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
