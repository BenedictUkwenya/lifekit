import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../widgets/comments_sheet.dart';
import 'event_detail_screen.dart';
import 'feed_detail_screen.dart';
import 'notifications_screen.dart';
import 'saved_posts_screen.dart';
import '../../groups/widgets/all_groups_tab.dart';
import '../../groups/screens/create_group_screen.dart';

// ─────────────────────────────────────────────
// FEEDS SCREEN
// ─────────────────────────────────────────────
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
  List<dynamic> groups = [];
  bool isLoading = true;
  int unreadNotifications = 0;

  // Event filtering + search state (persists across tab switches)
  String _selectedCategory = 'All';
  String _eventSearchQuery = '';
  final TextEditingController _eventSearchController = TextEditingController();
  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'emoji': '🌟'},
    {'label': 'Theatre', 'emoji': '🎭'},
    {'label': 'Sport', 'emoji': '🏀'},
    {'label': 'Festival', 'emoji': '🎉'},
    {'label': 'Tourism', 'emoji': '🏛️'},
    {'label': 'Music', 'emoji': '🎵'},
    {'label': 'Food', 'emoji': '🍽️'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final postsData = await _apiService.getFeeds();
      final eventsData = await _apiService.getEvents();
      final groupsData = await _apiService.getGroups();
      final counts = await _apiService.getUnreadCounts();

      if (mounted) {
        setState(() {
          posts = postsData ?? [];
          events = eventsData ?? [];
          groups = groupsData ?? [];
          unreadNotifications = counts['notifications'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get _featuredEvents =>
      events.where((e) => e['is_featured'] == true).toList();

  List<dynamic> get _filteredEvents {
    var list = events;
    if (_selectedCategory != 'All') {
      list = list
          .where(
            (e) =>
                (e['category'] ?? '').toString().toLowerCase() ==
                _selectedCategory.toLowerCase(),
          )
          .toList();
    }
    if (_eventSearchQuery.isNotEmpty) {
      list = list
          .where(
            (e) => (e['title'] ?? '').toString().toLowerCase().contains(
              _eventSearchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              pinned: true,
              floating: true,
              centerTitle: false,
              automaticallyImplyLeading: false,
              title: Text(
                "Feeds",
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              actions: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.bookmark_border,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedPostsScreen(),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.black,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ).then((_) => _fetchData()),
                          ),
                          if (unreadNotifications > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: List.generate(3, (i) {
                      final labels = ['Feeds', 'Events', 'Communities'];
                      final isSelected = _tabController.index == i;
                      return GestureDetector(
                        onTap: () {
                          _tabController.animateTo(i);
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                          ),
                          child: Text(
                            labels[i],
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
          body: isLoading
              ? const Center(child: LifeKitLoader())
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeedsList(),
                          _buildEventsTab(),
                          _buildGroupsList(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── TAB 1: FEEDS ───────────────────────────
  Widget _buildFeedsList() {
    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dynamic_feed_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No feeds yet",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Be the first to post something!",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: posts.length,
        itemBuilder: (context, index) => _FeedCard(
          post: posts[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeedDetailScreen(post: posts[index]),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TAB 2: EVENTS ──────────────────────────
  Widget _buildEventsTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 0. Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _eventSearchController,
                onChanged: (v) => setState(() => _eventSearchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                  suffixIcon: _eventSearchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _eventSearchController.clear();
                            setState(() => _eventSearchQuery = '');
                          },
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 1. Hero Carousel (hide when searching)
          if (_eventSearchQuery.isEmpty) ...[
            if (_featuredEvents.isNotEmpty)
              _EventCarousel(events: _featuredEvents)
            else
              _EventCarousel(events: events.take(4).toList()),
            const SizedBox(height: 12),
          ],

          // 2. Category chips (hide when searching)
          if (_eventSearchQuery.isEmpty)
            _CategoriesRow(
              categories: _categories,
              selected: _selectedCategory,
              onSelect: (cat) => setState(() => _selectedCategory = cat),
            ),

          const SizedBox(height: 12),

          // 3. Popular Today heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _eventSearchQuery.isNotEmpty
                      ? 'Search Results'
                      : 'Popular Today',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.sort, color: Colors.black87),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. Events grid
          if (_filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _eventSearchQuery.isNotEmpty
                          ? 'No events found for "$_eventSearchQuery"'
                          : 'No events in this category',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: _filteredEvents.length,
                itemBuilder: (context, index) =>
                    _EventGridCard(event: _filteredEvents[index]),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── TAB 3: GROUPS ──────────────────────────
  Widget _buildGroupsList() {
    return Column(
      children: [
        _buildCreateGroupBanner(),
        Expanded(
          child: AllGroupsTab(groups: groups, onRefresh: _fetchData),
        ),
      ],
    );
  }

  Widget _buildCreateGroupBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFB74B5C)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Start a Community",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Connect with people who share your interests.",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                final bool? created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
                if (created == true) _fetchData();
              },
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.add, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FEED CARD  (thumbnail left, text right)
// ─────────────────────────────────────────────
class _FeedCard extends StatefulWidget {
  final dynamic post;
  final VoidCallback? onTap;
  const _FeedCard({required this.post, this.onTap});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  final ApiService _apiService = ApiService();
  bool isLiked = false;
  int likeCount = 0;
  int commentsCount = 0;
  bool isBookmarked = false;
  String? myId;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes_count'] ?? 0;
    isLiked = widget.post['is_liked_by_me'] ?? false;
    commentsCount = widget.post['comments_count'] ?? 0;
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await _apiService.getCurrentUserId();
    if (mounted) {
      setState(() {
        myId = id;
      });
    }
  }

  Future<void> _handleLike() async {
    try {
      final result = await _apiService.toggleLike(widget.post['id']);
      if (!mounted) return;
      setState(() {
        isLiked = result['is_liked_by_me'] ?? isLiked;
        likeCount = result['likes_count'] ?? likeCount;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
    }
  }

  Future<void> _handleBookmark() async {
    try {
      final result = await _apiService.toggleBookmark(widget.post['id']);
      if (!mounted) return;
      setState(() {
        isBookmarked = result['is_saved'] ?? isBookmarked;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update bookmark: $e')));
    }
  }

  void _showPostOptions() {
    final bool isOwner = myId != null && widget.post['user_id'] == myId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('Report Post', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post reported. Thank you.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text('Share', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                final content = widget.post['content'] ?? '';
                final title = widget.post['title'] ?? '';
                final text =
                    (title.isNotEmpty ? '$title\n\n' : '') +
                    '$content\n\nShared from LifeKit';
                Share.share(text.trim());
              },
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _apiService.deletePost(widget.post['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post deleted'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete post: $e'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'] ?? {};
    final name = profile['full_name'] ?? 'User';
    final handle = profile['username'] ?? 'user';
    final pic = profile['profile_picture_url'];
    final title = widget.post['title'] ?? '';
    final content = widget.post['content'] ?? '';
    final image = widget.post['image_url'];
    final createdAt = widget.post['created_at'];

    String dateLabel = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        dateLabel = DateFormat("d'th,' MMMM yyyy").format(dt);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + more
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: pic != null
                        ? CachedNetworkImageProvider(pic)
                        : null,
                    child: pic == null
                        ? const Icon(Icons.person, color: Colors.grey, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
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
                          "@$handle",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    color: Colors.grey[400],
                    onPressed: _showPostOptions,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Body: thumbnail left + text right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        width: 100,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 100,
                          height: 90,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(width: image != null ? 12 : 0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        if (content.isNotEmpty) ...[
                          SizedBox(height: title.isNotEmpty ? 4 : 0),
                          Text(
                            content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Footer: like / comment / bookmark  +  date
              Row(
                children: [
                  // Like
                  GestureDetector(
                    onTap: _handleLike,
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$likeCount",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comment
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CommentsSheet(
                        postId: widget.post['id'],
                        onCommentPosted: () {
                          setState(() {
                            commentsCount++;
                          });
                        },
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$commentsCount",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bookmark
                  GestureDetector(
                    onTap: _handleBookmark,
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (dateLabel.isNotEmpty)
                    Text(
                      dateLabel,
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ), // end GestureDetector
    );
  }
}

// ─────────────────────────────────────────────
// EVENT CAROUSEL  (hero slider with dot indicators)
// ─────────────────────────────────────────────
class _EventCarousel extends StatefulWidget {
  final List<dynamic> events;
  const _EventCarousel({required this.events});

  @override
  State<_EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<_EventCarousel> {
  final PageController _pc = PageController();
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.events.length,
            itemBuilder: (context, i) {
              final e = widget.events[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: e),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: e['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40),
                          ),
                        ),
                        // Sponsors / bottom bar overlay (optional)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.white.withOpacity(0.85),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              e['title'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.events.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES ROW
// ─────────────────────────────────────────────
class _CategoriesRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoriesRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final isSelected = cat['label'] == selected;
            return GestureDetector(
              onTap: () => onSelect(cat['label']),
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          cat['emoji'],
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? AppColors.primary : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EVENT GRID CARD  (2-column grid card)
// ─────────────────────────────────────────────
class _EventGridCard extends StatelessWidget {
  final dynamic event;
  const _EventGridCard({required this.event});

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    String dayStr = '';
    String monthStr = '';
    try {
      date = DateTime.parse(event['event_date']);
      dayStr = DateFormat('dd').format(date);
      monthStr = DateFormat('MMM').format(date);
    } catch (_) {}

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl: event['image_url'] ?? '',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.grey[300]),
            ),
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            // Date chip top-left
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$dayStr\n$monthStr",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Title + location bottom
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if ((event['location'] ?? '').isNotEmpty)
                    Text(
                      event['location'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────
// ACTION PILL  (kept for backward compatibility)
// ─────────────────────────────────────────────
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
