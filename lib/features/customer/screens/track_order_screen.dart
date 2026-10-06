import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({
    super.key,
    this.orderId = 'Order #001',
    this.totalGallons = 5,
    this.address = 'Home Address, Cebu City',
    this.deliveryType = 'now',
    this.status = 'pending',
    this.scheduledDate,
    this.scheduledTime,
    this.driverName = 'John Doe',
    this.driverPhone = '+63 912 345 6789',
  });

  final String orderId;
  final int totalGallons;
  final String address;
  final String deliveryType;
  final String status;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;
  final String driverName;
  final String driverPhone;

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF6F8FB);

  static const LatLng _customerLocation =
      LatLng(14.5995, 120.9842);

  static const LatLng _driverLocation =
      LatLng(14.6095, 120.9892);

  String get _normalizedStatus {
    final raw = widget.status
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');

    if (raw.contains('delivered') ||
        raw.contains('completed')) {
      return 'delivered';
    }

    if (raw.contains('assigned')) {
      return 'assigned';
    }

    if (raw.contains('scheduled')) {
      return 'scheduled';
    }

    if (raw.contains('on_the_way') ||
        raw.contains('out_for_delivery')) {
      return 'on_the_way';
    }

    if (raw.contains('confirmed')) {
      return widget.deliveryType == 'scheduled'
          ? 'scheduled'
          : 'on_the_way';
    }

    return 'pending';
  }

  DateTime? get _effectiveScheduledDate {
    if (_normalizedStatus != 'scheduled') {
      return null;
    }

    return widget.scheduledDate ?? DateTime.now();
  }

  TimeOfDay? get _effectiveScheduledTime {
    if (_normalizedStatus != 'scheduled') {
      return null;
    }

    return widget.scheduledTime ??
        const TimeOfDay(hour: 9, minute: 0);
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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String _statusTitle() {
    switch (_normalizedStatus) {
      case 'assigned':
        return 'Driver Assigned';

      case 'scheduled':
        return 'Scheduled Delivery';

      case 'delivered':
        return 'Delivered';

      case 'on_the_way':
        return 'Driver is on the way';

      default:
        return 'Waiting for Confirmation';
    }
  }

  String _statusMessage() {
    switch (_normalizedStatus) {
      case 'assigned':
        return 'Driver has been assigned to your order.';

      case 'scheduled':
        return 'Your order is scheduled for delivery.';

      case 'delivered':
        return 'Your order has been successfully delivered.';

      case 'on_the_way':
        return 'Your driver is currently on the way.';

      default:
        return 'Waiting for store confirmation.';
    }
  }

  Widget _buildStatusCard() {
    final scheduledDate = _effectiveScheduledDate;
    final scheduledTime = _effectiveScheduledTime;

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _statusTitle(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF854D0E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage(),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          if (_normalizedStatus == 'scheduled' &&
              scheduledDate != null &&
              scheduledTime != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_formatDate(scheduledDate)} • '
              '${scheduledTime.format(context)}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (_normalizedStatus == 'pending' ||
        _normalizedStatus == 'scheduled') {
      return _CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Delivery',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFC7D7FE),
                ),
              ),
              child: const Text(
                'Tracking will be available once '
                'your order is accepted.',
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Track Delivery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: _customerLocation,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/'
                        '{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.aquaenlavada.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _customerLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.home,
                          color: Colors.green,
                          size: 36,
                        ),
                      ),
                      Marker(
                        point: _driverLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.blue,
                          size: 36,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDate = _effectiveScheduledDate;
    final scheduledTime = _effectiveScheduledTime;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),

          const SizedBox(height: 14),

          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Order ID',
                  value: widget.orderId,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Containers Ordered',
                  value:
                      '${widget.totalGallons} Containers',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Address',
                  value: widget.address,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _buildMapSection(),

          const SizedBox(height: 14),

          _CardContainer(
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: _primaryBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (scheduledDate != null &&
              scheduledTime != null) ...[
            const SizedBox(height: 14),
            _CardContainer(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scheduled Delivery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(scheduledDate)} • '
                    '${scheduledTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| CUSTOMER TRACK ORDER SCREEN
|--------------------------------------------------------------------------
*/

class CustomerTrackOrderScreen
    extends StatefulWidget {
  const CustomerTrackOrderScreen({
    super.key,
    required this.order,
  });

  final Map<String, dynamic> order;

  @override
  State<CustomerTrackOrderScreen> createState() =>
      _CustomerTrackOrderScreenState();
}

class _CustomerTrackOrderScreenState
    extends State<CustomerTrackOrderScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _liveOrder =
      <String, dynamic>{};

  Timer? _timer;

  String? driverName;
  String driverPhone = '';

  bool isLoadingDriver = false;

  String? _currentDriverId;

  bool _isRefreshing = false;

  // ---------------------------------------------------------------------------
  // FEEDBACK
  // ---------------------------------------------------------------------------

  bool _feedbackLoading = false;
  bool _feedbackSubmitting = false;
  bool _hasFeedback = false;
  bool _feedbackChecked = false;

  int _driverRating = 0;
  int _stationRating = 0;

  String _existingFeedbackComment = '';
  String _adminReply = '';
  String _adminRepliedAt = '';

  final TextEditingController _feedbackCommentController =
      TextEditingController();

  static const Color _background =
      Color(0xFFF6F8FB);

  static const Color _primaryBlue =
      Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _liveOrder =
        Map<String, dynamic>.from(widget.order);

    loadDriver();
    fetchOrder();
    startAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {
    if (state ==
        AppLifecycleState.resumed) {
      fetchOrder();
      startAutoRefresh();
    }

    if (state ==
        AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    WidgetsBinding.instance
        .removeObserver(this);

    _feedbackCommentController.dispose();

    super.dispose();
  }

  /*
  |--------------------------------------------------------------------------
  | AUTO REFRESH
  |--------------------------------------------------------------------------
  */

  void startAutoRefresh() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        fetchOrder();
      },
    );
  }

  /*
  |--------------------------------------------------------------------------
  | FETCH LATEST ORDER
  |--------------------------------------------------------------------------
  */

  Future<void> fetchOrder() async {
    if (_isRefreshing) {
      return;
    }

    final orderId =
        _liveOrder['id']
                ?.toString()
                .trim() ??
            '';

    if (orderId.isEmpty) {
      return;
    }

    _isRefreshing = true;

    try {
      final response =
          await Supabase.instance.client
              .from('orders')
              .select()
              .eq('id', orderId)
              .maybeSingle();

      if (!mounted || response == null) {
        return;
      }

      /*
      |--------------------------------------------------------------------------
      | DRIVER INFORMATION
      |--------------------------------------------------------------------------
      |
      | Keep driver information already stored in the order.
      | Then try employees.id, followed by employees.user_id.
      |
      */

      final driverId =
          response['driver_id']?.toString().trim() ?? '';

      String existingDriverName =
          response['driver_name']?.toString().trim() ?? '';

      String existingDriverPhone =
          response['driver_phone']?.toString().trim() ?? '';

      if (driverId.isNotEmpty) {
        Map<String, dynamic>? driverData;

        // First try employees.id.
        try {
          final result =
              await Supabase.instance.client
                  .from('employees')
                  .select('*')
                  .eq('id', driverId)
                  .maybeSingle();

          if (result != null) {
            driverData =
                Map<String, dynamic>.from(result);
          }
        } catch (e) {
          debugPrint(
            'fetchOrder driver lookup by id failed: $e',
          );
        }

        // If not found, try employees.user_id.
        if (driverData == null) {
          try {
            final result =
                await Supabase.instance.client
                    .from('employees')
                    .select('*')
                    .eq('user_id', driverId)
                    .maybeSingle();

            if (result != null) {
              driverData =
                  Map<String, dynamic>.from(result);
            }
          } catch (e) {
            debugPrint(
              'fetchOrder driver lookup by user_id failed: $e',
            );
          }
        }

        if (driverData != null) {
          final employeeName =
              driverData['full_name']?.toString().trim().isNotEmpty == true
                  ? driverData['full_name'].toString().trim()
                  : driverData['name']?.toString().trim().isNotEmpty == true
                      ? driverData['name'].toString().trim()
                      : driverData['employee_name']?.toString().trim().isNotEmpty == true
                          ? driverData['employee_name'].toString().trim()
                          : driverData['display_name']?.toString().trim().isNotEmpty == true
                              ? driverData['display_name'].toString().trim()
                              : '';

          final employeePhone =
              driverData['phone']?.toString().trim().isNotEmpty == true
                  ? driverData['phone'].toString().trim()
                  : driverData['mobile_number']?.toString().trim().isNotEmpty == true
                      ? driverData['mobile_number'].toString().trim()
                      : driverData['contact_number']?.toString().trim().isNotEmpty == true
                          ? driverData['contact_number'].toString().trim()
                          : '';

          if (employeeName.isNotEmpty) {
            existingDriverName = employeeName;
          }

          if (employeePhone.isNotEmpty) {
            existingDriverPhone = employeePhone;
          }
        }
      }

      // Preserve valid driver information on the order.
      if (existingDriverName.isNotEmpty) {
        response['driver_name'] =
            existingDriverName;
      }

      if (existingDriverPhone.isNotEmpty) {
        response['driver_phone'] =
            existingDriverPhone;
      }

      final oldOrder = _liveOrder;

      final oldStatus =
          oldOrder['status']?.toString();

      final newStatus =
          response['status']?.toString();

      final oldPayment =
          _normalizePaymentStatus(
        oldOrder['payment_status']
            ?.toString(),
      );

      final newPayment =
          _normalizePaymentStatus(
        response['payment_status']
            ?.toString(),
      );

      final oldVerifiedAt =
          oldOrder['payment_verified_at']
              ?.toString();

      final newVerifiedAt =
          response['payment_verified_at']
              ?.toString();

      final oldRejectedAt =
          oldOrder['payment_rejected_at']
              ?.toString();

      final newRejectedAt =
          response['payment_rejected_at']
              ?.toString();

      final oldReason =
          oldOrder[
                  'payment_rejection_reason']
              ?.toString();

      final newReason =
          response[
                  'payment_rejection_reason']
              ?.toString();

      final oldDriverId =
          oldOrder['driver_id']
              ?.toString();

      final newDriverId =
          response['driver_id']
              ?.toString();

      final changed =
          oldStatus != newStatus ||
          oldPayment != newPayment ||
          oldVerifiedAt != newVerifiedAt ||
          oldRejectedAt != newRejectedAt ||
          oldReason != newReason ||
          oldDriverId != newDriverId ||
          oldOrder['driver_name'] !=
              response['driver_name'] ||
          oldOrder['driver_phone'] !=
              response['driver_phone'];

      if (changed) {
        setState(() {
          _liveOrder =
              Map<String, dynamic>.from(
            response,
          );
        });

        await loadDriver();
      } else {
        _liveOrder =
            Map<String, dynamic>.from(
          response,
        );
      }

      // Once the order reaches delivered, load its real feedback record.
      if (_normalizedStatus() == 'delivered') {
        await _loadFeedbackIfDelivered();
      }
    } catch (e) {
      debugPrint(
        'Track order refresh error: $e',
      );
    } finally {
      _isRefreshing = false;
    }
  }



  /*
  |--------------------------------------------------------------------------
  | FEEDBACK
  |--------------------------------------------------------------------------
  |
  | Customers can submit feedback only after the order is delivered.
  | Feedback is tied to the real order, customer, and driver IDs.
  |--------------------------------------------------------------------------
  */

  String? _feedbackCustomerId() {
    final orderCustomerId =
        _order['customer_id']?.toString().trim() ?? '';

    if (orderCustomerId.isNotEmpty) {
      return orderCustomerId;
    }

    final authUserId =
        Supabase.instance.client.auth.currentUser?.id
            .trim();

    return authUserId == null || authUserId.isEmpty
        ? null
        : authUserId;
  }

  String _feedbackOrderId() {
    return _order['id']?.toString().trim() ?? '';
  }

  String? _feedbackDriverId() {
    final value = _order['driver_id']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> _loadFeedbackIfDelivered({
    bool force = false,
  }) async {
    if (_normalizedStatus() != 'delivered') {
      return;
    }

    if (_feedbackChecked && !force) {
      return;
    }

    final orderId = _feedbackOrderId();
    if (orderId.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _feedbackLoading = true;
      });
    }

    try {
      final response =
          await Supabase.instance.client
              .from('feedback')
              .select('*')
              .eq('order_id', orderId)
              .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        final data =
            Map<String, dynamic>.from(response);

        final comment =
            data['comment']?.toString() ?? '';
        final adminReply =
            data['admin_reply']?.toString() ?? '';
        final adminRepliedAt =
            data['admin_replied_at']?.toString() ?? '';

        _driverRating =
            int.tryParse(
                  data['driver_rating']?.toString() ?? '',
                ) ??
                0;

        _stationRating =
            int.tryParse(
                  data['station_rating']?.toString() ?? '',
                ) ??
                0;

        _existingFeedbackComment = comment;
        _adminReply = adminReply.trim();
        _adminRepliedAt = adminRepliedAt.trim();
        _feedbackCommentController.text = comment;
      } else {
        _driverRating = 0;
        _stationRating = 0;
        _existingFeedbackComment = '';
        _adminReply = '';
        _adminRepliedAt = '';
        _feedbackCommentController.clear();
      }

      setState(() {
        _hasFeedback = response != null;
        _feedbackChecked = true;
        _feedbackLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Feedback load error: $e',
      );

      if (!mounted) return;

      setState(() {
        _feedbackLoading = false;
        _feedbackChecked = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (_feedbackSubmitting || _hasFeedback) {
      return;
    }

    if (_normalizedStatus() != 'delivered') {
      _showFeedbackMessage(
        'Feedback can only be submitted after delivery.',
        isError: true,
      );
      return;
    }

    final orderId = _feedbackOrderId();
    final customerId = _feedbackCustomerId();
    final driverId = _feedbackDriverId();

    if (orderId.isEmpty || customerId == null) {
      _showFeedbackMessage(
        'Unable to identify this order or customer.',
        isError: true,
      );
      return;
    }

    if (_driverRating < 1 || _stationRating < 1) {
      _showFeedbackMessage(
        'Please rate both the driver and the water station.',
        isError: true,
      );
      return;
    }

    final comment =
        _feedbackCommentController.text.trim();

    if (!mounted) return;

    setState(() {
      _feedbackSubmitting = true;
    });

    try {
      await Supabase.instance.client
          .from('feedback')
          .insert({
            'order_id': orderId,
            'customer_id': customerId,
            'driver_id': driverId,
            'driver_rating': _driverRating,
            'station_rating': _stationRating,
            'comment': comment.isEmpty ? null : comment,
          });

      if (!mounted) return;

      setState(() {
        _hasFeedback = true;
        _feedbackSubmitting = false;
        _feedbackChecked = true;
        _existingFeedbackComment = comment;
      });

      _showFeedbackMessage(
        'Thank you! Your feedback has been submitted.',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'Feedback submit error: ${e.message}',
      );

      // 23505 = duplicate order_id.
      // This can happen if another request submitted feedback
      // at the same time. Load the existing record instead of
      // showing the customer a misleading failure.
      if (e.code == '23505') {
        await _loadFeedbackIfDelivered(force: true);

        if (mounted && _hasFeedback) {
          _showFeedbackMessage(
            'Feedback for this order has already been submitted.',
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _feedbackSubmitting = false;
          });

          _showFeedbackMessage(
            'Unable to submit feedback. Please try again.',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Feedback submit error: $e',
      );

      if (!mounted) return;

      setState(() {
        _feedbackSubmitting = false;
      });

      _showFeedbackMessage(
        'Unable to submit feedback. Please try again.',
        isError: true,
      );
    }
  }

  void _showFeedbackMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildStarRating({
    required String title,
    required int rating,
    required ValueChanged<int> onChanged,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final selected = starNumber <= rating;

            return IconButton(
              onPressed: enabled
                  ? () => onChanged(starNumber)
                  : null,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: Icon(
                selected
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 34,
                color: selected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFCBD5E1),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    if (_normalizedStatus() != 'delivered' ||
        _isPaymentRejected) {
      return const SizedBox.shrink();
    }

    if (_feedbackLoading) {
      return const _CardContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_hasFeedback) {
      return _CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback Submitted',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Thank you for sharing your experience.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildStarRating(
              title: 'Driver',
              rating: _driverRating,
              onChanged: (_) {},
              enabled: false,
            ),
            const SizedBox(height: 12),
            _buildStarRating(
              title: 'Water Station',
              rating: _stationRating,
              onChanged: (_) {},
              enabled: false,
            ),
            if (_existingFeedbackComment.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  _existingFeedbackComment,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (_adminReply.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFBAE6FD),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          size: 18,
                          color: Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'HydroHub Response',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (_adminRepliedAt.trim().isNotEmpty)
                          Text(
                            _formatAdminReplyDateTime(_adminRepliedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _adminReply,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Your Experience',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your order has been delivered. Tell us how we did.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStarRating(
            title: 'How was your driver?',
            rating: _driverRating,
            onChanged: (value) {
              setState(() {
                _driverRating = value;
              });
            },
            enabled: !_feedbackSubmitting,
          ),
          const SizedBox(height: 12),
          _buildStarRating(
            title: 'How was the water station?',
            rating: _stationRating,
            onChanged: (value) {
              setState(() {
                _stationRating = value;
              });
            },
            enabled: !_feedbackSubmitting,
          ),
          const SizedBox(height: 14),
          const Text(
            'Additional comments',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackCommentController,
            enabled: !_feedbackSubmitting,
            maxLines: 4,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Tell us about your experience...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: _primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _feedbackSubmitting
                  ? null
                  : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF93C5FD),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _feedbackSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _feedbackSubmitting
                    ? 'Submitting...'
                    : 'Submit Feedback',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | DRIVER
  |--------------------------------------------------------------------------
  */

  Future<void> loadDriver() async {
    try {
      /*
      |--------------------------------------------------------------------------
      | DRIVER INFORMATION FROM ORDER
      |--------------------------------------------------------------------------
      |
      | Use driver_name / driver_phone already stored in the order first.
      | Then resolve the employee from employees.id or employees.user_id.
      |
      */

      final orderDriverName =
          _liveOrder['driver_name']?.toString().trim() ?? '';

      final orderDriverPhone =
          _liveOrder['driver_phone']?.toString().trim() ?? '';

      final driverId =
          _liveOrder['driver_id']?.toString().trim() ?? '';

      // If the order already has the driver's name, show it immediately.
      if (orderDriverName.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          driverName = orderDriverName;

          if (orderDriverPhone.isNotEmpty) {
            driverPhone = orderDriverPhone;
          }

          _currentDriverId =
              driverId.isNotEmpty ? driverId : null;

          isLoadingDriver = false;
        });
      }

      /*
      |--------------------------------------------------------------------------
      | NO DRIVER ASSIGNED
      |--------------------------------------------------------------------------
      */

      if (driverId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _currentDriverId = null;

          if (driverName == null ||
              driverName!.trim().isEmpty) {
            driverName = 'Waiting for driver...';
          }

          isLoadingDriver = false;
        });

        return;
      }

      /*
      |--------------------------------------------------------------------------
      | AVOID REPEATED LOOKUPS
      |--------------------------------------------------------------------------
      */

      if (_currentDriverId == driverId &&
          driverName != null &&
          driverName!.trim().isNotEmpty &&
          driverName != 'Waiting for driver...' &&
          driverName != 'Unable to load driver' &&
          driverName != 'Driver assigned') {
        return;
      }

      if (!mounted) return;

      setState(() {
        _currentDriverId = driverId;
        isLoadingDriver = true;
      });

      /*
      |--------------------------------------------------------------------------
      | TRY employees.id
      |--------------------------------------------------------------------------
      */

      Map<String, dynamic>? employee;

      try {
        final result =
            await Supabase.instance.client
                .from('employees')
                .select('*')
                .eq('id', driverId)
                .maybeSingle();

        if (result != null) {
          employee =
              Map<String, dynamic>.from(result);
        }
      } catch (e) {
        debugPrint(
          'Driver lookup by employees.id failed: $e',
        );
      }

      /*
      |--------------------------------------------------------------------------
      | TRY employees.user_id
      |--------------------------------------------------------------------------
      */

      if (employee == null) {
        try {
          final result =
              await Supabase.instance.client
                  .from('employees')
                  .select('*')
                  .eq('user_id', driverId)
                  .maybeSingle();

          if (result != null) {
            employee =
                Map<String, dynamic>.from(result);
          }
        } catch (e) {
          debugPrint(
            'Driver lookup by employees.user_id failed: $e',
          );
        }
      }

      /*
      |--------------------------------------------------------------------------
      | EMPLOYEE FOUND
      |--------------------------------------------------------------------------
      */

      if (employee != null) {
        final name =
            employee['full_name']?.toString().trim().isNotEmpty == true
                ? employee['full_name'].toString().trim()
                : employee['name']?.toString().trim().isNotEmpty == true
                    ? employee['name'].toString().trim()
                    : employee['employee_name']?.toString().trim().isNotEmpty == true
                        ? employee['employee_name'].toString().trim()
                        : employee['display_name']?.toString().trim().isNotEmpty == true
                            ? employee['display_name'].toString().trim()
                            : '';

        final phone =
            employee['phone']?.toString().trim().isNotEmpty == true
                ? employee['phone'].toString().trim()
                : employee['mobile_number']?.toString().trim().isNotEmpty == true
                    ? employee['mobile_number'].toString().trim()
                    : employee['contact_number']?.toString().trim().isNotEmpty == true
                        ? employee['contact_number'].toString().trim()
                        : '';

        if (!mounted) return;

        setState(() {
          if (name.isNotEmpty) {
            driverName = name;
          }

          if (phone.isNotEmpty) {
            driverPhone = phone;
          }

          isLoadingDriver = false;
        });

        return;
      }

      /*
      |--------------------------------------------------------------------------
      | EMPLOYEE RECORD NOT FOUND
      |--------------------------------------------------------------------------
      |
      | Do not overwrite an existing driver name.
      |
      */

      if (!mounted) return;

      setState(() {
        if (driverName == null ||
            driverName!.trim().isEmpty ||
            driverName == 'Waiting for driver...') {
          driverName = 'Driver assigned';
        }

        isLoadingDriver = false;
      });

      debugPrint(
        'Driver employee record not found for driver_id: $driverId',
      );
    } catch (e) {
      debugPrint(
        'Driver fetch error: $e',
      );

      if (!mounted) return;

      /*
      |--------------------------------------------------------------------------
      | ERROR HANDLING
      |--------------------------------------------------------------------------
      |
      | Keep the driver name already received from the order.
      | Never replace it with "Unable to load driver".
      |
      */

      setState(() {
        if (driverName == null ||
            driverName!.trim().isEmpty) {
          driverName = 'Driver assigned';
        }

        isLoadingDriver = false;
      });
    }
  }
  /*
  |--------------------------------------------------------------------------
  | ORDER HELPERS
  |--------------------------------------------------------------------------
  */

  Map<String, dynamic> get _order =>
      _liveOrder;

  String _status() {
    return '${_order['status'] ?? ''}'
        .trim()
        .toLowerCase();
  }

  String _normalizedStatus() {
    final raw =
        _status().replaceAll(
      ' ',
      '_',
    );

    if (raw == 'completed') {
      return 'delivered';
    }

    if (raw == 'delivering' ||
        raw == 'in_progress' ||
        raw == 'out_for_delivery') {
      return 'on_the_way';
    }

    if (raw == 'accepted' ||
        raw == 'preparing') {
      return 'assigned';
    }

    if (raw.isEmpty) {
      return 'pending';
    }

    return raw;
  }

  /*
  |--------------------------------------------------------------------------
  | PAYMENT STATUS
  |--------------------------------------------------------------------------
  */

  String _normalizePaymentStatus(
      String? rawValue) {
    final value =
        (rawValue ?? '').trim();

    if (value.isEmpty) {
      return 'Pending';
    }

    final normalized =
        value.toLowerCase().replaceAll(
              RegExp(r'\s+'),
              '_',
            );

    if (normalized.contains(
            'verified') ||
        normalized.contains(
            'approved')) {
      return 'Verified';
    }

    if (normalized.contains(
            'rejected') ||
        normalized.contains(
            'declined')) {
      return 'Rejected';
    }

    if (normalized.contains(
        'pending')) {
      return 'Pending';
    }

    return 'Pending';
  }

  String _paymentStatusLabel() {
    return _normalizePaymentStatus(
      _order['payment_status']
          ?.toString(),
    );
  }

  String _paymentMethodLabel() {
    final raw =
        (_order['payment_method']
                    ?.toString() ??
                'Cash')
            .trim()
            .toLowerCase();

    if (raw.contains('gcash')) {
      return 'GCash';
    }

    return 'Cash';
  }

  bool get _isPaymentRejected =>
      _paymentStatusLabel() ==
      'Rejected';

  bool get _isPaymentVerified =>
      _paymentStatusLabel() ==
      'Verified';

  bool _hasReceipt() {
    final receipt =
        _order['receipt_url']
            ?.toString()
            .trim();

    return receipt != null &&
        receipt.isNotEmpty;
  }

  /*
  |--------------------------------------------------------------------------
  | REJECTION REASON
  |--------------------------------------------------------------------------
  */

  String? _paymentRejectionReason() {
    final value =
        _order[
                'payment_rejection_reason']
            ?.toString()
            .trim();

    if (value == null ||
        value.isEmpty) {
      return null;
    }

    return value;
  }

  /*
  |--------------------------------------------------------------------------
  | PAYMENT VERIFIED DATE
  |--------------------------------------------------------------------------
  */

  DateTime? _paymentVerifiedAt() {
    final raw =
        _order['payment_verified_at'];

    if (raw is DateTime) {
      return raw;
    }

    if (raw is String &&
        raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }

    return null;
  }

  String _formatPaymentDateTime(
      DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour =
        dateTime.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        dateTime.minute
            .toString()
            .padLeft(2, '0');

    return '${months[dateTime.month - 1]} '
        '${dateTime.day}, '
        '${dateTime.year} • '
        '$hour:$minute';
  }

  String _formatAdminReplyDateTime(
      String rawValue) {
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) {
      return '';
    }

    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[local.month - 1]} '
        '${local.day}, '
        '${local.year}';
  }

  /*
  |--------------------------------------------------------------------------
  | PAYMENT CARD
  |--------------------------------------------------------------------------
  |
  | IMPORTANT:
  | - No Down Payment
  | - No Remaining Balance
  | - No GCash Reference
  | - GCash is FULL PAYMENT
  | - Receipt verification remains
  |--------------------------------------------------------------------------
  */

  Widget _buildPaymentStatusCard() {
    final paymentMethod =
        _paymentMethodLabel();

    /*
    |--------------------------------------------------------------------------
    | COD
    |--------------------------------------------------------------------------
    */

    if (paymentMethod != 'GCash') {
      return _CardContainer(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            _paymentBadge(
              text: 'Cash on Delivery',
              background:
                  const Color(0xFFE2E8F0),
              textColor:
                  const Color(0xFF334155),
            ),

            const SizedBox(height: 8),

            const Text(
              'Payment will be collected upon delivery.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    /*
    |--------------------------------------------------------------------------
    | REJECTED
    |--------------------------------------------------------------------------
    */

    if (_isPaymentRejected) {
      final reason =
          _paymentRejectionReason();

      return _CardContainer(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            _paymentBadge(
              text: 'Payment Rejected',
              background:
                  const Color(0xFFFEE2E2),
              textColor:
                  const Color(0xFFB91C1C),
            ),

            const SizedBox(height: 8),

            const Text(
              'Your GCash payment could not be verified.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),

            if (reason != null) ...[
              const SizedBox(height: 12),

              _InfoRow(
                label: 'Reason',
                value: reason,
              ),
            ],

            const SizedBox(height: 12),

            const Text(
              'Please contact HydroHub support if you believe this was a mistake.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFB91C1C),
                fontWeight:
                    FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    /*
    |--------------------------------------------------------------------------
    | VERIFIED
    |--------------------------------------------------------------------------
    */

    if (_isPaymentVerified) {
      final verifiedAt =
          _paymentVerifiedAt();

      return _CardContainer(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            _paymentBadge(
              text: 'Payment Verified',
              background:
                  const Color(0xFFDCFCE7),
              textColor:
                  const Color(0xFF166534),
            ),

            const SizedBox(height: 8),

            const Text(
              'Your full GCash payment has been verified. Your order can now proceed.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),

            const SizedBox(height: 12),

            _InfoRow(
              label: 'Payment Method',
              value: 'GCash',
            ),

            const SizedBox(height: 8),

            _InfoRow(
              label: 'Payment',
              value: 'Full Payment',
            ),

            const SizedBox(height: 8),

            _InfoRow(
              label: 'Receipt',
              value: _hasReceipt()
                  ? 'Submitted'
                  : 'Not available',
            ),

            if (verifiedAt != null) ...[
              const SizedBox(height: 8),

              _InfoRow(
                label: 'Verified At',
                value:
                    _formatPaymentDateTime(
                  verifiedAt,
                ),
              ),
            ],
          ],
        ),
      );
    }

    /*
    |--------------------------------------------------------------------------
    | PENDING VERIFICATION
    |--------------------------------------------------------------------------
    */

    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 12),

          _paymentBadge(
            text:
                'Payment Verification Pending',
            background:
                const Color(0xFFFEF3C7),
            textColor:
                const Color(0xFF854D0E),
          ),

          const SizedBox(height: 8),

          const Text(
            'Your full GCash payment is being verified by HydroHub.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 12),

          _InfoRow(
            label: 'Payment Method',
            value: 'GCash',
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Payment',
            value: 'Full Payment',
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Receipt',
            value: _hasReceipt()
                ? 'Submitted for verification'
                : 'Not submitted',
          ),
        ],
      ),
    );
  }

  Widget _paymentBadge({
    required String text,
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | ORDER STATUS
  |--------------------------------------------------------------------------
  */

  String _statusLabel() {
    if (_isPaymentRejected) {
      return 'Payment Rejected';
    }

    switch (_normalizedStatus()) {
      case 'pending':
        return 'Pending';

      case 'assigned':
        return 'Driver Assigned';

      case 'on_the_way':
        return 'Driver is on the way';

      case 'delivered':
        return 'Delivered';

      default:
        return 'Pending';
    }
  }

  String _statusMessageLive() {
    if (_isPaymentRejected) {
      return 'This order cannot proceed because the GCash payment was rejected.';
    }

    switch (_normalizedStatus()) {
      case 'pending':
        return 'Waiting for store confirmation.';

      case 'assigned':
        return 'A driver has been assigned to your order.';

      case 'on_the_way':
        return 'Your driver is currently on the way.';

      case 'delivered':
        return 'Your order has been successfully delivered.';

      default:
        return 'Waiting for store confirmation.';
    }
  }

  Color _statusColor() {
    if (_isPaymentRejected) {
      return const Color(0xFFB91C1C);
    }

    switch (_normalizedStatus()) {
      case 'pending':
        return const Color(0xFFCA8A04);

      case 'assigned':
        return const Color(0xFF2563EB);

      case 'on_the_way':
        return const Color(0xFFEA580C);

      case 'delivered':
        return const Color(0xFF16A34A);

      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusBackground() {
    if (_isPaymentRejected) {
      return const Color(0xFFFEE2E2);
    }

    switch (_normalizedStatus()) {
      case 'pending':
        return const Color(0xFFFEF3C7);

      case 'assigned':
        return const Color(0xFFDBEAFE);

      case 'on_the_way':
        return const Color(0xFFFFEDD5);

      case 'delivered':
        return const Color(0xFFDCFCE7);

      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Widget _buildStatusCardLive() {
    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _statusBackground(),
              borderRadius:
                  BorderRadius.circular(999),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
                color: _statusColor(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _statusMessageLive(),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | DELIVERY PROGRESS
  |--------------------------------------------------------------------------
  */

  int _currentStepIndex() {
    if (_isPaymentRejected) {
      return 0;
    }

    switch (_normalizedStatus()) {
      case 'pending':
        return 0;

      case 'assigned':
        return 1;

      case 'on_the_way':
        return 2;

      case 'delivered':
        return 3;

      default:
        return 0;
    }
  }

  Widget _buildProgressTrackerRow() {
    if (_isPaymentRejected) {
      return const SizedBox.shrink();
    }

    const steps = [
      'Order Placed',
      'Accepted',
      'On the Way',
      'Delivered',
    ];

    final currentStep =
        _currentStepIndex();

    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children:
                List.generate(
              steps.length,
              (index) {
                final isCompleted =
                    index <= currentStep;

                final isCurrent =
                    index == currentStep;

                return Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          isCompleted
                              ? const Color(
                                  0xFF16A34A,
                                )
                              : const Color(
                                  0xFFE2E8F0,
                                ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color:
                                  Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color: isCurrent
                                    ? _primaryBlue
                                    : const Color(
                                        0xFF94A3B8,
                                      ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: 70,
                      child: Text(
                        steps[index],
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isCurrent
                                  ? FontWeight
                                      .w700
                                  : FontWeight
                                      .w600,
                          color: isCompleted
                              ? const Color(
                                  0xFF0F172A,
                                )
                              : const Color(
                                  0xFF64748B,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | DRIVER
  |--------------------------------------------------------------------------
  */

  Widget _buildDirectDriverCard() {
    if (_isPaymentRejected) {
      return const SizedBox.shrink();
    }

    final displayName =
        driverName ??
            'Waiting for driver...';

    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Driver',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 12),

          isLoadingDriver
              ? const Text(
                  'Loading driver information...',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        Color(0xFF94A3B8),
                  ),
                )
              : _InfoRow(
                  label: 'Driver Name',
                  value: displayName,
                ),

          if (!isLoadingDriver &&
              driverPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Phone Number',
              value: driverPhone,
            ),
          ],
        ],
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | ORDER INFORMATION
  |--------------------------------------------------------------------------
  */

  String _gallons() {
    return '${_order['gallons'] ?? 0} Containers';
  }

  String _productName() {
    final value = _order['product_name']?.toString().trim() ?? '';
    return value.isEmpty ? 'Water' : value;
  }

  String _capacity() {
    final value = _order['capacity']?.toString().trim() ?? '';
    return value.isEmpty ? 'Size unavailable' : value;
  }

  String _address() {
    return '${_order['address'] ?? 'No address'}';
  }

  String _totalPayment() {
    final value =
        _order['total_price'];

    if (value is num) {
      return '₱${value.toStringAsFixed(0)}';
    }

    final parsed =
        num.tryParse(
      value?.toString() ?? '',
    );

    if (parsed != null) {
      return '₱${parsed.toStringAsFixed(0)}';
    }

    return 'Not available';
  }

  Widget _buildOrderInfoCard() {
    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 12),

          _InfoRow(
            label: 'Product',
            value: _productName(),
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Size',
            value: _capacity(),
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Quantity',
            value: _gallons(),
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Address',
            value: _address(),
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Total Payment',
            value: _totalPayment(),
          ),
        ],
      ),
    );
  }

  /*
  |--------------------------------------------------------------------------
  | MAP
  |--------------------------------------------------------------------------
  */

  double _latitude() {
    final value =
        _order['latitude'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        14.5995;
  }

  double _longitude() {
    final value =
        _order['longitude'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        120.9842;
  }

  double _driverLatitude() {
    final value =
        _order['driver_lat'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        14.5995;
  }

  double _driverLongitude() {
    final value =
        _order['driver_lng'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        120.9842;
  }

  bool _hasDriverLocation() {
    return _order['driver_lat'] != null &&
        _order['driver_lng'] != null;
  }

  bool get _isDelivering {
    if (_isPaymentRejected) {
      return false;
    }

    final status =
        _normalizedStatus();

    return status ==
            'on_the_way' ||
        status == 'delivering';
  }

  Widget _buildMapSectionLive() {
    if (!_isDelivering) {
      return const SizedBox.shrink();
    }

    final customerLocation =
        LatLng(
      _latitude(),
      _longitude(),
    );

    return _CardContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter:
                      customerLocation,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/'
                        '{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.aquaenlavada.app',
                  ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point:
                            customerLocation,
                        width: 50,
                        height: 50,
                        child:
                            const Icon(
                          Icons.location_on,
                          color:
                              Colors.red,
                          size: 40,
                        ),
                      ),

                      if (_hasDriverLocation())
                        Marker(
                          point: LatLng(
                            _driverLatitude(),
                            _driverLongitude(),
                          ),
                          width: 40,
                          height: 40,
                          child:
                              const Icon(
                            Icons
                                .delivery_dining,
                            color:
                                Colors.blue,
                            size: 36,
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
    );
  }

  /*
  |--------------------------------------------------------------------------
  | BUILD
  |--------------------------------------------------------------------------
  */

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,

      appBar: AppBar(
        title:
            const Text('Track Order'),
        backgroundColor:
            _background,
        elevation: 0,
        scrolledUnderElevation: 0,

        actions: [
          IconButton(
            tooltip:
                'Refresh order',
            onPressed:
                fetchOrder,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchOrder,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(16),

          children: [
            _buildStatusCardLive(),

            const SizedBox(height: 14),

            _buildPaymentStatusCard(),

            if (!_isPaymentRejected) ...[
              const SizedBox(height: 14),
              _buildProgressTrackerRow(),
            ],

            if (!_isPaymentRejected) ...[
              const SizedBox(height: 14),
              _buildDirectDriverCard(),
            ],

            const SizedBox(height: 14),

            _buildOrderInfoCard(),

            if (_normalizedStatus() == 'delivered' &&
                !_isPaymentRejected) ...[
              const SizedBox(height: 14),
              _buildFeedbackCard(),
            ],

            if (!_isPaymentRejected) ...[
              const SizedBox(height: 14),
              _buildMapSectionLive(),
            ],

            if (_isPaymentRejected) ...[
              const SizedBox(height: 14),

              _CardContainer(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color:
                          Color(0xFFDC2626),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'This order cannot proceed because '
                        'the GCash payment was rejected.',
                        style:
                            const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              Color(0xFF991B1B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| REUSABLE CARD
|--------------------------------------------------------------------------
*/

class _CardContainer
    extends StatelessWidget {
  const _CardContainer({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),

        boxShadow: const [
          BoxShadow(
            color:
                Color(0x14233455),
            blurRadius: 14,
            offset:
                Offset(0, 6),
          ),
        ],
      ),

      child: child,
    );
  }
}

/*
|--------------------------------------------------------------------------
| INFORMATION ROW
|--------------------------------------------------------------------------
*/

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          label,
          style: const TextStyle(
            color:
                Color(0xFF64748B),
            fontSize: 14,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            value,
            textAlign:
                TextAlign.end,
            style:
                const TextStyle(
              color:
                  Color(0xFF0F172A),
              fontWeight:
                  FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/*
|--------------------------------------------------------------------------
| STATUS HELPERS
|--------------------------------------------------------------------------
*/

int getStepIndex(
    String status) {
  final normalized =
      status
          .trim()
          .toLowerCase()
          .replaceAll(
            ' ',
            '_',
          );

  switch (normalized) {
    case 'pending':
      return 0;

    case 'accepted':
    case 'preparing':
    case 'assigned':
      return 1;

    case 'delivering':
    case 'in_progress':
    case 'out_for_delivery':
    case 'on_the_way':
      return 2;

    case 'completed':
    case 'delivered':
      return 3;

    default:
      return 0;
  }
}

String getStatusMessage(
    String status) {
  final normalized =
      status
          .trim()
          .toLowerCase()
          .replaceAll(
            ' ',
            '_',
          );

  switch (normalized) {
    case 'pending':
      return 'Waiting for store confirmation';

    case 'accepted':
    case 'preparing':
    case 'assigned':
      return 'Driver Assigned';

    case 'delivering':
    case 'in_progress':
    case 'out_for_delivery':
    case 'on_the_way':
      return 'Driver is on the way';

    case 'completed':
    case 'delivered':
      return 'Delivered';

    default:
      return 'Waiting for store confirmation';
  }
}