import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../../../core/providers/cart_provider.dart';

import '../../services/screens/services_list_screen.dart';
import '../../services/screens/category_items_screen.dart';
import '../../provider/screens/provider_onboarding_intro_screen.dart';
import '../../provider/screens/my_services_list_screen.dart';
import 'feeds_screen.dart';
import 'chats_list_screen.dart';
import 'notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'search_results_screen.dart';
import '../../places/screens/places_list_screen.dart';
import '../../places/screens/place_detail_screen.dart';
import '../../services/screens/service_booking_detail_screen.dart';
import '../../bookings/screens/bookings_screen.dart';
import '../../bookings/screens/cart_screen.dart';
import '../../groups/screens/group_detail_screen.dart';
import 'ai_assistant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? userProfile;
  List<dynamic> offers = [];
  List<dynamic> categories = [];
  List<String> recentSearches = [];
  List<dynamic> popularServices = [];
  List<dynamic> nearbyPlaces = [];
  bool isLoading = true;

  int _currentNavIndex = 0;
  int _currentBannerIndex = 0;
  int _profileScreenRefreshSeed = 0;

  // Places filter
  final List<String> _placeFilters = [
    'Nearby',
    'Popular',
    'Local',
    'Convenient',
    'Central',
  ];
  String _selectedPlaceFilter = 'Nearby';

  // Badge counts & Indicators
  int unreadNotifications = 0;
  int unreadChats = 0;
  int activeBookingsCount = 0;
  bool hasNewFeeds = true; // <-- NEW: Toggle this based on your logic

  // Nearest upcoming confirmed booking (for home banner)
  Map<String, dynamic>? _nearestBooking;

  // AI Discovery recommendations
  List<dynamic> aiRecommendations = [];

  // AI Success Task
  bool _taskDoneToday = false;

  @override
  void initState() {
    super.initState();
    _loadLocalRecents();
    // SWR: paint from cache immediately, then revalidate in background
    _loadHomeCache().then((_) => _fetchAllData());
    _fetchCounts();
    _checkTaskDone();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCounts() async {
    try {
      final data = await _apiService.getUnreadCounts();
      if (mounted) {
        setState(() {
          unreadNotifications = data['notifications'] ?? 0;
          unreadChats = data['chats'] ?? 0;
          activeBookingsCount = data['active_bookings'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLocalRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _checkTaskDone() async {
    final prefs = await SharedPreferences.getInstance();
    final doneDate = prefs.getString('task_done_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (mounted) setState(() => _taskDoneToday = doneDate == today);
  }

  /// Returns the task for today based on days since profile creation.
  Map<String, dynamic>? _getTodayTask() {
    final plan = userProfile?['onboarding_plan'];
    if (plan == null || plan is! List || plan.isEmpty) return null;
    final createdAt = DateTime.tryParse(userProfile?['created_at'] ?? '');
    final dayIndex = createdAt != null
        ? DateTime.now().difference(createdAt).inDays.clamp(0, 6)
        : 0;
    return Map<String, dynamic>.from(plan[dayIndex] as Map);
  }

  Future<void> _saveRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    if (!recentSearches.contains(query)) {
      recentSearches.insert(0, query);
      if (recentSearches.length > 6) recentSearches.removeLast();
      await prefs.setStringList('recent_searches', recentSearches);
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearRecent(String term) async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches.remove(term);
    await prefs.setStringList('recent_searches', recentSearches);
    if (mounted) setState(() {});
  }

  Future<void> _clearAllRecents() async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches.clear();
    await prefs.setStringList('recent_searches', recentSearches);
    if (mounted) setState(() {});
  }

  // ── Stale-While-Revalidate cache helpers ─────────────────────────────────

  /// Paints the UI instantly from SharedPreferences cache (if available).
  /// Sets isLoading = false so the user sees content immediately.
  Future<void> _loadHomeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString('home_cache_profile');
      final cachedOffers = prefs.getString('home_cache_offers');
      final cachedCats = prefs.getString('home_cache_categories');
      final cachedPop = prefs.getString('home_cache_popular');
      if (cachedProfile == null) return; // no cache yet
      if (!mounted) return;
      setState(() {
        userProfile = Map<String, dynamic>.from(
          jsonDecode(cachedProfile) as Map,
        );
        offers = jsonDecode(cachedOffers ?? '[]') as List;
        categories = jsonDecode(cachedCats ?? '[]') as List;
        popularServices = jsonDecode(cachedPop ?? '[]') as List;
        isLoading = false; // show stale content immediately
      });
    } catch (_) {}
  }

  /// Persists fresh home data to SharedPreferences for the next cold start.
  Future<void> _saveHomeCache({
    required Map<String, dynamic> profile,
    required List offers,
    required List categories,
    required List popular,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('home_cache_profile', jsonEncode(profile));
      await prefs.setString('home_cache_offers', jsonEncode(offers));
      await prefs.setString('home_cache_categories', jsonEncode(categories));
      await prefs.setString('home_cache_popular', jsonEncode(popular));
    } catch (_) {}
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _saveRecent(query.trim());
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: query.trim()),
      ),
    );
  }

  Future<void> _fetchAllData() async {
    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getOffers(),
        _apiService.getCategories(),
        _apiService.getPopularServices(),
      ]);

      final profileData = results[0] as Map<String, dynamic>;
      var offersData = results[1] as List<dynamic>;
      final catsData = results[2] as List<dynamic>;
      final popData = results[3] as List<dynamic>;

      if (offersData.isEmpty) {
        offersData = [
          {
            'title': 'Get 20% off your\nfirst booking!',
            'image_url':
                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
            'description': 'Valid until Oct 30',
          },
        ];
      }

      if (mounted) {
        setState(() {
          userProfile = profileData['profile'];
          offers = offersData;
          categories = catsData;
          popularServices = popData;
          isLoading = false;
        });
      }

      // Persist to cache so the next launch is instant (SWR revalidation)
      _saveHomeCache(
        profile: profileData['profile'] as Map<String, dynamic>,
        offers: offersData,
        categories: catsData,
        popular: popData,
      );

      // Non-critical: places
      try {
        final placesData = await _apiService.getNearbyPlaces(6.5244, 3.3792);
        if (mounted) setState(() => nearbyPlaces = placesData);
      } catch (_) {}

      // Non-critical: AI Discovery recommendations
      try {
        final discoveryData = await _apiService.getAiDiscovery();
        final recs = discoveryData['recommendations'] as List<dynamic>? ?? [];
        if (mounted) setState(() => aiRecommendations = recs);
      } catch (_) {}

      // Non-critical: nearest confirmed booking for proactive banner
      try {
        final bookings = await _apiService.getClientBookings();
        final now = DateTime.now();
        final upcoming = bookings.where((b) {
          if (b['status'] != 'confirmed') return false;
          final t = DateTime.tryParse(b['scheduled_time'] ?? '');
          return t != null &&
              t.isAfter(now.subtract(const Duration(minutes: 30)));
        }).toList();
        upcoming.sort(
          (a, b) => DateTime.parse(
            a['scheduled_time'],
          ).compareTo(DateTime.parse(b['scheduled_time'])),
        );
        if (mounted) {
          setState(
            () => _nearestBooking = upcoming.isNotEmpty ? upcoming.first : null,
          );
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Local Flag Helpers ────────────────────

  // Gets the country code from the user's physical phone settings (e.g., 'en_GE' -> 'GE')
  String _getLocalCountryCode() {
    final profileCountry = userProfile?['country']?.toString();
    if (profileCountry != null && profileCountry.trim().length == 2) {
      return profileCountry.trim().toUpperCase();
    }
    return 'NG';
  }

  // Converts the 2-letter country code into a Flag Emoji
  String _getFlagEmoji(String countryCode) {
    final normalized = countryCode.toUpperCase().trim();
    final isValid =
        normalized.length == 2 &&
        normalized.codeUnits.every((c) => c >= 0x41 && c <= 0x5A);
    final safeCode = isValid ? normalized : 'NG';
    const int flagOffset = 0x1F1E6;
    const int asciiOffset = 0x41;
    final int firstChar = safeCode.codeUnitAt(0) - asciiOffset + flagOffset;
    final int secondChar = safeCode.codeUnitAt(1) - asciiOffset + flagOffset;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  // ── Safe Image Helper ──────────────────────
  // Handles cases where Supabase saves the image as a nested list [["url"]]
  String _getSafeImage(
    dynamic item, {
    String fallback = 'https://via.placeholder.com/400',
  }) {
    var rawImages = item['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      var first = rawImages[0];
      if (first is String && first.startsWith('http')) return first;
      if (first is List && first.isNotEmpty) {
        var nested = first[0];
        if (nested is String && nested.startsWith('http')) return nested;
      }
    }
    return fallback;
  }

  // ── Category helpers ──────────────────────
  String _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('health') || name.contains('wellness')) {
      return 'https://cdn-icons-png.flaticon.com/512/2966/2966334.png';
    }
    if (name.contains('laundry')) {
      return 'https://cdn-icons-png.flaticon.com/512/2954/2954888.png';
    }
    if (name.contains('hair') || name.contains('beauty')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050257.png';
    }
    if (name.contains('family') || name.contains('care')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050226.png';
    }
    if (name.contains('plumb') || name.contains('maint')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050239.png';
    }
    if (name.contains('home')) {
      return 'https://cdn-icons-png.flaticon.com/512/619/619153.png';
    }
    if (name.contains('tech')) {
      return 'https://cdn-icons-png.flaticon.com/512/1055/1055687.png';
    }
    if (name.contains('clean')) {
      return 'https://cdn-icons-png.flaticon.com/512/995/995016.png';
    }
    if (name.contains('edu') || name.contains('tutor')) {
      return 'https://cdn-icons-png.flaticon.com/512/2232/2232688.png';
    }
    if (name.contains('event')) {
      return 'https://cdn-icons-png.flaticon.com/512/3132/3132084.png';
    }
    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

  Color _getCategoryColor(String name) {
    name = name.toLowerCase();
    if (name.contains('health')) return const Color(0xFFE3F2FD);
    if (name.contains('laundry')) return const Color(0xFFE8F5E9);
    if (name.contains('hair')) return const Color(0xFFF3E5F5);
    if (name.contains('care') || name.contains('family')) {
      return const Color(0xFFFFEBEE);
    }
    if (name.contains('clean')) return const Color(0xFFE0F7FA);
    if (name.contains('edu')) return const Color(0xFFFFF3E0);
    if (name.contains('tech')) return const Color(0xFFECEFF1);
    if (name.contains('event')) return const Color(0xFFFCE4EC);
    return Colors.grey[100]!;
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeContent(),
      const ServicesListScreen(),
      const FeedsScreen(),
      const ChatsListScreen(),
      ProfileScreen(key: ValueKey('profile_$_profileScreenRefreshSeed')),
    ];

    return Scaffold(
      extendBodyBehindAppBar: _currentNavIndex == 0,
      extendBody:
          true, // IMPORTANT: Lets content scroll behind the floating nav bar
      body: IndexedStack(index: _currentNavIndex, children: screens),
      floatingActionButton: _currentNavIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
                ),
                backgroundColor: AppColors.primary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tooltip: 'LifeKit AI',
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/logo_white2.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // ── FLOATING MODERN BOTTOM NAV ────────────────────────────
  Widget _buildModernBottomNav() {
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Explore',
      ),
      _NavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: 'Feeds',
        showDot: hasNewFeeds,
      ), // <-- Feeds Dot
      _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Chats',
        badge: unreadChats,
      ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9), // Slightly transparent
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ), // Glassmorphism effect
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final active = _currentNavIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentNavIndex = i;
                        if (i == 2) {
                          hasNewFeeds = false; // Clear feeds dot when clicked
                        }
                        if (i == 4) {
                          _profileScreenRefreshSeed += 1;
                        }
                      });
                      _fetchCounts();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                active ? item.activeIcon : item.icon,
                                color: active
                                    ? AppColors.primary
                                    : Colors.grey[400],
                                size: active ? 26 : 24, // Slight pop effect
                              ),
                              // Number Badge
                              if (item.badge != null && item.badge! > 0)
                                Positioned(
                                  right: -6,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${item.badge}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Simple Dot Indicator (For Feeds)
                              if (item.showDot && !active)
                                Positioned(
                                  right: 0,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
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
                          const SizedBox(height: 4),
                          if (active) // Only show text when active for cleaner look, or show all if you prefer
                            Text(
                              item.label,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Home Content ──────────────────────────
  Widget _buildHomeContent() {
    return Stack(
      children: [
        // Background
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/home_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        isLoading
            ? const Center(child: LifeKitLoader())
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _fetchAllData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    // Increased bottom padding to prevent content from hiding behind the floating nav bar
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 22),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildQuickActionBar(),
                        if (_nearestBooking != null) ...[
                          const SizedBox(height: 16),
                          _buildUpcomingBanner(),
                        ],
                        const SizedBox(height: 22),

                        // AI Success Task
                        if (_getTodayTask() != null && !_taskDoneToday) ...[
                          _buildSuccessTaskCard(),
                          const SizedBox(height: 20),
                        ],

                        // AI Recommendations
                        if (aiRecommendations.isNotEmpty) ...[
                          _buildAiRecommendations(),
                          const SizedBox(height: 28),
                        ],

                        // Offers
                        if (offers.isNotEmpty) ...[
                          _buildOffersCard(),
                          const SizedBox(height: 28),
                        ],

                        // Services
                        _buildSectionHeader(
                          'Services',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServicesListScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildServicesRow(),
                        const SizedBox(height: 28),

                        // Popular services
                        _buildPopularServices(),
                        const SizedBox(height: 28),

                        // Recent Searches
                        if (recentSearches.isNotEmpty) ...[
                          _buildRecentSearchesHeader(),
                          const SizedBox(height: 14),
                          _buildRecentSearchCards(),
                          const SizedBox(height: 28),
                        ],

                        // Places
                        _buildSectionHeader(
                          'Places',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlacesListScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPlaceFilterChips(),
                        const SizedBox(height: 14),
                        _buildPlacesList(),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  // ── Upcoming Banner Helpers ───────────────────────────────────────────────

  /// Returns relative time info for the home banner.
  /// Returns null if the booking is too far away (> 2 days).
  Map<String, dynamic>? _getRelativeTimeLabelHome(DateTime scheduledTime) {
    final now = DateTime.now();
    final diff = scheduledTime.difference(now);
    if (diff.inMinutes < -30) return null;

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final scheduledMidnight = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );
    final dayDiff = scheduledMidnight.difference(todayMidnight).inDays;

    if (diff.inMinutes <= 120) {
      return {'text': 'happening right now!', 'emoji': '🔴', 'isUrgent': true};
    } else if (dayDiff == 0) {
      final timeStr =
          '${scheduledTime.hour % 12 == 0 ? 12 : scheduledTime.hour % 12}:${scheduledTime.minute.toString().padLeft(2, '0')} ${scheduledTime.hour >= 12 ? 'PM' : 'AM'}';
      return {'text': 'today at $timeStr', 'emoji': '⏰', 'isUrgent': true};
    } else if (dayDiff == 1) {
      return {'text': 'tomorrow', 'emoji': '📅', 'isUrgent': false};
    } else if (dayDiff == 2) {
      return {'text': 'in 2 days', 'emoji': '🗓️', 'isUrgent': false};
    }
    return null;
  }

  Widget _buildUpcomingBanner() {
    if (_nearestBooking == null) return const SizedBox.shrink();

    final scheduledTime = DateTime.tryParse(
      _nearestBooking!['scheduled_time'] ?? '',
    );
    if (scheduledTime == null) return const SizedBox.shrink();

    final label = _getRelativeTimeLabelHome(scheduledTime);
    if (label == null) return const SizedBox.shrink();

    final serviceTitle =
        (_nearestBooking!['services']?['title'] ?? 'a service') as String;
    final bool isUrgent = label['isUrgent'] == true;
    final String emoji = label['emoji'] as String;
    final String timeText = label['text'] as String;

    final List<Color> gradientColors = isUrgent
        ? [AppColors.primary, const Color(0xFFFF5C5C)]
        : [const Color(0xFFFF8C42), const Color(0xFFFFBF69)];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrgent ? 'Service is $timeText!' : 'Reminder',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"$serviceTitle" is $timeText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────
  Widget _buildHeader() {
    final name = userProfile?['full_name'] ?? 'User';
    final firstName = name.split(' ')[0];
    final profilePic = userProfile?['profile_picture_url'];

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[300],
          backgroundImage: profilePic != null
              ? CachedNetworkImageProvider(profilePic)
              : const AssetImage('assets/images/onboarding1.png')
                    as ImageProvider,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello $firstName 👋',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Explore the soars of delfa oceans',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            _fetchCounts();
          },
          child: _CircleIconBtn(
            icon: Icons.notifications_outlined,
            hasBadge: unreadNotifications > 0,
          ),
        ),
        const SizedBox(width: 10),
        // ── Cart shortcut with live badge ──────
        Consumer<CartProvider>(
          builder: (context, cart, _) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleIconBtn(
                  icon: Icons.shopping_cart_outlined,
                  hasBadge: false,
                ),
                if (cart.items.isNotEmpty)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Search Bar ────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _onSearch,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search services, providers...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.black45, size: 20),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              widthFactor: 1.0,
              child: Text(
                _getFlagEmoji(_getLocalCountryCode()),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // ── Quick Action Bar ──────────────────────
  Widget _buildQuickActionBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuickChip(
            icon: Icons.calendar_today_outlined,
            label: 'My Bookings',
            badge: activeBookingsCount > 0 ? activeBookingsCount : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingsScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickChip(
            icon: Icons.place_outlined,
            label: 'Places',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlacesListScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickChip(
            icon: Icons.card_giftcard_outlined,
            label: 'Rewards',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required IconData icon,
    required String label,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 15, color: AppColors.primary),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -7,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Offers Card ───────────────────────────
  Widget _buildOffersCard() {
    final offer = offers[_currentBannerIndex % offers.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userProfile?['full_name']?.toString().split(' ')[0] ?? 'Hey'}, a special offer awaits!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      offer['description'] ?? 'Limited time offer',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServicesListScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Explore',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer['title'] ?? 'Special Offer',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ...List.generate(
                offers.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 5),
                  width: _currentBannerIndex == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentBannerIndex == i
                        ? AppColors.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                CarouselSlider(
                  options: CarouselOptions(
                    height: 150,
                    viewportFraction: 1.0,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    onPageChanged: (index, _) =>
                        setState(() => _currentBannerIndex = index),
                  ),
                  items: offers
                      .map(
                        (o) => GestureDetector(
                          // Make the image tappable!
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServicesListScreen(),
                            ),
                          ),
                          child: CachedNetworkImage(
                            imageUrl:
                                o['image_url'] ??
                                'https://via.placeholder.com/400x200',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey[200]),
                          ),
                        ),
                      )
                      .toList(),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Popular',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ────────────────────────
  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                'See all',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Services Row ──────────────────────────
  Widget _buildServicesRow() {
    List<Widget> items = [
      _ServiceItem(
        color: Colors.green,
        icon: Icons.add,
        label: 'Create\nService',
        isIconWhite: true,
        onTap: () {
          final isProvider = userProfile?['is_service_provider'] == true;
          if (isProvider) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProviderOnboardingIntroScreen(),
              ),
            );
          }
        },
      ),
      ...categories
          .take(4)
          .map(
            (cat) => _ServiceItem(
              color: _getCategoryColor(cat['name']),
              imageUrl: _getCategoryIcon(cat['name']),
              label: cat['name'],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryItemsScreen(
                    categoryId: cat['id'],
                    categoryName: cat['name'],
                  ),
                ),
              ),
            ),
          ),
      _ServiceItem(
        color: const Color(0xFFF3E5F5),
        icon: Icons.grid_view_rounded,
        label: 'More\nServices',
        iconColor: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServicesListScreen()),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: item,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── NEW: POPULAR SERVICES ─────────────────
  // ── NEW: POPULAR SERVICES ─────────────────
  Widget _buildPopularServices() {
    if (popularServices.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Popular Providers', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServicesListScreen()),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: popularServices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final service = popularServices[i];
              final provider = service['profiles'] ?? {};
              final providerName = provider['full_name'] ?? 'Unknown';

              // USE THE NEW SAFE IMAGE HELPER HERE
              final String coverImage = _getSafeImage(service);

              final double avgRating = (service['average_rating'] is int)
                  ? (service['average_rating'] as int).toDouble()
                  : (service['average_rating'] ?? 0.0);
              final price = service['price'] ?? 0;

              return GestureDetector(
                onTap: () {
                  // Safely check IDs before navigating to prevent crashes
                  final sId = service['id'];
                  final pId = service['provider_id'];
                  if (sId == null || pId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Service details unavailable."),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceBookingDetailScreen(
                        serviceId: sId,
                        providerId: pId,
                        providerName: providerName,
                        providerPic: provider['profile_picture_url'],
                        serviceTitle: service['title'] ?? 'Service',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 185,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: coverImage,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            height: 110,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['title'] ?? 'Untitled',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              providerName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      avgRating == 0 ? "New" : "$avgRating",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "\$$price",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
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
            },
          ),
        ),
      ],
    );
  }

  // ── Recent Searches ───────────────────────
  Widget _buildRecentSearchesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent searches',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: _clearAllRecents,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchCards() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recentSearches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final term = recentSearches[i];
          final matchingCat = categories.firstWhere(
            (c) => c['name'].toString().toLowerCase().contains(
              term.toLowerCase().split(' ').first,
            ),
            orElse: () => null,
          );
          final iconUrl = matchingCat != null
              ? _getCategoryIcon(matchingCat['name'])
              : 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
          final bgColor = matchingCat != null
              ? _getCategoryColor(matchingCat['name'])
              : Colors.grey[100]!;

          return GestureDetector(
            onTap: () => _onSearch(term),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.search,
                            size: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _clearRecent(term),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    term,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to search',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Places Filter Chips ───────────────────
  Widget _buildPlaceFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _placeFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final filter = _placeFilters[i];
          final selected = _selectedPlaceFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedPlaceFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                filter,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── AI Success Task Card ─────────────────
  Widget _buildSuccessTaskCard() {
    final task = _getTodayTask();
    if (task == null) return const SizedBox.shrink();
    final dayNum = task['day'] ?? 1;
    final taskText = task['task']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\uD83C\uDFAF', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Your AI Success Task',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Day $dayNum',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            taskText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final prefs = await SharedPreferences.getInstance();
                final today = DateTime.now().toIso8601String().substring(0, 10);
                await prefs.setString('task_done_date', today);
                if (mounted) setState(() => _taskDoneToday = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mark Done',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Recommendations ────────────────────
  Widget _buildAiRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ).createShader(bounds),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Recommended for You',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: aiRecommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final rec = aiRecommendations[index] as Map<String, dynamic>;
              final type = rec['type'] as String? ?? '';
              final title = rec['title'] as String? ?? '';
              final reason = rec['reason'] as String? ?? '';
              final imageUrl = rec['image_url'] as String? ?? '';
              final id = rec['id'] as String? ?? '';

              return GestureDetector(
                onTap: () {
                  if (type == 'service' && id.isNotEmpty) {
                    final providerId = rec['provider_id']?.toString() ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceBookingDetailScreen(
                          serviceId: id,
                          serviceTitle: title,
                          providerId: providerId,
                        ),
                      ),
                    );
                  } else if (type == 'community' && id.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: id),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  type.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
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
      ],
    );
  }

  // ── Places List ───────────────────────────
  Widget _buildPlacesList() {
    if (nearbyPlaces.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.place_outlined, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(
                'No places nearby',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayPlaces = nearbyPlaces.take(6).toList();

    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: displayPlaces.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final place = displayPlaces[i];
          final imgUrl = (place['image_urls'] as List?)?.isNotEmpty == true
              ? place['image_urls'][0]
              : 'https://via.placeholder.com/400';
          final rating = place['rating'] ?? 0.0;
          final city = place['city'] ?? '';

          final distance = '${(i + 1) * 34} km';

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceDetailScreen(place: place),
              ),
            ),
            child: Container(
              width: 185,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(height: 130, color: Colors.grey[200]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                place['name'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              distance,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                city,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$rating',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
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
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NAV ITEM DATA CLASS
// ─────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;
  final bool showDot; // <-- NEW
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
    this.showDot = false, // <-- NEW
  });
}

// ─────────────────────────────────────────────
// CIRCLE ICON BUTTON
// ─────────────────────────────────────────────
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final bool hasBadge;
  const _CircleIconBtn({required this.icon, this.hasBadge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          Center(child: Icon(icon, color: Colors.black87, size: 20)),
          if (hasBadge)
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE ITEM
// ─────────────────────────────────────────────
class _ServiceItem extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? imageUrl;
  final String label;
  final VoidCallback onTap;
  final bool isIconWhite;
  final Color? iconColor;

  const _ServiceItem({
    required this.color,
    this.icon,
    this.imageUrl,
    required this.label,
    required this.onTap,
    this.isIconWhite = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: imageUrl != null ? const EdgeInsets.all(12) : null,
            decoration: BoxDecoration(
              color: isIconWhite ? color : color.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: imageUrl != null
                ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.contain)
                : Icon(
                    icon,
                    color: isIconWhite ? Colors.white : iconColor,
                    size: 26,
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 68,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
