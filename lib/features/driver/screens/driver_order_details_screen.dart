import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverOrderDetailsScreen extends StatelessWidget {
  const DriverOrderDetailsScreen({
    super.key,
    this.customerName = 'Juan Dela Cruz',
    this.orderId = 'Order #001',
    this.address = 'Blk 8 Lot 12, Quezon City, Metro Manila',
    this.status = 'Pending',
    this.contactNumber = '+63 912 345 6789',
    this.totalGallons = 5,
    this.exchangeContainers = 3,
    this.newContainers = 2,
  });

  final String customerName;
  final String orderId;
  final String address;
  final String status;
  final String contactNumber;
  final int totalGallons;
  final int exchangeContainers;
  final int newContainers;

  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _successGreen = Color(0xFF16A34A);
  static const LatLng _customerLocation = LatLng(14.5995, 120.9842);
  static const LatLng _driverLocation = LatLng(14.5920, 120.9785);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Order Details',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Order ID', value: orderId),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Status',
                      value: status,
                      valueColor: _statusColor(status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Customer Name', value: customerName),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Contact Number', value: contactNumber),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Delivery Address', value: address),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'Total Gallons',
                      value: '$totalGallons Gallons',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Exchange Containers',
                      value: '$exchangeContainers',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'New Containers', value: '$newContainers'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Map Section',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                      const Text(
                        'Customer Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: FlutterMap(
                            options: const MapOptions(
                              initialCenter: _customerLocation,
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.aquaenlavada.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _customerLocation,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                  Marker(
                                    point: _driverLocation,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.delivery_dining,
                                      color: Color(0xFF2563EB),
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text(
                    'Open in Maps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryBlue,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Start Delivery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Mark as Delivered',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverMapScreen(),
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

  static Color _statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'delivering':
        return const Color(0xFF1D4ED8);
      case 'delivered':
        return const Color(0xFF15803D);
      case 'pending':
      default:
        return const Color(0xFFB45309);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
