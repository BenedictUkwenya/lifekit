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

  List<dynamic> allConversations = []; // Source of truth
  List<dynamic> filteredConversations = []; // Display list
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
        return name.contains(query);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: const LifeKitLoader());
    }

    // Note: We removed the full screen empty state to allow showing the search bar
    // even if list is empty initially, but you can revert if preferred.

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Chats",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SEARCH BAR
            _buildSearchBar(),

            const SizedBox(height: 24),

            // 2. ONLINE FRIENDS CAROUSEL (Mocking "Online" with recent contacts)
            if (allConversations.isNotEmpty) ...[
              Text(
                "Active Now",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allConversations.length,
                  itemBuilder: (context, index) {
                    return _buildAvatarItem(allConversations[index]);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 3. FILTER TABS (Visual only for now)
            Row(
              children: [
                _buildTab("All", true),
                const SizedBox(width: 12),
                _buildTab("Services", false),
                const SizedBox(width: 12),
                _buildTab("Communities", false),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              "Messages",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // 4. VERTICAL LIST (Grouped Logic)
            if (filteredConversations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "No messages found",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(), // Let parent scroll
                itemCount: filteredConversations.length,
                itemBuilder: (context, index) {
                  final chat = filteredConversations[index];
                  final bookings = chat['bookings'] as List;
                  final otherUser = chat['other_user'];

                  return _buildConversationTile(otherUser, bookings);
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          hintText: "Search name...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildAvatarItem(dynamic chat) {
    final otherUser = chat['other_user'];
    final pic = otherUser['profile_picture_url'];
    final bookings = chat['bookings'] as List;

    return GestureDetector(
      onTap: () => _navigateToDetail(otherUser, bookings),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Stack(
          children: [
            CircleAvatar(
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
            // Green Dot for "Online"
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(dynamic otherUser, List bookings) {
    return GestureDetector(
      onTap: () => _navigateToDetail(otherUser, bookings),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        color: Colors.transparent, // Make clickable
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              backgroundImage: otherUser['profile_picture_url'] != null
                  ? CachedNetworkImageProvider(otherUser['profile_picture_url'])
                  : null,
              child: otherUser['profile_picture_url'] == null
                  ? Text(
                      (otherUser['full_name'] ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
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
                          fontSize: 14,
                        ),
                      ),
                      // Show "2 Bookings" badge if multiple, else time (mocked for now)
                      if (bookings.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${bookings.length} Orders",
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else
                        Text(
                          "10:45",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tap to view chat & booking details",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  Widget _buildTab(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.grey,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
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
}
