import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

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

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> messages = [];
  bool isLoading = true;
  bool isSending = false;

  // Current Booking Context
  late dynamic currentBooking;
  bool isChatLocked = false;

  @override
  void initState() {
    super.initState();
    // Default to the first booking passed
    if (widget.bookings.isNotEmpty) {
      _selectBooking(widget.bookings[0]);
    }
    // Start Polling (Real-time simulation)
    _startPolling();
  }

  void _selectBooking(dynamic booking) {
    setState(() {
      currentBooking = booking;
      // Check Status for Locking
      String status = booking['status'] ?? 'pending';
      isChatLocked = (status == 'completed' || status == 'cancelled');
    });
    _fetchMessages();
  }

  void _startPolling() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _fetchMessages(isPolling: true);
        _startPolling();
      }
    });
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
    setState(() => isSending = true);

    try {
      await _apiService.sendMessage(currentBooking['id'], content);
      setState(() => isSending = false);
      _fetchMessages(isPolling: true);
      _scrollToBottom();
    } catch (e) {
      setState(() => isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
                      // Identify sender. If sender_id matches OtherUser ID, it's incoming.
                      bool isMe = msg['sender_id'] != widget.otherUser['id'];
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // 3. Input Area OR Locked Message
          if (isChatLocked) _buildLockedFooter() else _buildInputArea(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUser['full_name'] ?? 'User',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (!isChatLocked)
                Text(
                  "Online",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.green),
                ),
            ],
          ),
        ],
      ),
      actions: [
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

  // The "Ticket" at the top showing what we are talking about
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
        child: Text(
          msg['content'],
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
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
