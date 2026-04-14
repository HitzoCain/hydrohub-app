import 'package:flutter/material.dart';

import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_order_details_screen.dart';
import 'driver_profile_screen.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  int _selectedFilterIndex = 0;

  static const List<String> _filters = ['Active', 'Completed'];

  static const List<_DeliveryItemData> _deliveries = [
    _DeliveryItemData(
      orderId: 'Order #001',
      customerName: 'Juan Dela Cruz',
      address: 'Blk 8 Lot 12, Quezon City',
      gallons: 5,
      status: _DeliveryStatus.delivering,
    ),
    _DeliveryItemData(
      orderId: 'Order #004',
      customerName: 'Maria Santos',
      address: 'P. Burgos St, Makati City',
      gallons: 3,
      status: _DeliveryStatus.completed,
    ),
  ];

  List<_DeliveryItemData> get _filteredDeliveries {
    final selectedStatus = _selectedFilterIndex == 0
        ? _DeliveryStatus.delivering
        : _DeliveryStatus.completed;
    return _deliveries
        .where((delivery) => delivery.status == selectedStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'My Deliveries',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _FilterTabs(
                filters: _filters,
                selectedIndex: _selectedFilterIndex,
                onSelected: (index) {
                  setState(() {
                    _selectedFilterIndex = index;
                  });
                },
              ),
            ),
            Expanded(
              child: _filteredDeliveries.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _filteredDeliveries.length,
                      itemBuilder: (context, index) {
                        final delivery = _filteredDeliveries[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == _filteredDeliveries.length - 1 ? 0 : 12,
                          ),
                          child: _DeliveryCard(
                            delivery: delivery,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => DriverOrderDetailsScreen(
                                    orderId: delivery.orderId,
                                    status: delivery.status.label,
                                    customerName: delivery.customerName,
                                    contactNumber: '+63 912 345 6789',
                                    deliveryAddress: delivery.address,
                                    totalGallons: delivery.gallons,
                                    exchangeContainers: 3,
                                    newContainers: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
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
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List<Widget>.generate(filters.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < filters.length - 1 ? 8 : 0,
              ),
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x142563EB),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filters[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF1E3A8A)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onTap,
  });

  final _DeliveryItemData delivery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _statusTheme(delivery.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12233455),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${delivery.gallons} Gallons',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      delivery.orderId,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12233455),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              color: Color(0xFF94A3B8),
              size: 42,
            ),
            SizedBox(height: 10),
            Text(
              'No assigned deliveries yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryItemData {
  const _DeliveryItemData({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.gallons,
    required this.status,
  });

  final String orderId;
  final String customerName;
  final String address;
  final int gallons;
  final _DeliveryStatus status;
}

class _StatusTheme {
  const _StatusTheme({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}

enum _DeliveryStatus {
  delivering('Delivering'),
  completed('Completed');

  const _DeliveryStatus(this.label);
  final String label;
}

_StatusTheme _statusTheme(_DeliveryStatus status) {
  switch (status) {
    case _DeliveryStatus.delivering:
      return const _StatusTheme(
        foreground: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case _DeliveryStatus.completed:
      return const _StatusTheme(
        foreground: Color(0xFF15803D),
        background: Color(0xFFDCFCE7),
      );
  }
}
