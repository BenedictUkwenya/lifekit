import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CORE ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// --- SCREENS ---
import '../../services/screens/services_list_screen.dart';
import '../../services/screens/category_items_screen.dart';
import '../../services/screens/service_booking_detail_screen.dart';
import '../../provider/screens/provider_onboarding_intro_screen.dart';
import 'feeds_screen.dart';
import '../../bookings/screens/bookings_screen.dart';
import 'chats_list_screen.dart';
import 'notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'search_results_screen.dart';

// --- PLACES IMPORTS (ADDED) ---
import '../../places/screens/places_list_screen.dart';
import '../../places/screens/place_detail_screen.dart';

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
  List<dynamic> nearbyPlaces = []; // NEW: Places Data
  bool isLoading = true;

  int _currentNavIndex = 0;
  int _currentBannerIndex = 0;

  // Badge Counts
  int unreadNotifications = 0;
  int unreadChats = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalRecents();
    _fetchAllData();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    try {
      final data = await _apiService.getUnreadCounts();
      if (mounted) {
        setState(() {
          unreadNotifications = data['notifications'] ?? 0;
          unreadChats = data['chats'] ?? 0;
        });
      }
    } catch (e) {
      print("Error fetching counts: $e");
    }
  }

  Future<void> _loadLocalRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_searches') ?? [];
      if (recentSearches.isEmpty) {
        recentSearches = ["House Cleaning", "Plumber", "Barber"];
      }
    });
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (!recentSearches.contains(query)) {
      recentSearches.insert(0, query);
      if (recentSearches.length > 5) recentSearches.removeLast();
      await prefs.setStringList('recent_searches', recentSearches);
      setState(() {});
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
    );
  }

  Future<void> _fetchAllData() async {
    try {
      // 1. Load CRITICAL Data (Profile, Categories, Services)
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

      // Mock Offer if empty
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

      // 2. Load OPTIONAL Data (Places - External API)
      try {
        final placesData = await _apiService.getNearbyPlaces(6.5244, 3.3792);
        if (mounted) {
          setState(() {
            nearbyPlaces = placesData;
          });
        }
      } catch (e) {
        print("Places failed to load (ignoring): $e");
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Critical Home Fetch Error: $e");
    }
  }

  // --- ICONS HELPERS ---

  String _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('health') || name.contains('wellness'))
      return 'https://cdn-icons-png.flaticon.com/512/2966/2966334.png';
    if (name.contains('laundry'))
      return 'https://cdn-icons-png.flaticon.com/512/2954/2954888.png';
    if (name.contains('hair') || name.contains('beauty'))
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050257.png';
    if (name.contains('family') || name.contains('care'))
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050226.png';
    if (name.contains('plumb') || name.contains('maint'))
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050239.png';
    if (name.contains('home'))
      return 'https://cdn-icons-png.flaticon.com/512/619/619153.png';
    if (name.contains('tech'))
      return 'https://cdn-icons-png.flaticon.com/512/1055/1055687.png';
    if (name.contains('clean'))
      return 'https://cdn-icons-png.flaticon.com/512/995/995016.png';
    if (name.contains('edu') || name.contains('tutor'))
      return 'https://cdn-icons-png.flaticon.com/512/2232/2232688.png';
    if (name.contains('lang') || name.contains('comm'))
      return 'https://cdn-icons-png.flaticon.com/512/3898/3898082.png';
    if (name.contains('event'))
      return 'https://cdn-icons-png.flaticon.com/512/3132/3132084.png';
    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

  Color _getCategoryColor(String name) {
    name = name.toLowerCase();
    if (name.contains('health')) return const Color(0xFFE3F2FD);
    if (name.contains('laundry')) return const Color(0xFFE8F5E9);
    if (name.contains('hair')) return const Color(0xFFF3E5F5);
    if (name.contains('care') || name.contains('family'))
      return const Color(0xFFFFEBEE);
    if (name.contains('clean')) return const Color(0xFFE0F7FA);
    if (name.contains('edu')) return const Color(0xFFFFF3E0);
    if (name.contains('tech')) return const Color(0xFFECEFF1);
    if (name.contains('event')) return const Color(0xFFFCE4EC);
    return Colors.grey[100]!;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeContent(),
      const BookingsScreen(),
      const FeedsScreen(),
      const ChatsListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: _currentNavIndex == 0,
      body: screens[_currentNavIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() => _currentNavIndex = index);
            _fetchCounts();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              label: "Bookings",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              label: "Feeds",
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(Icons.chat_bubble_outline, unreadChats),
              label: "Chats",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return Stack(
      children: [
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSearchBar(),
                      const SizedBox(height: 24),

                      if (offers.isNotEmpty) _buildOffersCard(),
                      if (offers.isNotEmpty) const SizedBox(height: 24),

                      _buildSectionHeader("Services", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServicesListScreen(),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      _buildServicesRow(),
                      const SizedBox(height: 24),

                      if (recentSearches.isNotEmpty) ...[
                        _buildSectionHeader(
                          "Recent searches",
                          null,
                          showSeeAll: false,
                        ),
                        const SizedBox(height: 12),
                        _buildRecentSearchesList(),
                        const SizedBox(height: 24),
                      ],

                      // --- PLACES SECTION ---
                      _buildSectionHeader("Places", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlacesListScreen(),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // --- HORIZONTAL PLACES ROW ---
                      _buildPlacesList(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  // --- PLACES: HORIZONTAL SCROLL ROW ---
  Widget _buildPlacesList() {
    if (nearbyPlaces.isEmpty) {
      return Center(
        child: Text(
          "No places nearby.",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    // Show up to 6 cards horizontally
    final displayPlaces = nearbyPlaces.length > 6
        ? nearbyPlaces.sublist(0, 6)
        : nearbyPlaces;

    return SizedBox(
      height: 220, // Fixed height for the horizontal row
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: displayPlaces.length,
        itemBuilder: (context, index) {
          final place = displayPlaces[index];
          final imgUrl = (place['image_urls'] as List).isNotEmpty
              ? place['image_urls'][0]
              : "https://via.placeholder.com/400";

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceDetailScreen(place: place),
              ),
            ),
            child: Container(
              width: 180, // Fixed card width
              margin: EdgeInsets.only(
                right: index == displayPlaces.length - 1 ? 0 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${place['rating']}",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.circle,
                              size: 3,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                place['city'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

  // --- EXISTING WIDGETS ---

  Widget _buildHeader() {
    String name = userProfile?['full_name'] ?? 'User';
    String firstName = name.split(' ')[0];
    String? profilePic = userProfile?['profile_picture_url'];
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
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
                "Hello $firstName",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                "Explore the soars of delfa oceans",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
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
          child: _HeaderIconBtn(
            icon: Icons.notifications_outlined,
            hasBadge: unreadNotifications > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: "Search...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.black45),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildServicesRow() {
    List<Widget> rowItems = [];
    rowItems.add(
      Padding(
        padding: const EdgeInsets.only(right: 15),
        child: _ServiceItem(
          color: Colors.green,
          icon: Icons.add,
          label: "Create\nService",
          isIconWhite: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProviderOnboardingIntroScreen(),
            ),
          ),
        ),
      ),
    );
    int count = 0;
    for (var cat in categories) {
      if (count >= 4) break;
      rowItems.add(
        Padding(
          padding: const EdgeInsets.only(right: 15),
          child: _ServiceItem(
            color: _getCategoryColor(cat['name']),
            imageUrl: _getCategoryIcon(cat['name']),
            label: cat['name'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryItemsScreen(
                    categoryId: cat['id'],
                    categoryName: cat['name'],
                  ),
                ),
              );
            },
          ),
        ),
      );
      count++;
    }
    rowItems.add(
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: _ServiceItem(
          color: const Color(0xFFF3E5F5),
          icon: Icons.grid_view_rounded,
          label: "More\nServices",
          iconColor: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServicesListScreen()),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
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
          children: rowItems,
        ),
      ),
    );
  }

  Widget _buildRecentSearchesList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: recentSearches.map((term) {
          return GestureDetector(
            onTap: () => _onSearch(term),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    term,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOffersCard() {
    final currentOffer = offers[_currentBannerIndex % offers.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Special offer awaits!",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currentOffer['description'] ?? "Limited time",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Explore",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentOffer['title'] ?? "Offer",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          CarouselSlider(
            options: CarouselOptions(
              height: 130.0,
              viewportFraction: 1.0,
              autoPlay: true,
              onPageChanged: (index, reason) =>
                  setState(() => _currentBannerIndex = index),
            ),
            items: offers.map((offer) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl:
                      offer['image_url'] ??
                      'https://via.placeholder.com/400x200',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (c, u, e) => Container(color: Colors.grey[300]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    VoidCallback? onTap, {
    bool showSeeAll = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (showSeeAll)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: Text(
                "See all",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool hasBadge;
  const _HeaderIconBtn({required this.icon, this.hasBadge = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Center(child: Icon(icon, color: Colors.black, size: 20)),
          if (hasBadge)
            Positioned(
              right: 10,
              top: 10,
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
            width: 70,
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
