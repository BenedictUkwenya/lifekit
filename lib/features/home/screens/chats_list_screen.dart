import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'chat_detail_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<dynamic> allConversations = [];
  List<dynamic> filteredConversations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchChats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredConversations = allConversations.where((chat) {
        final name = (chat['other_user']['full_name'] ?? '')
            .toString()
            .toLowerCase();
        final lastMessage = (chat['last_message'] ?? '')
            .toString()
            .toLowerCase();
        // Also search by service title
        final bookings = chat['bookings'] as List;
        bool serviceMatch = bookings.any(
          (b) => (b['services']['title'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query),
        );

        return name.contains(query) ||
            serviceMatch ||
            lastMessage.contains(query);
      }).toList();
    });
  }

  List<dynamic> get _activeConversations =>
      filteredConversations.where((chat) => chat['is_active'] == true).toList();

  List<dynamic> get _finishedConversations =>
      filteredConversations.where((chat) => chat['is_active'] != true).toList();

  String _formatRelativeTime(dynamic rawTime) {
    if (rawTime == null) return '';
    final parsed = DateTime.tryParse(rawTime.toString());
    if (parsed == null) return '';

    final now = DateTime.now();
    final localTime = parsed.toLocal();
    final diff = now.difference(localTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inHours < 48) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${localTime.day}/${localTime.month}';
  }

  Future<void> _fetchChats() async {
    try {
      final data = await _apiService.getConversations();
      if (mounted) {
        setState(() {
          allConversations = data;
          filteredConversations = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching chats: $e");
    }
  }

  void _navigateToDetail(dynamic otherUser, List bookings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatDetailScreen(otherUser: otherUser, bookings: bookings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: LifeKitLoader()),
      );
    }

    final currentList = _tabController.index == 0
        ? _activeConversations
        : _finishedConversations;
    final isActiveTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "Messages",
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Starting a new conversation is coming soon!",
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
            icon: Container(
              padding: const EdgeInsets.all(8),
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
              child: const Icon(
                Icons.edit_square,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchChats,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  hintText: "Search for chats or services...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (allConversations.isNotEmpty) ...[
              Text(
                "Recent Contacts",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allConversations.length,
                  itemBuilder: (context, index) {
                    return _buildActiveAvatar(allConversations[index]);
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppColors.primary,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Finished'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (currentList.isEmpty)
              _buildTabEmptyState(isActiveTab)
            else
              ...currentList.map((chat) => _buildModernChatTile(chat)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabEmptyState(bool isActiveTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(
              isActiveTab
                  ? Icons.mark_chat_unread_outlined
                  : Icons.history_rounded,
              size: 40,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 10),
            Text(
              isActiveTab
                  ? "No active conversations right now"
                  : "Your past chats will appear here",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAvatar(dynamic chat) {
    final otherUser = chat['other_user'];
    final pic = otherUser['profile_picture_url'];
    final bookings = chat['bookings'] as List;

    return GestureDetector(
      onTap: () => _navigateToDetail(otherUser, bookings),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2), // Border width
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 2,
                ), // The "Ring"
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[200],
                backgroundImage: pic != null
                    ? CachedNetworkImageProvider(pic)
                    : null,
                child: pic == null
                    ? Text(
                        (otherUser['full_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.black54),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (otherUser['full_name'] ?? 'User').split(' ')[0],
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernChatTile(dynamic chat) {
    final otherUser = chat['other_user'];
    final bookings = chat['bookings'] as List;
    final unreadCount = int.tryParse('${chat['unread_count'] ?? 0}') ?? 0;
    final hasUnread = unreadCount > 0;
    final String lastActive = _formatRelativeTime(chat['last_message_time']);
    final String lastMessage =
        (chat['last_message'] ?? '').toString().trim().isEmpty
        ? "No messages yet"
        : chat['last_message'].toString();

    String serviceContext = "General";
    if (bookings.isNotEmpty) {
      serviceContext = bookings[0]['services']['title'];
      if (bookings.length > 1) serviceContext += " +${bookings.length - 1}";
    }

    return GestureDetector(
      onTap: () => _navigateToDetail(otherUser, bookings),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: otherUser['profile_picture_url'] != null
                      ? CachedNetworkImageProvider(
                          otherUser['profile_picture_url'],
                        )
                      : null,
                  child: otherUser['profile_picture_url'] == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                // Online Dot
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: chat['is_active'] == true
                          ? Colors.green
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherUser['full_name'] ?? 'User',
                          style: GoogleFonts.poppins(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Wrap in Flexible so this side can never push
                      // the name text off-screen.
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (lastActive.isNotEmpty)
                              Text(
                                lastActive,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            if (lastActive.isNotEmpty)
                              const SizedBox(width: 6),
                            // Hard cap so a long title can't overflow.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 90),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  serviceContext,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.grey[700],
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            hasUnread
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: unreadCount > 99 ? 8 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
