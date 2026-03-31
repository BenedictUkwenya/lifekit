import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'service_booking_detail_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';

class CategoryItemsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryItemsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> allServices = [];
  List<dynamic> filteredServices = [];
  List<dynamic> subCategories = [];

  bool isLoading = true;
  String? selectedFilterId;

  // NEW: Variable to store the logged-in user's ID
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Fetch Current User Profile to get ID
      final profileData = await _apiService.getUserProfile();
      final myId = profileData['profile']['id'];

      // 2. Fetch Category Data
      final subsData = await _apiService.getSubCategories(widget.categoryId);
      final servicesData = await _apiService.getServicesByCategory(
        widget.categoryId,
      );

      if (mounted) {
        setState(() {
          currentUserId = myId; // Store the ID
          subCategories = subsData;
          allServices = servicesData;
          filteredServices = allServices;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- ACTIONS ---
  void _onSearchChanged(String query) {
    setState(() {
      filteredServices = allServices.where((s) {
        final title = s['title']?.toString().toLowerCase() ?? '';
        final provider =
            s['profiles']?['full_name']?.toString().toLowerCase() ?? '';
        return title.contains(query.toLowerCase()) ||
            provider.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _onFilterTap(String subId) {
    setState(() {
      if (selectedFilterId == subId) {
        selectedFilterId = null;
        filteredServices = allServices;
      } else {
        selectedFilterId = subId;
        filteredServices = allServices
            .where((s) => s['category_id'] == subId)
            .toList();
      }
    });
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Sort Results",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text("Top Rated"),
              onTap: () {
                setState(
                  () => filteredServices.sort(
                    (a, b) => (b['average_rating'] ?? 0).compareTo(
                      a['average_rating'] ?? 0,
                    ),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text("Price: Low to High"),
              onTap: () {
                setState(
                  () => filteredServices.sort(
                    (a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0),
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTierInfo = filteredServices.any((service) {
      final tier = service['profiles']?['subscription_tier'];
      return tier != null && tier.toString().trim().isNotEmpty;
    });
    final List<dynamic> featuredServices = [];
    final List<dynamic> standardServices = [];
    for (int i = 0; i < filteredServices.length; i++) {
      final service = filteredServices[i];
      final isPremium = _isPremiumService(service, i, hasTierInfo);
      if (isPremium) {
        featuredServices.add(service);
      } else {
        standardServices.add(service);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.black),
            ),
            onPressed: _showSortMenu,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Search ${widget.categoryName}...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                if (subCategories.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: subCategories.length,
                      itemBuilder: (context, index) {
                        final sub = subCategories[index];
                        final isSelected = selectedFilterId == sub['id'];
                        return GestureDetector(
                          onTap: () => _onFilterTap(sub['id']),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Text(
                                sub['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    "Showing ${filteredServices.length} results",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                Expanded(
                  child: filteredServices.isEmpty
                      ? const Center(child: Text("No services found."))
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          children: [
                            if (featuredServices.isNotEmpty) ...[
                              _buildSectionHeader("Featured Providers"),
                              ...featuredServices.map(
                                (service) => _buildProviderCard(
                                  service,
                                  isPremium: true,
                                ),
                              ),
                            ],
                            if (standardServices.isNotEmpty) ...[
                              _buildSectionHeader("More Providers"),
                              ...standardServices.map(
                                (service) => _buildProviderCard(
                                  service,
                                  isPremium: false,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  bool _isPremiumService(dynamic service, int index, bool hasTierInfo) {
    final tier = service['profiles']?['subscription_tier']?.toString();
    if (hasTierInfo) {
      return tier == 'Business' || tier == 'Pro';
    }
    return index < 2;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProviderCard(dynamic service, {required bool isPremium}) {
    final Map<String, dynamic> provider = service['profiles'] ?? {};
    final String providerName = provider['full_name'] ?? "Unknown Provider";
    final String? providerPic = provider['profile_picture_url'];
    final String location = service['location_text'] ?? "Online/Remote";
    final price = service['price'] ?? 0;

    // --- CHECK IF ME ---
    final bool isMe = (service['provider_id'] == currentUserId);

    // REAL DATA: Ratings
    final double avgRating = (service['average_rating'] is int)
        ? (service['average_rating'] as int).toDouble()
        : (service['average_rating'] ?? 0.0);

    // Image Logic
    String? coverImage;
    var rawImages = service['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      coverImage = (rawImages[0] is String) ? rawImages[0] : null;
    }

    final Color premiumBorderColor = AppColors.primary.withOpacity(0.6);
    final Color premiumBackgroundColor = const Color(0xFFFFF7ED);
    final Color standardBorderColor = Colors.grey.shade100;

    return GestureDetector(
      // --- NEW LOGIC: PREVENT SELF-BOOKING ---
      onTap: () {
        if (service['provider_id'] == currentUserId) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                "Action not allowed",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                "You cannot book your own service.",
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
          return; // Stop here, don't navigate
        }

        // Navigate normally if IDs don't match
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceBookingDetailScreen(
              serviceId: service['id'],
              providerId: service['provider_id'],
              providerName: providerName,
              providerPic: providerPic,
              serviceTitle: service['title'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: isPremium && !isMe ? premiumBackgroundColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isMe
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 1.5,
                )
              : isPremium
              ? Border.all(color: premiumBorderColor, width: 1.5)
              : Border.all(color: standardBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      color: Colors.grey[200],
                      child: coverImage != null
                          ? CachedNetworkImage(
                              imageUrl: coverImage,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),

                  // Location Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "YOUR LISTING" Badge
                  if (isMe)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Your Listing",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (isPremium)
                    Positioned(
                      top: isMe ? 44 : 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9CF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: premiumBorderColor),
                        ),
                        child: Text(
                          "Featured",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: providerPic != null
                            ? CachedNetworkImageProvider(providerPic)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 60),
                        child: Text(
                          // Highlight Name if Me
                          isMe ? "$providerName (Me)" : providerName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isMe ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ),
                      // REAL RATING DISPLAY
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(
                            avgRating == 0 ? " New" : " $avgRating",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          service['title'],
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "\$$price",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 16,
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
}
