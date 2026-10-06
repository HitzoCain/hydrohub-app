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

  final TextEditingController _returnedController = TextEditingController(
    text: '0',
  );
  final TextEditingController _damagedController = TextEditingController(
    text: '0',
  );
  final TextEditingController _missingController = TextEditingController(
    text: '0',
  );

  // Previous borrowed-container return (separate from the current order exchange).
  bool _returnPreviousBorrowed = false;
  bool _isLoadingBorrowings = false;
  List<Map<String, dynamic>> _activeBorrowings = [];

  final TextEditingController _borrowReturnController = TextEditingController(
    text: '0',
  );
  final TextEditingController _borrowDamagedController = TextEditingController(
    text: '0',
  );
  final TextEditingController _borrowMissingController = TextEditingController(
    text: '0',
  );

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

    _borrowReturnController.dispose();
    _borrowDamagedController.dispose();
    _borrowMissingController.dispose();

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
    final lat =
        _toDouble(source['customer_lat']) ??
        _toDouble(source['latitude']) ??
        _toDouble(source['lat']) ??
        _toDouble(source['address_lat']) ??
        _toDouble(source['address_latitude']);
    final lng =
        _toDouble(source['customer_lng']) ??
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

      // Compatibility for older orders. Never infer an exchange return
      // for a Borrow Container order.
      final totalGallons = _toInt(
        orderData['gallons'],
        fallback: widget.totalGallons,
      );

      final deliveryType = _textOf(
        orderData['delivery_type'],
        fallback: '',
      ).toLowerCase();
      final borrowContainers = _toInt(
        orderData['borrow_containers'],
        fallback: 0,
      );

      final isBorrowRecord =
          deliveryType == 'borrow_containers' ||
          borrowContainers > 0 ||
          _textOf(orderData['borrow_status'], fallback: 'none').toLowerCase() !=
              'none';

      final hasExchangeCount =
          orderData.containsKey('exchange_containers') &&
          orderData['exchange_containers'] != null;
      final hasNewContainerCount =
          orderData.containsKey('new_containers') &&
          orderData['new_containers'] != null;

      if (!isBorrowRecord &&
          !hasExchangeCount &&
          !hasNewContainerCount &&
          _hasTrueValue(orderData['exchange_required']) &&
          totalGallons > 0) {
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
              final addrLat =
                  _toDouble(addressData['latitude']) ??
                  _toDouble(addressData['lat']);
              final addrLng =
                  _toDouble(addressData['longitude']) ??
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

        // Previous borrowed-container returns are optional. Reset them when
        // the order is loaded so the driver must explicitly opt in.
        _returnPreviousBorrowed = false;
        _borrowReturnController.text = '0';
        _borrowDamagedController.text = '0';
        _borrowMissingController.text = '0';
      });

      await _loadActiveBorrowings();
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

  Future<void> _loadActiveBorrowings() async {
    final customerId = _textOf(_order?['customer_id'], fallback: '');

    if (customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _activeBorrowings = [];
        });
      }
      return;
    }

    setState(() {
      _isLoadingBorrowings = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Load only active borrowings belonging to this customer. The current
      // order is excluded because this feature is specifically for containers
      // borrowed from an earlier transaction.
      final response = await supabase
          .from('container_borrowings')
          .select()
          .eq('customer_id', customerId)
          .inFilter('status', ['approved', 'borrowed', 'partially_returned'])
          .neq('order_id', _rawOrderId)
          .order('borrowed_at', ascending: true);

      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );

      final activeRows = rows.where((row) {
        final quantity = _toInt(row['quantity'], fallback: 0);
        final returned = _toInt(row['returned_quantity'], fallback: 0);
        final damaged = _toInt(row['damaged_quantity'], fallback: 0);
        final missing = _toInt(row['missing_quantity'], fallback: 0);

        final outstanding = quantity - returned - damaged - missing;

        return outstanding > 0;
      }).toList();

      if (!mounted) return;

      setState(() {
        _activeBorrowings = activeRows;
      });
    } catch (e) {
      debugPrint('Failed to load active borrowed containers: $e');

      if (mounted) {
        setState(() {
          _activeBorrowings = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBorrowings = false;
        });
      }
    }
  }

  int _borrowingOutstanding(Map<String, dynamic> borrowing) {
    final quantity = _toInt(borrowing['quantity'], fallback: 0);
    final returned = _toInt(borrowing['returned_quantity'], fallback: 0);
    final damaged = _toInt(borrowing['damaged_quantity'], fallback: 0);
    final missing = _toInt(borrowing['missing_quantity'], fallback: 0);

    return (quantity - returned - damaged - missing).clamp(0, quantity).toInt();
  }

  int get _totalOutstandingBorrowed {
    return _activeBorrowings.fold<int>(
      0,
      (total, row) => total + _borrowingOutstanding(row),
    );
  }

  int get _borrowReturnQuantity => _controllerValue(_borrowReturnController);

  int get _borrowDamagedQuantity => _controllerValue(_borrowDamagedController);

  int get _borrowMissingQuantity => _controllerValue(_borrowMissingController);

  int get _borrowAccountedQuantity =>
      _borrowReturnQuantity + _borrowDamagedQuantity + _borrowMissingQuantity;

  Widget _buildPreviousBorrowedReturnCard() {
    final outstanding = _totalOutstandingBorrowed;
    final accounted = _borrowAccountedQuantity;
    final remaining = outstanding - accounted;
    final isComplete = _returnPreviousBorrowed && remaining == 0;
    final isOver = remaining < 0;
    final hasOutstanding = outstanding > 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFD97706),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Previous Borrowed Containers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (!_isLoadingBorrowings && hasOutstanding)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$outstanding',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isLoadingBorrowings
                ? 'Checking the customer\'s previous borrowed-container records...'
                : hasOutstanding
                ? 'The customer has $outstanding outstanding borrowed container(s) from previous transactions. These can be returned during this delivery even though they are not part of the current order.'
                : 'No outstanding borrowed containers were found for this customer.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoadingBorrowings)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            if (hasOutstanding) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Borrowing Records',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._activeBorrowings.map((borrowing) {
                      final quantity = _borrowingOutstanding(borrowing);
                      if (quantity <= 0) {
                        return const SizedBox.shrink();
                      }

                      final capacity = _resolvedCapacity(borrowing);
                      final borrowedAt = _textOf(
                        borrowing['borrowed_at'],
                        fallback: '',
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 7,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                borrowedAt.isEmpty
                                    ? '$capacity • $quantity container(s) outstanding'
                                    : '$capacity • $quantity container(s) outstanding\nBorrowed: $borrowedAt',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Customer wants to return borrowed containers',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              subtitle: Text(
                hasOutstanding
                    ? 'Turn this on when the customer gives previously borrowed containers to the driver.'
                    : 'There are no previous borrowed containers available to return.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF64748B),
                ),
              ),
              value: _returnPreviousBorrowed,
              activeThumbColor: _primaryBlue,
              onChanged: hasOutstanding
                  ? (value) {
                      setState(() {
                        _returnPreviousBorrowed = value;
                        if (!value) {
                          _borrowReturnController.text = '0';
                          _borrowDamagedController.text = '0';
                          _borrowMissingController.text = '0';
                        }
                      });
                    }
                  : null,
            ),
            if (_returnPreviousBorrowed && hasOutstanding) ...[
              const Divider(height: 24),
              _InfoRow(
                label: 'Outstanding Borrowed',
                value: '$outstanding containers',
                valueColor: const Color(0xFFD97706),
              ),
              const SizedBox(height: 14),
              _buildQuantityField(
                label: 'Returned',
                controller: _borrowReturnController,
                icon: Icons.replay_circle_filled_outlined,
                color: _successGreen,
              ),
              const SizedBox(height: 10),
              _buildQuantityField(
                label: 'Damaged',
                controller: _borrowDamagedController,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(height: 10),
              _buildQuantityField(
                label: 'Missing',
                controller: _borrowMissingController,
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
                      : isOver
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isComplete
                        ? const Color(0xFFBBF7D0)
                        : isOver
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFFED7AA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle_outline
                          : isOver
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: isComplete
                          ? _successGreen
                          : isOver
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isComplete
                            ? 'All entered previous borrowed containers are accounted for.'
                            : isOver
                            ? 'The quantities exceed the customer\'s outstanding borrowed containers.'
                            : '$remaining container(s) still need to be accounted for. Partial returns are allowed.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: isComplete
                              ? const Color(0xFF166534)
                              : isOver
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _recordPreviousBorrowedReturns({
    required SupabaseClient supabase,
    required String customerId,
    required String currentOrderId,
    required String driverId,
  }) async {
    if (!_returnPreviousBorrowed) return;

    final returned = _borrowReturnQuantity;
    final damaged = _borrowDamagedQuantity;
    final missing = _borrowMissingQuantity;
    final totalToAccount = returned + damaged + missing;

    if (totalToAccount <= 0) {
      throw Exception(
        'Please enter a returned, damaged, or missing quantity for the previous borrowed containers.',
      );
    }

    // Reload the latest records so the database remains the source of truth.
    final response = await supabase
        .from('container_borrowings')
        .select()
        .eq('customer_id', customerId)
        .inFilter('status', ['approved', 'borrowed', 'partially_returned'])
        .neq('order_id', currentOrderId)
        .order('borrowed_at', ascending: true);

    final borrowings = List<Map<String, dynamic>>.from(
      (response as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );

    int latestOutstanding = 0;
    for (final borrowing in borrowings) {
      latestOutstanding += _borrowingOutstanding(borrowing);
    }

    if (latestOutstanding <= 0) {
      throw Exception(
        'The customer has no outstanding borrowed containers to return.',
      );
    }

    if (totalToAccount > latestOutstanding) {
      throw Exception(
        'The return quantity exceeds the customer\'s current outstanding borrowed quantity of $latestOutstanding. Please refresh and try again.',
      );
    }

    int remainingReturned = returned;
    int remainingDamaged = damaged;
    int remainingMissing = missing;

    for (final borrowing in borrowings) {
      if (remainingReturned <= 0 &&
          remainingDamaged <= 0 &&
          remainingMissing <= 0) {
        break;
      }

      final borrowingId = borrowing['id']?.toString();
      if (borrowingId == null || borrowingId.isEmpty) {
        continue;
      }

      final outstanding = _borrowingOutstanding(borrowing);
      if (outstanding <= 0) continue;

      // Allocate the customer's actual returned containers first, oldest
      // borrowing first. Any damaged/missing quantity is then allocated
      // against the remaining quantity of that same borrowing.
      final allocateReturned = remainingReturned > outstanding
          ? outstanding
          : remainingReturned;
      remainingReturned -= allocateReturned;

      int remainingForDamage = outstanding - allocateReturned;

      final allocateDamaged = remainingDamaged > remainingForDamage
          ? remainingForDamage
          : remainingDamaged;
      remainingDamaged -= allocateDamaged;
      remainingForDamage -= allocateDamaged;

      final allocateMissing = remainingMissing > remainingForDamage
          ? remainingForDamage
          : remainingMissing;
      remainingMissing -= allocateMissing;

      final allocatedTotal =
          allocateReturned + allocateDamaged + allocateMissing;

      if (allocatedTotal <= 0) {
        continue;
      }

      final oldReturned = _toInt(borrowing['returned_quantity'], fallback: 0);
      final oldDamaged = _toInt(borrowing['damaged_quantity'], fallback: 0);
      final oldMissing = _toInt(borrowing['missing_quantity'], fallback: 0);
      final quantity = _toInt(borrowing['quantity'], fallback: 0);

      final newReturned = oldReturned + allocateReturned;
      final newDamaged = oldDamaged + allocateDamaged;
      final newMissing = oldMissing + allocateMissing;

      final newOutstanding = quantity - newReturned - newDamaged - newMissing;

      if (newReturned + newDamaged + newMissing > quantity) {
        throw Exception(
          'The return would exceed the original borrowed quantity for borrowing record $borrowingId.',
        );
      }

      final nextStatus = newOutstanding <= 0
          ? 'returned'
          : 'partially_returned';

      final now = DateTime.now().toIso8601String();

      // ---------------------------------------------------------------
      // RECORD THE PHYSICAL RETURN
      // ---------------------------------------------------------------
      // Your current container_returns schema does not have borrowing_id,
      // so the borrowing record ID is included in notes. The current order
      // ID links this return to the delivery during which it was collected.
      final capacity = _resolvedCapacity(borrowing);

      await supabase.from('container_returns').insert({
        'order_id': currentOrderId,
        'driver_id': driverId,
        'customer_id': customerId,
        'customer_name': borrowing['customer_name'] ?? _resolvedCustomerName(),
        'capacity': capacity,
        'expected_quantity': allocatedTotal,
        'returned_quantity': allocateReturned,
        'damaged_quantity': allocateDamaged,
        'missing_quantity': allocateMissing,
        'notes':
            'Previous borrowed-container return. Borrowing ID: $borrowingId. '
            'Recorded by driver $driverId during order $currentOrderId.',
      });

      // ---------------------------------------------------------------
      // UPDATE THE CUSTOMER'S OUTSTANDING BORROWING
      // ---------------------------------------------------------------
      final updateData = <String, dynamic>{
        'returned_quantity': newReturned,
        'damaged_quantity': newDamaged,
        'missing_quantity': newMissing,
        'status': nextStatus,
        'updated_at': now,
        'notes':
            'Previous borrowed-container return recorded by driver $driverId during order $currentOrderId.',
      };

      if (nextStatus == 'returned') {
        updateData['returned_at'] = now;
      }

      await supabase
          .from('container_borrowings')
          .update(updateData)
          .eq('id', borrowingId);
    }

    if (remainingReturned > 0 || remainingDamaged > 0 || remainingMissing > 0) {
      throw Exception(
        'The borrowed-container return could not be completely recorded. Please refresh and try again.',
      );
    }
  }

  String _resolvedCustomerName() {
    return _textOf(_order?['customer_name'], fallback: widget.customerName);
  }

  String _resolvedContactNumber() {
    final fromOrder = _textOf(_order?['customer_phone'], fallback: '');
    if (fromOrder.isNotEmpty) {
      return fromOrder;
    }
    return _textOf(widget.contactNumber, fallback: 'Not provided');
  }

  String _resolvedPaymentMethod() {
    final method = _textOf(
      _order?['payment_method'],
      fallback: '',
    ).trim().toLowerCase();

    switch (method) {
      case 'gcash':
        return 'GCash';
      case 'cash':
      case 'cod':
      case 'cash on delivery':
        return 'Cash on Delivery';
      case '':
        return 'Not specified';
      default:
        return method;
    }
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

  String _resolvedDeliveryType([Map<String, dynamic>? source]) {
    final order = source ?? _order ?? const <String, dynamic>{};

    final rawType = _textOf(
      order['delivery_type'],
      fallback: '',
    ).trim().toLowerCase();

    if (rawType == 'borrow_containers' ||
        _toInt(order['borrow_containers'], fallback: 0) > 0 ||
        _textOf(
              order['borrow_status'],
              fallback: 'none',
            ).trim().toLowerCase() !=
            'none') {
      return 'borrow_containers';
    }

    if (rawType == 'with_exchange') return 'with_exchange';
    if (rawType == 'new_gallons') return 'new_gallons';

    if (_toBool(order['with_exchange'])) return 'with_exchange';
    if (_toInt(order['exchange_containers'], fallback: 0) > 0) {
      return 'with_exchange';
    }
    if (_hasTrueValue(order['exchange_required'])) return 'with_exchange';

    return 'new_gallons';
  }

  bool _isBorrowOrder([Map<String, dynamic>? source]) =>
      _resolvedDeliveryType(source) == 'borrow_containers';

  bool _isExchangeOrder([Map<String, dynamic>? source]) =>
      _resolvedDeliveryType(source) == 'with_exchange';

  int _resolvedBorrowContainers() {
    final total = _resolvedTotalGallons();
    final explicit = _order?['borrow_containers'];

    if (explicit != null) {
      final parsed = _toInt(explicit, fallback: 0);
      return parsed.clamp(0, total > 0 ? total : parsed).toInt();
    }

    return 0;
  }

  int _resolvedExchangeContainers() {
    if (_isBorrowOrder()) return 0;

    final total = _resolvedTotalGallons();
    final explicitExchange = _order?['exchange_containers'];

    if (explicitExchange != null) {
      final exchange = _toInt(explicitExchange, fallback: 0);
      if (exchange > 0) return exchange.clamp(0, total).toInt();

      if (_toBool(_order?['with_exchange'])) return total;
      return 0;
    }

    final newContainers = _order?['new_containers'];
    if (newContainers != null) {
      final newQuantity = _toInt(newContainers, fallback: total);
      return (total - newQuantity).clamp(0, total).toInt();
    }

    if (_toBool(_order?['with_exchange'])) return total;
    if (_hasTrueValue(_order?['exchange_required'])) return total;

    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  bool _hasTrueValue(dynamic value) => _toBool(value);

  String _containerTypeLabel() {
    switch (_resolvedDeliveryType()) {
      case 'with_exchange':
        return 'With Exchange';
      case 'borrow_containers':
        return 'Borrow Container';
      case 'new_gallons':
      default:
        return 'New Container';
    }
  }

  String _resolvedProductName() {
    final value = _textOf(_order?['product_name'], fallback: '');
    return value.isEmpty ? 'Water' : value;
  }

  String _resolvedProductCapacity() {
    final value = _textOf(_order?['capacity'], fallback: '');
    return value.isEmpty ? 'Size unavailable' : value;
  }

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

  int _controllerValue(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  int _expectedExchangeQuantity(
    Map<String, dynamic> order, {
    required int total,
  }) {
    if (_isBorrowOrder(order)) return 0;

    final explicit = order['exchange_containers'];
    if (explicit != null) {
      final parsed = _toInt(explicit, fallback: 0);
      if (parsed > 0) return parsed.clamp(0, total).toInt();
      if (_toBool(order['with_exchange'])) return total;
      return 0;
    }

    final newContainers = order['new_containers'];
    if (newContainers != null) {
      final newQty = _toInt(newContainers, fallback: total);
      return (total - newQty).clamp(0, total).toInt();
    }

    if (_toBool(order['with_exchange'])) return total;
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
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Payment Method',
                      value: _resolvedPaymentMethod(),
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
                    _InfoRow(
                      label: 'Delivery Address',
                      value: _resolvedAddress(),
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
                      'Order Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Product', value: _resolvedProductName()),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Size', value: _resolvedProductCapacity()),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Quantity',
                      value: '${_resolvedTotalGallons()} Containers',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Container Type',
                      value: _containerTypeLabel(),
                      valueColor: _primaryBlue,
                    ),
                    const SizedBox(height: 8),
                    if (_isBorrowOrder()) ...[
                      _InfoRow(
                        label: 'Borrow Containers',
                        value: '${_resolvedBorrowContainers()}',
                      ),
                      const SizedBox(height: 8),
                    ] else if (_isExchangeOrder()) ...[
                      _InfoRow(
                        label: 'Exchange Containers',
                        value: '${_resolvedExchangeContainers()}',
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      _InfoRow(
                        label: 'New Containers',
                        value: '${_resolvedTotalGallons()}',
                      ),
                      const SizedBox(height: 8),
                    ],
                    _InfoRow(
                      label: 'Total Payment',
                      value: _resolvedTotalPayment(),
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
              if (_isExchangeOrder() &&
                  _expectedReturnQuantity > 0 &&
                  _currentStatus == 'in_progress') ...[
                const SizedBox(height: 14),
                _buildContainerReturnCard(),
              ],
              // Always show this section while the delivery is in progress.
              // It lets the driver verify whether the customer has old
              // borrowed containers, even when the outstanding balance is 0.
              if (_currentStatus == 'in_progress') ...[
                const SizedBox(height: 14),
                _buildPreviousBorrowedReturnCard(),
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
            'Record the empty containers the customer returned for this exchange. Any container not returned must be marked as damaged or missing before delivery can be completed.',
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
                  isComplete ? Icons.check_circle_outline : Icons.info_outline,
                  color: isComplete ? _successGreen : const Color(0xFFD97706),
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
            color: color.withValues(alpha: 0.10),
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
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
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

    // Previous borrowed containers are completely separate from the current
    // order exchange. The customer can return them during any delivery.
    if (_returnPreviousBorrowed) {
      final outstanding = _totalOutstandingBorrowed;
      final accounted = _borrowAccountedQuantity;

      if (accounted <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter how many previous borrowed containers were returned, damaged, or missing.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (accounted > outstanding) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Borrowed container return cannot exceed $outstanding outstanding container(s).',
            ),
            backgroundColor: Colors.red,
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
        _order = {...?_order, 'status': 'in_progress'};
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

  String _resolvedCapacity(Map<String, dynamic> order) {
    final rawCapacity = order['capacity']?.toString().trim().isNotEmpty == true
        ? order['capacity'].toString()
        : (order['product_name']?.toString() ?? '5 gallons');

    final capacityText = rawCapacity.trim().toLowerCase();

    if (capacityText.contains('5')) return '5 gallons';
    if (capacityText.contains('3')) return '3 gallons';
    if (capacityText.contains('2')) return '2 gallons';

    return rawCapacity.trim();
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

      // Reload the latest order so the database is always the source of truth.
      final orderResponse = await supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        throw Exception('Order not found. Please refresh and try again.');
      }

      final freshOrder = Map<String, dynamic>.from(orderResponse);
      final deliveryType = _resolvedDeliveryType(freshOrder);
      final isExchange = deliveryType == 'with_exchange';
      final isBorrow = deliveryType == 'borrow_containers';

      final gallons = _toInt(
        freshOrder['gallons'],
        fallback: widget.totalGallons,
      );

      if (gallons <= 0) {
        throw Exception('Invalid gallon quantity for this order.');
      }

      // ===============================================================
      // WITH EXCHANGE
      // ===============================================================
      // Only an actual exchange requires an immediate container return.
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
            'Container quantities must equal the expected return. '
            'Expected $expectedReturn, but $accounted was accounted for.',
          );
        }

        final existingReturns = await supabase
            .from('container_returns')
            .select('id, returned_quantity, damaged_quantity, missing_quantity')
            .eq('order_id', orderId);

        int alreadyAccounted = 0;
        for (final row in (existingReturns as List<dynamic>)) {
          final record = Map<String, dynamic>.from(row as Map);
          alreadyAccounted +=
              _toInt(record['returned_quantity'], fallback: 0) +
              _toInt(record['damaged_quantity'], fallback: 0) +
              _toInt(record['missing_quantity'], fallback: 0);
        }

        if (alreadyAccounted == expectedReturn) {
          // Already recorded completely. Do not create a duplicate.
        } else if (alreadyAccounted > 0) {
          throw Exception(
            'A partial container return is already recorded for this order. '
            'Please contact the station administrator before completing it again.',
          );
        } else {
          final capacity = _resolvedCapacity(freshOrder);

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

      // ===============================================================
      // BORROW CONTAINER
      // ===============================================================
      // Borrowing is NOT an immediate return. The customer can return the
      // borrowed container on a later transaction.
      if (isBorrow) {
        final borrowQuantity = _toInt(
          freshOrder['borrow_containers'],
          fallback: 0,
        );

        if (borrowQuantity <= 0) {
          throw Exception(
            'This borrow order has no borrowed-container quantity.',
          );
        }

        final existingBorrowings = await supabase
            .from('container_borrowings')
            .select('id')
            .eq('order_id', orderId);

        if ((existingBorrowings as List<dynamic>).isEmpty) {
          final capacity = _resolvedCapacity(freshOrder);

          String? deliveryId;
          try {
            final deliveryResponse = await supabase
                .from('deliveries')
                .select('id')
                .eq('order_id', orderId)
                .limit(1)
                .maybeSingle();

            deliveryId = deliveryResponse?['id']?.toString();
          } catch (e) {
            debugPrint('Delivery lookup for borrowing skipped: $e');
          }

          await supabase.from('container_borrowings').insert({
            'order_id': orderId,
            'delivery_id': deliveryId,
            'customer_id': freshOrder['customer_id']?.toString() ?? '',
            'customer_name': freshOrder['customer_name'],
            'capacity': capacity,
            'quantity': borrowQuantity,
            'returned_quantity': 0,
            'damaged_quantity': 0,
            'missing_quantity': 0,
            'status': 'borrowed',
            'notes':
                'Container borrowed by customer and recorded during delivery completion.',
            'borrowed_at': DateTime.now().toIso8601String(),
          });
        }

        // Synchronize the order borrowing status.
        await supabase
            .from('orders')
            .update({
              'borrow_containers': borrowQuantity,
              'borrow_status': 'borrowed',
            })
            .eq('id', orderId);

        // Synchronize delivery_type when a delivery record already exists.
        try {
          await supabase
              .from('deliveries')
              .update({'delivery_type': 'borrow_containers'})
              .eq('order_id', orderId);
        } catch (e) {
          debugPrint('Delivery type sync skipped: $e');
        }
      }

      // ===============================================================
      // PREVIOUS BORROWED-CONTAINER RETURN
      // ===============================================================
      // This is intentionally independent from the current order's
      // delivery_type. It updates older customer borrowing records.
      if (_returnPreviousBorrowed) {
        await _recordPreviousBorrowedReturns(
          supabase: supabase,
          customerId: freshOrder['customer_id']?.toString() ?? '',
          currentOrderId: orderId,
          driverId: driverId,
        );
      }

      // ===============================================================
      // COMPLETE ORDER
      // ===============================================================
      await supabase
          .from('orders')
          .update({'status': 'delivered'})
          .eq('id', orderId);

      await supabase
          .from('employees')
          .update({'status': 'active'})
          .eq('id', driverId);

      if (!mounted) return;

      final previousBorrowReturnCount = _borrowReturnQuantity;
      final hadPreviousBorrowReturn = _returnPreviousBorrowed;

      setState(() {
        _order = {
          ...freshOrder,
          'status': 'delivered',
          if (isBorrow) 'borrow_status': 'borrowed',
        };
        _currentStatus = 'delivered';
        _isLoading = false;
        _returnPreviousBorrowed = false;
      });

      widget.onOrderCompleted?.call();

      final previousBorrowReturnMessage = hadPreviousBorrowReturn
          ? ' $previousBorrowReturnCount previous borrowed container(s) returned.'
          : '';

      final message = isExchange
          ? 'Delivery completed. Empty containers were recorded as returned, damaged, or missing.$previousBorrowReturnMessage'
          : isBorrow
          ? 'Delivery completed. ${_toInt(freshOrder['borrow_containers'], fallback: 0)} borrowed container(s) were recorded.$previousBorrowReturnMessage'
          : 'Delivery completed successfully.$previousBorrowReturnMessage';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );

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
