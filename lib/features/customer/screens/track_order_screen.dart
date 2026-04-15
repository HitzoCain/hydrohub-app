import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

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
