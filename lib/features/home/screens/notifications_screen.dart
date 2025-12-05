import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// Navigation Targets
import '../../bookings/screens/bookings_screen.dart';
import 'chats_list_screen.dart';
// import 'event_receipt_screen.dart'; // If you want to deep link to tickets later

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final data = await _apiService.getNotifications();
      if (mounted) {
        setState(() {
          notifications = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- ACTIONS ---

  Future<void> _handleTap(dynamic notif) async {
    // 1. Mark as Read (Optimistic UI update)
    if (notif['is_read'] == false) {
      setState(() {
        notif['is_read'] = true;
      });
      // Call API silently
      _apiService.markNotificationRead(notif['id']);
    }

    // 2. Navigate based on Type
    final type = notif['type'];
    // final refId = notif['reference_id']; // Use this if you want to fetch specific details

    if (type == 'chat_message') {
      // Go to Chats List (Deep linking to specific chat requires fetching the booking object first)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatsListScreen()),
      );
    } else if (type.toString().startsWith('booking_')) {
      // Go to Bookings Tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
      );
    } else if (type == 'event_ticket') {
      // Stay here or show snackbar, or go to wallet/history if you have one
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("View ticket in your email or transactions."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(notifications[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notif) {
    final bool isRead = notif['is_read'] ?? false;
    final String type = notif['type'] ?? 'system';
    final DateTime created = DateTime.parse(notif['created_at']);
    final String timeAgo = _getTimeAgo(created);

    return GestureDetector(
      onTap: () => _handleTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? Colors.white
              : const Color(0xFFFFF9FA), // Light pink tint for unread
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : AppColors.primary.withOpacity(0.3),
          ),
          boxShadow: isRead
              ? []
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON BASED ON TYPE
            _buildIcon(type),

            const SizedBox(width: 16),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notif['title'] ?? 'Notification',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isRead ? Colors.black : AppColors.primary,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeAgo,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
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

  Widget _buildIcon(String type) {
    IconData icon;
    Color color;

    if (type == 'chat_message') {
      icon = Icons.chat_bubble_outline;
      color = Colors.blue;
    } else if (type.startsWith('booking')) {
      icon = Icons.calendar_today;
      color = Colors.orange;
    } else if (type == 'event_ticket') {
      icon = Icons.confirmation_number_outlined;
      color = Colors.green;
    } else if (type == 'service_review') {
      icon = Icons.verified_outlined;
      color = Colors.purple;
    } else {
      icon = Icons.notifications_outlined;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  String _getTimeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return DateFormat('MMM dd').format(date);
  }
}
