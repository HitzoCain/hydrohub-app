import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverChatScreen extends StatefulWidget {
  const DriverChatScreen({
    super.key,
    required this.customerName,
    required this.orderId,
    required this.status,
    required this.conversationId,
    required this.driverId,

    // Station Contact Center support
    this.isStationContactCenter = false,
    this.stationName = 'Aqua In Lavada',
  });

  final String customerName;
  final String orderId;
  final String status;
  final String conversationId;
  final String driverId;

  /// True when this conversation is with the station/admin.
  final bool isStationContactCenter;

  /// Name displayed for the station contact.
  final String stationName;

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  static const Color _background = Color(0xFFF6F8FB);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);

  static const Color _stationOrange = Color(0xFFF97316);
  static const Color _stationLight = Color(0xFFFFF7ED);

  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<_ChatMessage> _messages = [];

  bool _loading = true;
  bool _sending = false;

  String _customerPhone = '';

  String _productInfo = '';

  Timer? _refreshTimer;

  bool get _isStationChat => widget.isStationContactCenter;

  String get _chatName {
    if (_isStationChat) {
      return widget.stationName;
    }

    return widget.customerName;
  }

  String get _chatSubtitle {
    if (_isStationChat) {
      return 'Station Contact Center';
    }

    return _customerPhone.isNotEmpty ? _customerPhone : 'Phone unavailable';
  }

  @override
  void initState() {
    super.initState();

    _loadMessages();

    // Auto refresh every 3 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      if (!_isStationChat && _customerPhone.isEmpty) {
        await _loadCustomerPhone();
      }

      final data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      final loadedMessages = (data as List)
          .map((item) => _ChatMessage.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;

      setState(() {
        _messages = loadedMessages;

        if (!silent) {
          _loading = false;
        }
      });

      await _markIncomingMessagesRead();

      if (!silent) {
        _scrollToBottom();
      }
    } catch (error) {
      debugPrint('Failed to load driver messages: $error');

      if (!silent && mounted) {
        setState(() {
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load messages.')),
        );
      }
    }
  }

  Future<void> _markIncomingMessagesRead() async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', widget.conversationId)
          .eq('sender_type', _isStationChat ? 'admin' : 'customer')
          .eq('is_read', false);
    } catch (error) {
      debugPrint('Failed to mark driver chat messages as read: $error');
    }
  }

  Future<void> _loadCustomerPhone() async {
    if (widget.orderId.trim().isEmpty) return;

    try {
      final order = await _supabase
          .from('orders')
          .select('customer_phone, product_name, capacity, gallons')
          .eq('id', widget.orderId)
          .maybeSingle();

      _customerPhone = order?['customer_phone']?.toString().trim() ?? '';
      _productInfo = _formatProductInfo(order);
    } catch (error) {
      debugPrint('Failed to load customer phone: $error');
    }
  }

  String _formatProductInfo(Map<String, dynamic>? order) {
    final product = order?['product_name']?.toString().trim();
    final capacity = order?['capacity']?.toString().trim();
    final quantity = order?['gallons']?.toString().trim();

    final productLabel = product == null || product.isEmpty ? 'Water' : product;
    final sizeLabel = capacity == null || capacity.isEmpty
        ? 'Size unavailable'
        : capacity;
    final quantityLabel = quantity == null || quantity.isEmpty ? '0' : quantity;

    return '$productLabel • $sizeLabel • $quantityLabel Containers';
  }

  Future<void> _callCustomer() async {
    if (_customerPhone.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number is not available.'),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: _customerPhone);
    final launched = await launchUrl(uri);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone app.')),
      );
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final now = DateTime.now().toLocal();

      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_type': 'driver',
        'sender_id': widget.driverId,
        'message': text,
        'is_read': false,
        'created_at': now.toIso8601String(),
      });

      // Update conversation preview.
      await _supabase
          .from('conversations')
          .update({
            'last_message': text,
            'last_message_at': now.toIso8601String(),

            // A new message makes the conversation active.
            'status': 'active',
            'archived_at': null,
          })
          .eq('id', widget.conversationId);

      _messageController.clear();

      await _loadMessages();

      _scrollToBottom();
    } catch (error) {
      debugPrint('Failed to send message: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isStationChat
                  ? 'Failed to send message to the station.'
                  : 'Failed to send message.',
            ),
          ),
        );
      }
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(DateTime dateTime) {
    return TimeOfDay.fromDateTime(dateTime).format(context);
  }

  // ============================================================
  // MESSAGE TYPE
  // ============================================================

  String _senderLabel(_ChatMessage message) {
    switch (message.senderType) {
      case 'admin':
        return _isStationChat ? 'Station Contact Center' : 'Admin';

      case 'driver':
        return 'You';

      case 'customer':
        return widget.customerName;

      default:
        return 'Unknown';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,

        iconTheme: const IconThemeData(color: _darkText),

        titleSpacing: 0,

        title: Row(
          children: [
            // ==================================================
            // PROFILE CIRCLE
            // ==================================================
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isStationChat ? _stationLight : const Color(0xFFEFF4FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isStationChat
                      ? const Color(0xFFFED7AA)
                      : const Color(0xFFDBEAFE),
                ),
              ),
              alignment: Alignment.center,

              child: _isStationChat
                  ? const Icon(
                      Icons.support_agent_rounded,
                      color: _stationOrange,
                      size: 21,
                    )
                  : Text(
                      widget.customerName.isNotEmpty
                          ? widget.customerName.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),

            const SizedBox(width: 10),

            // ==================================================
            // NAME + SUBTITLE
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _darkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    _chatSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isStationChat ? _stationOrange : _secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          if (!_isStationChat)
            IconButton(
              tooltip: 'Call customer',
              onPressed: _callCustomer,
              icon: const Icon(Icons.phone_outlined),
            ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              _loadMessages();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER INFORMATION
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),

              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: _isStationChat
                      ? _stationLight
                      : const Color(0xFFEFF4FF),

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(
                    color: _isStationChat
                        ? const Color(0xFFFED7AA)
                        : const Color(0xFFDBEAFE),
                  ),

                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================
                    Container(
                      width: 42,
                      height: 42,

                      decoration: BoxDecoration(
                        color: _isStationChat ? _stationOrange : _primaryBlue,
                        shape: BoxShape.circle,
                      ),

                      alignment: Alignment.center,

                      child: Icon(
                        _isStationChat
                            ? Icons.support_agent_rounded
                            : Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ==================================================
                    // INFORMATION
                    // ==================================================
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isStationChat
                                ? 'Station Contact Center'
                                : (_productInfo.isNotEmpty
                                      ? _productInfo
                                      : 'Water • Size unavailable • 0 Containers'),

                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _darkText,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            _isStationChat
                                ? 'Contact the station for assistance or delivery concerns.'
                                : 'Delivery Status: ${widget.status}',

                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // MESSAGES
            // ==================================================
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryBlue),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),

                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isStationChat
                                  ? Icons.support_agent_outlined
                                  : Icons.chat_bubble_outline_rounded,

                              size: 58,

                              color: const Color(0xFF94A3B8),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              _isStationChat
                                  ? 'Contact the Station'
                                  : 'Start conversation with customer',

                              textAlign: TextAlign.center,

                              style: const TextStyle(
                                color: _secondaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _isStationChat
                                  ? 'Send a message to the station for assistance.'
                                  : 'Send a message to coordinate the delivery.',

                              textAlign: TextAlign.center,

                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,

                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),

                      itemCount: _messages.length,

                      itemBuilder: (context, index) {
                        final message = _messages[index];

                        return _MessageBubble(
                          message: message,

                          senderName: _senderLabel(message),

                          timeLabel: _formatTime(message.createdAt),

                          customerName: widget.customerName,

                          stationName: widget.stationName,

                          isStationChat: _isStationChat,
                        );
                      },
                    ),
            ),

            // ==================================================
            // MESSAGE INPUT
            // ==================================================
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,

                      textInputAction: TextInputAction.send,

                      onSubmitted: (_) => _sendMessage(),

                      decoration: InputDecoration(
                        hintText: _isStationChat
                            ? 'Message the station...'
                            : 'Type a message...',

                        filled: true,

                        fillColor: const Color(0xFFF1F5F9),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  InkWell(
                    onTap: _sending ? null : _sendMessage,

                    borderRadius: BorderRadius.circular(24),

                    child: Container(
                      width: 46,
                      height: 46,

                      decoration: BoxDecoration(
                        color: _sending
                            ? const Color(0xFF94A3B8)
                            : _isStationChat
                            ? _stationOrange
                            : _primaryBlue,

                        shape: BoxShape.circle,
                      ),

                      alignment: Alignment.center,

                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE MODEL
// ============================================================

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.senderType,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String senderType;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  factory _ChatMessage.fromMap(Map<String, dynamic> map) {
    return _ChatMessage(
      id: map['id']?.toString() ?? '',
      senderType: map['sender_type']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.senderName,
    required this.timeLabel,
    required this.customerName,
    required this.stationName,
    required this.isStationChat,
  });

  final _ChatMessage message;
  final String senderName;
  final String timeLabel;
  final String customerName;
  final String stationName;
  final bool isStationChat;

  @override
  Widget build(BuildContext context) {
    final isDriver = message.senderType == 'driver';

    final isAdmin = message.senderType == 'admin';

    final isCustomer = message.senderType == 'customer';

    // ----------------------------------------------------------
    // Driver = RIGHT
    // Admin / Customer = LEFT
    // ----------------------------------------------------------

    final alignment = isDriver ? Alignment.centerRight : Alignment.centerLeft;

    // ----------------------------------------------------------
    // Bubble colors
    // ----------------------------------------------------------

    final bubbleColor = isDriver
        ? const Color(0xFF2563EB)
        : isAdmin
        ? const Color(0xFFFFF7ED)
        : Colors.white;

    final textColor = isDriver ? Colors.white : const Color(0xFF0F172A);

    final senderColor = isDriver
        ? Colors.white
        : isAdmin
        ? const Color(0xFFC2410C)
        : const Color(0xFF334155);

    // ----------------------------------------------------------
    // Border radius
    // ----------------------------------------------------------

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isDriver ? 16 : 4),
      bottomRight: Radius.circular(isDriver ? 4 : 16),
    );

    // ----------------------------------------------------------
    // Avatar
    // ----------------------------------------------------------

    Widget avatar;

    if (isAdmin) {
      // ========================================================
      // ADMIN / STATION
      // ========================================================

      avatar = Container(
        width: 34,
        height: 34,

        decoration: BoxDecoration(
          color: isStationChat
              ? const Color(0xFFFFEDD5)
              : const Color(0xFFFFEDD5),

          shape: BoxShape.circle,
        ),

        alignment: Alignment.center,

        child: Icon(
          isStationChat
              ? Icons.support_agent_rounded
              : Icons.admin_panel_settings_rounded,

          size: 18,

          color: const Color(0xFFC2410C),
        ),
      );
    } else if (isCustomer) {
      // ========================================================
      // CUSTOMER
      // ========================================================

      avatar = Container(
        width: 34,
        height: 34,

        decoration: const BoxDecoration(
          color: Color(0xFFEFF4FF),
          shape: BoxShape.circle,
        ),

        alignment: Alignment.center,

        child: Text(
          customerName.isNotEmpty
              ? customerName.substring(0, 1).toUpperCase()
              : '?',

          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
    } else {
      avatar = const SizedBox(width: 34, height: 34);
    }

    return Align(
      alignment: alignment,

      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),

        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              if (!isDriver) ...[avatar, const SizedBox(width: 8)],

              Flexible(
                child: Column(
                  crossAxisAlignment: isDriver
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // SENDER
                    // ==================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),

                      child: Text(
                        senderName,

                        style: TextStyle(
                          color: senderColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ==================================================
                    // MESSAGE
                    // ==================================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),

                      decoration: BoxDecoration(
                        color: bubbleColor,

                        borderRadius: borderRadius,

                        border: isAdmin
                            ? Border.all(color: const Color(0xFFFED7AA))
                            : null,

                        boxShadow: isDriver
                            ? const []
                            : const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                      ),

                      child: Text(
                        message.message,

                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ==================================================
                    // TIME
                    // ==================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),

                      child: Text(
                        timeLabel,

                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
