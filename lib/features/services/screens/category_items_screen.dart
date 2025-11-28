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
  List<dynamic> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final data = await _apiService.getServicesByCategory(widget.categoryId);
      if (mounted) {
        setState(() {
          services = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching services: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: const LifeKitLoader())
          : services.isEmpty
          ? Center(child: Text("No services found in ${widget.categoryName}"))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: services.length,
              itemBuilder: (context, index) {
                return _buildProviderCard(services[index]);
              },
            ),
    );
  }

  Widget _buildProviderCard(dynamic service) {
    // --- 1. ROBUST DATA EXTRACTION (Fixes the Crash) ---

    // Handle Profile
    Map<String, dynamic> provider = {};
    if (service['profiles'] is Map) {
      provider = service['profiles'];
    }

    final providerName = provider['full_name'] ?? "Unknown Provider";
    final providerPic = provider['profile_picture_url'];

    // Handle Image URLs (The fix for [[null]])
    String imageUrl = "https://via.placeholder.com/400x200"; // Default
    var rawImages = service['image_urls'];

    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      var firstItem = rawImages[0];

      if (firstItem is String) {
        // Case: ["url"]
        imageUrl = firstItem;
      } else if (firstItem is List && firstItem.isNotEmpty) {
        // Case: [["url"]] or [[null]]
        var nestedItem = firstItem[0];
        if (nestedItem is String) {
          imageUrl = nestedItem;
        }
      }
    }
    // ------------------------------------------------

    // Handle Price & Currency
    final price = service['price'] ?? 0;
    final currency = service['currency'] ?? 'USD';

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
              serviceTitle: service['title'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                // Location Tag
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey,
                        ),
                        Text(
                          " Tallas, Georgia",
                          style: GoogleFonts.poppins(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Provider Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: providerPic != null
                                ? CachedNetworkImageProvider(providerPic)
                                : const AssetImage(
                                        'assets/images/onboarding1.png',
                                      )
                                      as ImageProvider,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    providerName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              Text(
                                service['title'],
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Price/Rating
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$currency $price",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.amber,
                              ),
                              Text(
                                " 4.5",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
  }
}
