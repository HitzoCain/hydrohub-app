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

  final TextEditingController _returnedController =
      TextEditingController(text: '0');
  final TextEditingController _damagedController =
      TextEditingController(text: '0');
  final TextEditingController _missingController =
      TextEditingController(text: '0');

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

  @override
  void dispose() {
    _returnedController.dispose();
    _damagedController.dispose();
    _missingController.dispose();
    super.dispose();
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

      // Compatibility for older orders created before the customer app
      // started saving the actual exchange/new-container counts.
      // If the order says exchange was selected but has no count fields,
      // treat the ordered quantity as exchange and zero as new containers.
      // New orders always have the explicit fields, so their exact selection
      // is preserved.
      final totalGallons = _toInt(orderData['gallons'], fallback: widget.totalGallons);
      final hasExchangeCount = orderData.containsKey('exchange_containers') &&
          orderData['exchange_containers'] != null;
      final hasNewContainerCount = orderData.containsKey('new_containers') &&
          orderData['new_containers'] != null;

      if (!hasExchangeCount && !hasNewContainerCount &&
          _hasTrueValue(orderData['exchange_required']) && totalGallons > 0) {
        orderData['exchange_containers'] = totalGallons;
        orderData['new_containers'] = 0;
        orderData['with_exchange'] = true;
      }

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

        if (_isExchangeOrder(orderData)) {
          // Start the driver's actual return inputs at zero.
          // The driver must account for every expected container as
          // returned, damaged, or missing before completing the order.
          _returnedController.text = '0';
          _damagedController.text = '0';
          _missingController.text = '0';
        }
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

    // The customer's selected quantity is the source of truth.
    final explicitExchange = _order?['exchange_containers'];
    if (explicitExchange != null) {
      final exchange = _toInt(explicitExchange, fallback: 0);
      if (exchange > 0) {
        return exchange.clamp(0, total).toInt();
      }

      // Some older/newer records may contain `exchange_containers = 0`
      // together with `with_exchange = true`. In that case the boolean
      // explicitly says the customer selected exchange.
      if (_toBool(_order?['with_exchange'])) {
        return total;
      }

      return 0;
    }

    // Compatibility with orders created before exchange_containers was saved.
    final newContainers = _order?['new_containers'];
    if (newContainers != null) {
      final newQuantity = _toInt(newContainers, fallback: total);
      final inferred = total - newQuantity;
      return inferred.clamp(0, total).toInt();
    }

    // Compatibility with orders that only saved the customer's boolean.
    if (_toBool(_order?['with_exchange'])) {
      return total;
    }

    // Legacy orders used exchange_required as the actual selected exchange
    // flag. Use it only as the final fallback when the newer fields are absent.
    if (_hasTrueValue(_order?['exchange_required'])) {
      return total;
    }

    return 0;
  }

  int _resolvedNewContainers() {
    final total = _resolvedTotalGallons();

    final explicit = _order?['new_containers'];
    if (explicit != null) {
      final parsed = _toInt(explicit, fallback: 0);
      return parsed.clamp(0, total).toInt();
    }

    final exchange = _resolvedExchangeContainers();
    return (total - exchange).clamp(0, total).toInt();
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  bool _hasTrueValue(dynamic value) => _toBool(value);

  String _resolvedTotalPayment() {
    final totalPrice = _order?['total_price'];
    if (totalPrice is num) {
      return '₱${totalPrice.toStringAsFixed(0)}';
    }
    if (totalPrice is String) {
      final parsed = num.tryParse(totalPrice);
      if (parsed != null) {
        return '₱${parsed.toStringAsFixed(0)}';
      }
      if (totalPrice.trim().isNotEmpty) {
        return totalPrice.trim();
      }
    }

    return 'Not available';
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

  bool _isExchangeOrder([Map<String, dynamic>? source]) {
    final order = source ?? _order ?? const <String, dynamic>{};
    final total = _toInt(order['gallons'], fallback: widget.totalGallons);

    final explicitExchange = order['exchange_containers'];
    if (explicitExchange != null) {
      final exchange = _toInt(explicitExchange, fallback: 0);
      if (exchange > 0) return true;
      if (_toBool(order['with_exchange'])) return total > 0;
      return false;
    }

    final newContainers = order['new_containers'];
    if (newContainers != null) {
      final newQuantity = _toInt(newContainers, fallback: total);
      return (total - newQuantity) > 0;
    }

    if (_toBool(order['with_exchange'])) return total > 0;

    // Final compatibility fallback for legacy records.
    if (_hasTrueValue(order['exchange_required'])) return total > 0;

    if (source == null && _order == null) {
      return widget.exchangeContainers > 0;
    }

    return false;
  }

  int _controllerValue(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  int _expectedExchangeQuantity(
    Map<String, dynamic> order, {
    required int total,
  }) {
    // Primary source: the customer's actual exchange quantity.
    final explicit = order['exchange_containers'];
    if (explicit != null) {
      final parsed = _toInt(explicit, fallback: 0);
      if (parsed > 0) return parsed.clamp(0, total).toInt();
      if (_toBool(order['with_exchange'])) return total;
      return 0;
    }

    // Compatibility with orders that saved only the new-container quantity.
    final newContainers = order['new_containers'];
    if (newContainers != null) {
      final newQty = _toInt(newContainers, fallback: total);
      final inferred = total - newQty;
      return inferred.clamp(0, total).toInt();
    }

    // Compatibility with orders that saved the customer's exchange boolean.
    if (_toBool(order['with_exchange'])) return total;

    // Legacy compatibility for the current database structure.
    if (_hasTrueValue(order['exchange_required'])) return total;

    if (order.isEmpty && widget.exchangeContainers > 0) {
      return widget.exchangeContainers.clamp(0, total).toInt();
    }

    return 0;
  }

  int get _expectedReturnQuantity => _expectedExchangeQuantity(
        _order ?? const <String, dynamic>{},
        total: _resolvedTotalGallons(),
      );

  int get _returnedQuantity => _controllerValue(_returnedController);
  int get _damagedQuantity => _controllerValue(_damagedController);
  int get _missingQuantity => _controllerValue(_missingController);

  int get _accountedQuantity =>
      _returnedQuantity + _damagedQuantity + _missingQuantity;

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
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Total Payment',
                      value: _resolvedTotalPayment(),
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
              if (_expectedReturnQuantity > 0 &&
                  _currentStatus == 'in_progress') ...[
                const SizedBox(height: 14),
                _buildContainerReturnCard(),
              ],
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const DriverMapScreen(),
                      ),
                    );
                  },
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

  Widget _buildContainerReturnCard() {
    final expected = _expectedReturnQuantity;
    final accounted = _accountedQuantity;
    final remaining = expected - accounted;
    final isComplete = remaining == 0;
    final isOver = remaining < 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: _primaryBlue,
                size: 21,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Container Return',
                  style: TextStyle(
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$accounted / $expected',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter what the customer actually returned. Damaged and missing containers must also be accounted for before delivery can be completed.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Expected Return',
            value: '$expected containers',
            valueColor: _primaryBlue,
          ),
          const SizedBox(height: 14),
          _buildQuantityField(
            label: 'Returned',
            controller: _returnedController,
            icon: Icons.replay_circle_filled_outlined,
            color: _successGreen,
          ),
          const SizedBox(height: 10),
          _buildQuantityField(
            label: 'Damaged',
            controller: _damagedController,
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: 10),
          _buildQuantityField(
            label: 'Missing',
            controller: _missingController,
            icon: Icons.help_outline_rounded,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: isComplete
                      ? _successGreen
                      : const Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isComplete
                        ? 'All containers are accounted for. You can mark the delivery as delivered.'
                        : isOver
                            ? 'The quantities exceed the expected return. Please correct the values.'
                            : '$remaining container(s) still need to be accounted for.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: isComplete
                          ? const Color(0xFF166534)
                          : const Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: _primaryBlue,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCompleteDelivery() async {
    // A return is required only when an actual exchange quantity exists.
    final expectedReturn = _expectedReturnQuantity;

    if (expectedReturn > 0) {
      final accounted = _accountedQuantity;

      if (accounted != expectedReturn) {
        final remaining = expectedReturn - accounted;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining > 0
                  ? 'Please account for all $expectedReturn containers. $remaining container(s) still need to be marked as returned, damaged, or missing.'
                  : 'The returned, damaged, and missing quantities cannot exceed $expectedReturn containers.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

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
      final session = await DriverSession.load();
      final driverId = session?.id ?? DriverSession.id;

      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver ID not found');
      }

      final supabase = Supabase.instance.client;

      // Always reload the latest order from Supabase before completing it.
      // The database order is the source of truth for the delivery quantity
      // and exchange quantity.
      final orderResponse = await supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        throw Exception('Order not found. Please refresh and try again.');
      }

      final freshOrder = Map<String, dynamic>.from(orderResponse);

      // Only exchange_containers (or the compatible new_containers fallback)
      // determines whether the customer must return containers.
      final isExchange = _isExchangeOrder(freshOrder);

      final gallons = _toInt(
        freshOrder['gallons'],
        fallback: widget.totalGallons,
      );

      if (gallons <= 0) {
        throw Exception('Invalid gallon quantity for this order.');
      }

      // ---------------------------------------------------------------
      // RECORD ACTUAL CONTAINER RETURN / CONDITION
      // ---------------------------------------------------------------
      // For exchange orders, the driver must account for every expected
      // container as returned, damaged, or missing. We never assume that
      // the full expected quantity was returned.
      if (isExchange) {
        final expectedReturn = _expectedExchangeQuantity(
          freshOrder,
          total: gallons,
        );

        final returned = _returnedQuantity;
        final damaged = _damagedQuantity;
        final missing = _missingQuantity;
        final accounted = returned + damaged + missing;

        if (expectedReturn <= 0) {
          throw Exception(
            'This exchange order has no expected container return quantity.',
          );
        }

        if (accounted != expectedReturn) {
          throw Exception(
            'Container quantities must equal the expected return. Expected $expectedReturn, but $accounted was accounted for.',
          );
        }

        final existingReturns = await supabase
            .from('container_returns')
            .select(
              'id, returned_quantity, damaged_quantity, missing_quantity',
            )
            .eq('order_id', orderId);

        int alreadyAccounted = 0;
        for (final row in (existingReturns as List<dynamic>)) {
          final record = Map<String, dynamic>.from(row as Map);
          alreadyAccounted +=
              _toInt(record['returned_quantity'], fallback: 0) +
              _toInt(record['damaged_quantity'], fallback: 0) +
              _toInt(record['missing_quantity'], fallback: 0);
        }

        // If a previous attempt already recorded the complete return, do not
        // insert another record. This keeps the operation idempotent.
        if (alreadyAccounted == expectedReturn) {
          // Nothing else is inserted. The existing return record remains the
          // permanent transaction-history record.
        } else if (alreadyAccounted > 0) {
          throw Exception(
            'A partial container return is already recorded for this order. Please contact the station administrator before completing it again.',
          );
        } else {
          final rawCapacity =
              freshOrder['capacity']?.toString().trim().isNotEmpty == true
                  ? freshOrder['capacity'].toString()
                  : (freshOrder['product_name']?.toString() ?? '5 gallons');

          final capacityText = rawCapacity.trim().toLowerCase();
          final capacity = capacityText.contains('5')
              ? '5 gallons'
              : capacityText.contains('3')
                  ? '3 gallons'
                  : rawCapacity.trim();

          await supabase.from('container_returns').insert({
            'order_id': orderId,
            'driver_id': driverId,
            'customer_id': freshOrder['customer_id'],
            'customer_name': freshOrder['customer_name'],
            'capacity': capacity,
            'expected_quantity': expectedReturn,
            'returned_quantity': returned,
            'damaged_quantity': damaged,
            'missing_quantity': missing,
            'notes':
                'Exchange return recorded by driver before delivery completion.',
          });
        }
      }

      // ---------------------------------------------------------------
      // COMPLETE THE ORDER
      // ---------------------------------------------------------------
      await supabase
          .from('orders')
          .update({'status': 'delivered'})
          .eq('id', orderId);

      // Driver is available again after completing the delivery.
      await supabase
          .from('employees')
          .update({'status': 'active'})
          .eq('id', driverId);

      if (!mounted) return;

      setState(() {
        _order = {
          ...freshOrder,
          'status': 'delivered',
        };
        _currentStatus = 'delivered';
        _isLoading = false;
      });

      widget.onOrderCompleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExchange
                ? 'Delivery completed. Empty containers returned to inventory.'
                : 'Delivery completed successfully.',
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );

      // Give the success message a moment to appear before returning.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;
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
          duration: const Duration(seconds: 4),
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