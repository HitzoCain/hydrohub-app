import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/track_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = Color(0xFFF6F8FB);

  int _selectedFilterIndex = 0;

  static const List<String> _filters = ['All', 'Active', 'Completed'];

  static const List<_OrderItemData> _orders = [
    _OrderItemData(
      orderId: 'Order #001',
      gallons: '5 Gallons',
      price: '₱250',
      status: 'Delivered',
    ),
    _OrderItemData(
      orderId: 'Order #002',
      gallons: '3 Gallons',
      price: '₱180',
      status: 'On the way',
    ),
    _OrderItemData(
      orderId: 'Order #003',
      gallons: '6 Gallons',
      price: '₱320',
      status: 'Pending',
    ),
  ];

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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
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
    required this.gallons,
    required this.price,
    required this.status,
  });

  final String orderId;
  final String gallons;
  final String price;
  final String status;
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

  int _stepFromStatus() {
    switch (order.status) {
      case 'Pending':
        return 1;
      case 'On the way':
        return 2;
      case 'Delivered':
        return 3;
      default:
        return 0;
    }
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
                  status: order.status,
                  currentStep: _stepFromStatus(),
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
