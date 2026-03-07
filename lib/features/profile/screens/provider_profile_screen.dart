import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lifekit_frontend/features/profile/screens/service_profile_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? providerPic;

  const ProviderProfileScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerPic,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool isLoading = true;
  List<dynamic> services = [];
  Map<String, dynamic>? profileData;

  // Dynamic values
  String calculatedRating = "New";
  String experienceStr = "New";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProviderDetails();
  }

  Future<void> _fetchProviderDetails() async {
    try {
      final serviceData = await _apiService.getProviderServices(
        widget.providerId,
      );

      if (mounted) {
        setState(() {
          services = serviceData['services'] ?? [];
          if (serviceData['provider_profile'] != null) {
            profileData = serviceData['provider_profile'];
          }
          _calculateStats(); // Calculate after data is set
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateStats() {
    // 1. Calculate Average Rating
    if (services.isNotEmpty) {
      double totalRating = 0;
      int count = 0;

      for (var s in services) {
        var r = s['average_rating'];
        if (r != null) {
          totalRating += (r is int) ? r.toDouble() : (r as double);
          count++;
        }
      }

      if (count > 0 && totalRating > 0) {
        calculatedRating = (totalRating / count).toStringAsFixed(1);
      }
    }

    // 2. Calculate Experience (Time since profile creation or first service)
    // Note: Ensure your backend 'getProviderServices' selects 'created_at' in the profile query
    String? dateStr = profileData?['created_at'];

    // Fallback: If profile doesn't have date, try using the oldest service date
    if (dateStr == null && services.isNotEmpty) {
      // Sort to find oldest
      List sorted = List.from(services);
      sorted.sort((a, b) => a['created_at'].compareTo(b['created_at']));
      dateStr = sorted.first['created_at'];
    }

    if (dateStr != null) {
      final joinedDate = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(joinedDate);
      if (diff.inDays > 365) {
        experienceStr = "${(diff.inDays / 365).floor()}yr";
      } else if (diff.inDays > 30) {
        experienceStr = "${(diff.inDays / 30).floor()}mo";
      } else {
        experienceStr = "<1mo";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sharing Link Copied!")),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: widget.providerPic != null
                              ? CachedNetworkImageProvider(widget.providerPic!)
                              : null,
                          child: widget.providerPic == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.providerName,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profileData?['bio'] ??
                              "Professional service provider on LifeKit.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              calculatedRating, // Dynamic
                              "Rating",
                              Icons.star,
                              Colors.amber,
                            ),
                            _buildStatItem(
                              "${services.length}",
                              "Services",
                              Icons.work,
                              Colors.blue,
                            ),
                            _buildStatItem(
                              experienceStr, // Dynamic
                              "Exp.",
                              Icons.timer,
                              Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(text: "Services"),
                        Tab(text: "Reviews"),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Services Tab
                  services.isEmpty
                      ? Center(
                          child: Text(
                            "No services yet",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: services.length,
                          itemBuilder: (context, index) =>
                              _buildServiceCard(services[index]),
                        ),

                  // Reviews Tab (Placeholder for now)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rate_review_outlined,
                          color: Colors.grey,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Reviews will appear here",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildServiceCard(dynamic service) {
    // Safety check for image
    String imageUrl = 'https://via.placeholder.com/150';
    if (service['image_urls'] != null &&
        (service['image_urls'] as List).isNotEmpty) {
      var img = (service['image_urls'] as List)[0];
      if (img is String) imageUrl = img;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceProfileScreen(
              service: service,
              providerId: widget.providerId,
              providerName: widget.providerName,
              providerPic: widget.providerPic,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['title'] ?? "Untitled",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "\$${service['price']}",
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
