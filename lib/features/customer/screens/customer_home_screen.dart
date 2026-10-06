import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  Timer? _greetingTimer;
  Timer? _orderRefreshTimer;

  Future<_DashboardOrdersData> _dashboardOrdersFuture = Future.value(
    const _DashboardOrdersData(activeOrders: [], recentOrders: []),
  );
  Future<String> _customerAvatarFuture = Future<String>.value('');

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
    _customerAvatarFuture = _fetchCustomerAvatar();

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
      setState(() {
        _customerAvatarFuture = _fetchCustomerAvatar();
      });
    }
  }

  Future<String> _fetchCustomerAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return '';

    try {
      final profile = await supabase
          .from('customer_profiles')
          .select('avatar_url')
          .eq('user_id', user.id)
          .maybeSingle();
      return profile?['avatar_url']?.toString().trim() ?? '';
    } catch (error) {
      debugPrint('Failed to load customer profile photo: $error');
      return '';
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),

        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

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
          FutureBuilder<_DashboardOrdersData>(
            future: _dashboardOrdersFuture,

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to load orders',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed: () =>
                            _reloadDashboardOrders(showLoading: false),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                );
              }

              final dashboardOrders =
                  snapshot.data ??
                  const _DashboardOrdersData(
                    activeOrders: [],
                    recentOrders: [],
                  );

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 20,
                      16,
                      0,
                    ),
                    child: Column(
                      children: [
                        FutureBuilder<String>(
                          future: _customerAvatarFuture,
                          builder: (context, avatarSnapshot) {
                            return _GreetingSection(
                              avatarUrl: avatarSnapshot.data ?? '',
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _OrderWaterCard(
                          onTap: () {
                            CustomerNavController.instance.goTo(1);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: 'Active Orders',
                          onSeeAllTap: () {
                            CustomerNavController.instance.goTo(2);
                          },
                        ),
                        const SizedBox(height: 8),
                        _ActiveOrdersList(
                          activeOrders: dashboardOrders.activeOrders,
                        ),
                        const SizedBox(height: 14),
                        _RecentOrdersHeader(
                          onSeeAllTap: () {
                            CustomerNavController.instance.goTo(2);
                          },
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _customerAvatarFuture,
                            builder: (context, avatarSnapshot) {
                              return RefreshIndicator(
                                onRefresh: () async {
                                  _reloadDashboardOrders(showLoading: false);
                                  try {
                                    await _dashboardOrdersFuture;
                                  } catch (_) {}
                                },
                                child: _RecentOrdersList(
                                  recentOrders: dashboardOrders.recentOrders,
                                  avatarUrl: avatarSnapshot.data ?? '',
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (_isRefreshing)
                    Positioned(
                      top:
                          MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          8,
                      right: 16,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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
  const _GreetingSection({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final customerName = CustomerSession.name?.trim().isNotEmpty == true
        ? CustomerSession.name!.trim()
        : 'Customer';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xEBF8FBFF), Color(0xE6EAF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E5FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A233455),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: avatarUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE4F0FF),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                    )
                  : Image.network(
                      avatarUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFE4F0FF),
                            child: Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: Color(0xFF2563EB),
                                size: 24,
                              ),
                            ),
                          ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF183B8F),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26183B8F),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -24,
                    bottom: -24,
                    right: -20,
                    width: 200,
                    child: Image.asset(
                      'assets/images/flashing water&gallons.png',
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
                            const Color(0xFF183B8F),
                            const Color(0xFF183B8F),
                            const Color(0xFF183B8F).withValues(alpha: 0.92),
                            const Color(0xFF183B8F).withValues(alpha: 0),
                          ],
                          stops: const [0, 0.36, 0.58, 0.88],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ORDER WATER NOW',
                            style: TextStyle(
                              color: Color(0xFFB9D8FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Aqua en Lavada',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Clean water, delivered to your home.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFDCEBFF),
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.water_drop_rounded,
                                  color: Color(0xFF183B8F),
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Place Order',
                                  style: TextStyle(
                                    color: Color(0xFF183B8F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF183B8F),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  const _SectionHeader({required this.title, required this.onSeeAllTap});

  final String title;
  final VoidCallback onSeeAllTap;

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
        GestureDetector(
          onTap: onSeeAllTap,
          child: Text(
            'See all →',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

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
          color: const Color(0xE8FFFFFF),
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

    return AspectRatio(
      aspectRatio: 2.22,
      child: _ActiveOrderCard(order: activeOrders.first),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Map<String, dynamic> order;

  String _status() => '${order['status'] ?? ''}'.trim().toLowerCase();

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

  @override
  Widget build(BuildContext context) {
    final gallons = order['gallons']?.toString() ?? '0';
    final address = '${order['address'] ?? 'No address'}';
    final driverName = order['driver_name']?.toString().trim() ?? '';
    final progress = switch (_status()) {
      'pending' => 'Order pending',
      'assigned' => 'Driver assigned',
      'on_the_way' ||
      'on the way' ||
      'in_transit' ||
      'in transit' ||
      'in_progress' ||
      'in progress' => 'On the way',
      'preparing' => 'Preparing your order',
      _ => _statusLabel(),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A233455),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/active-orders.jpg',
                  fit: BoxFit.fill,
                  alignment: Alignment.center,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 42,
                  width: constraints.maxWidth * 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.94),
                          Colors.white.withValues(alpha: 0.88),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 8,
                  bottom: constraints.maxHeight * 0.26,
                  width: constraints.maxWidth * 0.56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBg(),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 13,
                              color: _badgeColor(),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _statusLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _badgeColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$gallons Containers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B285D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF647EA6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Color(0xFF1672D4),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              progress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1672D4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (driverName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.delivery_dining_rounded,
                              size: 19,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                driverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0B285D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * 0.049,
                  bottom: constraints.maxHeight * 0.046,
                  width: constraints.maxWidth * 0.427,
                  height: constraints.maxHeight * 0.142,
                  child: Semantics(
                    button: true,
                    label: 'Track Live',
                    child: Material(
                      color: const Color(0xFF167DE5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => CustomerNavController.instance.goTo(2),
                        borderRadius: BorderRadius.circular(20),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Track Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward_rounded, size: 14),
                          ],
                        ),
                      ),
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

// ================================================================
// RECENT ORDERS LIST
// ================================================================

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList({
    required this.recentOrders,
    required this.avatarUrl,
  });

  final List<Map<String, dynamic>> recentOrders;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (recentOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xE8FFFFFF),
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
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: recentOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _RecentOrderTile(order: recentOrders[index], avatarUrl: avatarUrl),
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

// ================================================================
// RECENT ORDER TILE
// ================================================================

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order, required this.avatarUrl});

  final Map<String, dynamic> order;
  final String avatarUrl;

  String _orderLabel() {
    final customerName = (order['customer_name'] ?? order['name'] ?? 'Customer')
        .toString()
        .trim();

    return customerName.isEmpty ? 'Customer' : customerName;
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

  Widget _profileAvatar() {
    final imageUrl = avatarUrl.trim();
    if (imageUrl.isEmpty) {
      return _fallbackAvatar();
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFEFF6FF),
      child: Icon(Icons.person_outline, color: Color(0xFF2563EB), size: 21),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE8FFFFFF),

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

        leading: _profileAvatar(),

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
