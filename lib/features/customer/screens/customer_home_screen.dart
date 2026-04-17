import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/customer_nav_controller.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_in_laba_app/features/customer/customer_session.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  Future<_DashboardOrdersData> _dashboardOrdersFuture =
      Future<_DashboardOrdersData>.value(
        const _DashboardOrdersData(activeOrders: [], recentOrders: []),
      );

  static const Color _background = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _reloadDashboardOrders();
    CustomerNavController.instance.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    CustomerNavController.instance.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (CustomerNavController.instance.index == 0) {
      _reloadDashboardOrders();
    }
  }

  void _reloadDashboardOrders() {
    setState(() {
      _dashboardOrdersFuture = _fetchDashboardOrders();
    });
  }

  Future<_DashboardOrdersData> _fetchDashboardOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    final customerId = user?.id;

    debugPrint('Customer ID: $customerId');

    if (customerId == null || customerId.trim().isEmpty) {
      return const _DashboardOrdersData(activeOrders: [], recentOrders: []);
    }

    final today = DateTime.now().toIso8601String().split('T')[0];

    final activeOrders = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .not('status', 'in', '(delivered,cancelled)')
        .order('created_at', ascending: false);

    final recentOrders = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(5);

    debugPrint('Active Orders: ${activeOrders.length}');
    debugPrint('Today: $today');

    return _DashboardOrdersData(
      activeOrders: List<Map<String, dynamic>>.from(activeOrders),
      recentOrders: List<Map<String, dynamic>>.from(recentOrders),
    );
  }

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
      body: FutureBuilder<_DashboardOrdersData>(
        future: _dashboardOrdersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to load orders',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final dashboardOrders =
              snapshot.data ??
              const _DashboardOrdersData(activeOrders: [], recentOrders: []);
          final activeOrders = dashboardOrders.activeOrders;
          final recentOrders = dashboardOrders.recentOrders;

          return RefreshIndicator(
            onRefresh: () async {
              _reloadDashboardOrders();
              await _dashboardOrdersFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                const _GreetingSection(),
                const SizedBox(height: 20),
                _OrderWaterCard(
                  onTap: () {
                    CustomerNavController.instance.goTo(1);
                  },
                ),
                const SizedBox(height: 28),
                const _SectionHeader(title: 'Active Orders'),
                const SizedBox(height: 12),
                _ActiveOrdersList(activeOrders: activeOrders),
                const SizedBox(height: 28),
                _RecentOrdersHeader(
                  onSeeAllTap: () {
                    CustomerNavController.instance.goTo(2);
                  },
                ),
                const SizedBox(height: 12),
                _RecentOrdersList(recentOrders: recentOrders),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardOrdersData {
  const _DashboardOrdersData({
    required this.activeOrders,
    required this.recentOrders,
  });

  final List<Map<String, dynamic>> activeOrders;
  final List<Map<String, dynamic>> recentOrders;
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    final customerName = CustomerSession.name ?? 'Customer';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $customerName 👋',
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

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Map<String, dynamic> order;

  String _status() => '${order['status'] ?? ''}'.toLowerCase();

  String _statusLabel() {
    switch (_status()) {
      case 'pending':
        return 'Pending';
      case 'on_the_way':
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
      case 'on_the_way':
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
      case 'on_the_way':
        return const Color(0xFFDBEAFE);
      case 'preparing':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String _orderLabel() {
    final id = '${order['id'] ?? ''}';
    if (id.isEmpty) return 'Order';
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
  const _RecentOrderTile({required this.order});

  final Map<String, dynamic> order;

  String _orderLabel() {
    final id = '${order['id'] ?? ''}';
    if (id.isEmpty) return 'Order';
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
    if (parsed == null) return 'Unknown date';
    return '${_monthName(parsed.month)} ${parsed.day}';
  }

  String _status() => '${order['status'] ?? ''}'.toLowerCase();

  String _statusLabel() {
    switch (_status()) {
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'on_the_way':
        return 'On the Way';
      case 'pending':
        return 'Pending';
      default:
        return '${order['status'] ?? 'Unknown'}';
    }
  }

  Color _statusColor() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFEA580C);
      case 'on_the_way':
        return const Color(0xFF2563EB);
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBgColor() {
    switch (_status()) {
      case 'pending':
        return const Color(0xFFFFEDD5);
      case 'on_the_way':
        return const Color(0xFFDBEAFE);
      case 'delivered':
      case 'completed':
        return const Color(0xFFDCFCE7);
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
