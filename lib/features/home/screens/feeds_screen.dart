import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_cache.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../widgets/comments_sheet.dart';
import 'event_detail_screen.dart';
import 'feed_detail_screen.dart';
import 'notifications_screen.dart';
import 'saved_posts_screen.dart';

import '../../services/screens/service_booking_detail_screen.dart';
import '../../services/screens/skill_swap_dashboard_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // SWR: paint from cache immediately, then revalidate in background
    _loadFromCache();
    _fetchData();
  }

  void _loadFromCache() {
    final cachedPosts = AppCache.instance.get<List<dynamic>>('feeds');
    final cachedEvents = AppCache.instance.get<List<dynamic>>('events');
    if ((cachedPosts != null || cachedEvents != null) && mounted) {
      setState(() {
        if (cachedPosts != null) posts = cachedPosts;
        if (cachedEvents != null) events = cachedEvents;
        isLoading = false;
      });
    }
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
      final counts = await _apiService.getUnreadCounts();

      if (mounted) {
        setState(() {
          posts = postsData;
          events = eventsData;
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
      backgroundColor: const Color(0xFFEEEEF3),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.black12,
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
                        Icons.bookmark_border_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedPostsScreen(),
                        ),
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.black87,
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
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 9,
                              height: 9,
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
                    const SizedBox(width: 8),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEF3), width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: List.generate(2, (i) {
                      final labels = ['Feeds', 'Events'];
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
                                    color: const Color(0xFFDDDDE5),
                                    width: 1,
                                  ),
                          ),
                          child: Text(
                            labels[i],
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
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
                        children: [_buildFeedsList(), _buildEventsTab()],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── TAB 1: FEEDS ───────────────────────────
  void _openComposeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposePostSheet(
        onPosted: (newPost) {
          setState(() => posts.insert(0, newPost));
        },
      ),
    );
  }

  Widget _buildFeedsList() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: posts.length + 2,
        itemBuilder: (context, index) {
          // index 0 = compose box
          if (index == 0) return _buildComposeBox();
          // index 1 = trending tags strip
          if (index == 1) return _buildTrendingStrip();
          final post = posts[index - 2];
          return _FeedCard(
            key: ValueKey(post['id']),
            post: post,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FeedDetailScreen(post: post)),
            ),
            onDeleted: () {
              final deletedId = post['id'];
              setState(() => posts.removeWhere((p) => p['id'] == deletedId));
            },
          );
        },
      ),
    );
  }

  Widget _buildComposeBox() {
    return GestureDetector(
      onTap: _openComposeSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.10),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        "What's on your mind?",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF0F0F5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _ComposeQuickBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Photo',
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 16),
                  _ComposeQuickBtn(
                    icon: Icons.sell_rounded,
                    label: 'Tag',
                    color: const Color(0xFF3B82F6),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFB74B5C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Post',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildTrendingStrip() {
    final trending = [
      ('🔥', 'Trending', const Color(0xFFFF6B6B)),
      ('🔧', 'Skill Offer', const Color(0xFF3B82F6)),
      ('💡', 'Tips', const Color(0xFFA855F7)),
      ('🤝', 'Swap', AppColors.primary),
      ('🔍', 'Looking For', const Color(0xFFF97316)),
      ('💼', 'Services', const Color(0xFF22C55E)),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Trending',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF6B6B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: trending.map((t) {
                final (emoji, label, color) = t;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
}

// ─────────────────────────────────────────────
// FEED CARD  (thumbnail left, text right)
// ─────────────────────────────────────────────
class _FeedCard extends StatefulWidget {
  final dynamic post;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  const _FeedCard({super.key, required this.post, this.onTap, this.onDeleted});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool isLiked = false;
  int likeCount = 0;
  int commentsCount = 0;
  bool isBookmarked = false;
  String? myId;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _showHeart = false;

  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes_count'] ?? 0;
    isLiked = widget.post['is_liked_by_me'] ?? false;
    commentsCount = widget.post['comments_count'] ?? 0;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _heartScale = CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeOutBack,
    );
    // Entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();
    _loadMyId();
  }

  @override
  void dispose() {
    _heartController.dispose();
    _entranceController.dispose();
    super.dispose();
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

  Future<void> _handleImageDoubleTapLike() async {
    setState(() => _showHeart = true);
    _heartController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });

    if (!isLiked) {
      await _handleLike();
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
                    '${title.isNotEmpty ? '$title\n\n' : ''}$content\n\nShared from LifeKit';
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
                    widget.onDeleted?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete post: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
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
    final title = widget.post['title'] as String? ?? '';
    final content = widget.post['content'] as String? ?? '';
    final tag = widget.post['tag'] as String? ?? 'general';
    final createdAt = widget.post['created_at'];

    // Collect image URLs — prefer image_urls array, fall back to image_url
    final rawUrls = widget.post['image_urls'];
    List<String> images = [];
    if (rawUrls is List && rawUrls.isNotEmpty) {
      images = rawUrls.whereType<String>().toList();
    } else if (widget.post['image_url'] is String &&
        (widget.post['image_url'] as String).isNotEmpty) {
      images = [widget.post['image_url'] as String];
    }

    String dateLabel = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 1) {
          dateLabel = 'Just now';
        } else if (diff.inMinutes < 60) {
          dateLabel = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          dateLabel = '${diff.inHours}h ago';
        } else if (diff.inDays < 7) {
          dateLabel = '${diff.inDays}d ago';
        } else {
          dateLabel = DateFormat('MMM d').format(dt);
        }
      } catch (_) {}
    }

    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFFF0F0F5),
                        backgroundImage: pic != null
                            ? CachedNetworkImageProvider(pic)
                            : null,
                        child: pic == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.grey,
                                size: 21,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _TagChip(tag: tag),
                              ],
                            ),
                            Text(
                              '@$handle · $dateLabel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.grey[400],
                        ),
                        onPressed: _showPostOptions,
                      ),
                    ],
                  ),
                ),

                // ── Text body ──
                if (title.isNotEmpty || content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      images.isEmpty ? 14 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        if (content.isNotEmpty) ...[
                          if (title.isNotEmpty) const SizedBox(height: 4),
                          Text(
                            content,
                            maxLines: images.isNotEmpty ? 2 : 5,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // ── Images ──
                if (images.isNotEmpty)
                  GestureDetector(
                    onDoubleTap: _handleImageDoubleTapLike,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        title.isEmpty && content.isEmpty ? 10 : 0,
                        14,
                        12,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _PostImageGrid(
                          images: images,
                          showHeart: _showHeart,
                          heartScale: _heartScale,
                        ),
                      ),
                    ),
                  ),

                // ── Service CTA (only for service posts) ──
                if (widget.post['service_id'] != null)
                  _ServiceCTABlock(post: widget.post),

                // ── Divider ──
                Container(
                  height: 1,
                  color: const Color(0xFFF0F0F5),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),

                // ── Footer ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      _ActionBtn(
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: '$likeCount',
                        color: isLiked ? Colors.red : Colors.grey[500]!,
                        active: isLiked,
                        onTap: _handleLike,
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '$commentsCount',
                        color: Colors.grey[500]!,
                        active: false,
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CommentsSheet(
                            postId: widget.post['id'],
                            onCommentPosted: () =>
                                setState(() => commentsCount++),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        icon: Icons.repeat_rounded,
                        label: 'Share',
                        color: Colors.grey[500]!,
                        active: false,
                        onTap: () {
                          final text =
                              '${title.isNotEmpty ? '$title\n\n' : ''}$content\n\nShared from LifeKit'
                                  .trim();
                          Share.share(text);
                        },
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _handleBookmark,
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isBookmarked
                              ? AppColors.primary
                              : Colors.grey[400],
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE CTA BLOCK  (Book / Swap buttons on service posts)
// ─────────────────────────────────────────────
class _ServiceCTABlock extends StatelessWidget {
  final dynamic post;
  const _ServiceCTABlock({required this.post});

  // Parse price label from title: "Title • ₦5000" → "₦5,000"
  String _priceLabel() {
    final title = post['title'] as String? ?? '';
    final parts = title.split(' • ');
    return parts.length > 1 ? parts.last.trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final serviceId = post['service_id'] as String;
    final providerId = post['user_id'] as String? ?? '';
    final titleParts = (post['title'] as String? ?? '').split(' • ');
    final serviceTitle = titleParts.first.trim();
    final priceLabel = _priceLabel();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SERVICE',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (priceLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        priceLabel,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (serviceTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    serviceTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Book button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceBookingDetailScreen(
                  providerId: providerId,
                  serviceId: serviceId,
                  serviceTitle: serviceTitle.isNotEmpty
                      ? serviceTitle
                      : 'Service',
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFB74B5C)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '📅 Book',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Swap button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SkillSwapDashboardScreen(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
              ),
              child: Text(
                '🤝 Swap',
                style: GoogleFonts.poppins(
                  color: Color(0xFF3B82F6),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPOSE QUICK BUTTON
// ─────────────────────────────────────────────
class _ComposeQuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ComposeQuickBtn({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BUTTON (footer of feed card)
// ─────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// POST IMAGE GRID  (1, 2, or 3 images)
// ─────────────────────────────────────────────
class _PostImageGrid extends StatelessWidget {
  final List<String> images;
  final bool showHeart;
  final Animation<double> heartScale;
  const _PostImageGrid({
    required this.images,
    required this.showHeart,
    required this.heartScale,
  });

  Widget _img(String url, {double? height, double? width}) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width ?? double.infinity,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget grid;
    if (images.length == 1) {
      grid = _img(images[0], height: 200);
    } else if (images.length == 2) {
      grid = Row(
        children: [
          Expanded(child: _img(images[0], height: 180)),
          const SizedBox(width: 3),
          Expanded(child: _img(images[1], height: 180)),
        ],
      );
    } else {
      // 3 images: one large left, two stacked right
      grid = Row(
        children: [
          Expanded(flex: 3, child: _img(images[0], height: 200)),
          const SizedBox(width: 3),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _img(images[1], height: 98.5),
                const SizedBox(height: 3),
                _img(images[2], height: 98.5),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        grid,
        if (showHeart)
          ScaleTransition(
            scale: heartScale,
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
      ],
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

// ─────────────────────────────────────────────
// TAG CHIP
// ─────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  static const _labels = {
    'general': '✦ General',
    'skill_offer': '🔧 Skill Offer',
    'service': '💼 Service',
    'looking_for': '🔍 Looking For',
    'tip': '💡 Tip',
    'swap': '🤝 Swap',
  };

  static const _colors = {
    'general': Color(0xFF9E9E9E),
    'skill_offer': Color(0xFF3B82F6),
    'service': Color(0xFF22C55E),
    'looking_for': Color(0xFFF97316),
    'tip': Color(0xFFA855F7),
    'swap': AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    if (tag == 'general') return const SizedBox.shrink();
    final label = _labels[tag] ?? tag;
    final color = _colors[tag] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPOSE POST SHEET
// ─────────────────────────────────────────────
class _ComposePostSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> newPost) onPosted;
  const _ComposePostSheet({required this.onPosted});

  @override
  State<_ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends State<_ComposePostSheet> {
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  final _apiService = ApiService();
  String _selectedTag = 'general';
  bool _isPosting = false;
  String? _errorMessage;
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const _tags = [
    ('general', '✦ General', Color(0xFF9E9E9E)),
    ('skill_offer', '🔧 Skill Offer', Color(0xFF3B82F6)),
    ('service', '💼 Service', Color(0xFF22C55E)),
    ('looking_for', '🔍 Looking For', Color(0xFFF97316)),
    ('tip', '💡 Tip', Color(0xFFA855F7)),
    ('swap', '🤝 Swap', AppColors.primary),
  ];

  Future<void> _pickImages() async {
    final remaining = 3 - _pickedImages.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted) return;
    setState(() {
      final toAdd = picked.take(remaining).toList();
      _pickedImages.addAll(toAdd);
    });
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _isPosting = true;
      _errorMessage = null;
    });
    try {
      // Upload images first
      final List<String> uploadedUrls = [];
      for (final xfile in _pickedImages) {
        final url = await _apiService.uploadPostImage(File(xfile.path));
        uploadedUrls.add(url);
      }

      final newPost = await _apiService.createPost(
        content: content,
        title: _titleController.text.trim(),
        imageUrls: uploadedUrls,
        tag: _selectedTag,
      );
      if (mounted) {
        widget.onPosted(newPost);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[ComposePost] ERROR: $e');
      if (mounted) {
        setState(() {
          _isPosting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          // Error banner
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top row: title + post button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Create Post',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isPosting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 0,
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Post',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title field
          TextField(
            controller: _titleController,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Add a title (optional)',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[350],
                fontSize: 15,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 6),

          // Content field
          TextField(
            controller: _contentController,
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // Image previews
          if (_pickedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_pickedImages[i].path),
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImages.removeAt(i)),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF0F0F5)),
          const SizedBox(height: 12),

          // Bottom toolbar: image picker + tag label
          Row(
            children: [
              // Image picker button
              GestureDetector(
                onTap: _pickedImages.length < 3 ? _pickImages : null,
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_library_rounded,
                      color: _pickedImages.length < 3
                          ? const Color(0xFF22C55E)
                          : Colors.grey[300],
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _pickedImages.isEmpty
                          ? 'Add Photos'
                          : '${_pickedImages.length}/3',
                      style: GoogleFonts.poppins(
                        color: _pickedImages.length < 3
                            ? const Color(0xFF22C55E)
                            : Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Tag label
              Text(
                'Tag:',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tag chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((t) {
              final (value, label, color) = t;
              final selected = _selectedTag == value;
              return GestureDetector(
                onTap: () => setState(() => _selectedTag = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.12)
                        : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: selected ? color : Colors.grey[500],
                      fontSize: 12.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
