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
    this.status = 'on_the_way',
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
  static const LatLng _customerLocation = LatLng(14.5995, 120.9842);
  static const LatLng _driverLocation = LatLng(14.6095, 120.9892);

  String get _normalizedStatus {
    final raw = widget.status.trim().toLowerCase().replaceAll(' ', '_');

    if (raw.contains('delivered') || raw.contains('completed')) {
      return 'delivered';
    }
    if (raw.contains('scheduled')) {
      return 'scheduled';
    }
    if (raw.contains('on_the_way') || raw.contains('out_for_delivery')) {
      return 'on_the_way';
    }
    if (raw.contains('confirmed')) {
      return widget.deliveryType == 'scheduled' ? 'scheduled' : 'on_the_way';
    }

    return widget.deliveryType == 'scheduled' ? 'scheduled' : 'on_the_way';
  }

  DateTime? get _effectiveScheduledDate {
    if (_normalizedStatus != 'scheduled') {
      return null;
    }
    return widget.scheduledDate ?? DateTime(2026, 4, 20);
  }

  TimeOfDay? get _effectiveScheduledTime {
    if (_normalizedStatus != 'scheduled') {
      return null;
    }
    return widget.scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
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

  String _statusTitle() {
    switch (_normalizedStatus) {
      case 'scheduled':
        return 'Scheduled Delivery';
      case 'delivered':
        return 'Delivered';
      case 'on_the_way':
      default:
        return 'On the Way';
    }
  }

  String _statusMessage() {
    switch (_normalizedStatus) {
      case 'scheduled':
        return 'Your order is scheduled. Delivery will start at the selected time.';
      case 'delivered':
        return 'Order completed successfully';
      case 'on_the_way':
      default:
        return 'Driver is on the way';
    }
  }

  Widget _buildStatusCard() {
    final scheduledDate = _effectiveScheduledDate;
    final scheduledTime = _effectiveScheduledTime;

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusTitle(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (_normalizedStatus == 'scheduled' &&
              scheduledDate != null &&
              scheduledTime != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_formatDate(scheduledDate)} • ${scheduledTime.format(context)}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _statusMessage(),
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

  Widget _buildMapSection() {
    if (_normalizedStatus == 'scheduled') {
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
                border: Border.all(color: const Color(0xFFC7D7FE)),
              ),
              child: const Text(
                'Tracking will be available once delivery starts',
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
                _InfoRow(label: 'Order ID', value: widget.orderId),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Gallons Ordered',
                  value: '${widget.totalGallons} Gallons',
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Address', value: widget.address),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildMapSection(),
          const SizedBox(height: 14),
          _CardContainer(
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: _primaryBlue),
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
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14233455),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CustomerTrackOrderScreen extends StatefulWidget {
  const CustomerTrackOrderScreen({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<CustomerTrackOrderScreen> createState() =>
      _CustomerTrackOrderScreenState();
}

class _CustomerTrackOrderScreenState extends State<CustomerTrackOrderScreen> {
  Map<String, dynamic> _liveOrder = <String, dynamic>{};
  Timer? _timer;
  String? driverName;
  String driverPhone = '';
  bool isLoadingDriver = false;
  String? _currentDriverId;

  static const Color _background = Color(0xFFF6F8FB);

  @override
  void initState() {
    super.initState();
    _liveOrder = Map<String, dynamic>.from(widget.order);
    loadDriver();
    startAutoRefresh();
  }

  Future<void> loadDriver() async {
    try {
      final supabase = Supabase.instance.client;
      final driverId = _liveOrder['driver_id'];

      debugPrint('Driver ID from order: $driverId');

      // If no driver assigned yet
      if (driverId == null || driverId.toString().isEmpty) {
        if (!mounted) return;
        setState(() {
          _currentDriverId = null;
          driverName = 'Waiting for driver...';
          driverPhone = '';
          isLoadingDriver = false;
        });
        return;
      }

      final driverIdString = driverId.toString();
      if (_currentDriverId == driverIdString &&
          driverName != null &&
          driverName!.isNotEmpty) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _currentDriverId = driverIdString;
        isLoadingDriver = true;
      });

      // Fetch driver safely (TEXT vs UUID fix)
      final response = await supabase
          .from('employees')
          .select('*')
          .eq('id', driverIdString)
          .maybeSingle();

      debugPrint('Driver response: $response');

      if (!mounted) return;

      if (response == null) {
        setState(() {
          driverName = 'Driver not found';
          driverPhone = '';
          isLoadingDriver = false;
        });
        return;
      }

      setState(() {
        driverName = response['name'] ?? 'Unknown Driver';
        driverPhone = response['contact'] ?? '';
        isLoadingDriver = false;
      });
    } catch (e) {
      debugPrint('Driver fetch error: $e');

      if (!mounted) return;

      setState(() {
        driverName = 'Error loading driver';
        driverPhone = '';
        isLoadingDriver = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchOrder();
    });
  }

  Future<void> fetchOrder() async {
    final orderId = _liveOrder['id']?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', orderId)
          .single();

      if (!mounted) {
        return;
      }

      // Fetch driver info from employees table if driver_id exists
      if (response['driver_id'] != null) {
        try {
          final driverId = response['driver_id'].toString();
          final driverData = await Supabase.instance.client
              .from('employees')
              .select('full_name, name, phone, mobile_number')
              .eq('id', driverId)
              .maybeSingle();

          if (driverData != null) {
            response['driver_name'] =
                driverData['full_name'] ?? driverData['name'] ?? 'Driver';
            response['driver_phone'] =
                driverData['phone'] ?? driverData['mobile_number'] ?? '';
          }
        } catch (_) {
          // If employees query fails, use existing values
        }
      }

      final previousStatus = _liveOrder['status']?.toString();
      final newStatus = response['status']?.toString();
      final previousDriverId = _liveOrder['driver_id']?.toString();
      final newDriverId = response['driver_id']?.toString();

      if (previousStatus != newStatus ||
          previousDriverId != newDriverId ||
          _liveOrder['driver_name'] != response['driver_name'] ||
          _liveOrder['driver_phone'] != response['driver_phone']) {
        setState(() {
          _liveOrder = Map<String, dynamic>.from(response);
        });
        await loadDriver();
      }
    } catch (_) {
      // Keep last known UI state if polling request fails.
    }
  }

  Map<String, dynamic> get _order => _liveOrder;

  String _deliveryType() => '${_order['delivery_type'] ?? 'now'}'.toLowerCase();

  String _status() => '${_order['status'] ?? ''}'.toLowerCase();

  String _normalizedStatus() {
    final raw = _status().replaceAll(' ', '_');
    if (raw == 'completed') return 'delivered';
    if (raw == 'delivering') return 'on_the_way';
    if (raw.isEmpty) return 'pending';
    return raw;
  }

  bool get _isScheduled => _deliveryType() == 'scheduled';

  bool get _isDelivering {
    final status = _normalizedStatus();
    return status == 'on_the_way' || status == 'delivering';
  }

  bool get _hasAssignedDriver {
    final status = _normalizedStatus();
    return status == 'assigned' ||
        status == 'on_the_way' ||
        status == 'delivered';
  }

  String _statusLabel() {
    switch (_normalizedStatus()) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Driver Assigned';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      default:
        return _status().isEmpty ? 'Unknown' : '${_order['status'] ?? ''}';
    }
  }

  Color _statusColor() {
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

  int _currentStepIndex() {
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

  String _gallons() => '${_order['gallons'] ?? ''} Gallons';

  String _address() => '${_order['address'] ?? 'Home Address, Cebu City'}';

  double _latitude() {
    final lat = _order['latitude'];
    if (lat is double) return lat;
    if (lat is int) return lat.toDouble();
    if (lat is String) return double.tryParse(lat) ?? 14.5995;
    return 14.5995; // Default Cebu City
  }

  double _longitude() {
    final lng = _order['longitude'];
    if (lng is double) return lng;
    if (lng is int) return lng.toDouble();
    if (lng is String) return double.tryParse(lng) ?? 120.9842;
    return 120.9842; // Default Cebu City
  }

  double _driverLatitude() {
    final lat = _order['driver_lat'];
    if (lat is double) return lat;
    if (lat is int) return lat.toDouble();
    if (lat is String) return double.tryParse(lat) ?? 14.5995;
    return 14.5995; // Default Cebu City
  }

  double _driverLongitude() {
    final lng = _order['driver_lng'];
    if (lng is double) return lng;
    if (lng is int) return lng.toDouble();
    if (lng is String) return double.tryParse(lng) ?? 120.9842;
    return 120.9842; // Default Cebu City
  }

  bool _hasDriverLocation() {
    final lat = _order['driver_lat'];
    final lng = _order['driver_lng'];
    return lat != null && lng != null;
  }

  DateTime? _scheduledDate() {
    final raw = _order['scheduled_date'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  TimeOfDay? _scheduledTime() {
    final rawTime = _order['scheduled_time']?.toString();
    if (rawTime == null || rawTime.isEmpty) return null;
    final parts = rawTime.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildProgressTrackerRow() {
    const steps = ['Order Placed', 'Accepted', 'On the Way', 'Delivered'];
    final currentStep = _currentStepIndex();

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCompleted = index <= currentStep;
              final isCurrent = index == currentStep;

              return Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isCompleted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFE2E8F0),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      steps[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isCompleted
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectDriverCard() {
    final displayName = driverName ?? 'No driver assigned';

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Driver',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          isLoadingDriver
              ? const Text(
                  'Loading driver information...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                )
              : _InfoRow(label: 'Driver Name', value: displayName),
          if (!isLoadingDriver && driverPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Phone Number', value: driverPhone),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    DateTime scheduledDate,
    TimeOfDay scheduledTime,
  ) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            '${_formatDate(scheduledDate)} • ${scheduledTime.format(context)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Delivery will start at scheduled time',
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

  Widget _buildStatusCard() {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusBackground(),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _statusColor().withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(),
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            getStatusMessage(_normalizedStatus()),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          if (_normalizedStatus() == 'assigned' ||
              _normalizedStatus() == 'on_the_way') ...[
            const SizedBox(height: 8),
            const Text(
              'Estimated arrival: 10-15 minutes',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return _CardContainer(
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
          _InfoRow(label: 'Gallons', value: _gallons()),
          const SizedBox(height: 8),
          _InfoRow(label: 'Address', value: _address()),
          if (_isScheduled) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final scheduledDate = _scheduledDate();
                final scheduledTime = _scheduledTime();
                if (scheduledDate == null || scheduledTime == null) {
                  return const SizedBox.shrink();
                }
                return _InfoRow(
                  label: 'Scheduled',
                  value:
                      '${_formatDate(scheduledDate)} • ${scheduledTime.format(context)}',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (!_isDelivering) {
      return const SizedBox.shrink();
    }

    final customerLat = _latitude();
    final customerLng = _longitude();
    final customerLocation = LatLng(customerLat, customerLng);

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Location',
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
                options: MapOptions(
                  initialCenter: customerLocation,
                  initialZoom: 16,
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
                        width: 50,
                        height: 50,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasDriverLocation())
                        Marker(
                          point: LatLng(_driverLatitude(), _driverLongitude()),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC7D7FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1E3A8A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap map to view full address: ${_address()}',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDate = _scheduledDate();
    final scheduledTime = _scheduledTime();

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
          _buildProgressTrackerRow(),
          if (_isScheduled &&
              scheduledDate != null &&
              scheduledTime != null) ...[
            const SizedBox(height: 14),
            _buildScheduleCard(context, scheduledDate, scheduledTime),
          ],
          const SizedBox(height: 14),
          _buildDirectDriverCard(),
          if (_hasAssignedDriver) const SizedBox(height: 14),
          _buildOrderInfoCard(),
          const SizedBox(height: 14),
          _buildMapSection(),
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
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const Spacer(),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Maps order status to progress step index (0-3)
int getStepIndex(String status) {
  final normalized = status.trim().toLowerCase().replaceAll(' ', '_');

  if (normalized == 'completed') {
    return 3; // delivered
  }
  if (normalized == 'delivering') {
    return 2; // on_the_way
  }
  if (normalized.isEmpty) {
    return 0; // pending
  }

  switch (normalized) {
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

/// Returns a dynamic message based on order status
String getStatusMessage(String status) {
  final normalized = status.trim().toLowerCase().replaceAll(' ', '_');

  if (normalized == 'completed') {
    return 'Order delivered successfully';
  }
  if (normalized == 'delivering') {
    return 'Driver is on the way to your location';
  }
  if (normalized.isEmpty) {
    return 'Waiting for store confirmation';
  }

  switch (normalized) {
    case 'pending':
      return 'Waiting for store confirmation';
    case 'assigned':
      return 'Driver has been assigned';
    case 'on_the_way':
      return 'Driver is on the way to your location';
    case 'delivered':
      return 'Order delivered successfully';
    default:
      return 'Order status update';
  }
}
