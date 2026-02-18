import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../bookings/screens/book_service_screen.dart';

class ServiceProfileScreen extends StatefulWidget {
  final dynamic service;
  final String providerName;
  final String? providerPic;
  final String providerId;

  const ServiceProfileScreen({
    super.key,
    required this.service,
    required this.providerName,
    this.providerPic,
    required this.providerId,
  });

  @override
  State<ServiceProfileScreen> createState() => _ServiceProfileScreenState();
}

class _ServiceProfileScreenState extends State<ServiceProfileScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool isLoading = true;
  List<dynamic> reviews = [];
  List<dynamic> otherServices = [];
  List<dynamic> weeklySchedule = [];

  // Calendar State for UI Demo
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final token = await _apiService.storage.read(key: 'jwt_token');

      // 1. Fetch Reviews
      final reviewsData = await _apiService.getReviews(widget.service['id']);

      // 2. Fetch Other Services
      final providerData = await _apiService.getProviderServices(
        widget.providerId,
      );
      List<dynamic> allServices = providerData['services'] ?? [];
      List<dynamic> others = allServices
          .where((s) => s['id'] != widget.service['id'])
          .toList();

      // 3. Fetch Schedule
      final scheduleRes = await http.get(
        Uri.parse('${_apiService.baseUrl}/users/schedule/${widget.providerId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          reviews = reviewsData;
          otherServices = others;
          if (scheduleRes.statusCode == 200) {
            weeklySchedule = jsonDecode(scheduleRes.body)['schedule'] ?? [];
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isDayAvailable(DateTime day) {
    if (weeklySchedule.isEmpty) return true;
    String dayName = DateFormat('EEEE').format(day);
    var scheduleDay = weeklySchedule.firstWhere(
      (d) => d['day_of_week'] == dayName,
      orElse: () => null,
    );
    if (scheduleDay != null && scheduleDay['is_active'] == false) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF89273B);

    final double rating = (widget.service['average_rating'] is int)
        ? (widget.service['average_rating'] as int).toDouble()
        : (widget.service['average_rating'] ?? 0.0);

    final int totalReviews = widget.service['total_reviews'] ?? 0;
    final String location = widget.service['location_text'] ?? "Online/Remote";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.service['title'] ?? "Service",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : Stack(
              children: [
                NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            // --- 1. HERO IMAGE & AVATAR ---
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Cover Image
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                    image: DecorationImage(
                                      image:
                                          (widget.service['image_urls'] as List)
                                              .isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              widget.service['image_urls'][0],
                                            )
                                          : const AssetImage(
                                                  'assets/images/home_bg.png',
                                                )
                                                as ImageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // Avatar with Clean Border
                                Positioned(
                                  bottom: -30,
                                  left: 20,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      4,
                                    ), // Thicker white border
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          widget.providerPic != null
                                          ? CachedNetworkImageProvider(
                                              widget.providerPic!,
                                            )
                                          : null,
                                      child: widget.providerPic == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.grey,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // --- 2. PROVIDER INFO ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.providerName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "$rating ($totalReviews Reviews)",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          color: Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          location,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Action Buttons
                                Row(
                                  children: [
                                    _buildCircleBtn(
                                      Icons.calendar_today,
                                      brandColor,
                                      isPrimary: true,
                                    ),
                                    const SizedBox(width: 10),
                                    _buildCircleBtn(
                                      Icons.chat_bubble_outline,
                                      Colors.grey[200]!,
                                      isPrimary: false,
                                      iconColor: Colors.black,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // --- 3. STICKY TABS (CORRECTED ALIGNMENT) ---
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.black,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: brandColor,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          // FIX: Removed 'padding' property on TabBar (it causes centering/offset issues)
                          // Instead, we handle alignment in the delegate container or labelPadding
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          dividerColor: Colors.transparent,
                          // Ensures tabs start from the left
                          tabAlignment: TabAlignment.start,
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

                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAboutTab(),
                      _buildReviewsTab(),
                      _buildAvailabilityTab(brandColor),
                      _buildServicesTab(),
                    ],
                  ),
                ),

                // --- 5. BOTTOM BOOK BUTTON ---
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookServiceScreen(
                              service: widget.service,
                              providerName: widget.providerName,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        "Book Now",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- TAB CONTENT ---

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.service['description'] ?? "No description available.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag("Instant Confirmation"),
              _buildTag("Secure Payment"),
              _buildTag("Verified Provider"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 50),
          child: Text(
            "No reviews yet.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                    backgroundImage: CachedNetworkImageProvider(
                      user?['profile_picture_url'] ??
                          'https://via.placeholder.com/150',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    user?['full_name'] ?? "User",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${r['rating']}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF89273B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r['comment'] ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const Divider(height: 30, color: Colors.black12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityTab(Color brandColor) {
    final monthName = DateFormat('MMMM, yyyy').format(_currentDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Calendar",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
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
                  fontSize: 16,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                ),
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0xFFFEEAEB),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: Color(0xFF89273B)),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF89273B),
                  shape: BoxShape.circle,
                ),
                disabledTextStyle: TextStyle(color: Colors.grey),
              ),
              onDaySelected: (selectedDay, focusedDay) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    if (otherServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 50),
          child: Text(
            "No other services.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: otherServices.length,
      itemBuilder: (context, index) {
        final s = otherServices[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceProfileScreen(
                  service: s,
                  providerName: widget.providerName,
                  providerPic: widget.providerPic,
                  providerId: widget.providerId,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s['title'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HELPERS ---

  Widget _buildCircleBtn(
    IconData icon,
    Color color, {
    required bool isPrimary,
    Color? iconColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isPrimary ? color : Colors.white,
        shape: BoxShape.circle,
        border: isPrimary ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        icon,
        color: iconColor ?? (isPrimary ? Colors.white : Colors.black),
        size: 18,
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
      color: Colors.white,
      padding: const EdgeInsets.only(
        bottom: 10,
        top: 10,
        left: 10,
      ), // Left padding ensures alignment
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
