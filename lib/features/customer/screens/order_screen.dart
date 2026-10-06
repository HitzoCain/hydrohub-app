import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'address_screen.dart';
import 'customer_nav_controller.dart';
import 'track_order_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF1F5F9);

  bool _isSubmitting = false;
  bool _isFetchingLocationPreview = false;
  bool _isLoadingAddresses = false;
  bool _isLoadingProducts = false;
  String? _productError;
  int _totalGallons = 1;
  int _exchangeCount = 0;
  int _newContainerCount = 1;
  int _borrowCount = 0;
  int _maximumBorrowContainers = 10;
  double? _currentLat;
  double? _currentLng;
  List<_Product> _products = const [];
  _Product? _selectedProduct;
  List<_SavedAddress> _savedAddresses = const [];
  _SavedAddress? _selectedAddress;
  String _deliveryTime = 'Morning';
  String _deliveryType = 'now';
  String _paymentMethod = 'Cash';
  bool _loadingPaymentSettings = true;
  bool _paymentSettingsFailed = false;
  bool _codEnabled = false;
  bool _codVerification = false;
  bool _gcashEnabled = false;
  String _gcashNumber = '';
  String _gcashAccountName = '';
  String _gcashQrCodeUrl = '';
  XFile? _paymentReceipt;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _exchangeController = TextEditingController(
    text: '0',
  );
  final TextEditingController _newController = TextEditingController(text: '1');
  final TextEditingController _borrowController = TextEditingController(
    text: '0',
  );
  final TextEditingController _deliveryInstructionsController =
      TextEditingController();
  bool _borrowEnabled = true;
  String? _containerAllocationError;

  @override
  void initState() {
    super.initState();
    _refreshCurrentLocationPreview();
    loadAddresses();
    CustomerNavController.instance.addListener(_handleTabChange);
    _loadProducts();
    _loadBorrowSettings();
    _loadPaymentSettings();
  }

  @override
  void dispose() {
    CustomerNavController.instance.removeListener(_handleTabChange);
    _exchangeController.dispose();
    _newController.dispose();
    _borrowController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (CustomerNavController.instance.index == 1) {
      loadAddresses(force: true);
      _loadProducts(force: true);
    }
  }

  bool get _requiresExchange => _selectedProduct?.exchangeRequired ?? false;

  bool get _isGcashAvailable => _gcashEnabled;

  bool get _isCodAvailable => _codEnabled;

  bool get _hasAnyPaymentMethodAvailable => _codEnabled || _gcashEnabled;

  int get _estimatedPrice {
    final product = _selectedProduct;
    if (product == null) return 0;

    return (_exchangeCount * product.exchangePrice) +
        (_newContainerCount * product.basePrice) +
        (_borrowCount * product.basePrice);
  }

  void _syncAllocationControllers() {
    _exchangeController.text = '$_exchangeCount';
    _newController.text = '$_newContainerCount';
    _borrowController.text = '$_borrowCount';
  }

  int _parseQuantity(String value) {
    final parsed = int.tryParse(value.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  void _recalculateContainerTotal() {
    final exchange = _parseQuantity(_exchangeController.text);
    final newContainers = _parseQuantity(_newController.text);
    final borrow = _parseQuantity(_borrowController.text);

    setState(() {
      _exchangeCount = _requiresExchange ? exchange : 0;
      _newContainerCount = newContainers;
      _borrowCount = borrow;
      _totalGallons = _exchangeCount + _newContainerCount + _borrowCount;

      if (_borrowCount > _maximumBorrowContainers) {
        _containerAllocationError =
            'Borrow containers cannot exceed $_maximumBorrowContainers.';
      } else if (!_requiresExchange && exchange > 0) {
        _containerAllocationError =
            'Exchange is not available for the selected product.';
      } else if (!_borrowEnabled && borrow > 0) {
        _containerAllocationError = 'Borrowing is currently unavailable.';
      } else {
        _containerAllocationError = null;
      }
    });
  }

  void _onExchangeChanged(String value) {
    final quantity = _parseQuantity(value);
    if (!_requiresExchange && quantity > 0) {
      _exchangeController.text = '0';
      _exchangeController.selection = TextSelection.collapsed(
        offset: _exchangeController.text.length,
      );
    }
    _recalculateContainerTotal();
  }

  void _onNewChanged(String value) {
    _recalculateContainerTotal();
  }

  void _onBorrowChanged(String value) {
    final quantity = _parseQuantity(value);
    if (quantity > _maximumBorrowContainers) {
      _borrowController.text = '$_maximumBorrowContainers';
      _borrowController.selection = TextSelection.collapsed(
        offset: _borrowController.text.length,
      );
    }
    _recalculateContainerTotal();
  }

  void _selectProduct(_Product product) {
    setState(() {
      _selectedProduct = product;
      if (!product.exchangeRequired) {
        _exchangeCount = 0;
        _exchangeController.text = '0';
      }
      _totalGallons = _exchangeCount + _newContainerCount + _borrowCount;
      _containerAllocationError = null;
    });
  }

  Future<void> _loadBorrowSettings() async {
    if (!mounted) return;

    setState(() {});

    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('container_borrow_settings')
          .select('enabled,maximum_per_customer')
          .limit(1);

      var maximum = 10;
      var enabled = true;

      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        enabled = _toBool(row['enabled']);

        final value = row['maximum_per_customer'];
        if (value is num) {
          maximum = value.toInt();
        } else if (value is String) {
          maximum = int.tryParse(value) ?? 10;
        }
      }

      maximum = maximum.clamp(1, 100).toInt();

      if (!mounted) return;

      setState(() {
        _borrowEnabled = enabled;
        _maximumBorrowContainers = maximum;

        if (!_borrowEnabled) {
          _borrowCount = 0;
          _borrowController.text = '0';
        } else if (_borrowCount > maximum) {
          _borrowCount = maximum;
          _borrowController.text = '$maximum';
        }

        _totalGallons = _exchangeCount + _newContainerCount + _borrowCount;
      });
    } catch (e) {
      debugPrint(
        'Failed to load borrow settings; using default limit of 10: $e',
      );

      if (!mounted) return;

      setState(() {
        _borrowEnabled = true;
        _maximumBorrowContainers = 10;
      });
    }
  }

  Future<void> _loadPaymentSettings() async {
    if (!mounted) return;

    setState(() {
      _loadingPaymentSettings = true;
      _paymentSettingsFailed = false;
    });

    try {
      final client = Supabase.instance.client;

      Future<Map<String, dynamic>?> fetchLatestRow() async {
        for (final column in ['updated_at', 'created_at', 'id']) {
          try {
            final rows = await client
                .from('system_settings')
                .select(
                  'cod_enabled,cod_verification,gcash_enabled,gcash_number,gcash_account_name,gcash_qr_code_url',
                )
                .order(column, ascending: false)
                .limit(1)
                .timeout(const Duration(seconds: 8));

            if (rows.isNotEmpty) {
              return Map<String, dynamic>.from(rows.first);
            }
          } catch (e) {
            debugPrint('system_settings fetch failed for $column: $e');
          }
        }

        final rows = await client
            .from('system_settings')
            .select(
              'cod_enabled,cod_verification,gcash_enabled,gcash_number,gcash_account_name,gcash_qr_code_url',
            )
            .limit(1)
            .timeout(const Duration(seconds: 8));

        if (rows.isEmpty) return null;
        return Map<String, dynamic>.from(rows.first);
      }

      final settings = await fetchLatestRow();

      if (!mounted) return;

      setState(() {
        _codEnabled = _toBool(settings?['cod_enabled']);
        _codVerification = _toBool(settings?['cod_verification']);
        _gcashEnabled = _toBool(settings?['gcash_enabled']);
        _gcashNumber = _toText(settings?['gcash_number']);
        _gcashAccountName = _toText(settings?['gcash_account_name']);
        _gcashQrCodeUrl = _toText(settings?['gcash_qr_code_url']);
        _paymentSettingsFailed = false;
        _syncPaymentMethodSelection();
      });
    } on SocketException catch (e) {
      debugPrint('Failed to load payment settings: $e');
      if (!mounted) return;
      setState(() {
        _codEnabled = false;
        _codVerification = false;
        _gcashEnabled = false;
        _paymentSettingsFailed = true;
        _syncPaymentMethodSelection();
      });
    } on TimeoutException catch (e) {
      debugPrint('Payment settings timeout: $e');
      if (!mounted) return;
      setState(() {
        _codEnabled = false;
        _codVerification = false;
        _gcashEnabled = false;
        _paymentSettingsFailed = true;
        _syncPaymentMethodSelection();
      });
    } catch (e) {
      debugPrint('Failed to load payment settings: $e');
      if (!mounted) return;
      setState(() {
        _codEnabled = false;
        _codVerification = false;
        _gcashEnabled = false;
        _paymentSettingsFailed = true;
        _syncPaymentMethodSelection();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPaymentSettings = false;
        });
      }
    }
  }

  void _syncPaymentMethodSelection() {
    if (_codEnabled && _gcashEnabled) {
      if (_paymentMethod != 'Cash' && _paymentMethod != 'GCash') {
        _paymentMethod = 'Cash';
      }
      _paymentReceipt = null;
      return;
    }

    if (_codEnabled) {
      _paymentMethod = 'Cash';
      _paymentReceipt = null;
      return;
    }

    if (_gcashEnabled) {
      _paymentMethod = 'GCash';
      _paymentReceipt = null;
      return;
    }

    _paymentMethod = '';
    _paymentReceipt = null;
  }

  bool _isPaymentMethodEnabled(String paymentMethod) {
    if (paymentMethod == 'Cash') return _isCodAvailable;
    if (paymentMethod == 'GCash') return _isGcashAvailable;
    return false;
  }

  Future<void> _loadProducts({bool force = false}) async {
    if (_isLoadingProducts && !force) return;

    setState(() {
      _isLoadingProducts = true;
      _productError = null;
    });

    try {
      final rows = await Supabase.instance.client.from('products').select('*');
      final productRows = List<Map<String, dynamic>>.from(
        rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)),
      );

      final products = <_Product>[];
      for (final row in productRows) {
        final enabledValue = row['enabled'];
        if (enabledValue is bool && !enabledValue) {
          continue;
        }
        if (enabledValue is String) {
          final normalized = enabledValue.trim().toLowerCase();
          if (normalized == 'false' ||
              normalized == '0' ||
              normalized == 'no') {
            continue;
          }
        }

        final product = _Product.fromMap(row);
        if (product.id.isEmpty) {
          continue;
        }
        products.add(product);
      }

      if (!mounted) return;

      setState(() {
        _products = products;

        if (_products.isEmpty) {
          _selectedProduct = null;
          _productError = 'No available products found.';
          _exchangeCount = 0;
          _newContainerCount = 0;
          _borrowCount = 0;
          _syncAllocationControllers();
          _totalGallons = 0;
          return;
        }

        final selectedProductId = _selectedProduct?.id;
        _selectedProduct = _products.firstWhere(
          (product) => product.id == selectedProductId,
          orElse: () => _products.first,
        );
        _totalGallons = _exchangeCount + _newContainerCount + _borrowCount;
        _syncAllocationControllers();
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to load products: $e');
      debugPrint('Product loading stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _products = const [];
        _selectedProduct = null;
        _productError = 'Unable to load products.';
        _exchangeCount = 0;
        _newContainerCount = _totalGallons > 0 ? _totalGallons : 1;
        _borrowCount = 0;
        _syncAllocationControllers();
        _totalGallons = _newContainerCount;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> loadAddresses({bool force = false}) async {
    if (_isLoadingAddresses && !force) return;

    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _savedAddresses = const [];
          _selectedAddress = null;
        });
        return;
      }

      final addresses = await Supabase.instance.client
          .from('user_addresses')
          .select('id,label,latitude,longitude,address')
          .eq('user_id', user.id);

      final addressList = List<Map<String, dynamic>>.from(addresses)
          .map((row) {
            final id = row['id']?.toString().trim();
            final address = row['address']?.toString().trim() ?? '';
            final label = row['label']?.toString().trim() ?? '';
            final lat = _toDouble(row['latitude']);
            final lng = _toDouble(row['longitude']);

            if (id == null || id.isEmpty || address.isEmpty) return null;

            return _SavedAddress(
              id: id,
              label: label,
              address: address,
              latitude: lat,
              longitude: lng,
            );
          })
          .whereType<_SavedAddress>()
          .toList();

      if (!mounted) return;

      setState(() {
        _savedAddresses = addressList;

        final selectedAddressId = _selectedAddress?.id;
        if (_savedAddresses.isEmpty) {
          _selectedAddress = null;
          return;
        }

        if (selectedAddressId != null && selectedAddressId.isNotEmpty) {
          for (final address in _savedAddresses) {
            if (address.id == selectedAddressId) {
              _selectedAddress = address;
              return;
            }
          }
        }

        _selectedAddress = _savedAddresses.first;
      });
    } catch (e) {
      debugPrint('Failed to load saved addresses: $e');
      if (!mounted) return;
      setState(() {
        _savedAddresses = const [];
        _selectedAddress = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  Future<void> _openDeliveryAddressScreen() async {
    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const AddressScreen(popOnAddressChange: true),
      ),
    ).then((_) {
      if (!mounted) return;
      loadAddresses(force: true);
    });
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String _toText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text;
  }

  String? _normalizeReceiptExtension(String fileName) {
    final normalizedFileName = fileName.trim().toLowerCase();
    final lastDotIndex = normalizedFileName.lastIndexOf('.');
    if (lastDotIndex == -1 || lastDotIndex == normalizedFileName.length - 1) {
      return null;
    }

    final extension = normalizedFileName.substring(lastDotIndex + 1);
    switch (extension) {
      case 'jpg':
        return 'jpg';
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        return null;
    }
  }

  String? _inferReceiptExtensionFromBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpeg';
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return null;
  }

  String? _receiptContentTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  TimeOfDay _preferredTimeForSlot() {
    switch (_deliveryTime) {
      case 'Afternoon':
        return const TimeOfDay(hour: 14, minute: 0);
      case 'Evening':
        return const TimeOfDay(hour: 18, minute: 0);
      case 'Morning':
      default:
        return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Future<void> _pickPaymentReceipt() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || pickedFile == null) {
        return;
      }

      setState(() {
        _paymentReceipt = pickedFile;
      });
    } on PlatformException catch (e) {
      debugPrint('Receipt picker failed: $e');
      if (!mounted) return;

      final message = e.code == 'photo_access_denied'
          ? 'Photo access is denied. Please allow access in your device settings and try again.'
          : 'Unable to select a payment receipt. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      debugPrint('Unexpected receipt picker error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to upload the payment receipt right now.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high);

    return await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }

  Future<void> _refreshCurrentLocationPreview() async {
    if (_isFetchingLocationPreview) return;

    setState(() {
      _isFetchingLocationPreview = true;
    });

    try {
      final position = await _getCurrentLocation();

      if (!mounted) return;
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });
    } catch (_) {
      // Keep the current UI if location cannot be fetched.
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocationPreview = false;
        });
      }
    }
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!_isPaymentMethodEnabled(_paymentMethod)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No payment method is currently available. Please contact the administrator.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      if (_paymentMethod == 'GCash') {
        setState(() {
          _paymentMethod = 'Cash';
          _paymentReceipt = null;
        });
      }
      return;
    }

    if (_products.isEmpty || _productError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load products. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Validate the customer's container allocation.
    final exchange = _parseQuantity(_exchangeController.text);
    final newContainers = _parseQuantity(_newController.text);
    final borrow = _parseQuantity(_borrowController.text);

    if (exchange > 0 && !_requiresExchange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exchange is not available for the selected product.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (borrow > 0 && !_borrowEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrowing is currently unavailable.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (borrow > _maximumBorrowContainers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Borrow quantity cannot exceed $_maximumBorrowContainers containers.',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final totalContainers = exchange + newContainers + borrow;
    if (totalContainers < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least 1 container.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _exchangeCount = exchange;
      _newContainerCount = newContainers;
      _borrowCount = borrow;
      _totalGallons = totalContainers;
      _containerAllocationError = null;
    });

    if (_savedAddresses.isEmpty || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved address found. Please add one first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedAddress!.latitude == null ||
        _selectedAddress!.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected address is missing coordinates.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_deliveryType == 'scheduled') {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select both date and time for scheduled delivery.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    final product = _selectedProduct!;

    if (_paymentMethod == 'GCash' && _paymentReceipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload your GCash payment receipt before placing the order.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    var isLoadingShown = false;

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Placing your order...')),
              ],
            ),
          );
        },
      );
      isLoadingShown = true;

      final lat = _selectedAddress!.latitude!;
      final lng = _selectedAddress!.longitude!;

      if (mounted) {
        setState(() {
          _currentLat = lat;
          _currentLng = lng;
        });
      }

      debugPrint('Customer Lat: $lat');
      debugPrint('Customer Lng: $lng');

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please login first');
      }

      String? receiptUrl;
      if (_paymentMethod == 'GCash') {
        final paymentReceipt = _paymentReceipt;
        if (paymentReceipt == null) {
          throw Exception(
            'Please upload your GCash payment receipt before placing the order.',
          );
        }

        try {
          debugPrint('STARTING PAYMENT RECEIPT UPLOAD');
          debugPrint('Receipt name: ${paymentReceipt.name}');
          debugPrint('Receipt path: ${paymentReceipt.path}');
          debugPrint('Bucket: payment-receipts');
          debugPrint('Authenticated user ID: ${user.id}');

          final bytes = await paymentReceipt.readAsBytes();
          if (bytes.isEmpty) {
            throw Exception(
              'Receipt image is empty. Please choose another file.',
            );
          }

          final receiptExtension =
              _normalizeReceiptExtension(paymentReceipt.name) ??
              _normalizeReceiptExtension(paymentReceipt.path) ??
              _inferReceiptExtensionFromBytes(bytes);
          if (receiptExtension == null) {
            throw Exception(
              'Unsupported receipt image format. Please upload a JPG, PNG, or WEBP image.',
            );
          }

          final contentType = _receiptContentTypeForExtension(receiptExtension);
          if (contentType == null) {
            throw Exception(
              'Unsupported receipt image format. Please upload a JPG, PNG, or WEBP image.',
            );
          }

          final filePath =
              '${user.id}/receipt_${DateTime.now().millisecondsSinceEpoch}.$receiptExtension';

          debugPrint('Storage path: $filePath');
          debugPrint('Content type: $contentType');
          debugPrint('File size: ${bytes.length} bytes');

          await supabase.storage
              .from('payment-receipts')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(
                  upsert: false,
                  cacheControl: '3600',
                  contentType: contentType,
                ),
              );

          receiptUrl = filePath;
          debugPrint('PAYMENT RECEIPT UPLOAD SUCCESS');
          debugPrint('Uploaded path: $filePath');
        } catch (e, stackTrace) {
          debugPrint('PAYMENT RECEIPT UPLOAD FAILED');
          debugPrint('Error: $e');
          debugPrint('Error type: ${e.runtimeType}');
          debugPrint('Stack trace: $stackTrace');

          final customerMessage = e.toString().replaceFirst('Exception: ', '');
          if (customerMessage ==
                  'Unsupported receipt image format. Please upload a JPG, PNG, or WEBP image.' ||
              customerMessage ==
                  'Receipt image is empty. Please choose another file.') {
            rethrow;
          }

          throw Exception(
            'Unable to upload your payment receipt. Please check your connection and try again.',
          );
        }
      }

      final scheduledDate =
          _deliveryType == 'scheduled' && _selectedDate != null
          ? _selectedDate!.toIso8601String().split('T')[0]
          : null;

      final scheduledTimeToSave = _deliveryType == 'scheduled'
          ? (_selectedTime ?? _preferredTimeForSlot())
          : null;
      final scheduledTimeString = scheduledTimeToSave == null
          ? null
          : '${scheduledTimeToSave.hour.toString().padLeft(2, '0')}:${scheduledTimeToSave.minute.toString().padLeft(2, '0')}';

      var activeOrderLimit = 3;
      try {
        final settings = await supabase
            .from('system_settings')
            .select('max_active_orders_per_customer')
            .limit(1)
            .maybeSingle();
        final configuredLimit = settings?['max_active_orders_per_customer'];
        if (configuredLimit is int && configuredLimit > 0) {
          activeOrderLimit = configuredLimit;
        } else if (configuredLimit is num && configuredLimit > 0) {
          activeOrderLimit = configuredLimit.toInt();
        }
      } catch (error) {
        debugPrint('Failed to load active order limit; using 3: $error');
      }

      final customerOrders = await supabase
          .from('orders')
          .select('status,reservation_status')
          .eq('customer_id', user.id);
      final activeOrderCount = List<Map<String, dynamic>>.from(customerOrders)
          .where((order) {
            final status = order['status']?.toString().toLowerCase();
            final reservationStatus = order['reservation_status']
                ?.toString()
                .toLowerCase();
            return status == 'pending' ||
                reservationStatus == 'pending' ||
                reservationStatus == 'scheduled';
          })
          .length;

      if (activeOrderCount >= activeOrderLimit) {
        if (isLoadingShown && mounted) {
          Navigator.of(context).pop();
          isLoadingShown = false;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You already have 3 pending orders. Please wait until the station accepts one of your orders before placing another.',
              ),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        return;
      }

      final insertedOrder = await supabase
          .from('orders')
          .insert({
            // Persist the selected product snapshot with every order so
            // reports, receipts, and historical records remain accurate even if
            // the admin later renames or edits the product.
            'product_id': product.id,
            'product_name': product.productName,
            'capacity': product.capacity,
            'base_price': product.basePrice,
            'exchange_price': product.exchangePrice,
            // `exchange_required` is saved below using the customer's
            // actual selected exchange quantity, not the product setting.
            // Save the selected payment method. GCash orders require
            // the full order amount and an uploaded receipt for admin verification.
            'payment_method': _paymentMethod,
            'payment_status': 'Pending',
            'receipt_url': _paymentMethod == 'GCash' ? receiptUrl : null,
            'customer_id': user.id,
            'customer_name':
                (user.userMetadata?['full_name'] as String?)
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? (user.userMetadata?['full_name'] as String).trim()
                : 'Customer',
            'address': _selectedAddress!.address,
            'address_id': _selectedAddress!.id,
            'delivery_instructions':
                _deliveryInstructionsController.text.trim().isEmpty
                ? null
                : _deliveryInstructionsController.text.trim(),
            'customer_lat': lat,
            'customer_lng': lng,
            // Keep existing columns in sync for compatibility in map views.
            'latitude': lat,
            'longitude': lng,
            'gallons': _totalGallons,
            'total_price': _estimatedPrice,

            // Save the customer's actual container choice.
            // These values are different from the product's
            // `exchange_required` setting, which only describes whether
            // exchange is supported/available for the product.
            'exchange_containers': _exchangeCount,
            'new_containers': _newContainerCount,
            'borrow_containers': _borrowCount,
            'borrow_status': _borrowCount > 0 ? 'requested' : 'none',
            'borrow_notes': _borrowCount > 0
                ? 'Customer requested borrowed container.'
                : null,
            'with_exchange': _exchangeCount > 0,
            'exchange_required': _exchangeCount > 0,

            'delivery_type': _deliveryType,
            'scheduled_date': scheduledDate,
            'scheduled_time': scheduledTimeString,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      if (isLoadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingShown = false;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerTrackOrderScreen(order: insertedOrder),
        ),
      );
    } catch (e) {
      if (isLoadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingShown = false;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Order Water',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isLoadingProducts
                  ? 'Loading...'
                  : (_selectedProduct != null
                        ? '₱$_estimatedPrice est.'
                        : (_productError != null
                              ? 'Unable to load products'
                              : 'No product selected')),
              style: const TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _SectionCard(
                    title: 'Products',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose a product for this order',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_isLoadingProducts)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Loading available products...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else if (_productError != null)
                          Text(
                            _productError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (_products.isEmpty)
                          const Text(
                            'No available products found.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else
                          Column(
                            children: _products
                                .map(
                                  (product) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ProductTile(
                                      product: product,
                                      selected:
                                          _selectedProduct?.id == product.id,
                                      onTap: () => _selectProduct(product),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Quantity',
                    icon: Icons.water_drop_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total containers to order',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_totalGallons',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Total is calculated automatically from Exchange, New, and Borrow quantities below.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _deliveryInstructionsController,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 300,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            labelText: 'Delivery instructions (optional)',
                            hintText:
                                'Floor, unit, gate color, or nearby landmark',
                            alignLabelWithHint: true,
                            prefixIcon: const Icon(
                              Icons.sticky_note_2_outlined,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Container Details',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter how many containers you want for each option.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_requiresExchange) ...[
                          _QuantityInputCard(
                            title: 'With Exchange',
                            subtitle: 'Return an empty container',
                            priceText: _selectedProduct == null
                                ? 'Select product'
                                : '₱${_selectedProduct!.exchangePrice} each',
                            controller: _exchangeController,
                            onChanged: _onExchangeChanged,
                            icon: Icons.swap_horiz_rounded,
                            accentColor: const Color(0xFF1D4ED8),
                            backgroundColor: const Color(0xFFDBEAFE),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _QuantityInputCard(
                          title: 'New Containers',
                          subtitle: 'Buy a new container',
                          priceText: _selectedProduct == null
                              ? 'Select product'
                              : '₱${_selectedProduct!.basePrice} each',
                          controller: _newController,
                          onChanged: _onNewChanged,
                          icon: Icons.add_box_outlined,
                          accentColor: const Color(0xFFB45309),
                          backgroundColor: const Color(0xFFFEF3C7),
                        ),
                        const SizedBox(height: 10),
                        _QuantityInputCard(
                          title: 'Borrow Containers',
                          subtitle: _borrowEnabled
                              ? 'Temporarily borrow • Maximum $_maximumBorrowContainers'
                              : 'Borrowing is currently unavailable',
                          priceText: _borrowEnabled
                              ? (_selectedProduct == null
                                    ? 'Select product'
                                    : '₱${_selectedProduct!.basePrice} each')
                              : 'Unavailable',
                          controller: _borrowController,
                          onChanged: _onBorrowChanged,
                          enabled: _borrowEnabled,
                          icon: Icons.inventory_2_outlined,
                          accentColor: const Color(0xFF92400E),
                          backgroundColor: const Color(0xFFFEF3C7),
                        ),
                        if (_borrowEnabled && _borrowCount > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 0.7,
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 17,
                                  color: Color(0xFFB45309),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Borrowed containers are not expected back during this delivery. The driver will record them, and you can return them later.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.4,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_containerAllocationError != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              _containerAllocationError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Delivery Address',
                    icon: Icons.location_on_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingAddresses)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Loading saved addresses...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _openDeliveryAddressScreen,
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: const Text('Manage addresses'),
                          ),
                        ),
                        if (_savedAddresses.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'No address available',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        else ...[
                          // Dropdown for address selection
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAddress?.id,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 0.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 1.2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              hintText: 'Select an address',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            isExpanded: true,
                            items: _savedAddresses.map((address) {
                              return DropdownMenuItem<String>(
                                value: address.id,
                                child: Text(
                                  address.label.isNotEmpty
                                      ? address.label
                                      : address.address,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? addressId) {
                              if (addressId != null) {
                                setState(() {
                                  _selectedAddress = _savedAddresses.firstWhere(
                                    (addr) => addr.id == addressId,
                                    orElse: () => _savedAddresses.first,
                                  );
                                });
                              }
                            },
                          ),
                          // Selected address preview
                          if (_selectedAddress != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFDBEAFE),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAddress!.label.isNotEmpty
                                        ? _selectedAddress!.label
                                        : 'Saved Address',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedAddress!.address,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  if (_selectedAddress!.latitude != null &&
                                      _selectedAddress!.longitude != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Lat: ${_selectedAddress!.latitude!.toStringAsFixed(5)}, Lng: ${_selectedAddress!.longitude!.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.my_location,
                                size: 16,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentLat != null && _currentLng != null
                                      ? 'Current location: ${_currentLat!.toStringAsFixed(5)}, ${_currentLng!.toStringAsFixed(5)}'
                                      : 'Current location not available yet',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _isFetchingLocationPreview
                                    ? null
                                    : _refreshCurrentLocationPreview,
                                child: Text(
                                  _isFetchingLocationPreview
                                      ? 'Loading...'
                                      : 'Refresh',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Delivery Type',
                    icon: Icons.local_shipping_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose when you want this order delivered',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _DeliveryTypeOption(
                                title: 'Deliver Now',
                                selected: _deliveryType == 'now',
                                onTap: () {
                                  setState(() {
                                    _deliveryType = 'now';
                                    _selectedTime = null;
                                  });
                                },
                              ),
                              _DeliveryTypeOption(
                                title: 'Schedule Delivery',
                                selected: _deliveryType == 'scheduled',
                                onTap: () {
                                  setState(() {
                                    _deliveryType = 'scheduled';
                                    _selectedTime ??= _preferredTimeForSlot();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (_deliveryType == 'scheduled') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _selectedDate == null
                                        ? 'Select Date'
                                        : _formatDate(_selectedDate!),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF334155),
                                    side: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: ['Morning', 'Afternoon', 'Evening'].map((
                              slot,
                            ) {
                              final selected = _deliveryTime == slot;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: slot != 'Evening' ? 8 : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _deliveryTime = slot;
                                        _selectedTime = _preferredTimeForSlot();
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _primaryBlue
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? _primaryBlue
                                              : const Color(0xFFE2E8F0),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        slot,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_selectedDate != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Scheduled on ${_formatDate(_selectedDate!)} at $_deliveryTime',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Payment Method',
                    icon: Icons.payments_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose how you want to pay for this order',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_isCodAvailable)
                                _PaymentMethodOption(
                                  title: 'Cash on Delivery',
                                  subtitle: 'Pay upon delivery.',
                                  selected: _paymentMethod == 'Cash',
                                  onTap: () {
                                    if (_paymentMethod == 'Cash') {
                                      return;
                                    }
                                    setState(() {
                                      _paymentMethod = 'Cash';
                                    });
                                  },
                                ),
                              if (_loadingPaymentSettings)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Loading payment settings...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_isGcashAvailable)
                                _PaymentMethodOption(
                                  title: 'GCash',
                                  subtitle: 'Pay using GCash.',
                                  selected: _paymentMethod == 'GCash',
                                  onTap: () {
                                    if (_paymentMethod == 'GCash') {
                                      return;
                                    }
                                    setState(() {
                                      _paymentMethod = 'GCash';
                                    });
                                  },
                                ),
                              if (!_loadingPaymentSettings &&
                                  !_hasAnyPaymentMethodAvailable)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    'No payment method is currently available. Please contact the administrator.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_paymentSettingsFailed) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Unable to load payment settings. Cash remains available.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_codEnabled && _codVerification) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Cash on Delivery requires verification.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_paymentMethod == 'GCash' && _isGcashAvailable) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDBEAFE),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'GCash Account Name',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _gcashAccountName.isEmpty
                                            ? 'Unavailable'
                                            : _gcashAccountName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'GCash Number',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _gcashNumber.isEmpty
                                            ? 'Unavailable'
                                            : _gcashNumber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Amount to Pay',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₱$_estimatedPrice',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_gcashQrCodeUrl.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Semantics(
                                    button: true,
                                    label: 'Enlarge GCash payment QR code',
                                    child: GestureDetector(
                                      onTap: _showGcashQrCode,
                                      child: _GcashQrImage(
                                        imageUrl: _gcashQrCodeUrl,
                                        size: 104,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Upload Payment Receipt',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'After completing your GCash payment, upload the transaction receipt before placing your order.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_paymentReceipt == null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _pickPaymentReceipt,
                                      icon: const Icon(
                                        Icons.upload_file_outlined,
                                      ),
                                      label: const Text('Upload Receipt'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF2563EB,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFBFDBFE),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        minimumSize: const Size(0, 46),
                                      ),
                                    ),
                                  )
                                else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF15803D),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _paymentReceipt!.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF166534),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: _pickPaymentReceipt,
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Change Receipt'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Selected Product',
                          value:
                              _selectedProduct?.productName ??
                              'No product selected',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Capacity',
                          value:
                              _selectedProduct?.capacity ??
                              'No product selected',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(label: 'Quantity', value: '$_totalGallons'),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'With Exchange',
                          value: '$_exchangeCount',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'New Containers',
                          value: '$_newContainerCount',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Borrow Containers',
                          value: '$_borrowCount',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Delivery Type',
                          value: _deliveryType == 'now'
                              ? 'Deliver Now'
                              : 'Scheduled',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Payment Method',
                          value: _paymentMethod,
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Order Total',
                          value: '₱${_estimatedPrice.toStringAsFixed(0)}',
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Preferred Time',
                          value: _deliveryType == 'scheduled'
                              ? _deliveryTime
                              : 'Any time',
                        ),
                        if (_deliveryType == 'scheduled' &&
                            _selectedDate != null &&
                            _deliveryTime.isNotEmpty) ...[
                          const _SummaryDivider(),
                          _SummaryRow(
                            label: 'Scheduled For',
                            value:
                                '${_formatDate(_selectedDate!)} $_deliveryTime',
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Estimated Total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱$_estimatedPrice',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: Color(0xFF15803D),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ready to order',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.water_drop_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Placing Order...' : 'Place Order',
                    style: const TextStyle(
                      fontSize: 16,
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
            ),
          ],
        ),
      ),
    );
  }

  void _showGcashQrCode() {
    final imageUrl = _gcashQrCodeUrl;
    if (imageUrl.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _GcashQrImage(imageUrl: imageUrl, size: 280),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A233455),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 20, thickness: 0.5, color: Color(0xFFE2E8F0));
  }
}

class _QuantityInputCard extends StatelessWidget {
  const _QuantityInputCard({
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.controller,
    required this.onChanged,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final String priceText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        priceText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: enabled ? Colors.white : const Color(0xFFE2E8F0),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTypeOption extends StatelessWidget {
  const _DeliveryTypeOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Product {
  const _Product({
    required this.id,
    required this.productName,
    required this.capacity,
    required this.basePrice,
    required this.exchangePrice,
    required this.exchangeRequired,
  });

  final String id;
  final String productName;
  final String capacity;
  final int basePrice;
  final int exchangePrice;
  final bool exchangeRequired;

  factory _Product.fromMap(Map<String, dynamic> row) {
    return _Product(
      id: row['id']?.toString().trim() ?? '',
      productName: row['product_name']?.toString().trim() ?? '',
      capacity: row['capacity']?.toString().trim() ?? '',
      basePrice: _parseInt(row['base_price']),
      exchangePrice: _parseInt(row['exchange_price']),
      exchangeRequired: _parseBool(row['exchange_required']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final _Product product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.capacity,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProductBadge(
                          label: 'Base ₱${product.basePrice}',
                          backgroundColor: const Color(0xFFDBEAFE),
                          textColor: const Color(0xFF1D4ED8),
                        ),
                        _ProductBadge(
                          label: product.exchangeRequired
                              ? 'Exchange ₱${product.exchangePrice}'
                              : 'Exchange not required',
                          backgroundColor: product.exchangeRequired
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF1F5F9),
                          textColor: product.exchangeRequired
                              ? const Color(0xFFB45309)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _SavedAddress {
  const _SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;

  String get displayText {
    if (label.trim().isNotEmpty && address.trim().isNotEmpty) {
      return '$label - $address';
    }
    return label.trim().isNotEmpty ? label : address;
  }
}

class _GcashQrImage extends StatelessWidget {
  const _GcashQrImage({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Color(0xFFF8FAFC),
          child: Icon(
            Icons.qr_code_2_rounded,
            color: Color(0xFF94A3B8),
            size: 36,
          ),
        ),
      ),
    );
  }
}
