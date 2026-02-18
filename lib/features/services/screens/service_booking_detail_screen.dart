import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:carousel_slider/carousel_slider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../bookings/screens/book_service_screen.dart';
import '../../home/screens/chats_list_screen.dart';

class ServiceBookingDetailScreen extends StatefulWidget {
  final String providerId;
  final String serviceId;

  // FIX: Renamed back to 'serviceTitle' to match your Home/Search screens
  final String serviceTitle;

  final String providerName;
  final String? providerPic;

  const ServiceBookingDetailScreen({
    super.key,
    required this.providerId,
    required this.serviceId,
    required this.serviceTitle, // FIX: Matches the parameter name used in other files
    this.providerName = "Provider",
    this.providerPic,
  });

  @override
  State<ServiceBookingDetailScreen> createState() =>
      _ServiceBookingDetailScreenState();
}

class _ServiceBookingDetailScreenState extends State<ServiceBookingDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool isLoading = true;
  String? currentUserId;

  // Data Containers
  Map<String, dynamic>? providerProfile;
  List<dynamic> services = [];
  List<dynamic> filteredServices = []; // For Search
  List<dynamic> reviews = [];
  List<dynamic> weeklySchedule = [];

  // Current Service Data
  dynamic currentService;
  List<String> serviceImages = []; // List to hold all images

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

      // 1. Fetch Current User (For self-booking check)
      final profileData = await _apiService.getUserProfile();
      final myId = profileData['profile']['id'];

      // 2. Fetch Provider Services & Profile
      final servicesData = await _apiService.getProviderServices(
        widget.providerId,
      );

      // 3. Fetch Schedule
      final scheduleRes = await http.get(
        Uri.parse('${_apiService.baseUrl}/users/schedule/${widget.providerId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 4. Fetch Reviews
      final reviewsData = await _apiService.getReviews(widget.serviceId);

      if (mounted) {
        setState(() {
          currentUserId = myId;
          services = servicesData['services'] ?? [];
          filteredServices = services; // Initialize search list

          // Identify Current Service
          if (services.isNotEmpty) {
            currentService = services.firstWhere(
              (s) => s['id'] == widget.serviceId,
              orElse: () => services[0],
            );

            // --- EXTRACT ALL IMAGES ---
            serviceImages.clear();
            var rawImages = currentService['image_urls'];
            if (rawImages != null && rawImages is List) {
              for (var img in rawImages) {
                if (img is String) {
                  serviceImages.add(img);
                } else if (img is List && img.isNotEmpty) {
                  serviceImages.add(img[0]); // Handle nested arrays if any
                }
              }
            }
          }

          // Provider Profile
          if (servicesData['provider_profile'] != null) {
            providerProfile = servicesData['provider_profile'];
          } else if (services.isNotEmpty && services[0]['profiles'] != null) {
            providerProfile = services[0]['profiles'];
          }

          // Schedule
          if (scheduleRes.statusCode == 200) {
            weeklySchedule = jsonDecode(scheduleRes.body)['schedule'] ?? [];
          }

          // Reviews
          reviews = reviewsData;
          if (reviews.isNotEmpty) {
            double sum = 0;
            for (var r in reviews) sum += (r['rating'] as int);
            averageRating = sum / reviews.length;
            totalReviewsCount = reviews.length;
          } else if (currentService != null) {
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

  // --- SEARCH LOGIC ---
  void _onSearch(String query) {
    setState(() {
      filteredServices = services
          .where((s) => s['title'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  bool _isDayAvailable(DateTime day) {
    if (weeklySchedule.isEmpty) return true;
    String dayName = DateFormat('EEEE').format(day);
    var scheduleDay = weeklySchedule.firstWhere(
      (d) => d['day_of_week'] == dayName,
      orElse: () => null,
    );
    return scheduleDay != null && scheduleDay['is_active'];
  }

  void _attemptBooking(dynamic service) {
    if (widget.providerId == currentUserId) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            "Restricted",
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
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookServiceScreen(
            service: service,
            providerName: providerProfile?['full_name'] ?? "Provider",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF89273B); // Use consistent brand color

    final String name = providerProfile?['full_name'] ?? widget.providerName;
    final String pic =
        providerProfile?['profile_picture_url'] ?? widget.providerPic ?? "";
    final String bio =
        providerProfile?['bio'] ?? "Professional service provider on LifeKit.";
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
                      onPressed: () {
                        // Implement Share Logic
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // --- IMAGE CAROUSEL LOGIC ---
                        if (serviceImages.length > 1)
                          CarouselSlider(
                            options: CarouselOptions(
                              height: double.infinity,
                              viewportFraction: 1.0,
                              autoPlay: true,
                              autoPlayInterval: const Duration(seconds: 4),
                              scrollDirection: Axis.horizontal,
                            ),
                            items: serviceImages.map((imageUrl) {
                              return CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorWidget: (context, url, error) =>
                                    Container(color: Colors.grey[300]),
                              );
                            }).toList(),
                          )
                        else
                          CachedNetworkImage(
                            imageUrl: serviceImages.isNotEmpty
                                ? serviceImages[0]
                                : "https://via.placeholder.com/400",
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: Colors.grey[300]),
                          ),

                        // Dim Overlay for text readability (optional)
                        Container(color: Colors.black.withOpacity(0.1)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- AVATAR & NAME ROW ---
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
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
                            // Chat Button
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

                // --- TABS ---
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
                        Tab(text: "Services"),
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
                    // 1. ABOUT
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
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTag("Instant Confirmation"),
                              _buildTag("Verified Provider"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. REVIEWS
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
                                        const Icon(
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

                    // 3. AVAILABILITY
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

                    // 4. SERVICES (With Search & Standalone Options Logic)
                    Column(
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              onChanged: _onSearch,
                              decoration: InputDecoration(
                                hintText: "Search services...",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredServices.length,
                            itemBuilder: (context, index) {
                              return _buildBookableServiceCard(
                                filteredServices[index],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      // --- BOTTOM ACTION BUTTON (If on specific service) ---
      bottomNavigationBar: (currentService != null)
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: ElevatedButton(
                onPressed: () => _attemptBooking(currentService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Book This Service",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // --- WIDGET HELPER: Service Card with Standalone Options ---
  Widget _buildBookableServiceCard(dynamic service) {
    const Color brandColor = Color(0xFF89273B);
    String currency = service['currency'] == 'NGN' ? '₦' : '\$';

    // Highlight if it's the current service
    bool isCurrentService =
        (currentService != null && service['id'] == widget.serviceId);

    // Check for sub-options (Standalone)
    List<dynamic> subOptions = service['service_options'] ?? [];
    bool isStandalone = subOptions.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!isCurrentService) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceBookingDetailScreen(
                providerId: widget.providerId,
                serviceId: service['id'],
                serviceTitle:
                    service['title'], // FIX: Renamed back to serviceTitle
                providerName: widget.providerName,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentService ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isCurrentService
              ? Border.all(color: brandColor, width: 1.5)
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

            // --- DISPLAY STANDALONE SUB-OPTIONS ---
            if (isStandalone)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available Options:",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...subOptions
                        .take(3)
                        .map(
                          (opt) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: brandColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    opt['name'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                Text(
                                  "$currency${opt['price']}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (subOptions.length > 3)
                      Text(
                        "+ ${subOptions.length - 3} more",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // If standalone, show "Price Varies", else show Price
                Text(
                  isStandalone
                      ? "Price Varies"
                      : "$currency${service['price']}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: brandColor,
                  ),
                ),

                ElevatedButton(
                  onPressed: () => _attemptBooking(service),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
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

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}

// --- STICKY HEADER DELEGATE ---
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
