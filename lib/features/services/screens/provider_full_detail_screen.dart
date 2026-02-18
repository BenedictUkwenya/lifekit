import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../bookings/screens/book_service_screen.dart';
import '../../home/screens/chats_list_screen.dart';

class ProviderFullDetailScreen extends StatefulWidget {
  final String providerId;
  final String serviceId; // The ID of the specific service being viewed
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
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool isLoading = true;

  // Data Containers
  Map<String, dynamic>? providerProfile;
  List<dynamic> services = [];
  List<dynamic> reviews = [];
  List<dynamic> weeklySchedule = [];

  // Current Service Data (The one clicked)
  dynamic currentService;

  // Calculated Fields
  double averageRating = 0.0;
  int totalReviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final token = await _apiService.storage.read(key: 'jwt_token');

      // 1. Fetch Provider Services & Profile
      final servicesData = await _apiService.getProviderServices(
        widget.providerId,
      );

      // 2. Fetch Schedule
      final scheduleRes = await http.get(
        Uri.parse('${_apiService.baseUrl}/users/schedule/${widget.providerId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 3. Fetch Reviews (Specific to this service)
      final reviewsData = await _apiService.getReviews(widget.serviceId);

      if (mounted) {
        setState(() {
          // A. Store Services
          services = servicesData['services'] ?? [];

          // B. Identify Current Service
          if (services.isNotEmpty) {
            currentService = services.firstWhere(
              (s) => s['id'] == widget.serviceId,
              orElse: () => services[0],
            );
          }

          // C. Store Profile
          if (servicesData['provider_profile'] != null) {
            providerProfile = servicesData['provider_profile'];
          } else if (services.isNotEmpty && services[0]['profiles'] != null) {
            providerProfile = services[0]['profiles'];
          }

          // D. Store Schedule
          if (scheduleRes.statusCode == 200) {
            weeklySchedule = jsonDecode(scheduleRes.body)['schedule'] ?? [];
          }

          // E. Store Reviews
          reviews = reviewsData;
          if (reviews.isNotEmpty) {
            double sum = 0;
            for (var r in reviews) sum += (r['rating'] as int);
            averageRating = sum / reviews.length;
            totalReviewsCount = reviews.length;
          } else if (currentService != null) {
            // Fallback to service aggregate data
            averageRating = (currentService['average_rating'] ?? 0).toDouble();
            totalReviewsCount = (currentService['total_reviews'] ?? 0);
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching details: $e");
    }
  }

  // --- HELPER: Get Specific Service Image ---
  String _getCoverImage() {
    if (currentService == null) return "https://via.placeholder.com/400";

    var rawImages = currentService['image_urls'];
    if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      return (rawImages[0] is String)
          ? rawImages[0]
          : "https://via.placeholder.com/400";
    }
    return "https://via.placeholder.com/400";
  }

  // --- HELPER: Check Calendar Availability ---
  bool _isDayAvailable(DateTime day) {
    if (weeklySchedule.isEmpty) return true;
    String dayName = DateFormat('EEEE').format(day);
    var scheduleDay = weeklySchedule.firstWhere(
      (d) => d['day_of_week'] == dayName,
      orElse: () => null,
    );
    return scheduleDay != null && scheduleDay['is_active'];
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF89273B);

    final String name = providerProfile?['full_name'] ?? "Provider";
    final String pic = providerProfile?['profile_picture_url'] ?? "";
    final String bio = providerProfile?['bio'] ?? "No bio available.";

    String location = currentService?['location_text'] ?? "Online/Remote";

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: Colors.white,
                  leading: const BackButton(color: Colors.black),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.black,
                      ),
                      onPressed: () {},
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: _getCoverImage(),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Container(color: Colors.grey[300]),
                        ),
                        Container(color: Colors.black.withOpacity(0.1)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Avatar Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: pic.isNotEmpty
                                    ? CachedNetworkImageProvider(pic)
                                    : null,
                                child: pic.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
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
                                      const SizedBox(width: 4),
                                      Text(
                                        "${averageRating.toStringAsFixed(1)} ($totalReviewsCount Reviews)",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Message Button
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChatsListScreen(),
                                  ),
                                );
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Tabs
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black,
                      indicator: BoxDecoration(
                        color: brandColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "About"),
                        Tab(text: "Reviews"),
                        Tab(text: "Availability"),
                        Tab(text: "Services Offered"),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ],
              body: Container(
                color: const Color(0xFFFAFAFA),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. ABOUT TAB
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentService != null) ...[
                            Text(
                              "Service Description",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              currentService['description'] ??
                                  "No description available.",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            "About Provider",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            bio,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.6,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. REVIEWS TAB
                    reviews.isEmpty
                        ? Center(
                            child: Text(
                              "No reviews yet.",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final r = reviews[index];
                              final user = r['profiles'];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage:
                                              CachedNetworkImageProvider(
                                                user?['profile_picture_url'] ??
                                                    '',
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          user?['full_name'] ?? "User",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        Text(
                                          " ${r['rating']}",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      r['comment'] ?? "",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                ),
                              );
                            },
                          ),

                    // 3. AVAILABILITY TAB
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.now(),
                          lastDay: DateTime.now().add(const Duration(days: 90)),
                          focusedDay: DateTime.now(),
                          calendarFormat: CalendarFormat.month,
                          enabledDayPredicate: _isDayAvailable,
                          availableGestures: AvailableGestures.horizontalSwipe,
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                            titleTextStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: brandColor.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: brandColor,
                              shape: BoxShape.circle,
                            ),
                            disabledTextStyle: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          onDaySelected: (s, f) {},
                        ),
                      ),
                    ),

                    // 4. SERVICES TAB (UPDATED)
                    ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        // Pass 'true' to indicate we are inside the detail view
                        return _buildBookableServiceCard(services[index]);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBookableServiceCard(dynamic service) {
    String currency = service['currency'] == 'NGN' ? '₦' : '\$';

    // Check if this card represents the currently viewed service
    bool isCurrentService = (service['id'] == widget.serviceId);

    return GestureDetector(
      onTap: () {
        // NAVIGATE TO THIS SCREEN AGAIN WITH NEW ID
        if (!isCurrentService) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderFullDetailScreen(
                providerId: widget.providerId,
                serviceId: service['id'], // NEW SERVICE ID
                initialServiceTitle: service['title'],
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentService
              ? const Color(0xFFF9FAFB)
              : Colors.white, // Slight Highlight if current
          borderRadius: BorderRadius.circular(16),
          border: isCurrentService
              ? Border.all(color: const Color(0xFF89273B), width: 1.5)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
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
            Text(
              service['description'] ?? "",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$currency${service['price']}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF89273B),
                  ),
                ),

                // BOOK BUTTON GOES TO BOOKING FLOW
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookServiceScreen(
                          service: service,
                          providerName:
                              providerProfile?['full_name'] ?? "Provider",
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89273B),
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
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      alignment: Alignment.centerLeft,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
