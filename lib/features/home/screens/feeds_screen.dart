import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../widgets/comments_sheet.dart'; // Import Comment Sheet
import 'event_detail_screen.dart'; // Import Event Details

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<dynamic> posts = [];
  List<dynamic> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final postsData = await _apiService.getFeeds();
      final eventsData = await _apiService.getEvents();
      if (mounted) {
        setState(() {
          posts = postsData;
          events = eventsData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "Feeds",
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: AppColors.primary,
          ),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tabs: [
            _buildTab("Feeds"),
            _buildTab("Events"),
            _buildTab("Communities"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeedsList(),
                _buildEventsList(),
                _buildCommunitiesPlaceholder(),
              ],
            ),
    );
  }

  Widget _buildTab(String text) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // --- TAB 1: FEEDS ---
  Widget _buildFeedsList() {
    if (posts.isEmpty) {
      return Center(child: Text("No feeds yet", style: GoogleFonts.poppins()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        // Use the Interactive Feed Card
        return _FeedCard(post: posts[index]);
      },
    );
  }

  // --- TAB 2: EVENTS ---
  Widget _buildEventsList() {
    if (events.isEmpty) {
      return Center(
        child: Text("No upcoming events", style: GoogleFonts.poppins()),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _EventCard(event: events[index]);
      },
    );
  }

  // --- TAB 3: COMMUNITIES ---
  Widget _buildCommunitiesPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "Communities coming soon",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPONENT 1: INTERACTIVE FEED CARD (With Likes & Comments)
// =============================================================================
class _FeedCard extends StatefulWidget {
  final dynamic post;
  const _FeedCard({required this.post});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  final ApiService _apiService = ApiService();
  bool isLiked = false;
  int likeCount = 0;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes_count'] ?? 0;
    commentCount = widget.post['comments_count'] ?? 0;
  }

  void _handleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    _apiService.toggleLike(widget.post['id']);
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: widget.post['id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'] ?? {};
    final name = profile['full_name'] ?? 'Admin';
    final handle = profile['username'] ?? '@admin';
    final pic = profile['profile_picture_url'];
    final time = "2hrs ago";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: pic != null
                    ? CachedNetworkImageProvider(pic)
                    : null,
                child: pic == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "$handle • $time",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),

          // Image (If exists)
          if (widget.post['image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: widget.post['image_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) =>
                    Container(height: 200, color: Colors.grey[200]),
              ),
            ),
          if (widget.post['image_url'] != null) const SizedBox(height: 12),

          // Content
          Text(
            widget.post['content'] ?? "",
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Actions Row
          Row(
            children: [
              GestureDetector(
                onTap: _handleLike,
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$likeCount",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: _showComments,
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$commentCount",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPONENT 2: EVENT CARD (With Navigation)
// =============================================================================
class _EventCard extends StatelessWidget {
  final dynamic event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(event['event_date']);
    final dateStr = DateFormat('MMM d, yyyy').format(date);
    final timeStr = event['event_time'] ?? '12:00 PM';
    final price = event['price'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl:
                        event['image_url'] ??
                        "https://via.placeholder.com/400x200",
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) =>
                        Container(height: 180, color: Colors.grey[300]),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event['location'] ?? "Venue",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _infoBox(
                          Icons.calendar_today,
                          "Event Date",
                          dateStr,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoBox(
                          Icons.access_time,
                          "Event Time",
                          timeStr,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Starting from",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "\$$price",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Quick buy action or just navigate
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          "Buy Ticket",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
