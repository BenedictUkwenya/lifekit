import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  final List<dynamic> bookings;

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
  final TextEditingController _controller = TextEditingController();
  List<dynamic> messages = [];
  bool isLoading = true;
  Timer? _timer;
  String? myUserId;

  // Determines which booking we are currently sending messages about
  late dynamic activeBooking;

  @override
  void initState() {
    super.initState();
    // Default to the most recent booking (first in list)
    activeBooking = widget.bookings.first;

    _getId();
    _fetchMessages();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _fetchMessages(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getId() async {
    final profile = await _apiService.getUserProfile();
    if (mounted) setState(() => myUserId = profile['profile']['id']);
  }

  Future<void> _fetchMessages() async {
    try {
      // Extract all IDs
      List<String> ids = widget.bookings
          .map((b) => b['id'].toString())
          .toList();
      final data = await _apiService.getChatHistory(ids);
      if (mounted) {
        setState(() {
          messages = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();

    try {
      // Send to the ACTIVE booking ID
      await _apiService.sendMessage(activeBooking['id'], text);
      _fetchMessages();
    } catch (e) {
      print("Error sending: $e");
    }
  }

  // --- PROVIDER ACTIONS ---
  Future<void> _updateStatus(String status) async {
    try {
      await _apiService.updateBookingStatus(activeBooking['id'], status);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Booking $status")));

      // Update local state to reflect change visually immediately
      setState(() {
        activeBooking['status'] = status;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pic = widget.otherUser['profile_picture_url'];
    final name = widget.otherUser['full_name'] ?? 'User';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: pic != null
                  ? CachedNetworkImageProvider(pic)
                  : null,
              child: pic == null
                  ? Text(name[0], style: const TextStyle(color: Colors.black))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- BOOKING INFO CARD (Scrollable if multiple) ---
          Container(
            height: 130, // Fixed height for card
            color: Colors.grey[50],
            child: PageView.builder(
              itemCount: widget.bookings.length,
              onPageChanged: (index) {
                setState(() => activeBooking = widget.bookings[index]);
              },
              itemBuilder: (context, index) {
                return _buildBookingCard(widget.bookings[index]);
              },
            ),
          ),

          if (widget.bookings.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "${widget.bookings.length} Bookings - Swipe to switch context",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),

          const Divider(height: 1),

          // --- CHAT AREA ---
          Expanded(
            child: isLoading
                ? const Center(child: const LifeKitLoader())
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == myUserId;
                      return _buildMessageBubble(
                        msg['content'],
                        isMe,
                        msg['created_at'],
                      );
                    },
                  ),
          ),

          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText:
                          "Message about: ${activeBooking['service_title']}",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    final status = booking['status'];
    final bool isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  booking['service_title'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                Text(
                  "\$${booking['price']} • ${status.toUpperCase()}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _getStatusColor(status),
                  ),
                ),
              ],
            ),
          ),
          if (isPending) ...[
            // Provider Actions inside Chat
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _updateStatus('confirmed'),
              tooltip: "Accept",
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _updateStatus('cancelled'),
              tooltip: "Reject",
            ),
          ] else
            const Icon(Icons.info_outline, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'confirmed') return Colors.green;
    if (status == 'cancelled') return Colors.red;
    if (status == 'pending') return Colors.orange;
    return Colors.black;
  }
}
