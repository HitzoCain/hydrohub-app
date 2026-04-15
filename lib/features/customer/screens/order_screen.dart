import 'package:flutter/material.dart';

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
  int _totalGallons = 1;
  int _exchangeCount = 0;
  int _newContainerCount = 1;
  String _deliveryAddress = 'Home';
  String _deliveryTime = 'Morning';
  String _deliveryType = 'now';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int get _estimatedPrice =>
      (_exchangeCount * 250) + (_newContainerCount * 350);

  void _decreaseTotalGallons() {
    if (_totalGallons <= 1) return;
    setState(() {
      _totalGallons--;
      if (_exchangeCount > _totalGallons) _exchangeCount = _totalGallons;
      _newContainerCount = _totalGallons - _exchangeCount;
    });
  }

  void _increaseTotalGallons() {
    setState(() {
      _totalGallons++;
      _newContainerCount = _totalGallons - _exchangeCount;
    });
  }

  void _increaseExchange() {
    if (_exchangeCount >= _totalGallons) return;
    setState(() {
      _exchangeCount++;
      _newContainerCount = _totalGallons - _exchangeCount;
    });
  }

  void _decreaseExchange() {
    if (_exchangeCount <= 0) return;
    setState(() {
      _exchangeCount--;
      _newContainerCount = _totalGallons - _exchangeCount;
    });
  }

  void _increaseNewContainers() {
    if (_newContainerCount >= _totalGallons) return;
    setState(() {
      _newContainerCount++;
      _exchangeCount = _totalGallons - _newContainerCount;
    });
  }

  void _decreaseNewContainers() {
    if (_newContainerCount <= 0) return;
    setState(() {
      _newContainerCount--;
      _exchangeCount = _totalGallons - _newContainerCount;
    });
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    if (_deliveryType == 'scheduled') {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both date and time for scheduled delivery.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order placed successfully!'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackOrderScreen(
          orderId: 'Order #AQL-1042',
          totalGallons: _totalGallons,
          address: _deliveryAddress,
          deliveryType: _deliveryType,
          status: _deliveryType == 'scheduled' ? 'scheduled' : 'on_the_way',
          scheduledDate: _selectedDate,
          scheduledTime: _selectedTime,
          driverName: 'Juan Santos',
          driverPhone: '+63 917 555 0188',
        ),
      ),
    );
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
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
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
              '₱$_estimatedPrice est.',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _SectionCard(
                    title: 'Total Gallons',
                    icon: Icons.water_drop_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total number of gallons to order',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        _CounterRow(
                          value: _totalGallons,
                          onMinusTap: _decreaseTotalGallons,
                          onPlusTap: _increaseTotalGallons,
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
                          'Specify exchange and new containers',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        _CounterGroupCard(
                          title: 'With Exchange',
                          priceBadge: '₱250 each',
                          badgeColor: const Color(0xFF1D4ED8),
                          badgeBg: const Color(0xFFDBEAFE),
                          value: _exchangeCount,
                          onMinusTap: _decreaseExchange,
                          onPlusTap: _increaseExchange,
                        ),
                        const SizedBox(height: 10),
                        _CounterGroupCard(
                          title: 'New Containers',
                          priceBadge: '₱350 each',
                          badgeColor: const Color(0xFFB45309),
                          badgeBg: const Color(0xFFFEF3C7),
                          value: _newContainerCount,
                          onMinusTap: _decreaseNewContainers,
                          onPlusTap: _increaseNewContainers,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Delivery Address',
                    icon: Icons.location_on_outlined,
                    child: DropdownButtonFormField<String>(
                      initialValue: _deliveryAddress,
                      decoration: _fieldDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'Home', child: Text('Home')),
                        DropdownMenuItem(value: 'Office', child: Text('Office')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _deliveryAddress = value);
                      },
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
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
                                  });
                                },
                              ),
                              _DeliveryTypeOption(
                                title: 'Schedule Delivery',
                                selected: _deliveryType == 'scheduled',
                                onTap: () {
                                  setState(() {
                                    _deliveryType = 'scheduled';
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
                                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
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
                                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickTime,
                                  icon: const Icon(Icons.access_time_outlined, size: 16),
                                  label: Text(
                                    _selectedTime == null
                                        ? 'Select Time'
                                        : _selectedTime!.format(context),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF334155),
                                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedDate != null && _selectedTime != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Scheduled on ${_formatDate(_selectedDate!)} at ${_selectedTime!.format(context)}',
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
                    title: 'Delivery Time',
                    icon: Icons.schedule_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose a preferred time slot',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: ['Morning', 'Afternoon', 'Evening'].map((slot) {
                            final selected = _deliveryTime == slot;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: slot != 'Evening' ? 8 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () => setState(() => _deliveryTime = slot),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Total Gallons', value: '$_totalGallons'),
                        const _SummaryDivider(),
                        _SummaryRow(label: 'With Exchange', value: '$_exchangeCount'),
                        const _SummaryDivider(),
                        _SummaryRow(label: 'New Containers', value: '$_newContainerCount'),
                        const _SummaryDivider(),
                        _SummaryRow(
                          label: 'Delivery Type',
                          value: _deliveryType == 'now' ? 'Deliver Now' : 'Scheduled',
                        ),
                        if (_deliveryType == 'scheduled' &&
                            _selectedDate != null &&
                            _selectedTime != null) ...[
                          const _SummaryDivider(),
                          _SummaryRow(
                            label: 'Scheduled For',
                            value:
                                '${_formatDate(_selectedDate!)} ${_selectedTime!.format(context)}',
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                                        fontSize: 11, color: Color(0xFF64748B)),
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
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 12, color: Color(0xFF15803D)),
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
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.water_drop_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Placing Order...' : 'Place Order',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
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

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.value,
    required this.onMinusTap,
    required this.onPlusTap,
  });

  final int value;
  final VoidCallback onMinusTap;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CounterButton(icon: Icons.remove, onTap: onMinusTap),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CounterButton(icon: Icons.add, onTap: onPlusTap),
      ],
    );
  }
}

class _CounterGroupCard extends StatelessWidget {
  const _CounterGroupCard({
    required this.title,
    required this.priceBadge,
    required this.badgeColor,
    required this.badgeBg,
    required this.value,
    required this.onMinusTap,
    required this.onPlusTap,
  });

  final String title;
  final String priceBadge;
  final Color badgeColor;
  final Color badgeBg;
  final int value;
  final VoidCallback onMinusTap;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  priceBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CounterRow(
            value: value,
            onMinusTap: onMinusTap,
            onPlusTap: onPlusTap,
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 16, thickness: 0.5, color: Color(0xFFF1F5F9));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
              color: selected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}