import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aqua_in_laba_app/features/customer/screens/chat_screen.dart';

// Shared colors used by this file's widgets.
const Color _background = Color(0xFFF1F5F9);
const Color _primaryBlue = Color(0xFF2563EB);
const Color _darkText = Color(0xFF0F172A);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Timer? _refreshTimer;

  List<ConversationData> _conversations = [];
  List<ContactData> _contacts = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String _searchQuery = '';

  // ============================================================
  // TOTAL UNREAD
  // ============================================================

  int get _totalUnread {
    return _conversations.fold(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );
  }

  // ============================================================
  // FILTERED CONVERSATIONS
  // ============================================================

  List<ConversationData> get _filteredConversations {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _conversations;
    }

    return _conversations.where((conversation) {
      return conversation.name.toLowerCase().contains(query) ||
          conversation.orderInfo.toLowerCase().contains(query) ||
          conversation.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadConversations();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshConversations();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD CONVERSATIONS
  // ============================================================

  Future<void> _loadConversations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint('MessagesScreen: No logged-in customer.');

        if (!mounted) return;

        setState(() {
          _conversations = [];
          _contacts = [];
          _isLoading = false;
        });

        return;
      }

      final String customerId = user.id;

      debugPrint(
        'MessagesScreen: Loading conversations for customer $customerId',
      );

      // ==========================================================
      // 1. LOAD CUSTOMER ORDERS
      // ==========================================================

      final ordersResponse = await supabase
          .from('orders')
          .select(
            'id, customer_id, driver_id, status, created_at, product_name, capacity, gallons',
          )
          .eq('customer_id', customerId);

      final orders = List<Map<String, dynamic>>.from(ordersResponse);

      final orderIds = orders
          .map((order) => order['id'])
          .where((id) => id != null)
          .map((id) => id.toString())
          .toList();

      // ==========================================================
      // 2. ORDER LOOKUP
      // ==========================================================

      final Map<String, Map<String, dynamic>> orderMap = {};

      for (final order in orders) {
        final id = order['id'];

        if (id != null) {
          orderMap[id.toString()] = order;
        }
      }

      // ==========================================================
      // 3. LOAD DRIVERS
      // ==========================================================

      final Map<String, Map<String, dynamic>> driverMap = {};

      final driverIds = orders
          .map((order) => order['driver_id'])
          .where((id) => id != null)
          .map((id) => id.toString())
          .toSet()
          .toList();

      if (driverIds.isNotEmpty) {
        try {
          final driversResponse = await supabase
              .from('employees')
              .select('*')
              .inFilter('id', driverIds);

          final drivers = List<Map<String, dynamic>>.from(driversResponse);

          for (final driver in drivers) {
            final id = driver['id'];

            if (id != null) {
              driverMap[id.toString()] = driver;
            }
          }
        } catch (e) {
          debugPrint('MessagesScreen: Failed to load drivers: $e');
        }
      }

      // ==========================================================
      // 4. LOAD DELIVERY CONVERSATIONS
      // ==========================================================

      List<Map<String, dynamic>> deliveryConversations = [];

      if (orderIds.isNotEmpty) {
        final response = await supabase
            .from('conversations')
            .select('*')
            .inFilter('order_id', orderIds)
            .order('last_message_at', ascending: false);

        deliveryConversations = List<Map<String, dynamic>>.from(response);
      }

      // ==========================================================
      // 5. LOAD / CREATE SUPPORT CONVERSATION
      // ==========================================================

      Map<String, dynamic>? supportConversation;

      try {
        final existingSupport = await supabase
            .from('conversations')
            .select('*')
            .eq('conversation_type', 'support')
            .eq('participant_id', customerId)
            .maybeSingle();

        if (existingSupport != null) {
          supportConversation = Map<String, dynamic>.from(existingSupport);

          // Reactivate support conversation if needed.
          if (supportConversation['status'] == 'archived') {
            await supabase
                .from('conversations')
                .update({'status': 'active', 'archived_at': null})
                .eq('id', supportConversation['id']);

            supportConversation['status'] = 'active';

            supportConversation['archived_at'] = null;
          }
        } else {
          // Create the general Station Support
          // conversation for this customer.
          final now = DateTime.now().toLocal();

          final createdSupport = await supabase
              .from('conversations')
              .insert({
                'order_id': null,
                'customer_id': customerId,
                'participant_id': customerId,
                'conversation_type': 'support',
                'status': 'active',
                'last_message': null,
                'last_message_at': now.toIso8601String(),
              })
              .select('*')
              .single();

          supportConversation = Map<String, dynamic>.from(createdSupport);
        }
      } catch (e) {
        debugPrint('MessagesScreen: Support conversation error: $e');
      }

      // ==========================================================
      // 6. BUILD CONVERSATION IDS
      // ==========================================================

      final conversationIds = <String>[];

      for (final conversation in deliveryConversations) {
        final id = conversation['id'];

        if (id != null) {
          conversationIds.add(id.toString());
        }
      }

      if (supportConversation != null) {
        final id = supportConversation['id'];

        if (id != null) {
          conversationIds.add(id.toString());
        }
      }

      // ==========================================================
      // 7. LOAD UNREAD MESSAGES
      // ==========================================================

      final Map<String, int> unreadMap = {};

      if (conversationIds.isNotEmpty) {
        try {
          final unreadResponse = await supabase
              .from('messages')
              .select('conversation_id, sender_type, is_read')
              .inFilter('conversation_id', conversationIds)
              .eq('is_read', false);

          final unreadMessages = List<Map<String, dynamic>>.from(
            unreadResponse,
          );

          for (final message in unreadMessages) {
            final conversationId = message['conversation_id'];

            final senderType = message['sender_type']?.toString().toLowerCase();

            if (conversationId == null) {
              continue;
            }

            // Customer only needs to see unread messages
            // coming from driver or admin.
            if (senderType != 'driver' && senderType != 'admin') {
              continue;
            }

            final key = conversationId.toString();

            unreadMap[key] = (unreadMap[key] ?? 0) + 1;
          }
        } catch (e) {
          debugPrint('MessagesScreen: Failed to load unread messages: $e');
        }
      }

      // ==========================================================
      // 8. BUILD UI CONVERSATIONS
      // ==========================================================

      final List<ConversationData> loadedConversations = [];

      // ----------------------------------------------------------
      // DELIVERY / DRIVER CONVERSATIONS
      // ----------------------------------------------------------

      for (final conversation in deliveryConversations) {
        final conversationId = conversation['id']?.toString();

        final orderId = conversation['order_id']?.toString();

        if (conversationId == null || orderId == null) {
          continue;
        }

        final order = orderMap[orderId];

        final driverId =
            conversation['driver_id']?.toString() ??
            order?['driver_id']?.toString();

        final driver = driverId != null ? driverMap[driverId] : null;

        final driverName =
            driver?['name'] ?? driver?['full_name'] ?? 'Delivery Driver';

        final driverPhone =
            (order?['driver_phone'] ??
                    driver?['phone'] ??
                    driver?['mobile_number'] ??
                    driver?['contact_number'] ??
                    '')
                .toString()
                .trim();

        final driverAvatarUrl =
            driver?['profile_image_url']?.toString().trim() ?? '';

        final lastMessage = (conversation['last_message'] ?? '')
            .toString()
            .trim();

        final lastMessageAt = _parseDateTime(conversation['last_message_at']);

        final orderStatus = order?['status']?.toString() ?? 'pending';

        loadedConversations.add(
          ConversationData(
            id: conversationId,
            orderId: orderId,
            name: driverName.toString(),
            phone: driverPhone,
            avatarUrl: driverAvatarUrl,
            lastMessage: lastMessage.isEmpty ? 'No messages yet' : lastMessage,
            orderInfo: '',
            timeAgo: _formatTimeAgo(lastMessageAt),
            unreadCount: unreadMap[conversationId] ?? 0,
            type: ConversationType.driver,
            status: (conversation['status'] ?? 'active')
                .toString()
                .toLowerCase(),
            lastMessageAt: lastMessageAt,
            deliveryStatus: _deliveryStatus(orderStatus),
          ),
        );
      }

      // ----------------------------------------------------------
      // SUPPORT / STATION CONVERSATION
      // ----------------------------------------------------------

      if (supportConversation != null) {
        final supportId = supportConversation['id']?.toString();

        if (supportId != null && supportId.isNotEmpty) {
          final supportLastMessage = (supportConversation['last_message'] ?? '')
              .toString()
              .trim();

          final supportLastMessageAt = _parseDateTime(
            supportConversation['last_message_at'],
          );

          loadedConversations.add(
            ConversationData(
              id: supportId,
              orderId: null,
              name: 'Aqua In Lavada',
              phone: '',
              lastMessage: supportLastMessage.isEmpty
                  ? 'Contact the station for assistance'
                  : supportLastMessage,
              orderInfo: 'Station Support',
              timeAgo: _formatTimeAgo(supportLastMessageAt),
              unreadCount: unreadMap[supportId] ?? 0,
              type: ConversationType.support,
              status: (supportConversation['status'] ?? 'active')
                  .toString()
                  .toLowerCase(),
              lastMessageAt: supportLastMessageAt,
              deliveryStatus: 'Station Support',
            ),
          );
        }
      }

      // ==========================================================
      // 9. SORT CONVERSATIONS
      // ==========================================================

      loadedConversations.sort((a, b) {
        final aDate = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        final bDate = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      // ==========================================================
      // 10. ACTIVE DRIVER CONTACTS
      // ==========================================================

      final Map<String, ContactData> contactMap = {};

      for (final conversation in loadedConversations) {
        if (conversation.type != ConversationType.driver) {
          continue;
        }

        final key = conversation.name;

        if (!contactMap.containsKey(key)) {
          contactMap[key] = ContactData(
            name: conversation.name,
            phone: conversation.phone,
            avatarUrl: conversation.avatarUrl,
            orderInfo: conversation.orderInfo,
            type: ConversationType.driver,
            unreadCount: conversation.unreadCount,
            conversationId: conversation.id,
          );
        } else {
          final existing = contactMap[key]!;

          contactMap[key] = ContactData(
            name: existing.name,
            phone: existing.phone,
            avatarUrl: existing.avatarUrl,
            orderInfo: existing.orderInfo,
            type: existing.type,
            unreadCount: existing.unreadCount + conversation.unreadCount,
            conversationId: existing.conversationId,
          );
        }
      }

      // ==========================================================
      // 11. UPDATE UI
      // ==========================================================

      if (!mounted) return;

      setState(() {
        _conversations = loadedConversations;

        _contacts = contactMap.values.toList();

        _isLoading = false;
      });

      debugPrint(
        'MessagesScreen: Loaded '
        '${loadedConversations.length} conversations.',
      );
    } catch (e, stackTrace) {
      debugPrint('MessagesScreen: Failed to load conversations: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshConversations() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;

    try {
      await _loadConversationsSilently();
    } finally {
      _isRefreshing = false;
    }
  }

  // ============================================================
  // SILENT REFRESH
  // ============================================================

  Future<void> _loadConversationsSilently() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        return;
      }

      await _loadConversations();
    } catch (e) {
      debugPrint('MessagesScreen silent refresh error: $e');
    }
  }

  // ============================================================
  // OPEN CONVERSATION
  // ============================================================

  void _openConversation(ConversationData conversation) {
    // IMPORTANT:
    // Never pass an empty conversationId.
    //
    // The previous code had:
    //
    // ChatScreen(conversationId: '')
    //
    // That was the main reason the chat was empty.

    if (conversation.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation is not available.')),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversationId: conversation.id),
      ),
    ).then((_) {
      _refreshConversations();
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _deliveryStatus(String status) {
    final value = status.toLowerCase().trim();

    switch (value) {
      case 'out_for_delivery':
      case 'out for delivery':
        return 'Out for Delivery';

      case 'on_the_way':
      case 'on the way':
        return 'On the way';

      case 'delivered':
        return 'Delivered';

      case 'pending':
        return 'Pending';

      case 'confirmed':
        return 'Confirmed';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return 'On the way';
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

    final now = DateTime.now();

    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'now';
    }

    if (difference.inSeconds < 60) {
      return 'now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConversations;

    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w700, color: _darkText),
        ),

        backgroundColor: _background,

        elevation: 0,

        scrolledUnderElevation: 0,

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadConversations,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ======================================================
            // SEARCH
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),

                child: TextField(
                  decoration: const InputDecoration(
                    border: InputBorder.none,

                    icon: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),

                    hintText: 'Search conversations...',

                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),

                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            // ======================================================
            // ACTIVE DRIVERS
            // ======================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    'Active Deliveries',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),

                  Text(
                    _contacts.isEmpty
                        ? 'See all'
                        : '${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}',

                    style: const TextStyle(
                      fontSize: 12,
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 148,

              child: _contacts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No active deliveries.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      scrollDirection: Axis.horizontal,

                      itemCount: _contacts.length,

                      separatorBuilder: (_, __) => const SizedBox(width: 12),

                      itemBuilder: (context, index) {
                        final contact = _contacts[index];

                        ConversationData? conversation;

                        for (final item in _conversations) {
                          if (item.id == contact.conversationId) {
                            conversation = item;
                            break;
                          }
                        }

                        if (conversation == null) {
                          return const SizedBox();
                        }

                        return DriverAvatarWidget(
                          contact: contact,

                          onTap: () {
                            _openConversation(conversation!);
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 18),

            // ======================================================
            // CONVERSATIONS HEADER
            // ======================================================
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
                      color: _darkText,
                    ),
                  ),

                  if (_totalUnread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),

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
                    )
                  else
                    const Text(
                      '0 unread',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryBlue,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ======================================================
            // CONVERSATION LIST
            // ======================================================
            Expanded(
              child: RefreshIndicator(
                color: _primaryBlue,

                onRefresh: _loadConversations,

                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryBlue),
                      )
                    : filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),

                        children: [
                          const SizedBox(height: 100),

                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 55,
                            color: Color(0xFFCBD5E1),
                          ),

                          const SizedBox(height: 14),

                          Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? 'No conversations found'
                                  : 'No conversations yet',

                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),

                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

                        itemCount: filtered.length,

                        itemBuilder: (context, index) {
                          final conversation = filtered[index];

                          return ConversationItemWidget(
                            conversation: conversation,

                            onTap: () {
                              _openConversation(conversation);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ENUM
// ============================================================================

enum ConversationType { driver, support }

// ============================================================================
// CONTACT DATA
// ============================================================================

class ContactData {
  const ContactData({
    required this.name,
    this.phone = '',
    this.avatarUrl = '',
    required this.orderInfo,
    required this.type,
    required this.unreadCount,
    required this.conversationId,
  });

  final String name;

  final String phone;

  final String avatarUrl;
  final String orderInfo;
  final ConversationType type;
  final int unreadCount;
  final String conversationId;
}

// ============================================================================
// CONVERSATION DATA
// ============================================================================

class ConversationData {
  const ConversationData({
    required this.id,
    required this.orderId,
    required this.name,
    this.phone = '',
    this.avatarUrl = '',
    required this.lastMessage,
    required this.orderInfo,
    required this.timeAgo,
    required this.unreadCount,
    required this.type,
    required this.status,
    required this.lastMessageAt,
    required this.deliveryStatus,
  });

  final String id;

  final String? orderId;

  final String name;

  final String phone;

  final String avatarUrl;

  final String lastMessage;

  final String orderInfo;

  final String timeAgo;

  final int unreadCount;

  final ConversationType type;

  final String status;

  final DateTime? lastMessageAt;

  final String deliveryStatus;
}

// ============================================================================
// DRIVER AVATAR
// ============================================================================

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

                    border: Border.all(color: _primaryBlue, width: 2),

                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),

                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFFEFF6FF),
                    backgroundImage: contact.avatarUrl.isEmpty
                        ? null
                        : NetworkImage(contact.avatarUrl),
                    child: contact.avatarUrl.isEmpty
                        ? const Icon(
                            Icons.local_shipping_outlined,
                            color: Color(0xFF2563EB),
                          )
                        : null,
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
                          color: const Color(0xFFF1F5F9),
                          width: 2,
                        ),
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

              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 2),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),

                borderRadius: BorderRadius.circular(10),
              ),

              child: const Text(
                'Active',

                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONVERSATION ITEM
// ============================================================================

class ConversationItemWidget extends StatelessWidget {
  const ConversationItemWidget({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ConversationData conversation;
  final VoidCallback onTap;

  bool get _isSupport => conversation.type == ConversationType.support;

  bool get _isArchived => conversation.status == 'archived';

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = conversation.unreadCount > 0;
    final bool isDelivered =
        conversation.deliveryStatus.toLowerCase() == 'delivered';

    final Color accentColor = _isSupport
        ? const Color(0xFFF97316)
        : const Color(0xFF2563EB);

    final Color avatarBackground = _isSupport
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF6FF);

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

              border: Border.all(color: const Color(0xFFF1F5F9), width: 0.5),

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
                // ========================================================
                // ACCENT
                // ========================================================
                Container(
                  width: 3,
                  height: 60,

                  margin: const EdgeInsets.only(right: 10),

                  decoration: BoxDecoration(
                    color: hasUnread ? accentColor : const Color(0xFFE2E8F0),

                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // ========================================================
                // AVATAR
                // ========================================================
                Stack(
                  clipBehavior: Clip.none,

                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarBackground,
                      backgroundImage:
                          !_isSupport && conversation.avatarUrl.isNotEmpty
                          ? NetworkImage(conversation.avatarUrl)
                          : null,
                      child: _isSupport || conversation.avatarUrl.isEmpty
                          ? Icon(
                              _isSupport
                                  ? Icons.support_agent_rounded
                                  : Icons.local_shipping_outlined,
                              color: accentColor,
                              size: 21,
                            )
                          : null,
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

                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // ========================================================
                // CONTENT
                // ========================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                fontSize: 14,

                                fontWeight: hasUnread
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

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // ==================================================
                                // SUPPORT BADGE
                                // ==================================================
                                if (_isSupport)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),

                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),

                                      borderRadius: BorderRadius.circular(7),
                                    ),

                                    child: const Text(
                                      'Station Support',

                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFEA580C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                // ==================================================
                                // ORDER BADGE
                                // ==================================================
                                else if (conversation.orderInfo.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),

                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),

                                      borderRadius: BorderRadius.circular(6),
                                    ),

                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,

                                      children: [
                                        const Icon(
                                          Icons.receipt_long_outlined,

                                          size: 10,

                                          color: Color(0xFF2563EB),
                                        ),

                                        const SizedBox(width: 3),

                                        Text(
                                          conversation.orderInfo,

                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // ==================================================
                                // ARCHIVED
                                // ==================================================
                                if (_isArchived) ...[
                                  const SizedBox(width: 6),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),

                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),

                                      borderRadius: BorderRadius.circular(6),
                                    ),

                                    child: const Text(
                                      'Archived',

                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!_isSupport) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDelivered
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                conversation.deliveryStatus,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDelivered
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w700,
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

                // ========================================================
                // UNREAD
                // ========================================================
                if (hasUnread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),

                    height: 22,

                    padding: const EdgeInsets.symmetric(horizontal: 6),

                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: _primaryBlue,

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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
