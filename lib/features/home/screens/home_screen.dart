import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../services/screens/services_list_screen.dart';
import '../../services/screens/service_booking_detail_screen.dart';
import '../../provider/screens/provider_onboarding_intro_screen.dart';

// --- IMPORTS FOR NAVIGATION ---
import '../../bookings/screens/bookings_screen.dart'; // Tab 1
import 'chats_list_screen.dart'; // Tab 3
import 'notifications_screen.dart'; // Notification Screen
import '../../profile/screens/profile_screen.dart'; // Tab 4
import '../../../core/widgets/lifekit_loader.dart';

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
      final profile = await _apiService.getUserProfile();
      var off = await _apiService.getOffers();
      var cats = await _apiService.getCategories();
      var recents = await _apiService.getRecentSearches();
      var pop = await _apiService.getPopularServices();

      // --- MOCK DATA FALLBACKS ---
      if (off.isEmpty) {
        off = [
          {
            'title': 'Explore Soars Of\nDelfa Oceans',
            'image_url':
                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
            'description': 'Over 20,000 km',
          },
          {
            'title': 'Sunset at\nMalibu Beach',
            'image_url':
                'https://images.unsplash.com/photo-1519046904884-53103b34b206?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
            'description': 'Relaxing evening',
          },
        ];
      }

      if (mounted) {
        setState(() {
          userProfile = profile['profile'];
          offers = off;
          categories = cats;
          recentSearches = recents;
          popularServices = pop;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching home data: $e");
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeContent(), // 0: Home
      const BookingsScreen(), // 1: Bookings
      const Center(child: Text("Feeds Screen")), // 2: Feeds
      const ChatsListScreen(), // 3: Chats
      const ProfileScreen(), // 4: Profile
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

  // --- HOME CONTENT (Tab 0) ---
  Widget _buildHomeContent() {
    return Stack(
      children: [
        // 1. BACKGROUND IMAGE
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

        // 2. SCROLLABLE CONTENT
        isLoading
            ? const Center(child: const LifeKitLoader())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
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

                        // SERVICES
                        _buildSectionHeader("Services", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServicesListScreen(),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        _buildServicesContainer(),
                        const SizedBox(height: 24),

                        // RECENT SEARCHES
                        _buildSectionHeader(
                          "Recent searches",
                          null,
                          showSeeAll: false,
                        ),
                        const SizedBox(height: 12),
                        _buildRecentSearchesList(),
                        const SizedBox(height: 24),

                        // PLACES
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
              ),
      ],
    );
  }

  // --- WIDGET COMPONENTS ---

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
                overflow: TextOverflow.ellipsis,
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          child: const _HeaderIconBtn(
            icon: Icons.notifications_outlined,
            hasBadge: true,
          ),
        ),

        const SizedBox(width: 12),

        // --- FLAG FIX ---
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
              // Added error builder for fallback if network image fails
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.flag, color: Colors.green, size: 20);
              },
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gracie a special offer awaits!",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentOffer['description'] ?? "Over 20,000 km",
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
            currentOffer['title'] ?? "Special Offer",
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
              return GestureDetector(
                onTap: () {
                  // --- TOAST FOR COMING SOON ---
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("This offer is coming soon!"),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            offer['image_url'] ??
                            'https://via.placeholder.com/400x200',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            Container(color: Colors.grey[300]),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Popular",
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
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: offers.asMap().entries.map((entry) {
              return Container(
                width: 6.0,
                height: 6.0,
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBannerIndex == entry.key
                      ? Colors.black54
                      : Colors.grey[300],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesContainer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceItem(
            color: Colors.green,
            icon: Icons.add,
            label: "Create\nService",
            isIconWhite: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProviderOnboardingIntroScreen(),
                ),
              );
            },
          ),
          _ServiceItem(
            color: const Color(0xFFE3F2FD),
            iconColor: Colors.blue,
            icon: Icons.spa,
            label: "Health &\nWellness",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesListScreen()),
              );
            },
          ),
          _ServiceItem(
            color: const Color(0xFFFFF3E0),
            iconColor: Colors.orange,
            icon: Icons.content_cut,
            label: "Hair &\nBeauty",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesListScreen()),
              );
            },
          ),
          _ServiceItem(
            color: const Color(0xFFF9FBE7),
            iconColor: Colors.lime[700],
            icon: Icons.iron,
            label: "Laundry &\nIroning",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesListScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesList() {
    final list = recentSearches.isEmpty
        ? [
            {
              'term': 'Home plumbing',
              'time': '4 mins ago',
              'icon': Icons.plumbing,
              'color': const Color(0xFFE3F2FD),
            },
            {
              'term': 'Hair dressing',
              'time': '8 mins ago',
              'icon': Icons.content_cut,
              'color': const Color(0xFFFFF3E0),
            },
            {
              'term': 'Cleaning',
              'time': '10 mins ago',
              'icon': Icons.cleaning_services,
              'color': const Color(0xFFF3E5F5),
            },
          ]
        : recentSearches;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: list.map((item) {
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
                    color: item['color'] ?? Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] ?? Icons.search,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['term'] ?? item['search_term'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item['time'] ?? 'Just now',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.close, size: 14, color: Colors.grey),
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
        String imgUrl =
            (service['image_urls'] is List &&
                (service['image_urls'] as List).isNotEmpty)
            ? service['image_urls'][0]
            : "https://via.placeholder.com/400x200";

        final providerName =
            service['profiles']?['full_name'] ?? "Unknown Provider";
        final providerId = service['provider_id'] ?? "";

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceBookingDetailScreen(
                  serviceId: service['id'],
                  providerId: providerId,
                  providerName: providerName,
                  providerPic: service['profiles']?['profile_picture_url'],
                  serviceTitle: service['title'],
                ),
              ),
            );
          },
          child: _buildPlaceCard(
            title: service['title'] ?? 'Unknown',
            image: imgUrl,
            location: service['location_text'] ?? "Unknown Location",
            distance: "5 km",
            rating: (service['rating'] ?? 4.5).toString(),
          ),
        );
      },
    );
  }

  Widget _buildPlaceCard({
    required String title,
    required String image,
    required String location,
    required String distance,
    required String rating,
  }) {
    return Container(
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(
              imageUrl: image,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Container(height: 160, color: Colors.grey[300]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
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
                      distance,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        Text(
                          " $rating",
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
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
