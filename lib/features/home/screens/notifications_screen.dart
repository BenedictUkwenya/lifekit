import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// Navigation Targets
import '../../bookings/screens/bookings_screen.dart';
import '../../provider/screens/my_services_list_screen.dart';
import '../../provider/screens/subscription_plans_screen.dart';
import '../../services/screens/skill_swap_dashboard_screen.dart';
import 'chats_list_screen.dart';
import 'feeds_screen.dart';

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

  Future<void> _markAllRead() async {
    // 1. Optimistic UI Update
    setState(() {
      for (var n in notifications) {
        n['is_read'] = true;
      }
    });

    // 2. Call API
    try {
      await _apiService.markAllNotificationsRead();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                "All notifications marked as read",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle error if needed
    }
  }

  Future<void> _deleteNotification(int index, String id) async {
    // 1. Remove from list immediately
    setState(() {
      notifications.removeAt(index);
    });

    // 2. Call API
    try {
      await _apiService.deleteNotification(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                "Notification deleted",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Ideally revert UI change here if fail, but for delete it's rare
      print("Delete failed: $e");
    }
  }

  Future<void> _handleTap(dynamic notif) async {
    // Mark as read
    if (notif['is_read'] == false) {
      setState(() {
        final index = notifications.indexOf(notif);
        if (index != -1) notifications[index]['is_read'] = true;
      });
      _apiService.markNotificationRead(notif['id']);
    }

    final type = notif['type']?.toString() ?? '';

    if (type == 'chat_message') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatsListScreen()),
      );
    } else if (type.startsWith('booking') ||
        type == 'event_ticket' ||
        type == 'dispute_resolved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
      );
    } else if (type == 'service_review') {
      // Rejected/approved service — take user to their services list to fix it
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
      );
    } else if (type == 'trial_expired' ||
        type == 'ai_nudge_no_services' ||
        type == 'ai_nudge_inactive') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
      );
    } else if (type == 'post_comment' ||
        type == 'event_comment' ||
        type == 'group_comment' ||
        type == 'ai_city_pulse') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeedsScreen()),
      );
    } else if (type == 'swap_request' || type == 'swap_update') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SkillSwapDashboardScreen()),
      );
    }
    // system / payment / earning — no navigation, just marking read is enough
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
        actions: [
          // MARK ALL READ BUTTON
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                "Mark all read",
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildDismissibleItem(notif, index);
              },
            ),
    );
  }

  // Wraps item in Dismissible to allow Swipe-to-Delete
  Widget _buildDismissibleItem(dynamic notif, int index) {
    return Dismissible(
      key: Key(notif['id']),
      direction: DismissDirection.endToStart, // Swipe left to delete
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(index, notif['id']);
      },
      child: _buildNotificationItem(notif),
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

    // Types that navigate somewhere on tap
    final bool isActionable =
        type != 'system' &&
        type != 'payment' &&
        type != 'earning' &&
        type != 'refund';

    return GestureDetector(
      onTap: () => _handleTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFF9FA),
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
            _buildIcon(type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'] ?? 'Notification',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isRead ? Colors.black : AppColors.primary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
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
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                      if (isActionable) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· Tap to view',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.primary.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isActionable)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey[300],
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
    } else if (type.startsWith('booking') || type == 'event_ticket') {
      icon = Icons.calendar_today;
      color = Colors.orange;
    } else if (type == 'dispute_resolved' || type == 'booking_dispute') {
      icon = Icons.gavel_rounded;
      color = Colors.purple;
    } else if (type == 'service_review') {
      icon = Icons.rate_review_outlined;
      color = Colors.red;
    } else if (type == 'post_comment' ||
        type == 'event_comment' ||
        type == 'group_comment') {
      icon = Icons.comment_outlined;
      color = Colors.teal;
    } else if (type == 'ai_city_pulse' ||
        type == 'ai_nudge_no_services' ||
        type == 'ai_nudge_inactive') {
      icon = Icons.auto_awesome;
      color = const Color(0xFF89273B);
    } else if (type == 'trial_expired') {
      icon = Icons.timer_off_outlined;
      color = Colors.deepOrange;
    } else if (type == 'swap_request' || type == 'swap_update') {
      icon = Icons.swap_horiz_rounded;
      color = const Color(0xFFE8A020);
    } else if (type == 'earning' || type == 'payment' || type == 'refund') {
      icon = Icons.account_balance_wallet_outlined;
      color = Colors.green;
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
