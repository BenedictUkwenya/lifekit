import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../bookings/screens/book_service_screen.dart';

class ServiceBookingDetailScreen extends StatefulWidget {
  final String serviceId;
  final String providerId;
  final String providerName;
  final String? providerPic;
  final String serviceTitle;

  const ServiceBookingDetailScreen({
    super.key,
    required this.serviceId,
    required this.providerId,
    required this.providerName,
    this.providerPic,
    required this.serviceTitle,
  });

  @override
  State<ServiceBookingDetailScreen> createState() =>
      _ServiceBookingDetailScreenState();
}

class _ServiceBookingDetailScreenState
    extends State<ServiceBookingDetailScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> providerServices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProviderServices();
  }

  Future<void> _fetchProviderServices() async {
    try {
      // Fetches ALL services from this provider
      final data = await _apiService.getProviderServices(widget.providerId);
      if (mounted) {
        setState(() {
          providerServices = data['services'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
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
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.providerName,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search / Filter Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search ${widget.providerName}...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Showing results for \"${widget.serviceTitle}\"",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 16),

            isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: providerServices.length,
                    itemBuilder: (context, index) {
                      return _buildBookableServiceCard(providerServices[index]);
                    },
                  ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBookableServiceCard(dynamic service) {
    // 1. Extract Images safely
    List<String> images = [];
    var rawImages = service['image_urls'];

    if (rawImages != null && rawImages is List) {
      for (var item in rawImages) {
        if (item is String) {
          images.add(item);
        } else if (item is List && item.isNotEmpty && item[0] is String) {
          images.add(item[0]);
        }
      }
    }
    if (images.isEmpty) images = ["https://via.placeholder.com/150"];

    // 2. Extract Real Location from Backend
    // If null, show a fallback text
    String locationText = service['location_text'] ?? "No location provided";

    // 3. Extract Currency & Price
    String currency = service['currency'] ?? '\$';
    // Simple check to map 'USD' to '$' or 'NGN' to '₦' if needed
    if (currency == 'USD') currency = '\$';
    if (currency == 'NGN') currency = '₦';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
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
          // Image Row (Main + thumbnails)
          SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: images[0],
                      fit: BoxFit.cover,
                      height: 100,
                      errorWidget: (c, u, e) =>
                          Container(color: Colors.grey[200]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // If we had more images, we'd show them here.
                if (images.length > 1)
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: images[1],
                        fit: BoxFit.cover,
                        height: 100,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Title & Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Title
                    Text(
                      service['title'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // --- REAL LOCATION DISPLAY ---
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        Text(
                          " 3.5 ",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "(123 Reviews)",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Text(
                "$currency${service['price']}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Book Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // ... inside _buildBookableServiceCard ...
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookServiceScreen(
                      service: service, // Pass the whole service object
                      providerName: widget.providerName,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                "Book Now",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
