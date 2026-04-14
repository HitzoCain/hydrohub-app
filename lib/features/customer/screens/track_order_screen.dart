import 'package:flutter/material.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({
    super.key,
    this.orderId = 'Order #001',
    this.totalGallons = 5,
    this.status = 'On the way',
    this.currentStep = 2,
    this.driverName = 'John Doe',
    this.driverPhone = '+63 912 345 6789',
    this.statusMessage = 'Your order is on the way 🚚',
  });

  final String orderId;
  final int totalGallons;
  final String status;
  final int currentStep;
  final String driverName;
  final String driverPhone;
  final String statusMessage;

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF6F8FB);

  static const List<String> _steps = [
    'Order Placed',
    'Confirmed',
    'Out for Delivery',
    'Delivered',
  ];

  static const List<String> _timeLabels = [
    '08:15 AM',
    '08:22 AM',
    '09:05 AM',
    'Pending',
  ];

  @override
  Widget build(BuildContext context) {
    final safeCurrentStep = currentStep.clamp(0, _steps.length - 1);

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
                _InfoRow(label: 'Order ID', value: orderId),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Total Gallons',
                  value: '$totalGallons Gallons',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Status',
                  value: status,
                  valueColor: _primaryBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CardContainer(
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
                const SizedBox(height: 12),
                ...List<Widget>.generate(_steps.length, (index) {
                  final isLast = index == _steps.length - 1;
                  final isCompleted = index < safeCurrentStep;
                  final isCurrent = index == safeCurrentStep;

                  return _TimelineStep(
                    title: _steps[index],
                    timeLabel: _timeLabels[index],
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    isLast: isLast,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0x142563EB),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.person, color: _primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driverPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.phone_outlined, color: _primaryBlue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D7FE)),
              ),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: _primaryBlue, size: 28),
                  SizedBox(height: 8),
                  Text(
                    'Map View (Driver Location)',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: _primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusMessage,
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
    this.valueColor = const Color(0xFF0F172A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.timeLabel,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  final String title;
  final String timeLabel;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color stepColor = isCompleted || isCurrent
        ? const Color(0xFF2563EB)
        : const Color(0xFF94A3B8);

    final IconData stepIcon = isCompleted
        ? Icons.check_circle
        : Icons.radio_button_unchecked;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Icon(stepIcon, color: stepColor, size: 20),
              if (!isLast)
                Container(
                  width: 2,
                  height: 34,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isCompleted
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFFE2E8F0),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
