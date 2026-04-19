import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';

import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';
import 'driver_messages_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverOrderDetailsScreen extends StatefulWidget {
  const DriverOrderDetailsScreen({
    super.key,
    this.customerName = 'Juan Dela Cruz',
    this.orderId = 'Order #001',
    this.address = 'Blk 8 Lot 12, Quezon City, Metro Manila',
    this.status = 'Pending',
    this.contactNumber = '+63 912 345 6789',
    this.totalGallons = 5,
    this.exchangeContainers = 0,
    this.newContainers = 0,
    this.initialOrder,
    this.onOrderCompleted,
  });

  final String customerName;
  final String orderId;
  final String address;
  final String status;
  final String contactNumber;
  final int totalGallons;
  final int exchangeContainers;
  final int newContainers;
  final Map<String, dynamic>? initialOrder;
  final VoidCallback? onOrderCompleted;

  @override
  State<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _successGreen = Color(0xFF16A34A);
  static const LatLng _fallbackCustomerLocation = LatLng(14.5995, 120.9842);
  static const LatLng _fallbackDriverLocation = LatLng(14.5920, 120.9785);

  bool _isLoading = false;
  bool _isLoadingOrder = false;
  late String _currentStatus;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder == null
        ? null
        : Map<String, dynamic>.from(widget.initialOrder!);
    _currentStatus = _normalizeStatus(
      _textOf(_order?['status'], fallback: widget.status),
    );
    _loadOrderDetails();
  }

  String get _rawOrderId {
    final idFromOrder = _textOf(_order?['id'], fallback: '');
    if (idFromOrder.isNotEmpty) {
      return idFromOrder;
    }
    return widget.orderId.replaceFirst('Order #', '').trim();
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _isValidLatLng(double lat, double lng) {
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    // Treat (0,0) as invalid fallback data for this app.
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  List<double?> _extractCustomerCoordinates(Map<String, dynamic> source) {
    final lat = _toDouble(source['customer_lat']) ??
        _toDouble(source['latitude']) ??
        _toDouble(source['lat']) ??
        _toDouble(source['address_lat']) ??
        _toDouble(source['address_latitude']);
    final lng = _toDouble(source['customer_lng']) ??
        _toDouble(source['longitude']) ??
        _toDouble(source['lng']) ??
        _toDouble(source['address_lng']) ??
        _toDouble(source['address_longitude']);
    return [lat, lng];
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'json',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'HydroHub App (support@hydrohub.local)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return null;
      }

      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final lat = _toDouble(first['lat']);
      final lng = _toDouble(first['lon']);
      if (lat == null || lng == null || !_isValidLatLng(lat, lng)) {
        return null;
      }

      return LatLng(lat, lng);
    } catch (e) {
      debugPrint('Address geocoding failed: $e');
      return null;
    }
  }

  String _textOf(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return text;
  }

  Future<void> _loadOrderDetails() async {
    if (_rawOrderId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingOrder = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', _rawOrderId)
          .maybeSingle();

      if (!mounted || response == null) {
        return;
      }

      final orderData = Map<String, dynamic>.from(response);
      final extractedCoords = _extractCustomerCoordinates(orderData);
      final extractedLat = extractedCoords[0];
      final extractedLng = extractedCoords[1];

      final addressText = _textOf(orderData['address_text'], fallback: '');
      final addressValue = _textOf(orderData['address'], fallback: '');
      final hasAddressText = addressText.isNotEmpty || addressValue.isNotEmpty;

      if (extractedLat == null ||
          extractedLng == null ||
          !_isValidLatLng(extractedLat, extractedLng) ||
          !hasAddressText) {
        final addressId = _textOf(orderData['address_id'], fallback: '');
        if (addressId.isNotEmpty) {
          try {
            final addressResponse = await Supabase.instance.client
                .from('user_addresses')
                .select()
                .eq('id', addressId)
                .maybeSingle();

            if (addressResponse != null) {
              final addressData = Map<String, dynamic>.from(addressResponse);
              final addrLat = _toDouble(addressData['latitude']) ??
                  _toDouble(addressData['lat']);
              final addrLng = _toDouble(addressData['longitude']) ??
                  _toDouble(addressData['lng']);

              if (addrLat != null &&
                  addrLng != null &&
                  _isValidLatLng(addrLat, addrLng)) {
                orderData['customer_lat'] = addrLat;
                orderData['customer_lng'] = addrLng;
                orderData['latitude'] = addrLat;
                orderData['longitude'] = addrLng;
              }

              if (!hasAddressText) {
                final addressFromAddressBook = _textOf(
                  addressData['address_text'],
                  fallback: '',
                );
                final plainAddressFromAddressBook = _textOf(
                  addressData['address'],
                  fallback: '',
                );

                if (addressFromAddressBook.isNotEmpty) {
                  orderData['address_text'] = addressFromAddressBook;
                } else if (plainAddressFromAddressBook.isNotEmpty) {
                  orderData['address'] = plainAddressFromAddressBook;
                }
              }
            }
          } catch (e) {
            debugPrint('Address lookup fallback failed: $e');
          }
        }
      }

      final updatedCoords = _extractCustomerCoordinates(orderData);
      final updatedLat = updatedCoords[0];
      final updatedLng = updatedCoords[1];
      final hasValidCoordinates =
          updatedLat != null &&
          updatedLng != null &&
          _isValidLatLng(updatedLat, updatedLng);

      if (!hasValidCoordinates) {
        final geocodeAddress = _textOf(
          orderData['address_text'],
          fallback: _textOf(orderData['address'], fallback: widget.address),
        );

        final geocoded = await _geocodeAddress(geocodeAddress);
        if (geocoded != null) {
          orderData['customer_lat'] = geocoded.latitude;
          orderData['customer_lng'] = geocoded.longitude;
          orderData['latitude'] = geocoded.latitude;
          orderData['longitude'] = geocoded.longitude;
        }
      }

      setState(() {
        _order = orderData;
        _currentStatus = _normalizeStatus(
          _textOf(_order?['status'], fallback: _currentStatus),
        );
      });
    } catch (e) {
      debugPrint('Failed to load order details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrder = false;
        });
      }
    }
  }

  String _resolvedCustomerName() {
    return _textOf(
      _order?['customer_name'],
      fallback: widget.customerName,
    );
  }

  String _resolvedContactNumber() {
    final fromOrder = _textOf(_order?['customer_phone'], fallback: '');
    if (fromOrder.isNotEmpty) {
      return fromOrder;
    }
    return _textOf(widget.contactNumber, fallback: 'Not provided');
  }

  String _resolvedAddress() {
    final addressText = _textOf(_order?['address_text'], fallback: '');
    if (addressText.isNotEmpty) {
      return addressText;
    }
    return _textOf(_order?['address'], fallback: widget.address);
  }

  int _resolvedTotalGallons() {
    return _toInt(_order?['gallons'], fallback: widget.totalGallons);
  }

  int _resolvedExchangeContainers() {
    final total = _resolvedTotalGallons();
    final hasExchangeRaw = _order?['with_exchange'];
    if (hasExchangeRaw is bool && !hasExchangeRaw) {
      return 0;
    }

    final explicitExchange = _order?['exchange_containers'];
    if (explicitExchange == null) {
      return 0;
    }

    final exchange = _toInt(
      explicitExchange,
      fallback: 0,
    );
    if (exchange < 0) return 0;
    if (exchange > total) return total;
    return exchange;
  }

  int _resolvedNewContainers() {
    final total = _resolvedTotalGallons();
    final explicit = _order?['new_containers'];
    if (explicit != null) {
      final parsed = _toInt(explicit, fallback: total);
      if (parsed < 0) return 0;
      return parsed;
    }

    final hasExchangeRaw = _order?['with_exchange'];
    if (hasExchangeRaw is bool && !hasExchangeRaw) {
      return total;
    }

    final inferred = total - _resolvedExchangeContainers();
    return inferred < 0 ? 0 : inferred;
  }

  LatLng _resolvedCustomerLocation() {
    final source = _order ?? const <String, dynamic>{};
    final extractedCoords = _extractCustomerCoordinates(source);
    final lat = extractedCoords[0];
    final lng = extractedCoords[1];
    if (lat == null || lng == null || !_isValidLatLng(lat, lng)) {
      return _fallbackCustomerLocation;
    }
    return LatLng(lat, lng);
  }

  LatLng _resolvedDriverLocation() {
    final lat = _toDouble(_order?['driver_lat']);
    final lng = _toDouble(_order?['driver_lng']);
    if (lat == null || lng == null) {
      return _fallbackDriverLocation;
    }
    return LatLng(lat, lng);
  }

  bool _hasRealDriverLocation() {
    final lat = _toDouble(_order?['driver_lat']);
    final lng = _toDouble(_order?['driver_lng']);
    if (lat == null || lng == null) {
      return false;
    }
    return _isValidLatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final customerLocation = _resolvedCustomerLocation();
    final driverLocation = _resolvedDriverLocation();
    final hasDriverLocation = _hasRealDriverLocation();

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
                    _InfoRow(label: 'Order ID', value: widget.orderId),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Status',
                      value: _statusLabel(_currentStatus),
                      valueColor: _statusColor(_currentStatus),
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
                    _InfoRow(
                      label: 'Customer Name',
                      value: _resolvedCustomerName(),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Contact Number',
                      value: _resolvedContactNumber(),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Delivery Address', value: _resolvedAddress()),
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
                      value: '${_resolvedTotalGallons()} Gallons',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Exchange Containers',
                      value: '${_resolvedExchangeContainers()}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'New Containers',
                      value: '${_resolvedNewContainers()}',
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
                      'Map Section',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Customer Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        if (_isLoadingOrder) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: customerLocation,
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
                                  point: customerLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                                if (hasDriverLocation)
                                  Marker(
                                    point: driverLocation,
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              if (_currentStatus == 'assigned')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleStartDelivery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryBlue,
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Start Delivery',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              if (_currentStatus == 'in_progress')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCompleteDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Mark as Delivered',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
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
              MaterialPageRoute<void>(builder: (_) => const DriverMapScreen()),
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

  Future<void> _handleCompleteDelivery() async {
    final orderId = _rawOrderId;
    await _markDelivered(orderId);
  }

  Future<void> _handleStartDelivery() async {
    final orderId = _rawOrderId;
    await _startDelivery(orderId);
  }

  Future<void> _startDelivery(String orderId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final session = await DriverSession.load();
      final driverId = session?.id ?? DriverSession.id;

      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver ID not found');
      }

      final settings = await supabase
          .from('system_settings')
          .select('max_deliveries_per_driver')
          .limit(1)
          .maybeSingle();

      int maxDeliveries = 3;
      final maxRaw = settings?['max_deliveries_per_driver'];
      if (maxRaw is int) {
        maxDeliveries = maxRaw;
      } else if (maxRaw is num) {
        maxDeliveries = maxRaw.toInt();
      } else if (maxRaw is String) {
        maxDeliveries = int.tryParse(maxRaw) ?? maxDeliveries;
      }
      if (maxDeliveries < 1) {
        maxDeliveries = 1;
      }

      final inProgressOrders = await supabase
          .from('orders')
          .select('id')
          .eq('driver_id', driverId)
          .inFilter('status', ['in_progress', 'on_the_way']);

      if (inProgressOrders.length >= maxDeliveries) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot start new delivery. Max active deliveries reached ($maxDeliveries).',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Update order status to 'in_progress'
      await supabase
          .from('orders')
          .update({'status': 'in_progress'})
          .eq('id', orderId);

      if (!mounted) return;

      setState(() {
        _currentStatus = 'in_progress';
        _order = {
          ...?_order,
          'status': 'in_progress',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery started.'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting delivery: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _markDelivered(String orderId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get driver ID
      final session = await DriverSession.load();
      final driverId = session?.id ?? DriverSession.id;

      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver ID not found');
      }

      final supabase = Supabase.instance.client;

      // Update order status to 'delivered'
      await supabase
          .from('orders')
          .update({'status': 'delivered'})
          .eq('id', orderId);

      // Update driver status to 'active' (available)
      await supabase
          .from('employees')
          .update({'status': 'active'})
          .eq('id', driverId);

      if (!mounted) return;

      setState(() {
        _order = {
          ...?_order,
          'status': 'delivered',
        };
      });

      // Call the completion callback to refresh orders list
      widget.onOrderCompleted?.call();

      // Navigate back to orders list
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing delivery: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static Color _statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'in_progress':
      case 'on_the_way':
        return const Color(0xFF1D4ED8);
      case 'delivered':
        return const Color(0xFF15803D);
      case 'assigned':
      case 'pending':
      default:
        return const Color(0xFFB45309);
    }
  }

  static String _statusLabel(String value) {
    switch (value.toLowerCase()) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In progress';
      case 'on_the_way':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      default:
        return value;
    }
  }

  static String _normalizeStatus(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'assigned' ||
        normalized == 'in_progress' ||
        normalized == 'on_the_way' ||
        normalized == 'delivered') {
      return normalized == 'on_the_way' ? 'in_progress' : normalized;
    }
    if (normalized == 'delivering') return 'in_progress';
    if (normalized == 'pending') return 'assigned';
    return 'assigned';
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
