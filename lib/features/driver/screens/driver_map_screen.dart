import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'driver_dashboard_screen.dart';
import 'driver_order_details_screen.dart';
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
  static const LatLng _driverLocation = LatLng(14.5995, 120.9842);

  static const List<DeliveryLocationData> _customers = [
    DeliveryLocationData(
      customerName: 'Juan Dela Cruz',
      orderId: 'Order #001',
      address: 'Blk 8 Lot 12, Quezon City',
      status: DeliveryStatus.onTheWay,
      location: LatLng(14.6095, 120.9892),
    ),
    DeliveryLocationData(
      customerName: 'Maria Santos',
      orderId: 'Order #002',
      address: 'P. Burgos St, Makati City',
      status: DeliveryStatus.assigned,
      location: LatLng(14.5895, 120.9792),
    ),
    DeliveryLocationData(
      customerName: 'Pedro Reyes',
      orderId: 'Order #003',
      address: 'C. Raymundo Ave, Pasig City',
      status: DeliveryStatus.onTheWay,
      location: LatLng(14.6032, 120.9968),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = _customers
        .where(
          (delivery) =>
              delivery.status == DeliveryStatus.assigned ||
              delivery.status == DeliveryStatus.onTheWay,
        )
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
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: _driverLocation,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aquaenlavada.app',
                  ),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _TopInfoCard(activeCount: activeCount),
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

  List<Marker> _buildMarkers() {
    final customerMarkers = _customers.map((delivery) {
      return Marker(
        point: delivery.location,
        width: 128,
        height: 66,
        child: GestureDetector(
          onTap: () => _showDeliverySheet(delivery),
          child: DeliveryMarker(
            label: delivery.orderId,
            icon: Icons.location_on,
            iconColor: Colors.red,
          ),
        ),
      );
    });

    return [
      const Marker(
        point: _driverLocation,
        width: 90,
        height: 62,
        child: DeliveryMarker(
          label: 'Driver',
          icon: Icons.delivery_dining,
          iconColor: _primaryBlue,
        ),
      ),
      ...customerMarkers,
    ];
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
                    child: const Icon(Icons.location_on, color: _primaryBlue),
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
                    Navigator.push(
                      this.context,
                      MaterialPageRoute<void>(
                        builder: (context) => DriverOrderDetailsScreen(
                          customerName: delivery.customerName,
                          orderId: delivery.orderId,
                          address: delivery.address,
                          status: delivery.status.value,
                        ),
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
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Icon(icon, size: 34, color: iconColor),
      ],
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
  const _InfoRow({required this.label, required this.value});

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
    required this.location,
  });

  final String customerName;
  final String orderId;
  final String address;
  final DeliveryStatus status;
  final LatLng location;
}

class _StatusTheme {
  const _StatusTheme({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

enum DeliveryStatus {
  assigned('assigned', 'Assigned'),
  onTheWay('on_the_way', 'On the way');

  const DeliveryStatus(this.value, this.label);
  final String value;
  final String label;
}

_StatusTheme _statusTheme(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.onTheWay:
      return const _StatusTheme(
        foreground: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case DeliveryStatus.assigned:
      return const _StatusTheme(
        foreground: Color(0xFFB45309),
        background: Color(0xFFFEF3C7),
      );
  }
}
