import 'package:flutter/material.dart';
import 'package:aqua_in_laba_app/features/customer/screens/chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  static const Color _background = Color(0xFFF1F5F9);

  static const List<ContactData> _contacts = [
    ContactData(
      name: 'Driver John',
      orderInfo: 'Order #001',
      type: ConversationType.assignedDriver,
      unreadCount: 2,
    ),
    ContactData(
      name: 'Driver Mark',
      orderInfo: 'Order #003',
      type: ConversationType.driver,
      unreadCount: 0,
    ),
    ContactData(
      name: 'Support Team',
      orderInfo: 'General Help',
      type: ConversationType.support,
      unreadCount: 0,
    ),
  ];

  static const List<ConversationData> _conversations = [
    ConversationData(
      name: 'Driver John',
      lastMessage: 'On the way po sir',
      orderInfo: 'Order #001',
      timeAgo: '2m ago',
      unreadCount: 2,
      type: ConversationType.assignedDriver,
    ),
    ConversationData(
      name: 'Support Team',
      lastMessage: 'Let us know if you need help with your refill request.',
      orderInfo: 'General Concern',
      timeAgo: '15m ago',
      unreadCount: 0,
      type: ConversationType.support,
    ),
    ConversationData(
      name: 'Driver Mark',
      lastMessage: 'Delivered na po. Thank you!',
      orderInfo: 'Order #003',
      timeAgo: '1h ago',
      unreadCount: 0,
      type: ConversationType.driver,
    ),
  ];

  int get _totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF334155)),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF334155)),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Search conversations...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),

            // Active Contacts header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Contacts / Drivers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 132,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return DriverAvatarWidget(
                    contact: contact,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // Conversations header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_totalUnread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_totalUnread unread',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _conversations.isEmpty
                  ? const Center(
                      child: Text(
                        'No conversations yet',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return ConversationItemWidget(
                          conversation: conversation,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ChatScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Enums & Data Models ───────────────────────────────────────────────────

enum ConversationType { assignedDriver, driver, support }

class ContactData {
  const ContactData({
    required this.name,
    required this.orderInfo,
    required this.type,
    required this.unreadCount,
  });

  final String name;
  final String orderInfo;
  final ConversationType type;
  final int unreadCount;
}

class ConversationData {
  const ConversationData({
    required this.name,
    required this.lastMessage,
    required this.orderInfo,
    required this.timeAgo,
    required this.unreadCount,
    required this.type,
  });

  final String name;
  final String lastMessage;
  final String orderInfo;
  final String timeAgo;
  final int unreadCount;
  final ConversationType type;
}

// ─── Driver Avatar Widget ──────────────────────────────────────────────────

class DriverAvatarWidget extends StatelessWidget {
  const DriverAvatarWidget({
    super.key,
    required this.contact,
    required this.onTap,
  });

  final ContactData contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = contact.type == ConversationType.assignedDriver;
    final bool hasUnread = contact.unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAssigned
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      width: isAssigned ? 2 : 0,
                    ),
                    boxShadow: isAssigned
                        ? const [
                            BoxShadow(
                              color: Color(0x332563EB),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: isAssigned ? 27 : 25,
                    backgroundColor: isAssigned
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFE2E8F0),
                    child: Icon(
                      contact.type == ConversationType.support
                          ? Icons.support_agent_rounded
                          : Icons.local_shipping_outlined,
                      color: isAssigned
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFF1F5F9), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isAssigned ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              contact.orderInfo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF94A3B8)),
            ),
            if (isAssigned) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Assigned',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Conversation Item Widget ──────────────────────────────────────────────

class ConversationItemWidget extends StatelessWidget {
  const ConversationItemWidget({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ConversationData conversation;
  final VoidCallback onTap;

  bool get _isDelivered =>
      conversation.lastMessage.toLowerCase().contains('delivered') ||
      conversation.lastMessage.toLowerCase().contains('delivered na');

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = conversation.unreadCount > 0;
    final bool isAssigned =
        conversation.type == ConversationType.assignedDriver;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 0.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A233455),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left accent bar for assigned driver
                if (isAssigned)
                  Container(
                    width: 3,
                    height: 60,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: isAssigned ? 24 : 22,
                      backgroundColor: isAssigned
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF1F5F9),
                      child: Icon(
                        conversation.type == ConversationType.support
                            ? Icons.support_agent_rounded
                            : Icons.local_shipping_outlined,
                        color: isAssigned
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF475569),
                        size: 20,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isAssigned
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conversation.timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 10,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  conversation.orderInfo,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isDelivered) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Delivered',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Trailing
                if (hasUnread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}