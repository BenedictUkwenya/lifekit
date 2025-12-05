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
  List<dynamic> allServices = [];
  List<dynamic> filteredServices = [];
  List<dynamic> subCategories = []; // For the Chips

  bool isLoading = true;
  String? selectedFilterId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Fetch Sub-Categories (For the Filter Chips)
      final subsData = await _apiService.getSubCategories(widget.categoryId);

      // 2. Fetch Services
      // NOTE: Your ApiService returns a List<dynamic> here, not a Map.
      final servicesData = await _apiService.getServicesByCategory(
        widget.categoryId,
      );

      if (mounted) {
        setState(() {
          subCategories = subsData;
          // FIX IS HERE: Directly assign the list.
          allServices = servicesData;
          filteredServices = allServices;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Filter logic when clicking a Chip
  void _onFilterTap(String subId) {
    setState(() {
      if (selectedFilterId == subId) {
        selectedFilterId = null; // Unselect
        filteredServices = allServices;
      } else {
        selectedFilterId = subId; // Select
        filteredServices = allServices
            .where((s) => s['category_id'] == subId)
            .toList();
      }
    });
  }

  // Filter logic for Search Bar
  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredServices = selectedFilterId != null
            ? allServices
                  .where((s) => s['category_id'] == selectedFilterId)
                  .toList()
            : allServices;
      } else {
        filteredServices = allServices.where((s) {
          final title = s['title']?.toString().toLowerCase() ?? '';
          final provider =
              s['profiles']?['full_name']?.toString().toLowerCase() ?? '';
          return title.contains(query.toLowerCase()) ||
              provider.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.tune, size: 20, color: Colors.black),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SEARCH BAR
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
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Search ${widget.categoryName}",
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

                // 2. FILTER CHIPS (Sub-Categories)
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

                // 3. RESULTS COUNT
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    "Showing results ${filteredServices.length} \"${widget.categoryName}\"",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),

                // 4. LIST OF CARDS
                Expanded(
                  child: filteredServices.isEmpty
                      ? const Center(child: Text("No services found."))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: filteredServices.length,
                          itemBuilder: (context, index) {
                            return _buildProviderCard(filteredServices[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProviderCard(dynamic service) {
    final Map<String, dynamic> provider = service['profiles'] ?? {};
    final String providerName = provider['full_name'] ?? "Unknown Provider";
    final String? providerPic = provider['profile_picture_url'];
    final String serviceTitle = service['title'] ?? "Service";

    // Image Logic
    String? coverImage;
    var rawImages = service['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      var first = rawImages[0];
      coverImage = (first is String)
          ? first
          : (first is List && first.isNotEmpty ? first[0] : null);
    }

    // Location Logic (Fallback if null)
    final String location = service['location_text'] ?? "Tbilisi, Georgia";

    // Pricing Logic
    final price = service['price'] ?? 0;
    final isHourly = service['pricing_type'] == 'hourly';
    final currency = service['currency'] == 'NGN' ? '₦' : '\$';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceBookingDetailScreen(
              serviceId: service['id'],
              providerId: service['provider_id'],
              providerName: providerName,
              providerPic: providerPic,
              serviceTitle: serviceTitle,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
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
            // --- TOP IMAGE SECTION ---
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  // 1. Cover Image
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
                              errorWidget: (c, u, e) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                    ),
                  ),

                  // 2. Location Badge
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
                            location,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Provider Avatar (Overlapping)
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
                            : const AssetImage('assets/images/onboarding1.png')
                                  as ImageProvider,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BOTTOM INFO SECTION ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Rating Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                providerName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF89273B),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(
                            " 3.5",
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

                  // Service Tags & Price Row
                  Row(
                    children: [
                      _buildChip(serviceTitle),
                      const SizedBox(width: 8),
                      // Price display logic
                      Text(
                        "$currency$price${isHourly ? '/hr' : ''}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
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

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
