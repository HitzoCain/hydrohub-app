import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Note: the project does not have a local `supabase_service.dart` helper.
// Use `Supabase.instance.client` directly instead of importing a missing file.

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textGray = Color(0xFF64748B);

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  StreamSubscription<List<Map<String, dynamic>>>?
      _messageSubscription;

  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _conversation;
  // Note: driver and order full objects are not stored; only derived
  // values like `_driverName`, `_orderNumber`, and `_orderStatus` are used.

  bool _loading = true;
  bool _sending = false;

  String _driverName = 'Delivery Driver';

  String _orderNumber = '';

  String _orderStatus = '';

  @override
  void initState() {
    super.initState();

    _loadConversation();

    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();

    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD CONVERSATION
  // ============================================================

  Future<void> _loadConversation() async {
    try {
      setState(() {
        _loading = true;
      });

      final conversation = await Supabase.instance.client
          .from('conversations')
          .select('*')
          .eq('id', widget.conversationId)
          .maybeSingle();

      if (conversation == null) {
        if (!mounted) return;

        setState(() {
          _conversation = null;
          _loading = false;
        });

        return;
      }

      _conversation = conversation;

      // --------------------------------------------------------
      // Load order
      // --------------------------------------------------------

      final orderId = conversation['order_id'];

      if (orderId != null) {
        try {
          final order = await Supabase.instance.client
              .from('orders')
              .select('*')
              .eq('id', orderId)
              .maybeSingle();

            if (order != null) {
            _orderNumber =
                _getOrderNumber(order);

            _orderStatus =
                _getOrderStatus(order);
          }
        } catch (error) {
          debugPrint(
            'Failed to load order: $error',
          );
        }
      }

      // --------------------------------------------------------
      // Load driver
      // --------------------------------------------------------

      final driverId =
          conversation['driver_id'];

      if (driverId != null &&
          driverId.toString().isNotEmpty) {
        try {
          final driver =
              await Supabase.instance.client
                  .from('employees')
                  .select('*')
                  .eq(
                    'id',
                    driverId,
                  )
                  .maybeSingle();

          if (driver != null) {
            _driverName =
                _getDriverName(driver);
          }
        } catch (error) {
          debugPrint(
            'Failed to load driver: $error',
          );
        }
      }

      // --------------------------------------------------------
      // Load existing messages
      // --------------------------------------------------------

      await _loadMessages();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _scrollToBottom(
        animated: false,
      );
    } catch (error) {
      debugPrint(
        'Failed to load conversation: $error',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> _loadMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq(
            'conversation_id',
            widget.conversationId,
          )
          .order(
            'created_at',
            ascending: true,
          );

      if (!mounted) return;

      setState(() {
        _messages =
            List<Map<String, dynamic>>.from(
          data,
        );
      });
    } catch (error) {
      debugPrint(
        'Failed to load messages: $error',
      );
    }
  }

  // ============================================================
  // REALTIME MESSAGES
  // ============================================================

  void _subscribeToMessages() {
    _messageSubscription = Supabase.instance.client
        .from('messages')
        .stream(
          primaryKey: ['id'],
        )
        .eq(
          'conversation_id',
          widget.conversationId,
        )
        .order(
          'created_at',
          ascending: true,
        )
        .listen(
      (data) {
        if (!mounted) return;

        setState(() {
          _messages =
              List<Map<String, dynamic>>.from(
            data,
          );
        });

        _scrollToBottom();
      },
      onError: (error) {
        debugPrint(
          'Message realtime error: $error',
        );
      },
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text =
        _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (_sending) {
      return;
    }

    try {
      setState(() {
        _sending = true;
      });

      final user =
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No authenticated customer found.',
        );
      }

      // --------------------------------------------------------
      // Insert message
      // --------------------------------------------------------

      await Supabase.instance.client
          .from('messages')
          .insert({
        'conversation_id':
            widget.conversationId,
        'sender_type': 'customer',
        'sender_id': user.id,
        'message': text,
        'is_read': false,
      });

      // --------------------------------------------------------
      // Update conversation preview
      // --------------------------------------------------------

      await Supabase.instance.client
          .from('conversations')
          .update({
        'last_message': text,
        'last_message_at':
            DateTime.now().toIso8601String(),
        'status': 'active',
        'archived_at': null,
      })
          .eq(
        'id',
        widget.conversationId,
      );

      _messageController.clear();

      await _loadMessages();

      _scrollToBottom();
    } catch (error) {
      debugPrint(
        'Failed to send message: $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send message. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom({
    bool animated = true,
  }) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final position =
          _scrollController.position.maxScrollExtent;

      if (animated) {
        _scrollController.animateTo(
          position,
          duration:
              const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(
          position,
        );
      }
    });
  }

  // ============================================================
  // CONVERSATION TYPE
  // ============================================================

  String get _conversationType {
    final value =
        _conversation?['conversation_type'];

    return value?.toString() ?? 'delivery';
  }

  bool get _isSupportConversation {
    return _conversationType ==
        'support';
  }

  // ============================================================
  // DRIVER NAME
  // ============================================================

  String _getDriverName(
    Map<String, dynamic> driver,
  ) {
    final name =
        driver['full_name'] ??
        driver['name'] ??
        driver['employee_name'] ??
        driver['first_name'];

    if (name == null ||
        name.toString().trim().isEmpty) {
      return 'Delivery Driver';
    }

    return name.toString();
  }

  // ============================================================
  // ORDER NUMBER
  // ============================================================

  String _getOrderNumber(
    Map<String, dynamic> order,
  ) {
    final value =
        order['order_number'] ??
        order['order_no'] ??
        order['reference_number'] ??
        order['reference_no'];

    if (value != null &&
        value.toString().trim().isNotEmpty) {
      return value.toString();
    }

    final id = order['id'];

    if (id != null) {
      final idString =
          id.toString();

      if (idString.length >= 6) {
        return idString
            .substring(
              0,
              6,
            )
            .toUpperCase();
      }

      return idString.toUpperCase();
    }

    return '';
  }

  // ============================================================
  // ORDER STATUS
  // ============================================================

  String _getOrderStatus(
    Map<String, dynamic> order,
  ) {
    final value =
        order['status'] ??
        order['order_status'] ??
        '';

    if (value == null) {
      return '';
    }

    return value.toString();
  }

  // ============================================================
  // DISPLAY ORDER STATUS
  // ============================================================

  String _formatOrderStatus(
    String status,
  ) {
    if (status.trim().isEmpty) {
      return 'Delivery';
    }

    final normalized =
        status.toLowerCase();

    switch (normalized) {
      case 'pending':
        return 'Pending';

      case 'confirmed':
        return 'Confirmed';

      case 'assigned':
        return 'Driver Assigned';

      case 'out_for_delivery':
      case 'out-for-delivery':
      case 'on_the_way':
      case 'on-the-way':
        return 'On the way';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return status
            .replaceAll(
              '_',
              ' ',
            )
            .split(' ')
            .map(
              (word) {
                if (word.isEmpty) {
                  return '';
                }

                return word[0]
                        .toUpperCase() +
                    word.substring(1);
              },
            )
            .join(' ');
    }
  }

  // ============================================================
  // SENDER TYPE
  // ============================================================

  String _getSenderType(
    Map<String, dynamic> message,
  ) {
    return (
      message['sender_type'] ??
      ''
    )
        .toString()
        .toLowerCase();
  }

  // ============================================================
  // IS MY MESSAGE
  // ============================================================

  bool _isMyMessage(
    Map<String, dynamic> message,
  ) {
    return _getSenderType(message) ==
        'customer';
  }

  // ============================================================
  // SENDER NAME
  // ============================================================

  String _getSenderName(
    Map<String, dynamic> message,
  ) {
    final senderType =
        _getSenderType(message);

    switch (senderType) {
      case 'customer':
        return 'You';

      case 'driver':
        return _driverName;

      case 'admin':
        return 'Aqua In Lavada • Station Support';

      default:
        return 'Unknown Sender';
    }
  }

  // ============================================================
  // SENDER ROLE
  // ============================================================

  String _getSenderRole(
    Map<String, dynamic> message,
  ) {
    final senderType =
        _getSenderType(message);

    switch (senderType) {
      case 'customer':
        return '';

      case 'driver':
        return 'Delivery Driver';

      case 'admin':
        return 'Station Support';

      default:
        return '';
    }
  }

  // ============================================================
  // SENDER ICON
  // ============================================================

  IconData _getSenderIcon(
    Map<String, dynamic> message,
  ) {
    final senderType =
        _getSenderType(message);

    switch (senderType) {
      case 'driver':
        return Icons.local_shipping_rounded;

      case 'admin':
        return Icons.support_agent_rounded;

      case 'customer':
        return Icons.person_rounded;

      default:
        return Icons.person_outline_rounded;
    }
  }

  // ============================================================
  // SENDER ICON COLOR
  // ============================================================

  Color _getSenderIconColor(
    Map<String, dynamic> message,
  ) {
    final senderType =
        _getSenderType(message);

    switch (senderType) {
      case 'driver':
        return _primaryBlue;

      case 'admin':
        return const Color(0xFFF59E0B);

      case 'customer':
        return Colors.white;

      default:
        return _textGray;
    }
  }

  // ============================================================
  // MESSAGE TIME
  // ============================================================

  String _formatMessageTime(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return '';
    }

    final local =
        date.toLocal();

    final hour =
        local.hour % 12 == 0
            ? 12
            : local.hour % 12;

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: _background,

      appBar: _buildAppBar(),

      body: SafeArea(
        child: Column(
          children: [
            if (!_loading &&
                _conversation != null)
              _buildConversationCard(),

            Expanded(
              child: _buildMessages(),
            ),

            _buildComposer(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    final title =
        _isSupportConversation
            ? 'Aqua In Lavada'
            : _driverName;

    final subtitle =
        _isSupportConversation
            ? 'Station Support'
            : _orderNumber.isNotEmpty
                ? 'Order #$_orderNumber'
                : 'Delivery Driver';

    return AppBar(
      backgroundColor: Colors.white,

      foregroundColor: _textDark,

      elevation: 0,

      scrolledUnderElevation: 0,

      automaticallyImplyLeading: true,

      titleSpacing: 0,

      title: Row(
        children: [
          _buildHeaderAvatar(),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                    color: _textDark,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                    color: _textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _loadConversation();
          },
          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),

        IconButton(
          tooltip: 'Information',
          onPressed: () {
            _showConversationInfo();
          },
          icon: const Icon(
            Icons.info_outline_rounded,
          ),
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  // ============================================================
  // HEADER AVATAR
  // ============================================================

  Widget _buildHeaderAvatar() {
    if (_isSupportConversation) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(
            0xFFFFF7ED,
          ),
          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),
        child: const Icon(
          Icons.support_agent_rounded,
          color: Color(
            0xFFF59E0B,
          ),
          size: 23,
        ),
      );
    }

    final firstLetter =
        _driverName
                .trim()
                .isNotEmpty
            ? _driverName
                .trim()[0]
                .toUpperCase()
            : 'D';

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(
          0xFFEFF4FF,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION CARD
  // ============================================================

  Widget _buildConversationCard() {
    if (_isSupportConversation) {
      return Container(
        margin:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          8,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: const Color(
              0xFFE2E8F0,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFFFFF7ED,
                ),
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(
                  0xFFF59E0B,
                ),
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Station Support',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Aqua In Lavada • General Assistance',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(
          0xFFEFF4FF,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFD9E5FF,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: _primaryBlue,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _orderNumber.isNotEmpty
                      ? 'Order #$_orderNumber'
                      : 'Delivery Order',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color: _textDark,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _orderStatus.isNotEmpty
                      ? 'Delivery Status: ${_formatOrderStatus(_orderStatus)}'
                      : 'Driver: $_driverName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primaryBlue,
        ),
      );
    }

    if (_conversation == null) {
      return _buildConversationNotFound();
    }

    if (_messages.isEmpty) {
      return _buildEmptyMessages();
    }

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        18,
      ),
      itemCount: _messages.length,
      itemBuilder:
          (context, index) {
        final message =
            _messages[index];

        return _MessageBubble(
          message: message,
          senderName:
              _getSenderName(message),
          senderRole:
              _getSenderRole(message),
          senderIcon:
              _getSenderIcon(message),
          senderIconColor:
              _getSenderIconColor(
            message,
          ),
          isMine:
              _isMyMessage(message),
          timestamp:
              _formatMessageTime(
            message['created_at'],
          ),
        );
      },
    );
  }

  // ============================================================
  // EMPTY CHAT
  // ============================================================

  Widget _buildEmptyMessages() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFFEFF4FF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Icon(
                _isSupportConversation
                    ? Icons.support_agent_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: _primaryBlue,
                size: 31,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              _isSupportConversation
                  ? 'Start a conversation with Station Support'
                  : 'Start chatting with your driver',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 15,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _isSupportConversation
                  ? 'Send us a message if you need help with your order or delivery.'
                  : 'Send a message to coordinate your delivery.',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: _textGray,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION NOT FOUND
  // ============================================================

  Widget _buildConversationNotFound() {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 50,
              color: Color(
                0xFF94A3B8,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Conversation not found',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color: _textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'This conversation may no longer be available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE COMPOSER
  // ============================================================

  Widget _buildComposer() {
    final isArchived =
        _conversation?['status'] ==
            'archived';

    if (isArchived) {
      return Container(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          14,
        ),
        decoration:
            const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(
                0xFFE2E8F0,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: _textGray,
            ),

            const SizedBox(width: 10),

            const Expanded(
              child: Text(
                'This conversation has been archived.',
                style: TextStyle(
                  color: _textGray,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(
              0xFFE2E8F0,
            ),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller:
                  _messageController,
              minLines: 1,
              maxLines: 5,
              textInputAction:
                  TextInputAction.newline,
              decoration:
                  InputDecoration(
                hintText: _isSupportConversation
                  ? 'Message Station Support...'
                  : 'Message $_driverName...',
                hintStyle:
                    const TextStyle(
                  color: Color(
                    0xFF94A3B8,
                  ),
                  fontSize: 14,
                ),
                filled: true,
                fillColor:
                    const Color(
                  0xFFF1F5F9,
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  borderSide:
                      const BorderSide(
                    color:
                        _primaryBlue,
                    width: 1,
                  ),
                ),
              ),
              onSubmitted:
                  (_) {
                if (_messageController
                    .text
                    .trim()
                    .isNotEmpty) {
                  _sendMessage();
                }
              },
            ),
          ),

          const SizedBox(width: 9),

          GestureDetector(
            onTap:
                _sending
                    ? null
                    : _sendMessage,
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 150,
              ),
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color: _sending
                    ? const Color(
                        0xFF93C5FD,
                      )
                    : _primaryBlue,
                borderRadius:
                    BorderRadius.circular(
                  23,
                ),
              ),
              child: _sending
                  ? const Padding(
                      padding:
                          EdgeInsets.all(
                        13,
                      ),
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  void _showConversationInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            22,
          ),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Conversation Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed:
                          () =>
                              Navigator.pop(
                        context,
                      ),
                      icon:
                          const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_isSupportConversation)
                  _InfoRow(
                    icon:
                        Icons.support_agent_rounded,
                    label:
                        'Conversation',
                    value:
                        'Station Support',
                  )
                else
                  _InfoRow(
                    icon:
                        Icons.local_shipping_rounded,
                    label:
                        'Driver',
                    value:
                        _driverName,
                  ),

                if (_orderNumber
                    .isNotEmpty)
                  _InfoRow(
                    icon:
                        Icons.receipt_long_rounded,
                    label:
                        'Order',
                    value:
                        '#$_orderNumber',
                  ),

                if (_orderStatus
                    .isNotEmpty)
                  _InfoRow(
                    icon:
                        Icons.local_shipping_outlined,
                    label:
                        'Status',
                    value:
                        _formatOrderStatus(
                      _orderStatus,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class _MessageBubble
    extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.senderName,
    required this.senderRole,
    required this.senderIcon,
    required this.senderIconColor,
    required this.isMine,
    required this.timestamp,
  });

  final Map<String, dynamic> message;

  final String senderName;

  final String senderRole;

  final IconData senderIcon;

  final Color senderIconColor;

  final bool isMine;

  final String timestamp;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isMine) {
      return _buildMyMessage(
        context,
      );
    }

    return _buildIncomingMessage(
      context,
    );
  }

  // ============================================================
  // MY MESSAGE
  // ============================================================

  Widget _buildMyMessage(
    BuildContext context,
  ) {
    return Align(
      alignment:
          Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(
                    context,
                  ).size.width *
                  0.76,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 12,
          left: 45,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFF2563EB),
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      Radius.circular(
                    16,
                  ),
                  topRight:
                      Radius.circular(
                    16,
                  ),
                  bottomLeft:
                      Radius.circular(
                    16,
                  ),
                  bottomRight:
                      Radius.circular(
                    4,
                  ),
                ),
              ),
              child: Text(
                (message['message'] ??
                        '')
                    .toString(),
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'You',
                  style:
                      TextStyle(
                    color:
                        Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                if (timestamp
                    .isNotEmpty) ...[
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    timestamp,
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INCOMING MESSAGE
  // ============================================================

  Widget _buildIncomingMessage(
    BuildContext context,
  ) {
    final isDriver =
        message['sender_type']
                ?.toString()
                .toLowerCase() ==
            'driver';

    final isAdmin =
        message['sender_type']
                ?.toString()
                .toLowerCase() ==
            'admin';

    final bubbleColor = isAdmin
        ? const Color(
            0xFFFFFBEB,
          )
        : const Color(
            0xFFFFFFFF,
          );

    final borderColor = isAdmin
        ? const Color(
            0xFFFDE68A,
          )
        : const Color(
            0xFFE2E8F0,
          );

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(
                    context,
                  ).size.width *
                  0.78,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 13,
          right: 30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // SENDER IDENTIFICATION
            // --------------------------------------------------

            Row(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(
                    color: isAdmin
                        ? const Color(
                            0xFFFFF7ED,
                          )
                        : const Color(
                            0xFFEFF4FF,
                          ),
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                  ),
                  child: Icon(
                    senderIcon,
                    size: 16,
                    color:
                        senderIconColor,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Flexible(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      if (senderRole
                          .isNotEmpty)
                        Text(
                          senderRole,
                          style:
                              TextStyle(
                            color: isDriver
                                ? const Color(
                                    0xFF2563EB,
                                  )
                                : const Color(
                                    0xFFF59E0B,
                                  ),
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // --------------------------------------------------
            // BUBBLE
            // --------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration:
                  BoxDecoration(
                color:
                    bubbleColor,
                borderRadius:
                    const BorderRadius.only(
                  topLeft:
                      Radius.circular(
                    4,
                  ),
                  topRight:
                      Radius.circular(
                    16,
                  ),
                  bottomLeft:
                      Radius.circular(
                    16,
                  ),
                  bottomRight:
                      Radius.circular(
                    16,
                  ),
                ),
                border:
                    Border.all(
                  color:
                      borderColor,
                ),
              ),
              child: Text(
                (message['message'] ??
                        '')
                    .toString(),
                style:
                    const TextStyle(
                  color:
                      Color(0xFF0F172A),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 4),

            if (timestamp
                .isNotEmpty)
              Text(
                timestamp,
                style:
                    const TextStyle(
                  color:
                      Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;

  final String label;

  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEFF4FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color:
                  const Color(
                0xFF2563EB,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF94A3B8),
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    color:
                        Color(0xFF0F172A),
                    fontWeight:
                        FontWeight.w600,
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