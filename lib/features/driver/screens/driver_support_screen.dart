import 'package:flutter/material.dart';

import 'driver_messages_screen.dart';

class DriverSupportScreen extends StatelessWidget {
  const DriverSupportScreen({super.key});

  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FAQs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ..._faqItems.map(
                  (item) => _FaqTile(
                    question: item.question,
                    answer: item.answer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need More Help?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const DriverMessagesScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text(
                      'Chat with Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                const _ContactInfoRow(
                  icon: Icons.call_outlined,
                  label: '0917 123 4567',
                ),
                const SizedBox(height: 8),
                const _ContactInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'support@aquaenlavada.app',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      children: [
        Text(
          answer,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ContactInfoRow extends StatelessWidget {
  const _ContactInfoRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

const List<_FaqItem> _faqItems = [
  _FaqItem(
    question: 'How to start a delivery?',
    answer:
        'Open My Deliveries, select your assigned order, then tap Start Delivery to begin the trip.',
  ),
  _FaqItem(
    question: 'How to mark an order as delivered?',
    answer:
        'Open the order details after completing drop-off and tap Mark as Delivered to finish the task.',
  ),
  _FaqItem(
    question: 'What to do if customer is not available?',
    answer:
        'Try calling or sending a message first. If still unreachable, report it to admin using Chat with Admin.',
  ),
];
