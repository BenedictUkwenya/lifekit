import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'booking_receipt_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Data State
  List<dynamic> clientBookings = [];
  List<dynamic> providerRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Tab 0: My Bookings (Client Mode)
    // Tab 1: Client Requests (Provider Mode)
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  // --- FETCH DATA (With Sorting) ---
  Future<void> _fetchData() async {
    try {
      final cBookings = await _apiService.getClientBookings();
      final pRequests = await _apiService.getProviderRequests();

      if (mounted) {
        setState(() {
          // 1. Sort Client Bookings: Closest Upcoming Date first
          cBookings.sort((a, b) {
            final dateA = DateTime.parse(a['scheduled_time']);
            final dateB = DateTime.parse(b['scheduled_time']);
            return dateB.compareTo(dateA); // Newest/Future first
          });

          // 2. Sort Provider Requests: 'Pending' requests go to the top
          pRequests.sort((a, b) {
            if (a['status'] == 'pending' && b['status'] != 'pending') return -1;
            if (a['status'] != 'pending' && b['status'] == 'pending') return 1;
            // Then sort by date
            return DateTime.parse(
              b['scheduled_time'],
            ).compareTo(DateTime.parse(a['scheduled_time']));
          });

          clientBookings = cBookings;
          providerRequests = pRequests;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching bookings: $e");
    }
  }

  // --- PROVIDER ACTION: Accept or Reject ---
  Future<void> _handleProviderAction(String id, String status) async {
    try {
      // Show loading indicator temporarily
      setState(() => isLoading = true);

      // Call Backend
      await _apiService.updateBookingStatus(id, status);

      // Refresh Data to update UI
      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'confirmed'
                  ? "Booking Accepted! Client notified."
                  : "Booking Rejected. Funds refunded.",
            ),
            backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Bookings",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "My Bookings"),
            Tab(text: "Client Requests"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: const LifeKitLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClientView(), // TAB 1
                _buildProviderView(), // TAB 2
              ],
            ),
    );
  }

  // =========================================================
  // 1. CLIENT VIEW (My Bookings)
  // =========================================================
  Widget _buildClientView() {
    // PULL TO REFRESH WRAPPER
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: clientBookings.isEmpty
          ? _buildEmptyState("No service booked yet.")
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics:
                  const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even if list is short
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO CARD (Top Most Booking)
                  _buildHeroBookingCard(clientBookings.first, isClient: true),

                  const SizedBox(height: 24),

                  // 2. FILTER BAR (Visual)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("Ongoing", true),
                        _buildFilterChip("Completed", false),
                        _buildFilterChip("Upcoming", false),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. REMAINING LIST
                  if (clientBookings.length > 1)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: clientBookings.length - 1,
                      itemBuilder: (context, index) {
                        // Start from index 1 since 0 is the Hero Card
                        final booking = clientBookings[index + 1];
                        return _buildStandardBookingCard(
                          booking,
                          isClient: true,
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  // =========================================================
  // 2. PROVIDER VIEW (Requests)
  // =========================================================
  Widget _buildProviderView() {
    // PULL TO REFRESH WRAPPER
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: providerRequests.isEmpty
          ? _buildEmptyState("No booking requests received yet.")
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: providerRequests.length,
              itemBuilder: (context, index) {
                return _buildStandardBookingCard(
                  providerRequests[index],
                  isClient: false, // Important flag for logic
                );
              },
            ),
    );
  }

  // =========================================================
  // SHARED WIDGETS & CARDS
  // =========================================================

  // Empty State that supports Pull-To-Refresh
  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                "Pull down to refresh",
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // THE BIG CARD AT THE TOP (Figma Style)
  Widget _buildHeroBookingCard(dynamic booking, {required bool isClient}) {
    final dateObj = DateTime.parse(booking['scheduled_time']);
    final dateStr = DateFormat('dd MMM').format(dateObj); // 13 May
    final price = booking['total_price'];
    final serviceName = booking['services']['title'];
    final status = booking['status'];

    // Who is the other person?
    final otherName = isClient
        ? (booking['profiles']?['full_name'] ?? "Provider")
        : (booking['profiles']?['full_name'] ?? "Client");

    final otherPic = booking['profiles']?['profile_picture_url'];

    String statusText = "Upcoming Due";
    Color statusColor = Colors.black87;
    if (status == 'pending') {
      statusText = "Waiting Approval";
      statusColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: otherPic != null
                        ? CachedNetworkImageProvider(otherPic)
                        : const AssetImage('assets/images/onboarding1.png')
                              as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        otherName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8), // Light Red background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "\$$price",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Service Type: $serviceName",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // BUTTON: View Receipt (Escrow Logic)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingReceiptScreen(
                      booking: booking,
                      isClient: isClient,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "View Receipt",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STANDARD LIST CARD
  Widget _buildStandardBookingCard(dynamic booking, {required bool isClient}) {
    final serviceName = booking['services']['title'];
    final price = booking['total_price'];
    final dateObj = DateTime.parse(booking['scheduled_time']);
    final dateStr = DateFormat('MMM dd, hh:mm a').format(dateObj);
    final status = booking['status'];

    final otherName = isClient
        ? (booking['profiles']?['full_name'] ?? "Provider")
        : (booking['profiles']?['full_name'] ?? "Client");

    final otherPic = booking['profiles']?['profile_picture_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: otherPic != null
                    ? CachedNetworkImage(
                        imageUrl: otherPic,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/onboarding1.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$otherName",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$$price",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  if (isClient || status != 'pending')
                    _buildStatusBadge(status),
                ],
              ),
            ],
          ),

          // PROVIDER ACTIONS (Only for Provider View + Pending Status)
          if (!isClient && status == 'pending') ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _handleProviderAction(booking['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      "Reject",
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleProviderAction(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      "Accept",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? null
            : Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }
}
