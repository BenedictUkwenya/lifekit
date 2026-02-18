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

class _ChatsListScreenState extends State<ChatsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> allConversations = [];
  List<dynamic> filteredConversations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
        // Also search by service title
        final bookings = chat['bookings'] as List;
        bool serviceMatch = bookings.any(
          (b) => (b['services']['title'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query),
        );

        return name.contains(query) || serviceMatch;
      }).toList();
    });
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Premium Off-White
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
            onPressed: () {},
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Bar
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
              const SizedBox(height: 30),

              // 2. Active Now (Visual Touch)
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
                const SizedBox(height: 10),
              ],

              // 3. Main Chat List
              Text(
                "Conversations",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              if (filteredConversations.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    final chat = filteredConversations[index];
                    return _buildModernChatTile(chat);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              "No messages yet",
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
    final String lastActive =
        "2m ago"; // Mocked time for now (requires message API to be perfect)

    // Get Service Name (e.g. "Plumbing")
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
                      color: Colors.green,
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
                      Text(
                        otherUser['full_name'] ?? 'User',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        lastActive,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // The "Service Badge" - Shows context immediately
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 12,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            serviceContext,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
