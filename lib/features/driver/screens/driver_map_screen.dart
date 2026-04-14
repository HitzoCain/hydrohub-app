import 'package:flutter/material.dart';

import 'driver_dashboard_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  static const List<DeliveryLocationData> _deliveries = [
    DeliveryLocationData(
      customerName: 'Juan Dela Cruz',
      orderId: 'Order #001',
      address: 'Blk 8 Lot 12, Quezon City',
      status: DeliveryStatus.delivering,
      leftFactor: 0.18,
      topFactor: 0.30,
    ),
    DeliveryLocationData(
      customerName: 'Maria Santos',
      orderId: 'Order #002',
      address: 'P. Burgos St, Makati City',
      status: DeliveryStatus.pending,
      leftFactor: 0.62,
      topFactor: 0.48,
    ),
    DeliveryLocationData(
      customerName: 'Pedro Reyes',
      orderId: 'Order #003',
      address: 'C. Raymundo Ave, Pasig City',
      status: DeliveryStatus.delivering,
      leftFactor: 0.38,
      topFactor: 0.66,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = _deliveries
        .where((delivery) => delivery.status == DeliveryStatus.delivering)
        .length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Delivery Map',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFFEAF1FF),
                child: const Center(
                  child: Text(
                    'Map View (All Delivery Locations)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _TopInfoCard(activeCount: activeCount),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _deliveries.map((delivery) {
                      return Positioned(
                        left: constraints.maxWidth * delivery.leftFactor,
                        top: constraints.maxHeight * delivery.topFactor,
                        child: DeliveryMarker(
                          data: delivery,
                          onTap: () => _showDeliverySheet(delivery),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
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
          } else if (index == 1) {
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
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showDeliverySheet(DeliveryLocationData delivery) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final statusTheme = _statusTheme(delivery.status);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      delivery.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
              const SizedBox(height: 14),
              _InfoRow(label: 'Order ID', value: delivery.orderId),
              const SizedBox(height: 8),
              _InfoRow(label: 'Address', value: delivery.address),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Navigate to Order Details (UI only)'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'View Order Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DeliveryMarker extends StatelessWidget {
  const DeliveryMarker({
    super.key,
    required this.data,
    required this.onTap,
  });

  final DeliveryLocationData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDelivering = data.status == DeliveryStatus.delivering;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14233455),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              data.orderId,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: isDelivering ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                size: 28,
              ),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  data.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopInfoCard extends StatelessWidget {
  const _TopInfoCard({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14233455),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 16,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$activeCount Active Deliveries Today',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class DeliveryLocationData {
  const DeliveryLocationData({
    required this.customerName,
    required this.orderId,
    required this.address,
    required this.status,
    required this.leftFactor,
    required this.topFactor,
  });

  final String customerName;
  final String orderId;
  final String address;
  final DeliveryStatus status;
  final double leftFactor;
  final double topFactor;
}

class _StatusTheme {
  const _StatusTheme({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}

enum DeliveryStatus {
  delivering('Delivering'),
  pending('Pending');

  const DeliveryStatus(this.label);
  final String label;
}

_StatusTheme _statusTheme(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.delivering:
      return const _StatusTheme(
        foreground: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case DeliveryStatus.pending:
      return const _StatusTheme(
        foreground: Color(0xFFB45309),
        background: Color(0xFFFEF3C7),
      );
  }
}
