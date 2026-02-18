import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../services/screens/service_booking_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  List<dynamic> services = [];
  List<dynamic> providers = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    try {
      // 1. Fetch User ID (for "Me" check)
      final profileData = await _apiService.getUserProfile();
      final myId = profileData['profile']['id'];

      // 2. Perform Search
      final data = await _apiService.search(widget.query);

      if (mounted) {
        setState(() {
          currentUserId = myId;
          services = data['services'] ?? [];
          providers = data['providers'] ?? [];
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
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: Text(
          'Results for "${widget.query}"',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : services.isEmpty && providers.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (services.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      "Services",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ...services.map((s) => _buildBeautifulServiceCard(s)),
                  const SizedBox(height: 20),
                ],

                // Show Providers
                if (providers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      "Providers",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ...providers.map((p) => _buildSimpleProviderTile(p)),
                ],
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "No results found.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED CARD WITH SUB-OPTION CHECK ---
  Widget _buildBeautifulServiceCard(dynamic service) {
    final Map<String, dynamic> provider = service['profiles'] ?? {};
    final String providerName = provider['full_name'] ?? "Unknown";
    final String? providerPic = provider['profile_picture_url'];

    // Real Data Logic
    final String location = service['location_text'] ?? "Online/Remote";
    final double price = double.tryParse(service['price'].toString()) ?? 0.0;
    final String currency = service['currency'] == 'NGN' ? '₦' : '\$';
    final double avgRating = (service['average_rating'] is int)
        ? (service['average_rating'] as int).toDouble()
        : (service['average_rating'] ?? 0.0);

    // Checks
    final bool isMe = (service['provider_id'] == currentUserId);

    // Image
    String? coverImage;
    var rawImages = service['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      coverImage = (rawImages[0] is String) ? rawImages[0] : null;
    }

    // --- NEW: Check Sub-Options for Match ---
    final List options = service['service_options'] ?? [];
    bool matchesOption = options.any(
      (opt) => opt['name'].toString().toLowerCase().contains(
        widget.query.toLowerCase(),
      ),
    );

    return GestureDetector(
      onTap: () {
        // Prevent Self-Booking
        if (isMe) {
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
          return;
        }

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isMe
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 1.5,
                )
              : Border.all(color: Colors.grey.shade100),
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
            // Image Section
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

                  // Location
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

                  // Me Badge
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

                  // Avatar
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

            // Details Section
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
                          isMe ? "$providerName (Me)" : providerName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isMe ? AppColors.primary : Colors.black,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(
                            " ${avgRating == 0 ? 'New' : avgRating}",
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

                  // --- NEW: MATCH BADGE ---
                  if (matchesOption)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Offers '${widget.query}'",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

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
                        "$currency$price",
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

  // Simple tile for direct provider matches (if any)
  Widget _buildSimpleProviderTile(dynamic provider) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(
          provider['profile_picture_url'] ?? '',
        ),
        backgroundColor: Colors.grey[200],
      ),
      title: Text(
        provider['full_name'],
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to provider profile if needed
      },
    );
  }
}
