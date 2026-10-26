import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/services/push_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import 'event_detail_screen.dart';
import '../daily_plan.dart';
import '../widgets/daily_plan_card.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
import '../../services/screens/all_categories_screen.dart';
import '../../services/screens/skill_swap_dashboard_screen.dart';
import '../../services/screens/category_items_screen.dart';
import '../../provider/screens/provider_onboarding_intro_screen.dart';
import '../../provider/screens/my_services_list_screen.dart';
import '../../provider/screens/provider_dashboard_screen.dart';
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
import '../../groups/screens/communities_screen.dart';
import 'ai_assistant_screen.dart';
import '../../../core/widgets/service_action_sheet.dart';
import '../../services/screens/skill_swap_screens.dart'
    show SkillSwapBottomSheet;
import '../../../l10n/app_localizations.dart';

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
  List<dynamic> swapOpportunities = [];
  List<dynamic> nearbyPlaces = [];
  List<dynamic> homeGroups = [];
  bool isLoading = true;

  int _currentNavIndex = 0;
  int _currentBannerIndex = 0;

  // Places filter
  final List<String> _placeFilters = [
    'Nearby',
    'Popular',
    'Local',
    'Convenient',
    'Central',
  ];
  String _selectedPlaceFilter = 'Nearby';

  // Country flag (resolved from IP, defaults to Georgia)
  String _countryCode = 'GE';

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

  // Draggable AI button position (right/bottom offsets from screen edge)
  double _aiButtonRight = 16;
  double _aiButtonBottom = 96;

  // AI speech bubble
  String? _aiBubbleMessage;
  bool _showAiBubble = false;
  bool _notifPopupShownThisSession = false;
  String? _notifPopupText;
  bool _showNotifPopup = false;

  // Hardcoded fallback messages for when Gemini API fails
  static const List<String> _fallbackMessages = [
    '💡 Did you know? You can swap skills with other LifeKit users — no money needed!',
    '🌟 Tip: Complete your profile to get 3x more bookings from clients.',
    '🔄 Skill swaps are a great way to get services for free. Try the Swap Board!',
    '📅 Pro tip: Set your availability in your service listing to get booked faster.',
    '🤝 LifeKit connects 1000s of skilled people. Someone near you needs what you offer!',
    '⭐ Fun fact: Providers with 5+ reviews earn 60% more on average.',
    '🚀 Your next client could be searching for you right now. Keep your profile fresh!',
    '💬 Respond to booking requests quickly — fast responses get more 5-star reviews.',
    '🌍 LifeKit works globally. Your skills can earn you income anywhere in the world.',
    '🎯 Set competitive prices — check what similar services charge on the Explore tab.',
    '🏆 Fun fact: The world\'s first marketplace was in Ancient Greece, circa 500 BC!',
    '🧠 Did you know? Learning a new skill for just 20 mins a day makes you an expert in a year.',
    '🌱 Growth tip: Ask satisfied clients to leave a review — it helps more than you think!',
    '⚡ LifeKit AI can help you write the perfect service description. Just ask me!',
    '🎉 Welcome back! The best time to book or offer a service is right now.',
  ];

  @override
  void initState() {
    super.initState();
    // Signed in: ask for push permission (first time) and register this device.
    PushService.instance.registerForUser();
    _loadLocalRecents();
    _fetchCountryFromIp();
    // SWR: paint from cache immediately, then revalidate in background
    _loadHomeCache().then((_) => _fetchAllData());
    _fetchCounts();
    _checkInactivityNudge();
    // Trigger AI greeting shortly after home loads
    Future.delayed(const Duration(milliseconds: 1200), _triggerAiGreeting);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Discovery only returns an event's id; load the full record to open it.
  Future<void> _openEventById(String id) async {
    try {
      final events = await _apiService.getEvents();
      final event = events.cast<dynamic>().firstWhere(
        (e) => '${e['id']}' == id,
        orElse: () => null,
      );
      if (event == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      );
    } catch (e) {
      if (mounted) AppToast.error(context, appErrorMessage(context, e));
    }
  }

  // ── AI Greeting bubble ────────────────────────────────────────────────────
  Future<void> _triggerAiGreeting() async {
    if (!mounted) return;
    String message;
    try {
      // Lightweight endpoint, cached on the device for the day.
      message = (await _apiService.getAiGreeting()).trim();
      if (message.isEmpty) throw Exception('empty');
    } catch (_) {
      // Fallback to a random hardcoded message
      final idx =
          DateTime.now().millisecondsSinceEpoch % _fallbackMessages.length;
      message = _fallbackMessages[idx];
    }
    if (!mounted) return;
    setState(() {
      _aiBubbleMessage = message;
      _showAiBubble = true;
    });
    // Auto-dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showAiBubble = false);
    });
    // Also show notification popup ~2s after AI bubble (if not shown yet)
    Future.delayed(const Duration(seconds: 8), _tryShowNotifPopup);
  }

  Future<void> _tryShowNotifPopup() async {
    if (!mounted || _notifPopupShownThisSession) return;
    try {
      final notifs = await _apiService.getNotifications();
      if (notifs.isEmpty) return;
      final latest = notifs.first;
      final text = (latest['message'] ?? latest['title'] ?? '')
          .toString()
          .trim();
      if (text.isEmpty) return;
      _notifPopupShownThisSession = true;
      if (!mounted) return;
      setState(() {
        _notifPopupText = text;
        _showNotifPopup = true;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showNotifPopup = false);
      });
    } catch (_) {}
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


  /// Shows a bottom-sheet AI nudge when the user hasn't opened the app in 3+
  /// days and is registered as a service provider.
  Future<void> _checkInactivityNudge() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString('last_app_open');
    final today = DateTime.now();
    final todayKey = today.toIso8601String().substring(0, 10);

    // Always update the last-seen timestamp
    await prefs.setString('last_app_open', today.toIso8601String());

    if (lastSeenStr == null) return; // First ever open — no nudge

    final lastSeen = DateTime.tryParse(lastSeenStr);
    if (lastSeen == null) return;

    final daysSinceLastOpen = today.difference(lastSeen).inDays;
    if (daysSinceLastOpen < 3) return; // Not inactive enough

    // Only nudge service providers
    final isProvider = userProfile?['is_service_provider'] == true;
    if (!isProvider) {
      // Wait for profile to load if it hasn't yet
      await Future.delayed(const Duration(seconds: 2));
      if (!(userProfile?['is_service_provider'] == true)) return;
    }

    // Don't nudge more than once per day
    final lastNudgeDate = prefs.getString('last_inactivity_nudge_date');
    if (lastNudgeDate == todayKey) return;
    await prefs.setString('last_inactivity_nudge_date', todayKey);

    if (!mounted) return;
    // Slight delay so the home screen finishes building first
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _showAiNudgeSheet(daysSinceLastOpen);
  }

  void _showAiNudgeSheet(int daysSince) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.homeWelcomeBackOpportunities(daysSince),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context).txOurAiHasBeenTrackingDemand,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white70,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/ai/aihalfpic.jpg',
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProviderDashboardScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).txViewAiOpportunityRadar,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).maybeLater,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        // Use null titles/descriptions so the UI falls back to the localised
        // defaults from the ARB file (homeOfferTitle, homeOfferValidUntil).
        offersData = [
          {
            'title': null,
            'image_url':
                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
            'description': null,
          },
        ];
      }

      if (mounted) {
        setState(() {
          userProfile = profileData['profile'];
          offers = offersData;
          categories = catsData;
          popularServices = popData;
          swapOpportunities = popData
              .where((s) => s['is_skill_swap_available'] == true)
              .take(10)
              .toList();
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

      // Non-critical: communities
      try {
        final groupsData = await _apiService.getGroups();
        if (mounted) setState(() => homeGroups = groupsData ?? []);
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

  // Fetches the user's country from their IP address; falls back to 'GE' (Georgia)
  Future<void> _fetchCountryFromIp() async {
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/?fields=country_code'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final code =
            data['country_code']?.toString().toUpperCase().trim() ?? '';
        if (code.length == 2 && mounted) {
          setState(() => _countryCode = code);
          return;
        }
      }
    } catch (_) {}
    // Keep default 'GE'
  }

  // Returns the resolved country code
  String _getLocalCountryCode() => _countryCode;

  // Converts the 2-letter country code into a Flag Emoji
  String _getFlagEmoji(String countryCode) {
    final normalized = countryCode.toUpperCase().trim();
    final isValid =
        normalized.length == 2 &&
        normalized.codeUnits.every((c) => c >= 0x41 && c <= 0x5A);
    final safeCode = isValid ? normalized : 'GE';
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
      ProfileScreen(key: const ValueKey('profile')),
    ];

    return Scaffold(
      extendBodyBehindAppBar: _currentNavIndex == 0,
      extendBody:
          true, // IMPORTANT: Lets content scroll behind the floating nav bar
      body: Stack(
        children: [
          IndexedStack(index: _currentNavIndex, children: screens),
          // ── Notification popup ─────────────────────────────────────────
          if (_showNotifPopup && _notifPopupText != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildNotifPopup(_notifPopupText!),
            ),
          // ── AI speech bubble ──────────────────────────────────────────
          if (_currentNavIndex == 0 &&
              _showAiBubble &&
              _aiBubbleMessage != null)
            Positioned(
              right: _aiButtonRight + 68,
              bottom: _aiButtonBottom - 2,
              child: _buildAiBubble(_aiBubbleMessage!),
            ),
          // ── Draggable AI button — only visible on home tab ─────────────
          if (_currentNavIndex == 0)
            Positioned(
              right: _aiButtonRight,
              bottom: _aiButtonBottom,
              child: GestureDetector(
                onTap: () {
                  if (_showAiBubble) {
                    setState(() => _showAiBubble = false);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIAssistantScreen(),
                      ),
                    );
                  }
                },
                onPanUpdate: (details) {
                  final size = MediaQuery.of(context).size;
                  setState(() {
                    _aiButtonRight = (_aiButtonRight - details.delta.dx).clamp(
                      8.0,
                      size.width - 76.0,
                    );
                    _aiButtonBottom = (_aiButtonBottom - details.delta.dy)
                        .clamp(8.0, size.height - 76.0);
                  });
                },
                onPanEnd: (details) {
                  // Snap to nearest horizontal edge
                  final size = MediaQuery.of(context).size;
                  final centerX = size.width - _aiButtonRight - 30;
                  setState(() {
                    _aiButtonRight = centerX < size.width / 2
                        ? size.width -
                              76.0 // snap to left edge
                        : 16.0; // snap to right edge
                  });
                },
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/ai/aihalfpic.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // ── AI speech bubble widget ───────────────────────────────────────────────
  Widget _buildAiBubble(String message) {
    return Pressable(
      onTap: () => setState(() => _showAiBubble = false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  // ── Notification popup widget ─────────────────────────────────────────────
  Widget _buildNotifPopup(String text) {
    return Pressable(
      onTap: () => setState(() => _showNotifPopup = false),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => setState(() => _showNotifPopup = false),
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FLOATING MODERN BOTTOM NAV ────────────────────────────
  Widget _buildModernBottomNav() {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l10n.homeTabDiscover,
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: l10n.explore,
      ),
      _NavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: l10n.homeTabFeed,
        showDot: hasNewFeeds,
      ), // <-- Feeds Dot
      _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble_rounded,
        label: l10n.navChats,
        badge: unreadChats,
      ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: l10n.homeTabProfile,
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
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final active = _currentNavIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentNavIndex = i;
                          if (i == 2) {
                            hasNewFeeds = false; // Clear feeds dot when clicked
                          }
                        });
                        _fetchCounts();
                        // Re-trigger AI greeting every time user returns to home
                        if (i == 0) {
                          Future.delayed(
                            const Duration(milliseconds: 600),
                            _triggerAiGreeting,
                          );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
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
                                  size: active ? 26 : 24,
                                ),
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
                            if (active)
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
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
                        _buildHeader().fadeSlideIn(index: 0),
                        const SizedBox(height: 22),
                        _buildSearchBar().fadeSlideIn(index: 1),
                        const SizedBox(height: 16),
                        _buildQuickActionBar().fadeSlideIn(index: 2),
                        if (_nearestBooking != null) ...[
                          const SizedBox(height: 16),
                          _buildUpcomingBanner().fadeSlideIn(index: 3),
                        ],
                        const SizedBox(height: 22),

                        // AI Success Task
                        if (DailyPlan.fromProfile(userProfile) != null) ...[
                          DailyPlanCard(
                            profile: userProfile,
                            onPlanUpdated: (plan) => setState(() {
                              userProfile = {
                                ...?userProfile,
                                'onboarding_plan': plan,
                              };
                            }),
                          ).fadeSlideIn(index: 4),
                          const SizedBox(height: 20),
                        ],

                        // AI Recommendations
                        if (aiRecommendations.isNotEmpty) ...[
                          _buildAiRecommendations().fadeSlideIn(index: 5),
                          const SizedBox(height: 28),
                        ],

                        // Offers
                        if (offers.isNotEmpty) ...[
                          _buildOffersCard().fadeSlideIn(index: 6),
                          const SizedBox(height: 28),
                        ],

                        // Services
                        _buildSectionHeader(
                          AppLocalizations.of(context)!.servicesTitle,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllCategoriesScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildServicesRow().fadeSlideIn(index: 7),
                        const SizedBox(height: 28),

                        // Top Swap Opportunities
                        if (swapOpportunities.isNotEmpty) ...[
                          _buildTopSwapOpportunities().fadeSlideIn(index: 8),
                          const SizedBox(height: 28),
                        ],

                        // Communities
                        if (homeGroups.isNotEmpty) ...[
                          _buildCommunitiesSection().fadeSlideIn(index: 9),
                          const SizedBox(height: 28),
                        ],

                        // Popular services
                        _buildPopularServices().fadeSlideIn(index: 10),
                        const SizedBox(height: 28),

                        // Recent Searches
                        if (recentSearches.isNotEmpty) ...[
                          _buildRecentSearchesHeader().fadeSlideIn(index: 11),
                          const SizedBox(height: 14),
                          _buildRecentSearchCards().fadeSlideIn(index: 12),
                          const SizedBox(height: 28),
                        ],

                        // Places
                        _buildSectionHeader(
                          AppLocalizations.of(context)!.placesTitle,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlacesListScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPlaceFilterChips().fadeSlideIn(index: 13),
                        const SizedBox(height: 14),
                        _buildPlacesList().fadeSlideIn(index: 14),
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

    return Pressable(
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
        Pressable(
          onTap: () => setState(() => _currentNavIndex = 4),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[300],
            backgroundImage: profilePic != null
                ? CachedNetworkImageProvider(profilePic)
                : const AssetImage('assets/images/onboarding1.png')
                      as ImageProvider,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.homeHelloGreeting(firstName),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                AppLocalizations.of(context)!.homeWelcomeTagline,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
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
          builder: (context, cart, _) => Pressable(
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
    final l10n = AppLocalizations.of(context)!;
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
          hintText: l10n.search,
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
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuickChip(
            icon: Icons.calendar_today_outlined,
            label: l10n.myBookings,
            badge: activeBookingsCount > 0 ? activeBookingsCount : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingsScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickChip(
            icon: Icons.place_outlined,
            label: l10n.placesTitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlacesListScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickChip(
            icon: Icons.card_giftcard_outlined,
            label: l10n.rewards,
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
    return Pressable(
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
                      AppLocalizations.of(context)!.homeSpecialOfferAwaits(
                        userProfile?['full_name']?.toString().split(' ')[0] ?? 'Hey',
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      offer['description'] ?? AppLocalizations.of(context)!.homeOfferValidUntil,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
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
                    AppLocalizations.of(context)!.explore,
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
            offer['title'] ?? AppLocalizations.of(context)!.homeOfferTitle,
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
                        (o) => Pressable(
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
                          AppLocalizations.of(context)!.popular,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          Pressable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                AppLocalizations.of(context)!.seeAll,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Services Row ──────────────────────────
  Widget _buildServicesRow() {
    final l10n = AppLocalizations.of(context)!;
    List<Widget> items = [
      _ServiceItem(
        color: Colors.green,
        icon: Icons.add,
        label: l10n.createService,
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
        label: l10n.homeMoreServices,
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

  // ── SWAPPABLE BADGE ──────────────────────
  Widget _buildSwappableBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔄', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context).badgeSwappable,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourServiceBadge() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.45),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, color: Colors.white, size: 10),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                AppLocalizations.of(context)!.homeYourServiceBadge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOP SWAP OPPORTUNITIES ────────────────
  Widget _buildTopSwapOpportunities() {
    if (swapOpportunities.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppLocalizations.of(context)!.homeTopSwapOpportunities,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SkillSwapDashboardScreen()),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: swapOpportunities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final service = swapOpportunities[i];
              final sId = service['id']?.toString();
              final pId = service['provider_id']?.toString();
              final provider = service['profiles'] ?? {};
              final providerName = (provider['full_name'] ?? 'Provider')
                  .toString();
              final title = (service['title'] ?? 'Service').toString();
              final coverImage = _getSafeImage(service);
              final price = service['price'] ?? 0;
              final isOwn =
                  pId != null && pId == userProfile?['id']?.toString();

              return Pressable(
                onTap: () {
                  if (isOwn) {
                    AppToast.info(context, AppLocalizations.of(context)!.homeMyServiceBadge);
                    return;
                  }
                  if (sId == null || pId == null) return;
                  showServiceActionSheet(
                    context: context,
                    serviceTitle: title,
                    providerName: providerName,
                    coverImageUrl: coverImage,
                    isSwappable: true,
                    onBook: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceBookingDetailScreen(
                          serviceId: sId,
                          providerId: pId,
                          providerName: providerName,
                          providerPic: provider['profile_picture_url'],
                          serviceTitle: title,
                        ),
                      ),
                    ),
                    onSwap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SkillSwapBottomSheet(
                        initialTargetCategoryId: service['category_id']
                            ?.toString(),
                        initialTargetCategoryName:
                            (service['service_categories']?['name'] ?? title)
                                .toString(),
                        initialTargetCoverImageUrl: coverImage,
                        initialTargetServiceId: sId,
                        initialTargetProviderId: pId,
                        initialTargetProviderName: providerName,
                        initialTargetServiceTitle: title,
                        initialTargetProviderPic:
                            provider['profile_picture_url']?.toString(),
                      ),
                    ),
                  );
                },
                child: Opacity(
                  opacity: isOwn ? 0.75 : 1.0,
                  child: Container(
                    width: 165,
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
                        Stack(
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
                            Positioned(
                              top: 8,
                              left: 8,
                              child: isOwn
                                  ? _buildYourServiceBadge()
                                  : _buildSwappableBadge(),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      providerName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '\$$price',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── COMMUNITIES SECTION ───────────────────────────────────────
  Widget _buildCommunitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppLocalizations.of(context)!.communities,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
          ),
        ),
        const SizedBox(height: 14),
        // Beautiful gradient banner card
        Pressable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
          ),
          child: Container(
            height: 130,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  Color(0xFFB74B5C),
                  Color(0xFF6B1225),
                ],
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
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -30,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.homeCommunitiesCount(homeGroups.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.findYourTribe,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            IntrinsicWidth(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.homeBrowseAll,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Overlapping avatars
                      SizedBox(
                        width: 78,
                        height: 80,
                        child: Stack(
                          children: [
                            for (int i = 0; i < homeGroups.take(3).length; i++)
                              Positioned(
                                top: i * 22.0,
                                right: i * 8.0,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: ClipOval(
                                    child: homeGroups[i]['image_url'] != null
                                        ? CachedNetworkImage(
                                            imageUrl: homeGroups[i]['image_url'],
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(milliseconds: 250),
                                            errorWidget: (_, _, _) =>
                                                const Icon(
                                                  Icons.groups_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.groups_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Horizontal scrollable community chips
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: homeGroups.take(6).length,
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = homeGroups[i];
              return Pressable(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.12),
                        ),
                        child: ClipOval(
                          child: g['image_url'] != null
                              ? CachedNetworkImage(
                                  imageUrl: g['image_url'],
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 250),
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.groups_rounded,
                                    color: AppColors.primary,
                                    size: 12,
                                  ),
                                )
                              : const Icon(
                                  Icons.groups_rounded,
                                  color: AppColors.primary,
                                  size: 12,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (g['name'] ?? 'Group').toString().length > 14
                            ? '${(g['name'] ?? 'Group').toString().substring(0, 14)}…'
                            : (g['name'] ?? 'Group').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
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

  // ── NEW: POPULAR SERVICES ─────────────────
  // ── NEW: POPULAR SERVICES ─────────────────
  Widget _buildPopularServices() {
    if (popularServices.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(AppLocalizations.of(context)!.popularProviders, () {
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
              final sId = service['id'];
              final pId = service['provider_id'];
              final isOwn =
                  pId != null &&
                  pId.toString() == userProfile?['id']?.toString();

              return Pressable(
                onTap: () {
                  if (isOwn) {
                    AppToast.info(context, AppLocalizations.of(context)!.homeMyServiceBadge);
                    return;
                  }
                  // Safely check IDs before navigating to prevent crashes
                  if (sId == null || pId == null) {
                    AppToast.info(context, AppLocalizations.of(context).msgServiceUnavailable);
                    return;
                  }

                  showServiceActionSheet(
                    context: context,
                    serviceTitle: service['title'] ?? 'Service',
                    providerName: providerName,
                    coverImageUrl: coverImage,
                    isSwappable: service['is_skill_swap_available'] == true,
                    onBook: () => Navigator.push(
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
                    ),
                    onSwap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SkillSwapBottomSheet(
                        initialTargetCategoryId: service['category_id']
                            ?.toString(),
                        initialTargetCategoryName:
                            (service['service_categories']?['name'] ??
                                    service['title'] ??
                                    'Service')
                                .toString(),
                        initialTargetCoverImageUrl: coverImage,
                        initialTargetServiceId: sId,
                        initialTargetProviderId: pId,
                        initialTargetProviderName: providerName,
                        initialTargetServiceTitle:
                            (service['title'] ?? 'Service').toString(),
                        initialTargetProviderPic:
                            provider['profile_picture_url']?.toString(),
                      ),
                    ),
                  );
                },
                child: Opacity(
                  opacity: isOwn ? 0.75 : 1.0,
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
                        Stack(
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
                            Positioned(
                              top: 8,
                              left: 8,
                              child: isOwn
                                  ? _buildYourServiceBadge()
                                  : service['is_skill_swap_available'] == true
                                  ? _buildSwappableBadge()
                                  : const SizedBox(),
                            ),
                          ],
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
          AppLocalizations.of(context).recentSearches,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Pressable(
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

          return Pressable(
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
                      Pressable(
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
                    AppLocalizations.of(context).txTapToSearch,
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
  String _localisedFilter(String id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'Nearby':     return l10n.homeCategoryNearby;
      case 'Popular':    return l10n.popular;
      case 'Local':      return l10n.homeCategoryLocal;
      case 'Convenient': return l10n.homeCategoryConvenient;
      case 'Central':    return l10n.homeCategoryCentral;
      default:           return id;
    }
  }

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
          return Pressable(
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
                _localisedFilter(filter),
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

  // ── AI Recommendations ────────────────────
  Widget _buildAiRecommendations() {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.homeAIRecommended,
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

              return Pressable(
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
                  } else if (type == 'event' && id.isNotEmpty) {
                    _openEventById(id);
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
                AppLocalizations.of(context).noPlacesNearby,
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

          return Pressable(
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
    return Pressable(
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
