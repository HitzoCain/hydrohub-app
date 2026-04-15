import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const String _currentUserId = 'customer_1';

  int _selectedFilterIndex = 0;

  static const List<String> _filters = ['All', 'Active', 'Completed'];

  static final List<_OrderItemData> _orders = [
    _OrderItemData(
      orderId: 'Order #001',
      customerId: 'customer_1',
      gallons: '5 Gallons',
      price: '₱250',
      status: 'Delivered',
      deliveryType: 'now',
    ),
    _OrderItemData(
      orderId: 'Order #002',
      customerId: 'customer_2',
      gallons: '3 Gallons',
      price: '₱180',
      status: 'On the way',
      deliveryType: 'now',
    ),
    _OrderItemData(
      orderId: 'Order #003',
      customerId: 'customer_1',
      gallons: '6 Gallons',
      price: '₱320',
      status: 'Pending',
      deliveryType: 'scheduled',
      scheduledDate: DateTime(2026, 4, 20),
      scheduledTime: TimeOfDay(hour: 9, minute: 0),
    ),
    _OrderItemData(
      orderId: 'Order #004',
      customerId: 'customer_2',
      gallons: '4 Gallons',
      price: '₱220',
      status: 'Delivered',
      deliveryType: 'scheduled',
      scheduledDate: DateTime(2026, 4, 22),
      scheduledTime: TimeOfDay(hour: 14, minute: 30),
    ),
  ];

  List<_OrderItemData> get _visibleOrders {
    final userOrders = _orders
        .where((order) => order.customerId == _currentUserId)
        .toList();

    if (_selectedFilterIndex == 1) {
      return userOrders
          .where((order) => order.status != 'Delivered')
          .toList();
    }

    if (_selectedFilterIndex == 2) {
      return userOrders.where((order) => order.status == 'Delivered').toList();
    }

    return userOrders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
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
              child: _visibleOrders.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _visibleOrders.length,
                      itemBuilder: (context, index) {
                        final order = _visibleOrders[index];
                        return _OrderHistoryCard(order: order);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemData {
  const _OrderItemData({
    required this.orderId,
    required this.customerId,
    required this.gallons,
    required this.price,
    required this.status,
    required this.deliveryType,
    this.scheduledDate,
    this.scheduledTime,
  });

  final String orderId;
  final String customerId;
  final String gallons;
  final String price;
  final String status;
  final String deliveryType;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order});

  final _OrderItemData order;

  Color _statusColor() {
    switch (order.status) {
      case 'Delivered':
        return const Color(0xFF16A34A);
      case 'On the way':
        return const Color(0xFF2563EB);
      case 'Pending':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBackground() {
    switch (order.status) {
      case 'Delivered':
        return const Color(0xFFDCFCE7);
      case 'On the way':
        return const Color(0xFFDBEAFE);
      case 'Pending':
        return const Color(0xFFFFEDD5);
      default:
        return const Color(0xFFF1F5F9);
    }
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

  Color _deliveryTypeColor() {
    return order.deliveryType == 'scheduled'
        ? const Color(0xFF7C3AED)
        : const Color(0xFF0369A1);
  }

  Color _deliveryTypeBackground() {
    return order.deliveryType == 'scheduled'
        ? const Color(0xFFEDE9FE)
        : const Color(0xFFE0F2FE);
  }

  String _deliveryTypeLabel() {
    return order.deliveryType == 'scheduled' ? 'Scheduled' : 'On Demand';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TrackOrderScreen(
                  orderId: order.orderId,
                  totalGallons: int.tryParse(order.gallons.split(' ').first) ?? 1,
                  address: 'Home Address, Cebu City',
                  deliveryType: order.deliveryType,
                  status: order.status,
                  scheduledDate: order.scheduledDate,
                  scheduledTime: order.scheduledTime,
                ),
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
                        order.orderId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.gallons,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.price,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _deliveryTypeBackground(),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _deliveryTypeLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _deliveryTypeColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order.scheduledDate != null && order.scheduledTime != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${_formatDate(order.scheduledDate!)} • ${order.scheduledTime!.format(context)}',
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBackground(),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Text(
                          'Track',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
        child: const Text(
          'No orders yet',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
