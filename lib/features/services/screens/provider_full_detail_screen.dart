import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../bookings/screens/book_service_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';

class ProviderFullDetailScreen extends StatefulWidget {
  final String providerId;
  final String serviceId;
  final String initialServiceTitle;

  const ProviderFullDetailScreen({
    super.key,
    required this.providerId,
    required this.serviceId,
    required this.initialServiceTitle,
  });

  @override
  State<ProviderFullDetailScreen> createState() =>
      _ProviderFullDetailScreenState();
}

class _ProviderFullDetailScreenState extends State<ProviderFullDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? providerData;
  List<dynamic> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final data = await _apiService.getProviderServices(widget.providerId);
      if (mounted) {
        setState(() {
          services = data['services'] ?? [];
          if (data.containsKey('provider_profile') &&
              data['provider_profile'] != null) {
            providerData = data['provider_profile'];
          } else if (services.isNotEmpty) {
            var firstService = services[0];
            if (firstService['profiles'] != null) {
              providerData = firstService['profiles'];
            }
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- FIX: ROBUST IMAGE EXTRACTOR ---
  String _getSafeCoverImage() {
    if (services.isEmpty) return "https://via.placeholder.com/400";

    // Try to get image from the first service
    var rawImages = services[0]['image_urls'];

    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      var firstItem = rawImages[0];

      // Case 1: It's a direct string URL ["http..."]
      if (firstItem is String && firstItem.startsWith('http')) {
        return firstItem;
      }
      // Case 2: It's a nested list [["http..."]]
      else if (firstItem is List && firstItem.isNotEmpty) {
        var nestedItem = firstItem[0];
        if (nestedItem is String && nestedItem.startsWith('http')) {
          return nestedItem;
        }
      }
    }
    // Default fallback if nothing valid found
    return "https://via.placeholder.com/400";
  }

  @override
  Widget build(BuildContext context) {
    String providerName = providerData?['full_name'] ?? "Provider";
    String providerPic = providerData?['profile_picture_url'] ?? "";

    // Use the safe extractor
    String coverImage = _getSafeCoverImage();

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: const LifeKitLoader())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 280,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    leading: const BackButton(color: Colors.black),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.black),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.bookmark_border,
                          color: Colors.black,
                        ),
                        onPressed: () {},
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover Image
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 200,
                            child: CachedNetworkImage(
                              imageUrl: coverImage,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Container(color: Colors.grey[300]),
                            ),
                          ),
                          // Profile Card Overlay
                          Positioned(
                            top: 150,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: providerPic.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                                providerPic,
                                              )
                                            : const AssetImage(
                                                    'assets/images/onboarding1.png',
                                                  )
                                                  as ImageProvider,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              providerName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 16,
                                                  color: Colors.amber,
                                                ),
                                                Text(
                                                  " 3.5 (123)",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                Text(
                                                  " Georgia",
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
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: "About"),
                        Tab(text: "Reviews"),
                        Tab(text: "Availability"),
                        Tab(text: "Services Offered"),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  const Center(child: Text("About info goes here")),
                  const Center(child: Text("Reviews go here")),
                  const Center(child: Text("Availability Calendar goes here")),
                  _buildServicesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildServicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service['title'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service['description'] ?? "No description",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "\$${service['price']}",
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookServiceScreen(
                            service: service,
                            providerName:
                                providerData?['full_name'] ?? "Provider",
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      "Book Now",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
