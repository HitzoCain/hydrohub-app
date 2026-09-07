import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../driver_session.dart';
import 'driver_dashboard_screen.dart';
import 'driver_chat_screen.dart';
import 'driver_map_screen.dart';
import 'driver_orders_screen.dart';
import 'driver_profile_screen.dart';

class DriverMessagesScreen extends StatefulWidget {
  const DriverMessagesScreen({
    super.key,
  });

  @override
  State<DriverMessagesScreen> createState() =>
      _DriverMessagesScreenState();
}

class _DriverMessagesScreenState extends State<DriverMessagesScreen> {
  // COLORS
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _darkText = Color(0xFF0F172A);

  final SupabaseClient _supabase = Supabase.instance.client;

  Timer? _refreshTimer;

  String? _currentDriverId;

  bool _isLoading = true;
  bool _isRefreshing = false;

  String _searchQuery = '';

  List<ConversationData> _conversations = [];

  List<ActiveDeliveryData> _activeDeliveries = [];

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _initializeMessages();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _loadMessages(
          silent: true,
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initializeMessages() async {
    await _loadCurrentDriverId();

    if (!mounted) return;

    await _loadMessages();
  }

  // ===========================================================================
  // LOAD DRIVER ID
  // ===========================================================================

  Future<void> _loadCurrentDriverId() async {
    try {
        final session = await DriverSession.load();

        if (!mounted) return;

        final String? sessionIdRaw = session?.id;
        final String? sessionId = sessionIdRaw?.trim();

        final String? staticIdRaw = DriverSession.id;
        final String? staticId = staticIdRaw?.trim();

        final String? authIdRaw = _supabase.auth.currentUser?.id;
        final String? authId = authIdRaw?.trim();

        final resolvedId = sessionId != null && sessionId.isNotEmpty
          ? sessionId
          : (staticId != null && staticId.isNotEmpty ? staticId : authId);

      setState(() {
        _currentDriverId = resolvedId;
      });

      debugPrint(
        'Driver Messages - Current Driver ID: $_currentDriverId',
      );
    } catch (e) {
      debugPrint(
        'Failed to load DriverSession: $e',
      );

      if (!mounted) return;

      setState(() {
        _currentDriverId =
            DriverSession.id ??
                _supabase.auth.currentUser?.id;
      });
    }
  }

  // ===========================================================================
  // LOAD MESSAGES
  // ===========================================================================

  Future<void> _loadMessages({
    bool silent = false,
  }) async {
    final driverId =
        _currentDriverId?.trim();

    if (driverId == null ||
        driverId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _conversations = [];
        _activeDeliveries = [];
      });

      return;
    }

    if (!silent) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
        });
      }
    }

    try {
      // ========================================================================
      // 1. LOAD DELIVERY CONVERSATIONS
      // ========================================================================

      final response =
          await _supabase
              .from('conversations')
              .select('''
                id,
                order_id,
                last_message,
                last_message_at,
                created_at,
                status,
                delivered_at,
                archived_at,
                customer_id,
                conversation_type,
                driver_id,

                orders(
                  id,
                  customer_name,
                  driver_id,
                  status,
                  delivery_type,
                  gallons,
                  total_price
                )
              ''')
              .eq(
                'conversation_type',
                'delivery',
              )
              .order(
                'last_message_at',
                ascending: false,
              );

      final List<dynamic> rows =
          response as List<dynamic>;

      final List<ConversationData>
          conversations = [];

      // ========================================================================
      // PROCESS CUSTOMER CONVERSATIONS
      // ========================================================================

      for (final row in rows) {
        final Map<String, dynamic>
            conversation =
            Map<String, dynamic>.from(row);

        final dynamic orderData =
            conversation['orders'];

        if (orderData == null) {
          continue;
        }

        final Map<String, dynamic>
            order =
            Map<String, dynamic>.from(
          orderData,
        );

        final String? orderDriverId =
            order['driver_id']
                ?.toString()
                .trim();

        // Only show conversations belonging
        // to the currently logged-in driver.
        if (orderDriverId != driverId) {
          continue;
        }

        final String conversationStatus =
            '${conversation['status'] ?? 'active'}'
                .toLowerCase()
                .trim();

        // Do not show archived conversations.
        if (conversationStatus ==
            'archived') {
          continue;
        }

        final String orderStatus =
            _normalizeOrderStatus(
          order['status'],
        );

        // Do not show cancelled/rejected orders.
        if (orderStatus == 'cancelled' ||
            orderStatus == 'rejected') {
          continue;
        }

        final String conversationId =
            '${conversation['id']}';

        final String orderId =
            '${conversation['order_id'] ?? ''}';

        final String customerName =
            '${order['customer_name'] ?? 'Customer'}';

        final String lastMessage =
            '${conversation['last_message'] ?? 'No messages yet'}';

        final DateTime? lastMessageAt =
            _parseDate(
          conversation['last_message_at'],
        );

        // Customer messages are unread for the driver.
        final int unreadCount =
            await _getUnreadCount(
          conversationId,
          senderType: 'customer',
        );

        conversations.add(
          ConversationData(
            conversationId:
                conversationId,
            customerName:
                customerName,
            lastMessage:
                lastMessage,
            orderId:
                orderId,
            timeAgo:
                _timeAgo(lastMessageAt),
            unreadCount:
                unreadCount,
            status:
                _deliveryStatusFromOrder(
              orderStatus,
            ),
            highlight:
                unreadCount > 0,
            isStationContact:
                false,
          ),
        );
      }

      // ========================================================================
      // 2. GET / CREATE STATION SUPPORT
      // ========================================================================

      final stationConversation =
          await _getOrCreateStationConversation(
        driverId: driverId,
      );

      if (stationConversation != null) {
        final String conversationId =
            '${stationConversation['id']}';

        final String lastMessage =
            '${stationConversation['last_message'] ?? 'Contact the station for assistance'}';

        final DateTime? lastMessageAt =
            _parseDate(
          stationConversation[
              'last_message_at'],
        );

        // Admin messages are unread for the driver.
        final int unreadCount =
            await _getUnreadCount(
          conversationId,
          senderType: 'admin',
        );

        conversations.add(
          ConversationData(
            conversationId:
                conversationId,
            customerName:
                'Aqua In Lavada',
            lastMessage:
                lastMessage,
            orderId:
                '',
            timeAgo:
                _timeAgo(lastMessageAt),
            unreadCount:
                unreadCount,
            status:
                DeliveryStatus.station,
            highlight:
                unreadCount > 0,
            isStationContact:
                true,
          ),
        );
      }

      // ========================================================================
      // SORT CONVERSATIONS
      // ========================================================================

      conversations.sort(
        (a, b) {
          // Station Support stays on top.
          if (a.isStationContact &&
              !b.isStationContact) {
            return -1;
          }

          if (!a.isStationContact &&
              b.isStationContact) {
            return 1;
          }

          return 0;
        },
      );

      // ========================================================================
      // 3. LOAD ACTIVE DELIVERIES
      // ========================================================================

      final activeResponse =
          await _supabase
              .from('orders')
              .select('''
                id,
                customer_name,
                driver_id,
                status,
                delivery_type,
                gallons,
                total_price,
                created_at
              ''')
              .eq(
                'driver_id',
                driverId,
              )
              .inFilter(
                'status',
                [
                  'assigned',
                  'on_the_way',
                  'in_progress',
                  'in transit',
                  'on the way',
                  'out_for_delivery',
                  'delivering',
                ],
              )
              .order(
                'created_at',
                ascending: false,
              );

      final List<dynamic>
          activeRows =
          activeResponse as List<dynamic>;

      final List<ActiveDeliveryData>
          activeDeliveries =
          activeRows.map(
        (row) {
          final Map<String, dynamic>
              order =
              Map<String, dynamic>.from(
            row,
          );

          final String orderStatus =
              _normalizeOrderStatus(
            order['status'],
          );

          return ActiveDeliveryData(
            customerName:
                '${order['customer_name'] ?? 'Customer'}',
            orderId:
                '${order['id']}',
            status:
                _deliveryStatusFromOrder(
              orderStatus,
            ),
          );
        },
      ).toList();

      // ========================================================================
      // UPDATE UI
      // ========================================================================

      if (!mounted) return;

      setState(() {
        _conversations =
            conversations;

        _activeDeliveries =
            activeDeliveries;

        _isLoading =
            false;

        _isRefreshing =
            false;
      });

      debugPrint(
        'Customer conversations: '
        '${conversations.where((c) => !c.isStationContact).length}',
      );

      debugPrint(
        'Station support conversation: '
        '${conversations.any((c) => c.isStationContact)}',
      );

      debugPrint(
        'Active deliveries: '
        '${activeDeliveries.length}',
      );
    } catch (e) {
      debugPrint(
        'Failed to load driver messages: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load messages: $e',
            ),
          ),
        );
      }
    }
  }

  // ===========================================================================
  // GET / CREATE STATION SUPPORT CONVERSATION
  // ===========================================================================

  Future<Map<String, dynamic>?>
      _getOrCreateStationConversation({
    required String driverId,
  }) async {
    try {
      debugPrint(
        'Checking Station Support for driver: $driverId',
      );

      // ========================================================================
      // FIND EXISTING SUPPORT CHAT
      // ========================================================================
      //
      // IMPORTANT:
      // Do NOT use maybeSingle() here.
      //
      // If there are duplicate support conversations for the same driver,
      // maybeSingle() can throw an error and cause the support card to
      // disappear from the Messages screen.
      //
      // Instead, get the newest support conversation.
      // ========================================================================

      final List<dynamic> existingRows =
          await _supabase
              .from('conversations')
              .select('''
                id,
                order_id,
                customer_id,
                driver_id,
                last_message,
                last_message_at,
                created_at,
                status,
                delivered_at,
                archived_at,
                conversation_type
              ''')
              .eq(
                'conversation_type',
                'support',
              )
              .eq(
                'driver_id',
                driverId,
              )
              .order(
                'created_at',
                ascending: false,
              )
              .limit(1);

      // ========================================================================
      // EXISTING SUPPORT CHAT
      // ========================================================================

      if (existingRows.isNotEmpty) {
        final Map<String, dynamic>
            existing =
            Map<String, dynamic>.from(
          existingRows.first,
        );

        final String status =
            '${existing['status'] ?? 'active'}'
                .toLowerCase()
                .trim();

        // If support chat was archived, reopen it.
        if (status == 'archived') {
          final updated =
              await _supabase
                  .from('conversations')
                  .update({
                    'status': 'active',
                    'archived_at': null,
                  })
                  .eq(
                    'id',
                    existing['id'],
                  )
                  .select()
                  .single();

          debugPrint(
            'Station Support reopened: '
            '${updated['id']}',
          );

          return Map<String, dynamic>.from(
            updated,
          );
        }

        debugPrint(
          'Station Support found: '
          '${existing['id']}',
        );

        return existing;
      }

      // ========================================================================
      // CREATE NEW SUPPORT CHAT
      // ========================================================================

      debugPrint(
        'No Station Support conversation found.',
      );

      debugPrint(
        'Creating Station Support conversation...',
      );

      final created =
          await _supabase
              .from('conversations')
              .insert({
                'order_id': null,
                'customer_id': null,

                // The support conversation belongs
                // to this driver.
                'driver_id':
                    driverId,

                // IMPORTANT:
                // Your database allows:
                // delivery
                // support
                'conversation_type':
                    'support',

                'status':
                    'active',

                'last_message':
                    null,

                'last_message_at':
                    DateTime.now()
                        .toIso8601String(),
              })
              .select()
              .single();

      debugPrint(
        'Station Support created: '
        '${created['id']}',
      );

      return Map<String, dynamic>.from(
        created,
      );
    } catch (e) {
      debugPrint(
        'Station Support error: $e',
      );

      return null;
    }
  }

  // ===========================================================================
  // UNREAD COUNT
  // ===========================================================================

  Future<int> _getUnreadCount(
    String conversationId, {
    required String senderType,
  }) async {
    try {
      final response =
          await _supabase
              .from('messages')
              .select('id')
              .eq(
                'conversation_id',
                conversationId,
              )
              .eq(
                'sender_type',
                senderType,
              )
              .eq(
                'is_read',
                false,
              );

      final List<dynamic>
          messages =
          response as List<dynamic>;

      return messages.length;
    } catch (e) {
      debugPrint(
        'Failed to get unread count: $e',
      );

      return 0;
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  List<ConversationData>
      get _filteredConversations {
    final query =
        _searchQuery
            .toLowerCase()
            .trim();

    if (query.isEmpty) {
      return _conversations;
    }

    return _conversations.where(
      (conversation) {
        return conversation.customerName
                .toLowerCase()
                .contains(query) ||
            conversation.orderId
                .toLowerCase()
                .contains(query) ||
            conversation.lastMessage
                .toLowerCase()
                .contains(query);
      },
    ).toList();
  }

  // ===========================================================================
  // OPEN CUSTOMER CHAT
  // ===========================================================================

  void _openCustomerChat(
    ConversationData conversation,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DriverChatScreen(
          conversationId:
              conversation.conversationId,

          customerName:
              conversation.customerName,

          orderId:
              conversation.orderId,

          status:
              conversation.status.label,

          driverId:
              _currentDriverId ??
                  DriverSession.id ??
                  '',

          isStationContactCenter:
              false,
        ),
      ),
    ).then(
      (_) => _loadMessages(
        silent: true,
      ),
    );
  }

  // ===========================================================================
  // OPEN STATION SUPPORT CHAT
  // ===========================================================================

  void _openStationChat(
    ConversationData conversation,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DriverChatScreen(
          conversationId:
              conversation.conversationId,

          customerName:
              'Aqua In Lavada',

          orderId:
              '',

          status:
              conversation.status.label,

          driverId:
              _currentDriverId ??
                  DriverSession.id ??
                  '',

          isStationContactCenter:
              true,

          stationName:
              'Aqua In Lavada',
        ),
      ),
    ).then(
      (_) => _loadMessages(
        silent: true,
      ),
    );
  }

  // ===========================================================================
  // OPEN CONVERSATION
  // ===========================================================================

  void _openConversation(
    ConversationData conversation,
  ) {
    if (conversation.isStationContact) {
      _openStationChat(
        conversation,
      );
    } else {
      _openCustomerChat(
        conversation,
      );
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _manualRefresh() async {
    await _loadMessages();
  }

  // ===========================================================================
  // NORMALIZE ORDER STATUS
  // ===========================================================================

  String _normalizeOrderStatus(
    dynamic value,
  ) {
    final status =
        '${value ?? ''}'
            .toLowerCase()
            .trim()
            .replaceAll(
              '-',
              '_',
            )
            .replaceAll(
              ' ',
              '_',
            );

    switch (status) {
      case 'on_the_way':
      case 'in_transit':
      case 'in_progress':
      case 'out_for_delivery':
      case 'delivering':
        return 'on_the_way';

      case 'assigned':
      case 'accepted':
        return 'assigned';

      case 'completed':
      case 'delivered':
        return 'completed';

      case 'cancelled':
      case 'canceled':
        return 'cancelled';

      case 'rejected':
        return 'rejected';

      case 'pending':
      default:
        return 'pending';
    }
  }

  // ===========================================================================
  // DELIVERY STATUS
  // ===========================================================================

  DeliveryStatus _deliveryStatusFromOrder(
    String status,
  ) {
    switch (status) {
      case 'on_the_way':
        return DeliveryStatus.delivering;

      case 'assigned':
        return DeliveryStatus.assigned;

      case 'completed':
        return DeliveryStatus.completed;

      case 'pending':
      default:
        return DeliveryStatus.pending;
    }
  }

  // ===========================================================================
  // DATE PARSER
  // ===========================================================================

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    try {
      return DateTime.parse(
        value.toString(),
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // TIME AGO
  // ===========================================================================

  String _timeAgo(
    DateTime? date,
  ) {
    if (date == null) {
      return '';
    }

    final difference =
        DateTime.now().difference(
      date,
    );

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final filtered =
        _filteredConversations;

    final int unreadTotal =
        _conversations.fold(
      0,
      (
        total,
        conversation,
      ) =>
          total +
          conversation.unreadCount,
    );

    return Scaffold(
      backgroundColor:
          _background,
      body:
          SafeArea(
        child:
            Column(
          children: [
            _buildHeader(
              unreadTotal,
            ),

            _buildSearch(),

            _buildActiveDeliveries(),

            const SizedBox(
              height: 8,
            ),

            _SectionHeader(
              title:
                  'Conversations',
              trailing:
                  unreadTotal > 0
                      ? '$unreadTotal unread'
                      : '0 unread',
              onTrailingTap:
                  () {},
            ),

            const SizedBox(
              height: 10,
            ),

            Expanded(
              child:
                  _isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                _primaryBlue,
                          ),
                        )
                      : filtered.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              color:
                                  _primaryBlue,
                              onRefresh:
                                  _manualRefresh,
                              child:
                                  ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  20,
                                ),
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                itemCount:
                                    filtered.length,
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  final conversation =
                                      filtered[index];

                                  return _ConversationCard(
                                    data:
                                        conversation,
                                    onTap:
                                        () {
                                      _openConversation(
                                        conversation,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          _buildBottomNavigation(),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
    int unreadTotal,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        8,
      ),
      child:
          Row(
        children: [
          const Expanded(
            child:
                Text(
              'Messages',
              style:
                  TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w800,
                color:
                    _darkText,
              ),
            ),
          ),

          if (_isRefreshing)
            const Padding(
              padding:
                  EdgeInsets.only(
                right: 10,
              ),
              child:
                  SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      _primaryBlue,
                ),
              ),
            ),

          IconButton(
            tooltip:
                'Search',
            onPressed:
                () {
              FocusScope.of(
                context,
              ).requestFocus();
            },
            icon:
                const Icon(
              Icons.search_rounded,
              color:
                  Color(0xFF334155),
            ),
          ),

          IconButton(
            tooltip:
                'Refresh',
            onPressed:
                _manualRefresh,
            icon:
                const Icon(
              Icons.refresh_rounded,
              color:
                  Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        14,
      ),
      child:
          TextField(
        onChanged:
            (value) {
          setState(() {
            _searchQuery =
                value;
          });
        },
        decoration:
            InputDecoration(
          hintText:
              'Search customer or station...',
          hintStyle:
              const TextStyle(
            color:
                Color(0xFF94A3B8),
            fontSize:
                14,
          ),
          prefixIcon:
              const Icon(
            Icons.search_rounded,
            color:
                Color(0xFF94A3B8),
            size: 20,
          ),
          filled:
              true,
          fillColor:
              Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                const BorderSide(
              color:
                  Color(0xFFE2E8F0),
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                const BorderSide(
              color:
                  Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                const BorderSide(
              color:
                  _primaryBlue,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ACTIVE DELIVERIES
  // ===========================================================================

  Widget _buildActiveDeliveries() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title:
              'Active Deliveries',
          trailing:
              _activeDeliveries.isEmpty
                  ? ''
                  : 'See all',
          onTrailingTap:
              () {
            if (_activeDeliveries
                .isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          const DriverOrdersScreen(),
                ),
              );
            }
          },
        ),

        const SizedBox(
          height: 10,
        ),

        if (_activeDeliveries.isEmpty)
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              16,
              0,
              16,
              8,
            ),
            child:
                Text(
              'No active deliveries.',
              style:
                  TextStyle(
                fontSize: 13,
                color:
                    Color(0xFF94A3B8),
              ),
            ),
          )
        else
          SizedBox(
            height: 108,
            child:
                ListView.separated(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  _activeDeliveries.length,
              separatorBuilder:
                  (
                context,
                index,
              ) =>
                      const SizedBox(
                width: 18,
              ),
              itemBuilder:
                  (
                context,
                index,
              ) {
                final delivery =
                    _activeDeliveries[
                        index];

                return _ActiveDeliveryItem(
                  data:
                      delivery,
                  onTap:
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                const DriverOrdersScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION
  // ===========================================================================

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 2,
      type:
          BottomNavigationBarType.fixed,
      backgroundColor:
          Colors.white,
      elevation: 8,
      selectedItemColor:
          _primaryBlue,
      unselectedItemColor:
          const Color(0xFF94A3B8),
      selectedLabelStyle:
          const TextStyle(
        fontSize: 12,
        fontWeight:
            FontWeight.w700,
      ),
      unselectedLabelStyle:
          const TextStyle(
        fontSize: 12,
        fontWeight:
            FontWeight.w500,
      ),
      onTap:
          (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        const DriverDashboardScreen(),
              ),
            );
            break;

          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        const DriverOrdersScreen(),
              ),
            );
            break;

          case 2:
            break;

          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        const DriverMapScreen(),
              ),
            );
            break;

          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        const DriverProfileScreen(),
              ),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon:
              Icon(
            Icons.home_outlined,
          ),
          activeIcon:
              Icon(
            Icons.home_rounded,
          ),
          label:
              'Dashboard',
        ),
        BottomNavigationBarItem(
          icon:
              Icon(
            Icons.receipt_long_outlined,
          ),
          activeIcon:
              Icon(
            Icons.receipt_long_rounded,
          ),
          label:
              'Orders',
        ),
        BottomNavigationBarItem(
          icon:
              Icon(
            Icons.chat_bubble_outline_rounded,
          ),
          activeIcon:
              Icon(
            Icons.chat_bubble_rounded,
          ),
          label:
              'Messages',
        ),
        BottomNavigationBarItem(
          icon:
              Icon(
            Icons.navigation_outlined,
          ),
          activeIcon:
              Icon(
            Icons.navigation_rounded,
          ),
          label:
              'Map',
        ),
        BottomNavigationBarItem(
          icon:
              Icon(
            Icons.person_outline_rounded,
          ),
          activeIcon:
              Icon(
            Icons.person_rounded,
          ),
          label:
              'Profile',
        ),
      ],
    );
  }
}

// ============================================================================
// ACTIVE DELIVERY ITEM
// ============================================================================

class _ActiveDeliveryItem
    extends StatelessWidget {
  const _ActiveDeliveryItem({
    required this.data,
    required this.onTap,
  });

  final ActiveDeliveryData data;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      child:
          SizedBox(
        width:
            82,
        child:
            Column(
          children: [
            Container(
              width:
                  64,
              height:
                  64,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFF2563EB,
                  ),
                  width:
                      2,
                ),
              ),
              child:
                  Center(
                child:
                    Text(
                  data.customerName
                          .isNotEmpty
                      ? data
                          .customerName
                          .substring(
                          0,
                          1,
                        )
                          .toUpperCase()
                      : 'C',
                  style:
                      const TextStyle(
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(
                      0xFF2563EB,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              height:
                  6,
            ),

            Text(
              data.customerName,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize:
                    12,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(
                  0xFF334155,
                ),
              ),
            ),

            const SizedBox(
              height:
                  2,
            ),

            Text(
              _shortOrderId(
                data.orderId,
              ),
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize:
                    10,
                color:
                    Color(
                  0xFF94A3B8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortOrderId(
    String id,
  ) {
    if (id.isEmpty) {
      return '';
    }

    if (id.length <= 8) {
      return id;
    }

    return '#${id.substring(id.length - 6)}';
  }
}

// ============================================================================
// CONVERSATION CARD
// ============================================================================

class _ConversationCard
    extends StatelessWidget {
  const _ConversationCard({
    required this.data,
    required this.onTap,
  });

  final ConversationData data;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isStation =
        data.isStationContact;

    final bool hasUnread =
        data.unreadCount > 0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(
              0x0A0F172A,
            ),
            blurRadius:
                14,
            offset:
                Offset(
              0,
              5,
            ),
          ),
        ],
        border:
            Border.all(
          color:
              hasUnread
                  ? const Color(
                      0xFFBFDBFE,
                    )
                  : const Color(
                      0xFFF1F5F9,
                    ),
        ),
      ),
      child:
          Material(
        color:
            Colors.transparent,
        child:
            InkWell(
          onTap:
              onTap,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                // --------------------------------------------------------------
                // AVATAR
                // --------------------------------------------------------------

                Stack(
                  clipBehavior:
                      Clip.none,
                  children: [
                    Container(
                      width:
                          54,
                      height:
                          54,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            isStation
                                ? const Color(
                                    0xFFFFF7ED,
                                  )
                                : const Color(
                                    0xFFEFF6FF,
                                  ),
                        border:
                            Border.all(
                          color:
                              isStation
                                  ? const Color(
                                      0xFFF97316,
                                    )
                                  : const Color(
                                      0xFF2563EB,
                                    ),
                          width:
                              1.8,
                        ),
                      ),
                      child:
                          Center(
                        child:
                            isStation
                                ? const Icon(
                                    Icons
                                        .support_agent_rounded,
                                    color:
                                        Color(
                                      0xFFF97316,
                                    ),
                                    size:
                                        27,
                                  )
                                : Text(
                                    data.customerName
                                            .isNotEmpty
                                        ? data
                                            .customerName
                                            .substring(
                                            0,
                                            1,
                                          )
                                            .toUpperCase()
                                        : 'C',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          19,
                                      fontWeight:
                                          FontWeight.w800,
                                      color:
                                          Color(
                                        0xFF2563EB,
                                      ),
                                    ),
                                  ),
                      ),
                    ),

                    if (isStation)
                      Positioned(
                        right:
                            -2,
                        bottom:
                            -2,
                        child:
                            Container(
                          width:
                              18,
                          height:
                              18,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            shape:
                                BoxShape.circle,
                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFFF97316,
                              ),
                              width:
                                  1.4,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .headset_mic_rounded,
                            size:
                                10,
                            color:
                                Color(
                              0xFFF97316,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  width:
                      12,
                ),

                // --------------------------------------------------------------
                // MESSAGE INFORMATION
                // --------------------------------------------------------------

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              data.customerName,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                color:
                                    const Color(
                                  0xFF0F172A,
                                ),
                              ),
                            ),
                          ),

                          Text(
                            data.timeAgo,
                            style:
                                const TextStyle(
                              fontSize:
                                  11,
                              color:
                                  Color(
                                0xFF94A3B8,
                              ),
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            4,
                      ),

                      // Station Support label
                      if (isStation)
                        Container(
                          margin:
                              const EdgeInsets.only(
                            bottom:
                                4,
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal:
                                7,
                            vertical:
                                3,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFF7ED,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              6,
                            ),
                          ),
                          child:
                              const Text(
                            'STATION SUPPORT',
                            style:
                                TextStyle(
                              fontSize:
                                  9,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  Color(
                                0xFFC2410C,
                              ),
                            ),
                          ),
                        ),

                      Text(
                        data.lastMessage,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              13,
                          color:
                              hasUnread
                                  ? const Color(
                                      0xFF334155,
                                    )
                                  : const Color(
                                      0xFF94A3B8,
                                    ),
                          fontWeight:
                              hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                        ),
                      ),

                      const SizedBox(
                        height:
                            7,
                      ),

                      Row(
                        children: [
                          if (!isStation &&
                              data.orderId
                                  .isNotEmpty)
                            _SmallTag(
                              text:
                                  _shortOrderId(
                                data.orderId,
                              ),
                            ),

                          if (!isStation &&
                              data.orderId
                                  .isNotEmpty)
                            const SizedBox(
                              width:
                                  6,
                            ),

                          _StatusTag(
                            status:
                                data.status,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --------------------------------------------------------------
                // UNREAD BADGE
                // --------------------------------------------------------------

                if (hasUnread)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      left:
                          8,
                    ),
                    child:
                        CircleAvatar(
                      radius:
                          11,
                      backgroundColor:
                          isStation
                              ? const Color(
                                  0xFFF97316,
                                )
                              : const Color(
                                  0xFF2563EB,
                                ),
                      child:
                          Text(
                        '${data.unreadCount}',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortOrderId(
    String id,
  ) {
    if (id.isEmpty) {
      return '';
    }

    if (id.length <= 8) {
      return id;
    }

    return 'Order #${id.substring(id.length - 6)}';
  }
}

// ============================================================================
// SMALL TAG
// ============================================================================

class _SmallTag
    extends StatelessWidget {
  const _SmallTag({
    required this.text,
  });

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            4,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFEFF6FF,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Text(
        text,
        style:
            const TextStyle(
          fontSize:
              10,
          color:
              Color(
            0xFF2563EB,
          ),
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS TAG
// ============================================================================

class _StatusTag
    extends StatelessWidget {
  const _StatusTag({
    required this.status,
  });

  final DeliveryStatus status;

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isCompleted =
        status ==
            DeliveryStatus.completed;

    final bool isPending =
        status ==
            DeliveryStatus.pending;

    final bool isAssigned =
        status ==
            DeliveryStatus.assigned;

    final bool isStation =
        status ==
            DeliveryStatus.station;

    final Color color =
        isStation
            ? const Color(
                0xFFC2410C,
              )
            : isCompleted
                ? const Color(
                    0xFF15803D,
                  )
                : isPending
                    ? const Color(
                        0xFFB45309,
                      )
                    : isAssigned
                        ? const Color(
                            0xFF0369A1,
                          )
                        : const Color(
                            0xFF1D4ED8,
                          );

    final Color bg =
        isStation
            ? const Color(
                0xFFFFEDD5,
              )
            : isCompleted
                ? const Color(
                    0xFFDCFCE7,
                  )
                : isPending
                    ? const Color(
                        0xFFFEF3C7,
                      )
                    : isAssigned
                        ? const Color(
                            0xFFE0F2FE,
                          )
                        : const Color(
                            0xFFDBEAFE,
                          );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            3,
      ),
      decoration:
          BoxDecoration(
        color:
            bg,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Text(
        status.label,
        style:
            TextStyle(
          color:
              color,
          fontSize:
              10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal:
              16,
        ),
        padding:
            const EdgeInsets.all(
          24,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          boxShadow:
              const [
            BoxShadow(
              color:
                  Color(
                0x12233455,
              ),
              blurRadius:
                  12,
              offset:
                  Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child:
            const Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .chat_bubble_outline_rounded,
              color:
                  Color(
                0xFF94A3B8,
              ),
              size:
                  42,
            ),

            SizedBox(
              height:
                  10,
            ),

            Text(
              'No conversations yet',
              style:
                  TextStyle(
                fontSize:
                    16,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(
                  0xFF0F172A,
                ),
              ),
            ),

            SizedBox(
              height:
                  4,
            ),

            Text(
              'Customer and station messages will appear here.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    13,
                color:
                    Color(
                  0xFF64748B,
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
// SECTION HEADER
// ============================================================================

class _SectionHeader
    extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
    required this.onTrailingTap,
  });

  final String title;

  final String trailing;

  final VoidCallback
      onTrailingTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            16,
      ),
      child:
          Row(
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize:
                  15,
              fontWeight:
                  FontWeight.w700,
              color:
                  Color(
                0xFF0F172A,
              ),
            ),
          ),

          const Spacer(),

          if (trailing.isNotEmpty)
            GestureDetector(
              onTap:
                  onTrailingTap,
              child:
                  Text(
                trailing,
                style:
                    const TextStyle(
                  fontSize:
                      12,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(
                    0xFF2563EB,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// DELIVERY STATUS
// ============================================================================

enum DeliveryStatus {
  pending(
    'Pending',
  ),

  assigned(
    'Assigned',
  ),

  delivering(
    'On the Way',
  ),

  completed(
    'Completed',
  ),

  station(
    'Station Support',
  );

  const DeliveryStatus(
    this.label,
  );

  final String label;
}

// ============================================================================
// ACTIVE DELIVERY MODEL
// ============================================================================

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

// ============================================================================
// CONVERSATION MODEL
// ============================================================================

class ConversationData {
  const ConversationData({
    required this.conversationId,
    required this.customerName,
    required this.lastMessage,
    required this.orderId,
    required this.timeAgo,
    required this.unreadCount,
    required this.status,
    this.highlight = false,
    this.isStationContact = false,
  });

  final String conversationId;

  final String customerName;

  final String lastMessage;

  final String orderId;

  final String timeAgo;

  final int unreadCount;

  final DeliveryStatus status;

  final bool highlight;

  final bool isStationContact;
}