import 'package:flutter/material.dart';

import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverMessagesScreen extends StatefulWidget {
  const DriverMessagesScreen({super.key});

  @override
  State<DriverMessagesScreen> createState() => _DriverMessagesScreenState();
}

class _DriverMessagesScreenState extends State<DriverMessagesScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);

  static const List<ActiveDeliveryData> _activeDeliveries = [
    ActiveDeliveryData(
      customerName: 'Juan Dela Cruz',
      orderId: 'Order #001',
      status: DeliveryStatus.delivering,
    ),
    ActiveDeliveryData(
      customerName: 'Maria Santos',
      orderId: 'Order #002',
      status: DeliveryStatus.completed,
    ),
  ];

  static const List<ConversationData> _conversations = [
    ConversationData(
      customerName: 'Juan Dela Cruz',
      lastMessage: 'Sir, malapit na po ako sa gate ninyo.',
      orderId: 'Order #001',
      timeAgo: '2m ago',
      unreadCount: 2,
      status: DeliveryStatus.delivering,
      highlight: true,
    ),
    ConversationData(
      customerName: 'Maria Santos',
      lastMessage: 'Please call when you arrive.',
      orderId: 'Order #002',
      timeAgo: '10m ago',
      unreadCount: 1,
      status: DeliveryStatus.completed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final totalUnread = _conversations.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: Color(0xFF334155)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    SizedBox(width: 8),
                    Text(
                      'Search customer or order...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            _SectionHeader(
              title: 'Active Deliveries',
              trailing: 'See all',
              onTrailingTap: () {},
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _activeDeliveries.map((delivery) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ActiveDeliveryCard(data: delivery),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Conversations',
              trailing: '$totalUnread unread',
              onTrailingTap: () {},
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _conversations.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _conversations.length - 1 ? 0 : 12,
                          ),
                          child: ConversationCard(
                            data: conversation,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => DriverChatScreen(
                                    customerName: conversation.customerName,
                                    orderId: conversation.orderId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
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
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverMapScreen(),
              ),
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.data});

  final ActiveDeliveryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'Active Delivery',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomerAvatarItem(
            customerName: data.customerName,
            status: data.status,
            size: 42,
          ),
          const SizedBox(height: 8),
          Text(
            data.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.orderId,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusTag(status: data.status),
              if (data.status == DeliveryStatus.delivering) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class CustomerAvatarItem extends StatelessWidget {
  const CustomerAvatarItem({
    super.key,
    required this.customerName,
    required this.status,
    this.size = 46,
  });

  final String customerName;
  final DeliveryStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isActive = status == DeliveryStatus.delivering;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFFF1F5F9),
        child: Text(
          _initials(customerName),
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\\s+'));
    if (parts.isEmpty) {
      return 'C';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts[0].substring(0, 1).toUpperCase();
    final second = parts[1].substring(0, 1).toUpperCase();
    return '$first$second';
  }
}

class ConversationCard extends StatelessWidget {
  const ConversationCard({super.key, required this.data, required this.onTap});

  final ConversationData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12233455),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 54,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: data.highlight
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: CustomerAvatarItem(
                  customerName: data.customerName,
                  status: data.status,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data.orderId,
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusTag(status: data.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (data.unreadCount > 0)
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        '${data.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = status == DeliveryStatus.completed;
    final bool isPending = status == DeliveryStatus.pending;
    final color = isCompleted
      ? const Color(0xFF15803D)
      : isPending
        ? const Color(0xFFB45309)
        : const Color(0xFF1D4ED8);
    final bg = isCompleted
      ? const Color(0xFFDCFCE7)
      : isPending
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFDBEAFE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF94A3B8),
              size: 42,
            ),
            SizedBox(height: 10),
            Text(
              'No customer messages yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
    required this.onTrailingTap,
  });

  final String title;
  final String trailing;
  final VoidCallback onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverChatScreen extends StatelessWidget {
  const DriverChatScreen({
    super.key,
    required this.customerName,
    required this.orderId,
  });

  final String customerName;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(customerName),
        backgroundColor: const Color(0xFFF6F8FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              orderId,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Driver Chat Screen (UI only)',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}

enum DeliveryStatus {
  pending('Pending'),
  delivering('Delivering'),
  completed('Completed');

  const DeliveryStatus(this.label);
  final String label;
}

class ActiveDeliveryData {
  const ActiveDeliveryData({
    required this.customerName,
    required this.orderId,
    required this.status,
  });

  final String customerName;
  final String orderId;
  final DeliveryStatus status;
}

class ConversationData {
  const ConversationData({
    required this.customerName,
    required this.lastMessage,
    required this.orderId,
    required this.timeAgo,
    required this.unreadCount,
    required this.status,
    this.highlight = false,
  });

  final String customerName;
  final String lastMessage;
  final String orderId;
  final String timeAgo;
  final int unreadCount;
  final DeliveryStatus status;
  final bool highlight;
}
