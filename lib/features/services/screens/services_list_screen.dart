import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CORE IMPORTS ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/cart_provider.dart';

import 'category_items_screen.dart';
import 'skill_swap_screens.dart';
import '../../home/screens/search_results_screen.dart';
import '../../home/screens/notifications_screen.dart';
import 'service_booking_detail_screen.dart';
import '../../profile/screens/provider_profile_screen.dart';
import 'all_categories_screen.dart';
import '../../bookings/screens/cart_screen.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _fabGlowController;
  late final Animation<double> _fabGlowBlur;

  List<dynamic> categories = [];
  List<dynamic> featuredProviders = [];
  List<dynamic> allServices = [];
  bool isLoading = true;
  bool _isFabExtended = true;

  String _flagEmoji = '🇳🇬';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _fabGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fabGlowBlur = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(_fabGlowController);
    // SWR: paint from cache immediately, then revalidate in background
    _loadExploreCache().then((_) => _fetchExploreData());
    _fetchUserExtras();
  }

  @override
  void dispose() {
    _fabGlowController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserExtras() async {
    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getUnreadCounts(),
      ]);
      final profileData = results[0];
      final countsData = results[1];
      final profileCountry =
          profileData['profile']?['country']?.toString() ?? 'NG';
      if (mounted) {
        setState(() {
          _flagEmoji = _getFlagEmoji(
            profileCountry.trim().length == 2
                ? profileCountry.trim().toUpperCase()
                : 'NG',
          );
          _unreadNotifications = countsData['notifications'] ?? 0;
        });
      }
    } catch (_) {}
  }

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

  // ── SWR cache helpers ─────────────────────────────────────────────────────

  Future<void> _loadExploreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('explore_cache');
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw) as Map;
      setState(() {
        categories = List<dynamic>.from(data['categories'] ?? []);
        featuredProviders =
            List<dynamic>.from(data['featured_providers'] ?? []);
        allServices = List<dynamic>.from(data['all_services'] ?? []);
        isLoading = false; // show stale content immediately
      });
    } catch (_) {}
  }

  Future<void> _saveExploreCache(Map data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('explore_cache', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _fetchExploreData() async {
    try {
      final data = await _apiService.getExplore();
      if (mounted) {
        setState(() {
          categories = List<dynamic>.from(data['categories'] ?? []);
          featuredProviders = List<dynamic>.from(
            data['featured_providers'] ?? [],
          );
          allServices = List<dynamic>.from(data['all_services'] ?? []);
          isLoading = false;
        });
      }
      // Persist fresh data for the next cold start
      _saveExploreCache(data as Map);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- HELPER: Get Image for Category ---
  String _getCategoryImage(String name) {
    name = name.toLowerCase();

    if (name.contains('health') || name.contains('wellness')) {
      return 'https://cdn-icons-png.flaticon.com/512/2966/2966334.png';
    }
    if (name.contains('laundry') || name.contains('ironing')) {
      return 'https://cdn-icons-png.flaticon.com/512/2954/2954888.png';
    }
    if (name.contains('hair') ||
        name.contains('beauty') ||
        name.contains('salon')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050257.png';
    }
    if (name.contains('family') ||
        name.contains('care') ||
        name.contains('companion') ||
        name.contains('baby')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050226.png';
    }
    if (name.contains('plumbing') ||
        name.contains('maintenance') ||
        name.contains('handyman')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050239.png';
    }
    if (name.contains('home') || name.contains('lifestyle')) {
      return 'https://cdn-icons-png.flaticon.com/512/619/619153.png';
    }
    if (name.contains('tech') ||
        name.contains('digital') ||
        name.contains('computer')) {
      return 'https://cdn-icons-png.flaticon.com/512/1055/1055687.png';
    }
    if (name.contains('clean')) {
      return 'https://cdn-icons-png.flaticon.com/512/995/995016.png';
    }
    if (name.contains('education') ||
        name.contains('tutor') ||
        name.contains('guidance')) {
      return 'https://cdn-icons-png.flaticon.com/512/2232/2232688.png';
    }
    if (name.contains('communication') ||
        name.contains('language') ||
        name.contains('translat')) {
      return 'https://cdn-icons-png.flaticon.com/512/3898/3898082.png';
    }
    if (name.contains('event') ||
        name.contains('party') ||
        name.contains('photo')) {
      return 'https://cdn-icons-png.flaticon.com/512/3132/3132084.png';
    }

    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

  // --- HELPER: Get Background Color ---
  Color _getCategoryColor(String name) {
    name = name.toLowerCase();
    if (name.contains('health')) return const Color(0xFFE3F2FD);
    if (name.contains('laundry')) return const Color(0xFFE8F5E9);
    if (name.contains('hair')) return const Color(0xFFF3E5F5);
    if (name.contains('care') || name.contains('family')) {
      return const Color(0xFFFFEBEE);
    }
    if (name.contains('clean')) return const Color(0xFFE0F7FA);
    if (name.contains('education')) return const Color(0xFFFFF3E0);
    if (name.contains('tech')) return const Color(0xFFECEFF1);
    if (name.contains('event')) return const Color(0xFFFCE4EC);
    return Colors.grey[100]!;
  }

  // --- ACTION: Search ---
  void _onSearch(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 85),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedBuilder(
            animation: _fabGlowBlur,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: _fabGlowBlur.value,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              isExtended: _isFabExtended,
              onPressed: _openSkillSwap,
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white),
                  Transform.translate(
                    offset: const Offset(-3, -6),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
              label: Text(
                "Skill Swap",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse &&
              _isFabExtended) {
            setState(() => _isFabExtended = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_isFabExtended) {
            setState(() => _isFabExtended = true);
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: const Color(0xFFFAFAFA),
              toolbarHeight: 76,
              titleSpacing: 20,
              title: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
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
                    hintText: "Search services, providers...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.black45,
                      size: 20,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Center(
                        widthFactor: 1.0,
                        child: Text(
                          _flagEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              actions: [
                // ── Notification Bell ──────────────────
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                    _fetchUserExtras();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                        if (_unreadNotifications > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── Cart ──────────────────────────────
                Consumer<CartProvider>(
                  builder: (context, cart, _) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.black87,
                              size: 20,
                            ),
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
                ),
              ],
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              if (featuredProviders.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Featured Professionals"),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: featuredProviders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) =>
                                _buildFeaturedProviderCard(
                                  featuredProviders[index],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildSectionHeader("Browse Categories"),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AllCategoriesScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "See all",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 46,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) =>
                                _buildCategoryChip(categories[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                  child: _buildSectionHeader("All Services"),
                ),
              ),
              if (allServices.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildEmptyState(
                      icon: Icons.storefront_outlined,
                      title: "No services found",
                      subtitle: "New services will appear here once available.",
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildServiceCard(allServices[index]),
                    childCount: allServices.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Future<void> _openCategory(dynamic category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemsScreen(
          categoryId: category['id'],
          categoryName: category['name'],
        ),
      ),
    );
  }

  Map<String, dynamic>? _getProvider(dynamic service) {
    final raw = service['profiles'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

  String? _getServiceImage(dynamic service) {
    final rawImages = service['image_urls'];
    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first;
      if (first is String && first.isNotEmpty) return first;
    }
    return null;
  }

  Future<void> _openSkillSwap() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SkillSwapBottomSheet(),
    );
  }

  Widget _buildFeaturedProviderCard(dynamic provider) {
    final providerId = (provider['id'] ?? '').toString();
    final providerName = (provider['full_name'] ?? 'Professional').toString();
    final providerPic = provider['profile_picture_url']?.toString();
    final tier = (provider['subscription_tier'] ?? 'pro')
        .toString()
        .toUpperCase();

    return GestureDetector(
      onTap: () {
        if (providerId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(
              providerId: providerId,
              providerName: providerName,
              providerPic: providerPic,
            ),
          ),
        );
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1BF5A), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tier,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: providerPic != null
                    ? CachedNetworkImageProvider(providerPic)
                    : null,
                child: providerPic == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Featured Professional",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(dynamic category) {
    return GestureDetector(
      onTap: () => _openCategory(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _getCategoryColor(category['name']),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CachedNetworkImage(
                imageUrl: _getCategoryImage(category['name']),
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Icon(Icons.category, color: Colors.grey, size: 14),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.grey, size: 14),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category['name'] ?? 'Category',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    final provider = _getProvider(service);
    final providerName = (provider?['full_name'] ?? 'Service Provider')
        .toString();
    final serviceTitle = (service['title'] ?? 'Service').toString();
    final price = service['price'] ?? 0;
    final rating =
        double.tryParse((service['average_rating'] ?? '0').toString()) ?? 0.0;
    final coverImage = _getServiceImage(service);

    return GestureDetector(
      onTap: () {
        final serviceId = (service['id'] ?? '').toString();
        final providerId = (service['provider_id'] ?? '').toString();
        if (serviceId.isEmpty || providerId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceBookingDetailScreen(
              serviceId: serviceId,
              providerId: providerId,
              providerName: providerName,
              providerPic: provider?['profile_picture_url']?.toString(),
              serviceTitle: serviceTitle,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
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
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: coverImage != null
                    ? CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating == 0 ? "New" : rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "\$$price",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
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
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
