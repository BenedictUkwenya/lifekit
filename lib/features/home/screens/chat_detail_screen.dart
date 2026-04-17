import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../provider/screens/subscription_plans_screen.dart';
import 'report_user_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final dynamic otherUser;
  final List
  bookings; // Passed to contextually switch, though usually 1-on-1 per booking now

  const ChatDetailScreen({
    super.key,
    required this.otherUser,
    required this.bookings,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _typingChannel;
  Timer? _typingDebounceTimer;
  Timer? _typingVisibilityTimer;
  bool _hasBooking = false;

  List<dynamic> messages = [];
  bool isLoading = true;
  bool isSending = false;
  bool _isOtherUserTyping = false;
  bool _isTypingBroadcastActive = false;
  String _subscriptionTier = 'free';
  bool _isLoadingTier = false;
  bool _hasLoadedTier = false;
  final List<String> _savedReplies = [
    'Hi, I am on my way!',
    'Here is my pricing and what is included.',
    'Thanks for reaching out. I can start today.',
    'I just shared an update. Please check and confirm.',
  ];

  // Current Booking Context
  late dynamic currentBooking;
  bool isChatLocked = false;

  bool get _isProviderForCurrentBooking {
    if (!_hasBooking) return false;
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;
    return currentBooking['provider_id'] == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onMessageInputChanged);
    _loadSubscriptionTier();
    // Default to the first booking passed
    if (widget.bookings.isNotEmpty) {
      _selectBooking(widget.bookings[0]);
    }
  }

  void _selectBooking(dynamic booking) {
    setState(() {
      currentBooking = booking;
      _hasBooking = true;
      // Check Status for Locking
      String status = booking['status'] ?? 'pending';
      isChatLocked = (status == 'completed' || status == 'cancelled');
    });
    _fetchMessages();
    _subscribeToMessages(booking['id'].toString());
    _subscribeToTyping(booking['id'].toString());
  }

  Future<void> _subscribeToMessages(String bookingId) async {
    if (_messagesChannel != null) {
      await _supabase.removeChannel(_messagesChannel!);
    }

    _messagesChannel = _supabase.channel('public:messages:booking:$bookingId');
    _messagesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'booking_id',
        value: bookingId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (!mounted) return;
        final recordId = record['id'];
        if (recordId != null && messages.any((m) => m['id'] == recordId)) {
          return;
        }
        setState(() => messages.add(record));
        _scrollToBottom();
      },
    );

    _messagesChannel!.subscribe();
  }

  Future<void> _subscribeToTyping(String bookingId) async {
    if (_typingChannel != null) {
      await _supabase.removeChannel(_typingChannel!);
    }

    _typingChannel = _supabase.channel('public:typing:booking:$bookingId');
    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (!mounted) return;
        final currentUserId = _supabase.auth.currentUser?.id;
        final senderId = payload['sender_id']?.toString();
        if (currentUserId != null && senderId == currentUserId) return;

        final isTyping = payload['is_typing'] == true;
        _typingVisibilityTimer?.cancel();

        if (isTyping) {
          setState(() => _isOtherUserTyping = true);
          _typingVisibilityTimer = Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _isOtherUserTyping = false);
          });
        } else {
          setState(() => _isOtherUserTyping = false);
        }
      },
    );

    _typingChannel!.subscribe();
  }

  Future<void> _fetchMessages({bool isPolling = false}) async {
    try {
      final data = await _apiService.getMessages(currentBooking['id']);
      if (mounted) {
        setState(() {
          messages = data;
          if (!isPolling) isLoading = false;
        });
        if (!isPolling) _scrollToBottom();
      }
      try {
        await _apiService.markChatAsRead(currentBooking['id'].toString());
      } catch (_) {}
    } catch (e) {
      if (!isPolling) setState(() => isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || isChatLocked) return;

    final content = _messageController.text;
    _messageController.clear();
    _broadcastTyping(isTyping: false);
    setState(() => isSending = true);

    try {
      await _apiService.sendMessage(currentBooking['id'], content);
      setState(() => isSending = false);
      _fetchMessages(isPolling: true);
      _scrollToBottom();
    } catch (e) {
      setState(() => isSending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _onMessageInputChanged() {
    if (!_hasBooking || isChatLocked) return;
    _typingDebounceTimer?.cancel();

    final hasText = _messageController.text.trim().isNotEmpty;
    if (!hasText) {
      _broadcastTyping(isTyping: false);
      return;
    }

    _typingDebounceTimer = Timer(const Duration(milliseconds: 650), () {
      _broadcastTyping(isTyping: true);
    });
  }

  Future<void> _broadcastTyping({required bool isTyping}) async {
    if (_typingChannel == null || !_hasBooking) return;
    if (!isTyping && !_isTypingBroadcastActive) return;

    final userId = _supabase.auth.currentUser?.id;
    try {
      await _typingChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'booking_id': currentBooking['id'],
          'sender_id': userId,
          'is_typing': isTyping,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _isTypingBroadcastActive = isTyping;
    } catch (_) {}
  }

  Future<void> _loadSubscriptionTier() async {
    if (_isLoadingTier) return;
    _isLoadingTier = true;
    try {
      final tier = await _apiService.getCurrentSubscriptionTier();
      setState(() {
        _subscriptionTier = tier.toLowerCase();
        _hasLoadedTier = true;
        _hasLoadedTier = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionTier = 'free';
        _hasLoadedTier = true;
      });
    } finally {
      _isLoadingTier = false;
    }
  }

  Future<void> _onSavedRepliesTap() async {
    if (_isLoadingTier) return;
    if (!_hasLoadedTier) await _loadSubscriptionTier();

    final tier = _subscriptionTier.toLowerCase();
    final hasAccess = tier == 'pro' || tier == 'business';
    if (!mounted) return;
    if (hasAccess) {
      _showSavedRepliesSheet();
    } else {
      _showUpgradeToProSheet();
    }
  }

  void _showUpgradeToProSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upgrade to Pro to use Saved Replies',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save time by inserting pre-written templates.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionPlansScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      shadowColor: AppColors.primary.withOpacity(0.35),
                    ),
                    child: Text(
                      'Upgrade Now',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSavedRepliesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Saved Replies',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 12),
                ..._savedReplies.map((reply) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = reply;
                        _messageController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: reply.length),
                            );
                      },
                      title: Text(
                        reply,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.north_west_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatMessageTime(dynamic rawTime) {
    final parsed = DateTime.tryParse(rawTime?.toString() ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broadcastTyping(isTyping: false);
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
    }
    if (_typingChannel != null) {
      _supabase.removeChannel(_typingChannel!);
    }
    _typingDebounceTimer?.cancel();
    _typingVisibilityTimer?.cancel();
    _messageController.removeListener(_onMessageInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasBooking) {
      _subscribeToMessages(currentBooking['id'].toString());
      _subscribeToTyping(currentBooking['id'].toString());
      _fetchMessages(isPolling: true);
    } else if (state == AppLifecycleState.paused) {
      _broadcastTyping(isTyping: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          // 1. UNIQUE: Service Context Ticket
          _buildServiceTicket(),

          // 1b. Swap Contract banner (swap bookings only)
          _buildSwapContractBanner(),

          // 1c. Sticky deadline banner (confirmed bookings only)
          _buildDeadlineBanner(),

          // 2. Chat Area
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // null sender_id = system message (handled inside
                      // _buildMessageBubble). A non-null id that is NOT the
                      // other user's id means the current user sent it.
                      final senderId = msg['sender_id'];
                      final bool isMe =
                          senderId != null &&
                          senderId != widget.otherUser['id'];
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // 3. Input Area OR Locked Message
          if (isChatLocked)
            _buildLockedFooter()
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isProviderForCurrentBooking) _buildQuickActionBar(),
                _buildTypingIndicator(),
                _buildInputArea(),
              ],
            ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  AppBar _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            backgroundImage: widget.otherUser['profile_picture_url'] != null
                ? CachedNetworkImageProvider(
                    widget.otherUser['profile_picture_url'],
                  )
                : null,
            child: widget.otherUser['profile_picture_url'] == null
                ? const Icon(Icons.person, size: 20, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          // Expanded lets the Column take remaining space and prevents
          // long names from overflowing into the action icons.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser['full_name'] ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (!isChatLocked)
                  Text(
                    "Online",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.report_outlined, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReportUserScreen(targetUserId: widget.otherUser['id']),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.phone_outlined, color: Colors.black),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "In-app calling is coming soon!",
                  style: GoogleFonts.poppins(),
                ),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  // ── Swap Contract Banner ───────────────────────────────────────────────
  Widget _buildSwapContractBanner() {
    if (currentBooking == null) return const SizedBox.shrink();
    final price = currentBooking!['total_price'] ?? 0;
    if (price != 0) return const SizedBox.shrink(); // not a swap

    final String status = currentBooking!['status'] ?? 'pending';
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green.shade600;
        statusLabel = 'Swap Active';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'completed':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'Swap Completed';
        statusIcon = Icons.verified_outlined;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade400;
        statusLabel = 'Swap Cancelled';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = AppColors.primary;
        statusLabel = 'Awaiting Confirmation';
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.07),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Swap Contract',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (status == 'pending')
                  Text(
                    'Waiting for the other party to confirm',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 11, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The "Ticket" at the top showing what we are talking about
  // ── Deadline sticky banner ────────────────────────────────────────────────
  Widget _buildDeadlineBanner() {
    if (currentBooking == null) return const SizedBox.shrink();
    final String status = currentBooking['status'] ?? '';
    if (status != 'confirmed') return const SizedBox.shrink();

    final DateTime? scheduledTime = DateTime.tryParse(
      currentBooking['scheduled_time'] ?? '',
    );
    if (scheduledTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = scheduledTime.difference(now);

    // Grace: show up to 30 min past start
    if (diff.inMinutes < -30) return const SizedBox.shrink();

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final scheduledMidnight = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );
    final dayDiff = scheduledMidnight.difference(todayMidnight).inDays;

    String bannerText;
    Color bannerColor;
    IconData bannerIcon;

    if (diff.inMinutes <= 120) {
      bannerText = '🔴 Service is happening Today!';
      bannerColor = Colors.red.shade600;
      bannerIcon = Icons.alarm_on_rounded;
    } else if (dayDiff == 0) {
      final h = scheduledTime.hour % 12 == 0 ? 12 : scheduledTime.hour % 12;
      final m = scheduledTime.minute.toString().padLeft(2, '0');
      final period = scheduledTime.hour >= 12 ? 'PM' : 'AM';
      bannerText = '⏰ Service is happening Today at $h:$m $period';
      bannerColor = AppColors.primary;
      bannerIcon = Icons.today_rounded;
    } else if (dayDiff == 1) {
      bannerText = '📅 Service is Tomorrow';
      bannerColor = Colors.orange.shade700;
      bannerIcon = Icons.event_rounded;
    } else if (dayDiff == 2) {
      bannerText = '🗓️ Service is in 2 Days';
      bannerColor = Colors.blue.shade600;
      bannerIcon = Icons.calendar_today_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: bannerColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                color: bannerColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTicket() {
    if (currentBooking == null) return const SizedBox();

    final serviceName = currentBooking['services']?['title'] ?? 'Service';
    final price = currentBooking['total_price'] ?? 0;
    bool isSwap = price == 0;
    String status = currentBooking['status'] ?? 'pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSwap ? Icons.swap_horiz : Icons.receipt_long,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Status: ${status.toUpperCase()}",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (widget.bookings.length > 1)
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey,
            ), // Hint they can switch
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    // null sender_id = system-generated pill (booking confirmed, disputed, etc.)
    // The legacy 'SYSTEM' string check keeps old database rows rendering correctly.
    final bool isSystemMessage =
        msg['sender_id'] == null ||
        (msg['sender_id']?.toString().toUpperCase() == 'SYSTEM') ||
        (msg['type']?.toString().toLowerCase() == 'system');

    if (isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          // Cap width so very long system messages wrap instead of overflow.
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            (msg['content'] ?? '').toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final messageTime = _formatMessageTime(msg['created_at']);
    final isRead = msg['is_read'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg['content'],
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            if (messageTime.isNotEmpty) const SizedBox(height: 6),
            if (messageTime.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messageTime,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withOpacity(0.85)
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: isRead
                          ? const Color(0xFF59B8FF)
                          : Colors.grey.shade300,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final typingName = (widget.otherUser['full_name'] ?? 'User').toString();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: !_isOtherUserTyping
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('typing-indicator'),
              margin: const EdgeInsets.only(left: 18, right: 18, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$typingName is typing',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _applyQuickActionText(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Widget _buildQuickActionBar() {
    final actions = ["Request Location", "Send Offer", "Mark Complete"];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final label = actions[index];
          return ActionChip(
            label: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            shape: StadiumBorder(
              side: BorderSide(color: AppColors.primary.withOpacity(0.25)),
            ),
            onPressed: () => _applyQuickActionText(label),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: actions.length,
      ),
    );
  }

  // The "Beautiful" Floating Input
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.transparent, // Floating feel
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "File attachments are coming soon!",
                            style: GoogleFonts.poppins(),
                          ),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primary.withOpacity(0.9),
                    ),
                    onPressed: _onSavedRepliesTap,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // The "Chat Locked" Footer
  Widget _buildLockedFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Colors.grey, size: 30),
          const SizedBox(height: 8),
          Text(
            "This service is marked as ${currentBooking['status']}.",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            "Messaging is disabled for completed or cancelled services.",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.waving_hand, size: 40, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            "Say Hello!",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            "Start the conversation to discuss details.",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'confirmed') return Colors.green;
    if (status == 'completed') return AppColors.primary;
    if (status == 'cancelled') return Colors.red;
    return Colors.orange;
  }
}
