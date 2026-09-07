import 'dart:async';

import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFFF1F5F9);

  Timer? _greetingTimer;
  Timer? _orderRefreshTimer;

  Future<_DashboardOrdersData> _dashboardOrdersFuture = Future.value(
    const _DashboardOrdersData(activeOrders: [], recentOrders: []),
  );

  bool _isRefreshing = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    CustomerNavController.instance.addListener(_handleTabChange);

    // Initial order load
    _reloadDashboardOrders();

    // Update greeting every minute
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    // ==========================================================
    // AUTO REFRESH ORDERS
    // ==========================================================
    //
    // Every 15 seconds, check Supabase for updated order data.
    //
    // This allows the customer application to detect:
    //
    // - Admin verified payment
    // - Admin rejected payment
    // - Order status changed
    // - Driver assigned
    // - Driver started delivery
    // - Order delivered
    //
    // without requiring the customer to manually refresh.
    //
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _reloadDashboardOrders(showLoading: false);
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _orderRefreshTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    CustomerNavController.instance.removeListener(_handleTabChange);

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    // Refresh immediately when the app becomes active again.
    if (state == AppLifecycleState.resumed) {
      _reloadDashboardOrders(showLoading: false);
    }
  }

  // ============================================================
  // NAVIGATION TAB CHANGE
  // ============================================================

  void _handleTabChange() {
    if (!mounted) return;

    // Home tab
    if (CustomerNavController.instance.index == 0) {
      _reloadDashboardOrders(showLoading: false);
    }
  }

  // ============================================================
  // RELOAD DASHBOARD ORDERS
  // ============================================================

  void _reloadDashboardOrders({bool showLoading = false}) {
    if (!mounted) return;

    setState(() {
      _dashboardOrdersFuture = _fetchDashboardOrders();
      _isRefreshing = showLoading;
    });
  }

  // ============================================================
  // FETCH DASHBOARD ORDERS
  // ============================================================

  Future<_DashboardOrdersData> _fetchDashboardOrders() async {
    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;
    final customerId = user?.id;

    if (customerId == null || customerId.trim().isEmpty) {
      return const _DashboardOrdersData(activeOrders: [], recentOrders: []);
    }

    try {
      // ========================================================
      // FETCH ACTIVE ORDERS
      // ========================================================

      final activeOrdersResponse = await supabase
          .from('orders')
          .select()
          .eq('customer_id', customerId)
          .not('status', 'in', '(delivered,cancelled)')
          .order('created_at', ascending: false);

      // ========================================================
      // FETCH RECENT ORDERS
      // ========================================================

      final recentOrdersResponse = await supabase
          .from('orders')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(10);

      // ========================================================
      // CONVERT RESULTS
      // ========================================================

      final allActiveOrders = List<Map<String, dynamic>>.from(
        activeOrdersResponse,
      );

      final allRecentOrders = List<Map<String, dynamic>>.from(
        recentOrdersResponse,
      );

      // ========================================================
      // REMOVE REJECTED PAYMENT ORDERS
      // ========================================================
      //
      // IMPORTANT:
      //
      // Admin rejection changes:
      //
      // payment_status = "Rejected"
      //
      // The order status itself may still be:
      //
      // status = "pending"
      //
      // Therefore, checking only order.status is NOT enough.
      //
      // We explicitly remove every order whose payment_status
      // is rejected.
      //
      // We also handle:
      //
      // "Rejected"
      // "rejected"
      // "REJECTED"
      //
      // because the database/application may use different casing.
      //
      final activeOrders = allActiveOrders.where((order) {
        final paymentStatus = '${order['payment_status'] ?? ''}'
            .trim()
            .toLowerCase();

        return paymentStatus != 'rejected';
      }).toList();

      final recentOrders = allRecentOrders
          .where((order) {
            final paymentStatus = '${order['payment_status'] ?? ''}'
                .trim()
                .toLowerCase();

            return paymentStatus != 'rejected';
          })
          .take(5)
          .toList();

      return _DashboardOrdersData(
        activeOrders: activeOrders,
        recentOrders: recentOrders,
      );
    } catch (error) {
      debugPrint('========================================');
      debugPrint('CUSTOMER HOME ORDER FETCH ERROR');
      debugPrint('Error: $error');
      debugPrint('========================================');

      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
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
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),

        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: FutureBuilder<_DashboardOrdersData>(
        future: _dashboardOrdersFuture,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: () async {
                _reloadDashboardOrders(showLoading: false);

                try {
                  await _dashboardOrdersFuture;
                } catch (_) {}
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),

                  Center(
                    child: Text(
                      'Failed to load orders',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            );
          }

          final dashboardOrders =
              snapshot.data ??
              const _DashboardOrdersData(activeOrders: [], recentOrders: []);

          return RefreshIndicator(
            onRefresh: () async {
              _reloadDashboardOrders(showLoading: false);

              try {
                await _dashboardOrdersFuture;
              } catch (_) {}
            },

            child: Stack(
              children: [
                ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),

                  children: [
                    const _GreetingSection(),

                    const SizedBox(height: 18),

                    _OrderWaterCard(
                      onTap: () {
                        CustomerNavController.instance.goTo(1);
                      },
                    ),

                    const SizedBox(height: 24),

                    const _SectionHeader(title: 'Active Orders'),

                    const SizedBox(height: 12),

                    _ActiveOrdersList(
                      activeOrders: dashboardOrders.activeOrders,
                    ),

                    const SizedBox(height: 24),

                    _RecentOrdersHeader(
                      onSeeAllTap: () {
                        CustomerNavController.instance.goTo(2);
                      },
                    ),

                    const SizedBox(height: 12),

                    _RecentOrdersList(
                      recentOrders: dashboardOrders.recentOrders,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),

                // Small refresh indicator at the top while
                // background auto-refresh is happening.
                if (_isRefreshing)
                  const Positioned(
                    top: 8,
                    right: 16,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// DASHBOARD ORDERS DATA
// ================================================================

class _DashboardOrdersData {
  const _DashboardOrdersData({
    required this.activeOrders,
    required this.recentOrders,
  });

  final List<Map<String, dynamic>> activeOrders;
  final List<Map<String, dynamic>> recentOrders;
}

// ================================================================
// GREETING
// ================================================================

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  String _salutation() {
    final hour = DateTime.now().toLocal().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final customerName = (CustomerSession.name?.trim().isNotEmpty == true)
        ? CustomerSession.name!.trim()
        : 'Customer';

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFEAF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFD7E5FF)),

        boxShadow: const [
          BoxShadow(
            color: Color(0x102563EB),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  '${_salutation()}, $customerName 👋',

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.05,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Your water orders and active deliveries in one place.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ORDER WATER CARD
// ================================================================

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

// ================================================================
// SECTION HEADER
// ================================================================

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

// ================================================================
// ACTIVE ORDERS LIST
// ================================================================

class _ActiveOrdersList extends StatelessWidget {
  const _ActiveOrdersList({required this.activeOrders});

  final List<Map<String, dynamic>> activeOrders;

  @override
  Widget build(BuildContext context) {
    if (activeOrders.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),

        child: const Text(
          'No active orders',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 175,

      child: ListView(
        scrollDirection: Axis.horizontal,

        children: [
          for (int i = 0; i < activeOrders.length; i++) ...[
            _ActiveOrderCard(order: activeOrders[i]),

            if (i != activeOrders.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// ACTIVE ORDER CARD
// ================================================================

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Map<String, dynamic> order;

  String _status() {
    return '${order['status'] ?? ''}'.trim().toLowerCase();
  }

  String _statusLabel() {
    switch (_status()) {
      case 'pending':
        return 'Pending';

      case 'assigned':
        return 'Assigned';

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return 'On the Way';

      case 'preparing':
        return 'Preparing';

      default:
        return '${order['status'] ?? 'Unknown'}';
    }
  }

  Color _badgeColor() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFB45309);

      case 'assigned':
        return const Color(0xFF0369A1);

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return const Color(0xFF1D4ED8);

      case 'preparing':
        return const Color(0xFF9333EA);

      default:
        return const Color(0xFF64748B);
    }
  }

  Color _badgeBg() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFFEF3C7);

      case 'assigned':
        return const Color(0xFFE0F2FE);

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return const Color(0xFFDBEAFE);

      case 'preparing':
        return const Color(0xFFF3E8FF);

      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String _orderLabel() {
    final id = '${order['id'] ?? ''}';

    if (id.isEmpty) {
      return 'Order';
    }

    final short = id.length > 8 ? id.substring(0, 8) : id;

    return 'Order #$short';
  }

  @override
  Widget build(BuildContext context) {
    final gallons = order['gallons']?.toString() ?? '0';

    final address = '${order['address'] ?? 'No address'}';

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
            _orderLabel(),

            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),

            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

            decoration: BoxDecoration(
              color: _badgeBg(),
              borderRadius: BorderRadius.circular(20),
            ),

            child: Text(
              _statusLabel(),

              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _badgeColor(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '$gallons Gallons',

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),

            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          Text(
            address,

            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),

            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerTrackOrderScreen(order: order),
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

// ================================================================
// RECENT ORDERS LIST
// ================================================================

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList({required this.recentOrders});

  final List<Map<String, dynamic>> recentOrders;

  @override
  Widget build(BuildContext context) {
    if (recentOrders.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),

        child: const Text(
          'No recent orders',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < recentOrders.length; i++) ...[
          _RecentOrderTile(order: recentOrders[i]),

          if (i != recentOrders.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ================================================================
// RECENT ORDERS HEADER
// ================================================================

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

// ================================================================
// RECENT ORDER TILE
// ================================================================

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final Map<String, dynamic> order;

  String _orderLabel() {
    final id = '${order['id'] ?? ''}';

    if (id.isEmpty) {
      return 'Order';
    }

    final short = id.length > 8 ? id.substring(0, 8) : id;

    return 'Order #$short';
  }

  String _priceLabel() {
    final totalPrice = order['total_price'];

    if (totalPrice is num) {
      return '₱${totalPrice.toStringAsFixed(0)}';
    }

    return '₱0';
  }

  String _dateLabel() {
    final createdAt = '${order['created_at'] ?? ''}';

    final parsed = DateTime.tryParse(createdAt);

    if (parsed == null) {
      return 'Unknown date';
    }

    return '${_monthName(parsed.month)} ${parsed.day}';
  }

  String _status() {
    return '${order['status'] ?? ''}'.trim().toLowerCase();
  }

  String _statusLabel() {
    switch (_status()) {
      case 'delivered':
      case 'completed':
        return 'Delivered';

      case 'assigned':
        return 'Assigned';

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return 'On the Way';

      case 'pending':
        return 'Pending';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return '${order['status'] ?? 'Unknown'}';
    }
  }

  Color _statusColor() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFEA580C);

      case 'assigned':
        return const Color(0xFF0369A1);

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return const Color(0xFF2563EB);

      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);

      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);

      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBgColor() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFFFEDD5);

      case 'assigned':
        return const Color(0xFFE0F2FE);

      case 'on_the_way':
      case 'on the way':
      case 'in_transit':
      case 'in transit':
      case 'in_progress':
      case 'in progress':
        return const Color(0xFFDBEAFE);

      case 'delivered':
      case 'completed':
        return const Color(0xFFDCFCE7);

      case 'cancelled':
      case 'canceled':
        return const Color(0xFFFEE2E2);

      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String _monthName(int month) {
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

    return months[month - 1];
  }

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
          _orderLabel(),

          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),

        subtitle: Text(
          _dateLabel(),

          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),

        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          crossAxisAlignment: CrossAxisAlignment.end,

          children: [
            Text(
              _priceLabel(),

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
                color: _statusBgColor(),
                borderRadius: BorderRadius.circular(20),
              ),

              child: Text(
                _statusLabel(),

                style: TextStyle(
                  fontSize: 10,
                  color: _statusColor(),
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
