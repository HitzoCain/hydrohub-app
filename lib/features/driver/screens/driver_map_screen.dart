import 'dart:async';

import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const LatLng _fallbackDriverLocation = LatLng(14.5995, 120.9842);

  Future<_DriverMapData> _driverMapFuture = Future<_DriverMapData>.value(
    const _DriverMapData(
      deliveries: <DeliveryLocationData>[],
      driverLocation: _fallbackDriverLocation,
    ),
  );

  LatLng? _selectedCustomerLocation;
  LatLng _driverLocation = _fallbackDriverLocation;
  StreamSubscription<Position>? _positionSubscription;
  bool _isCustomerChooserExpanded = true;

  @override
  void initState() {
    super.initState();
    _startDriverLocationTracking();
    _driverMapFuture = _loadDriverMapData();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startDriverLocationTracking() async {
    await _refreshDriverLocation();

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return;
      }
    } else if (permission == LocationPermission.deniedForever) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() {
            _driverLocation = LatLng(position.latitude, position.longitude);
          });
        });
  }

  Future<void> _refreshDriverLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Failed to get live driver location: $e');
    }
  }

  void _reloadData() {
    setState(() {
      _driverMapFuture = _loadDriverMapData();
    });
  }

  Future<_DriverMapData> _loadDriverMapData() async {
    final driverIds = await _currentDriverIds();
    if (driverIds.isEmpty) {
      return const _DriverMapData(
        deliveries: <DeliveryLocationData>[],
        driverLocation: _fallbackDriverLocation,
      );
    }

    final deliveries = await _fetchAssignedDeliveries(driverIds);
    final driverLocation = _driverLocation;

    final sortedDeliveries = List<DeliveryLocationData>.from(deliveries)
      ..sort((a, b) {
        final aDistance = Geolocator.distanceBetween(
          driverLocation.latitude,
          driverLocation.longitude,
          a.location.latitude,
          a.location.longitude,
        );
        final bDistance = Geolocator.distanceBetween(
          driverLocation.latitude,
          driverLocation.longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return aDistance.compareTo(bDistance);
      });

    return _DriverMapData(
      deliveries: sortedDeliveries,
      driverLocation: driverLocation,
    );
  }

  Future<List<String>> _currentDriverIds() async {
    final ids = <String>{};

    final sessionId = await DriverSession.getDriverId();
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      ids.add(sessionId.trim());
    }

    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    if (authUserId != null && authUserId.trim().isNotEmpty) {
      ids.add(authUserId.trim());
    }

    return ids.toList(growable: false);
  }

  Future<List<DeliveryLocationData>> _fetchAssignedDeliveries(
    List<String> driverIds,
  ) async {
    final response = driverIds.length == 1
        ? await Supabase.instance.client
              .from('orders')
              .select()
              .eq('driver_id', driverIds.first)
              .inFilter('status', ['assigned', 'in_progress', 'on_the_way'])
              .order('created_at', ascending: false)
        : await Supabase.instance.client
              .from('orders')
              .select()
              .inFilter('driver_id', driverIds)
              .inFilter('status', ['assigned', 'in_progress', 'on_the_way'])
              .order('created_at', ascending: false);

    final orders = response.whereType<Map<String, dynamic>>().toList();
    final customerAvatarUrls = await _fetchCustomerAvatarUrls(orders);
    final deliveries = <DeliveryLocationData>[];

    for (final order in orders) {
      final customerId = order['customer_id']?.toString().trim() ?? '';
      final delivery = await _mapOrderToDelivery(
        order,
        avatarUrl: customerAvatarUrls[customerId] ?? '',
      );
      if (delivery != null) {
        deliveries.add(delivery);
      }
    }

    return deliveries;
  }

  Future<Map<String, String>> _fetchCustomerAvatarUrls(
    List<Map<String, dynamic>> orders,
  ) async {
    final customerIds = orders
        .map((order) => order['customer_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (customerIds.isEmpty) return {};

    try {
      final profiles = await Supabase.instance.client
          .from('customer_profiles')
          .select('user_id, avatar_url')
          .inFilter('user_id', customerIds);
      final avatarUrls = <String, String>{};
      for (final profile in profiles.whereType<Map<String, dynamic>>()) {
        final userId = profile['user_id']?.toString().trim() ?? '';
        final avatarUrl = profile['avatar_url']?.toString().trim() ?? '';
        if (userId.isNotEmpty && avatarUrl.isNotEmpty) {
          avatarUrls[userId] = avatarUrl;
        }
      }
      return avatarUrls;
    } catch (error) {
      debugPrint('Failed to load map customer photos: $error');
      return {};
    }
  }

  Future<DeliveryLocationData?> _mapOrderToDelivery(
    Map<String, dynamic> order, {
    required String avatarUrl,
  }) async {
    final coordinates = await _resolveCustomerLocation(order);
    if (coordinates == null) {
      return null;
    }

    final status = _deliveryStatusFromOrder(order['status']);

    return DeliveryLocationData(
      customerName: _textOf(order['customer_name'], fallback: 'Customer'),
      orderId: _orderLabel(order['id']),
      avatarUrl: avatarUrl,
      address: _resolvedAddress(order),
      productName: _textOf(order['product_name'], fallback: 'Water'),
      size: _textOf(
        order['capacity'] ?? order['size'],
        fallback: 'Size unavailable',
      ),
      containers: _textOf(
        order['gallons'] ?? order['container_count'],
        fallback: '0',
      ),
      status: status,
      location: coordinates,
      rawOrder: Map<String, dynamic>.from(order),
    );
  }

  Future<LatLng?> _resolveCustomerLocation(Map<String, dynamic> order) async {
    final lat =
        _toDouble(order['customer_lat']) ??
        _toDouble(order['latitude']) ??
        _toDouble(order['lat']) ??
        _toDouble(order['address_lat']) ??
        _toDouble(order['address_latitude']);
    final lng =
        _toDouble(order['customer_lng']) ??
        _toDouble(order['longitude']) ??
        _toDouble(order['lng']) ??
        _toDouble(order['address_lng']) ??
        _toDouble(order['address_longitude']);

    if (_isValidLatLng(lat, lng)) {
      return LatLng(lat!, lng!);
    }

    final addressId = _textOf(order['address_id'], fallback: '');
    if (addressId.isNotEmpty) {
      try {
        final addressResponse = await Supabase.instance.client
            .from('user_addresses')
            .select()
            .eq('id', addressId)
            .maybeSingle();

        if (addressResponse != null) {
          final addressData = Map<String, dynamic>.from(addressResponse);
          final addressLat =
              _toDouble(addressData['latitude']) ??
              _toDouble(addressData['lat']);
          final addressLng =
              _toDouble(addressData['longitude']) ??
              _toDouble(addressData['lng']);
          if (_isValidLatLng(addressLat, addressLng)) {
            return LatLng(addressLat!, addressLng!);
          }
        }
      } catch (e) {
        debugPrint('Map address fallback failed: $e');
      }
    }

    return null;
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _textOf(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return text;
  }

  String _orderLabel(dynamic value) {
    final id = _textOf(value, fallback: '');
    if (id.isEmpty) return 'Order';
    final short = id.length > 8 ? id.substring(0, 8) : id;
    return 'Order #$short';
  }

  String _resolvedAddress(Map<String, dynamic> order) {
    final addressText = _textOf(order['address_text'], fallback: '');
    if (addressText.isNotEmpty) return addressText;

    final address = _textOf(order['address'], fallback: '');
    if (address.isNotEmpty) return address;

    final lat =
        _toDouble(order['customer_lat']) ?? _toDouble(order['latitude']);
    final lng =
        _toDouble(order['customer_lng']) ?? _toDouble(order['longitude']);
    if (_isValidLatLng(lat, lng)) {
      return 'Lat: ${lat!.toStringAsFixed(6)}, Lng: ${lng!.toStringAsFixed(6)}';
    }

    return 'No address provided';
  }

  DeliveryStatus _deliveryStatusFromOrder(dynamic status) {
    final normalized = _textOf(status, fallback: 'assigned').toLowerCase();
    if (normalized == 'in_progress' || normalized == 'on_the_way') {
      return DeliveryStatus.onTheWay;
    }
    return DeliveryStatus.assigned;
  }

  @override
  Widget build(BuildContext context) {
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
        child: FutureBuilder<_DriverMapData>(
          future: _driverMapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load delivery map',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }

            final mapData =
                snapshot.data ??
                const _DriverMapData(
                  deliveries: <DeliveryLocationData>[],
                  driverLocation: _fallbackDriverLocation,
                );

            final activeCount = mapData.deliveries.length;
            final centerLocation =
                _selectedCustomerLocation ??
                (mapData.deliveries.isNotEmpty
                    ? mapData.deliveries.first.location
                    : mapData.driverLocation);

            return RefreshIndicator(
              onRefresh: () async => _reloadData(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: centerLocation,
                        initialZoom: mapData.deliveries.isEmpty ? 13 : 12.5,
                        onTap: (_, __) {
                          setState(() {
                            _selectedCustomerLocation = null;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.aquaenlavada.app',
                        ),
                        MarkerLayer(
                          markers: _buildMarkers(mapData, _driverLocation),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _TopInfoCard(activeCount: activeCount),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _CustomerChooserSheet(
                      deliveries: mapData.deliveries,
                      isExpanded: _isCustomerChooserExpanded,
                      onToggle: () {
                        setState(() {
                          _isCustomerChooserExpanded =
                              !_isCustomerChooserExpanded;
                        });
                      },
                      onPick: (delivery) {
                        setState(() {
                          _selectedCustomerLocation = delivery.location;
                        });
                        _showDeliverySheet(delivery);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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

  List<Marker> _buildMarkers(_DriverMapData mapData, LatLng driverLocation) {
    final customerMarkers = mapData.deliveries.map((delivery) {
      return Marker(
        point: delivery.location,
        width: 152,
        height: 76,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedCustomerLocation = delivery.location;
            });
            _showDeliverySheet(delivery);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 132),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  delivery.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Icon(
                Icons.location_on_rounded,
                size: 42,
                color: Color(0xFFDC2626),
              ),
            ],
          ),
        ),
      );
    });

    return [
      Marker(
        point: driverLocation,
        width: 90,
        height: 62,
        child: const DeliveryMarker(
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final statusTheme = _statusTheme(delivery.status);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _CustomerAvatar(
                      imageUrl: delivery.avatarUrl,
                      size: 58,
                      borderColor: const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
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
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: _primaryBlue,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delivery.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              delivery.size,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            delivery.containers,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                          const Text(
                            'Containers',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DELIVERY ADDRESS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _primaryBlue,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        delivery.address,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                            initialOrder: delivery.rawOrder,
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
    this.avatarUrl,
    this.isSelected = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final String? avatarUrl;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF1D4ED8) : Colors.transparent,
              width: 1,
            ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (avatarUrl != null)
          _CustomerAvatar(
            imageUrl: avatarUrl!,
            size: 48,
            borderColor: isSelected ? const Color(0xFF1D4ED8) : Colors.white,
          )
        else
          Icon(icon, size: 34, color: iconColor),
      ],
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({
    required this.imageUrl,
    required this.size,
    this.borderColor = Colors.white,
  });

  final String imageUrl;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: imageUrl.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: size * 0.52,
              color: const Color(0xFF2563EB),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_rounded,
                size: size * 0.52,
                color: const Color(0xFF2563EB),
              ),
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

class _CustomerChooserSheet extends StatelessWidget {
  const _CustomerChooserSheet({
    required this.deliveries,
    required this.isExpanded,
    required this.onToggle,
    required this.onPick,
  });

  final List<DeliveryLocationData> deliveries;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<DeliveryLocationData> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14233455),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deliveries.isEmpty
                      ? 'Customer locations'
                      : 'Choose a nearby customer',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${deliveries.length}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: isExpanded ? 'Hide customers' : 'Show customers',
                onPressed: onToggle,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
            ],
          ),
          if (isExpanded && deliveries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'No assigned customer locations found yet.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (isExpanded && deliveries.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: deliveries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final delivery = deliveries[index];
                  return GestureDetector(
                    onTap: () => onPick(delivery),
                    child: Container(
                      width: 196,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _CustomerAvatar(
                                imageUrl: delivery.avatarUrl,
                                size: 34,
                                borderColor: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  delivery.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            delivery.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${delivery.size} · ${delivery.containers} containers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DeliveryLocationData {
  const DeliveryLocationData({
    required this.customerName,
    required this.orderId,
    required this.avatarUrl,
    required this.address,
    required this.productName,
    required this.size,
    required this.containers,
    required this.status,
    required this.location,
    required this.rawOrder,
  });

  final String customerName;
  final String orderId;
  final String avatarUrl;
  final String address;
  final String productName;
  final String size;
  final String containers;
  final DeliveryStatus status;
  final LatLng location;
  final Map<String, dynamic> rawOrder;
}

class _DriverMapData {
  const _DriverMapData({
    required this.deliveries,
    required this.driverLocation,
  });

  final List<DeliveryLocationData> deliveries;
  final LatLng driverLocation;
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
