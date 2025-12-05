import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// --- CORE IMPORTS ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// --- SCREEN IMPORTS ---
import '../../services/screens/services_list_screen.dart'; // Full List
import '../../services/screens/category_items_screen.dart'; // <--- DIRECT PROVIDER LIST
import '../../services/screens/service_booking_detail_screen.dart';
import '../../provider/screens/provider_onboarding_intro_screen.dart';
import 'feeds_screen.dart';
import '../../bookings/screens/bookings_screen.dart';
import 'chats_list_screen.dart';
import 'notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  // --- DATA STATE ---
  Map<String, dynamic>? userProfile;
  List<dynamic> offers = [];
  List<dynamic> categories = [];
  List<dynamic> recentSearches = [];
  List<dynamic> popularServices = [];
  bool isLoading = true;

  // --- UI STATE ---
  int _currentNavIndex = 0;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getOffers(),
        _apiService.getCategories(),
        _apiService.getRecentSearches(),
        _apiService.getPopularServices(),
      ]);

      final profileData = results[0] as Map<String, dynamic>;
      var offersData = results[1] as List<dynamic>;
      final catsData = results[2] as List<dynamic>;
      final recentsData = results[3] as List<dynamic>;
      final popData = results[4] as List<dynamic>;

      if (offersData.isEmpty) {
        offersData = [
          {
            'title': 'Explore Soars Of\nDelfa Oceans',
            'image_url':
                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
            'description': 'Over 20,000 km',
          },
        ];
      }

      if (mounted) {
        setState(() {
          userProfile = profileData['profile'];
          offers = offersData;
          categories = catsData;
          recentSearches = recentsData;
          popularServices = popData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching home data: $e");
    }
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
          onTap: (index) => setState(() => _currentNavIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              label: "Bookings",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              label: "Feeds",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: "Chats",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 0 CONTENT ---
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
                      // --- ROW WITH SCROLL FIX ---
                      _buildServicesRow(),

                      const SizedBox(height: 24),

                      _buildSectionHeader(
                        "Recent searches",
                        null,
                        showSeeAll: false,
                      ),
                      const SizedBox(height: 12),
                      _buildRecentSearchesList(),

                      const SizedBox(height: 24),

                      _buildSectionHeader("Places", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServicesListScreen(),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      _buildPlacesList(),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  // --- WIDGETS ---

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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "Explore the soars of delfa oceans",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text("🌊", style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: const _HeaderIconBtn(
            icon: Icons.notifications_outlined,
            hasBadge: true,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: ClipOval(
            child: Image.network(
              "https://flagcdn.com/w40/ng.png",
              width: 22,
              height: 22,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.flag, color: Colors.green, size: 20),
            ),
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

  // --- UPDATED: SCROLLABLE SERVICES ROW (Fixes Overflow) ---
  Widget _buildServicesRow() {
    List<Widget> rowItems = [];

    // 1. CREATE SERVICE (Fixed)
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

    // 2. DYNAMIC CATEGORIES (First 3)
    int count = 0;
    for (var cat in categories) {
      if (count >= 3) break;

      Color bg = count == 0
          ? const Color(0xFFE3F2FD)
          : (count == 1 ? const Color(0xFFFFF3E0) : const Color(0xFFF9FBE7));
      Color iconColor = count == 0
          ? Colors.blue
          : (count == 1 ? Colors.orange : Colors.lime);
      IconData icon = count == 0
          ? Icons.spa
          : (count == 1 ? Icons.content_cut : Icons.clean_hands);

      rowItems.add(
        Padding(
          padding: const EdgeInsets.only(right: 15),
          child: _ServiceItem(
            color: bg,
            iconColor: iconColor,
            icon: icon,
            label: cat['name'],
            onTap: () {
              // --- NAVIGATION FIX: Direct to Provider List ---
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

    // 3. MORE SERVICES (Fixed)
    rowItems.add(
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: _ServiceItem(
          color: const Color(0xFFF3E5F5),
          iconColor: Colors.purple,
          icon: Icons.grid_view_rounded,
          label: "More\nServices",
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
      // FIX: Use SingleChildScrollView for Horizontal Scroll
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

  Widget _buildRecentSearchesList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: recentSearches.map((item) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['search_term'] ?? 'Search',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Just now',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlacesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: popularServices.length,
      itemBuilder: (context, index) {
        final service = popularServices[index];
        final imgUrl =
            (service['image_urls'] is List &&
                (service['image_urls'] as List).isNotEmpty)
            ? service['image_urls'][0]
            : null;
        final providerName = service['profiles']?['full_name'] ?? "Unknown";

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceBookingDetailScreen(
                serviceId: service['id'],
                providerId: service['provider_id'],
                providerName: providerName,
                providerPic: service['profiles']?['profile_picture_url'],
                serviceTitle: service['title'],
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
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
                  child: imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 160,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['title'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              service['location_text'] ?? "Unknown",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "5 km",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              Text(
                                " 4.5",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isIconWhite;
  final Color? iconColor;
  const _ServiceItem({
    required this.color,
    required this.icon,
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
            decoration: BoxDecoration(
              color: isIconWhite ? color : color.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isIconWhite ? Colors.white : iconColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          // Text Constraint to prevent Overflow
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
