import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// IMPORT THE TRACKING & CHAT SCREENS
import 'booking_tracking_screen.dart';
import '../../home/screens/chat_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> clientBookings = [];
  List<dynamic> providerRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final cBookings = await _apiService.getClientBookings();
      final pRequests = await _apiService.getProviderRequests();

      if (mounted) {
        setState(() {
          cBookings.sort((a, b) {
            final dateA = DateTime.parse(a['scheduled_time']);
            final dateB = DateTime.parse(b['scheduled_time']);
            return dateB.compareTo(dateA);
          });

          pRequests.sort((a, b) {
            if (a['status'] == 'pending' && b['status'] != 'pending') return -1;
            if (a['status'] != 'pending' && b['status'] == 'pending') return 1;
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

  void _goToTracking(dynamic booking, bool isClient) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookingTrackingScreen(booking: booking, isClient: isClient),
      ),
    );
    _fetchData();
  }

  void _goToChat(dynamic booking, bool isClient) {
    final otherUser = booking['profiles'];
    final otherId = isClient ? booking['provider_id'] : booking['client_id'];

    if (otherUser != null) {
      final chatUserObj = {
        'id': otherId,
        'full_name': otherUser['full_name'],
        'profile_picture_url': otherUser['profile_picture_url'],
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatDetailScreen(otherUser: chatUserObj, bookings: [booking]),
        ),
      );
    }
  }

  Future<void> _handleProviderAction(String id, String status) async {
    try {
      setState(() => isLoading = true);
      await _apiService.updateBookingStatus(id, status);
      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'confirmed'
                  ? "Request Accepted! Client notified."
                  : "Request Rejected.",
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
          ? const Center(child: LifeKitLoader())
          : TabBarView(
              controller: _tabController,
              children: [_buildClientView(), _buildProviderView()],
            ),
    );
  }

  Widget _buildClientView() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: clientBookings.isEmpty
          ? _buildEmptyState("No service booked yet.")
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBookingCard(clientBookings.first, isClient: true),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("Ongoing", true),
                        _buildFilterChip("Completed", false),
                        _buildFilterChip("Upcoming", false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (clientBookings.length > 1)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: clientBookings.length - 1,
                      itemBuilder: (context, index) {
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

  Widget _buildProviderView() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: providerRequests.isEmpty
          ? _buildEmptyState("No requests received yet.")
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: providerRequests.length,
              itemBuilder: (context, index) {
                return _buildStandardBookingCard(
                  providerRequests[index],
                  isClient: false,
                );
              },
            ),
    );
  }

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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBookingCard(dynamic booking, {required bool isClient}) {
    final dateObj = DateTime.parse(booking['scheduled_time']);
    final dateStr = DateFormat('dd MMM').format(dateObj);
    final num price = booking['total_price'] ?? 0;
    final serviceName = booking['services']['title'];
    final status = booking['status'];

    final String locationInfo = booking['location_details'] ?? "";
    final bool isPrivateLocation =
        locationInfo.isEmpty ||
        locationInfo.toLowerCase() == "user home address";

    final bool isSwap = (price == 0);

    final otherName = isClient
        ? (booking['profiles']?['full_name'] ?? "Provider")
        : (booking['profiles']?['full_name'] ?? "Client");

    final otherPic = booking['profiles']?['profile_picture_url'];

    String statusText = "Upcoming Due";
    Color statusColor = Colors.black87;
    if (status == 'pending') {
      statusText = "Waiting Approval";
      statusColor = Colors.orange;
    } else if (status == 'completed') {
      statusText = "Completed";
      statusColor = Colors.green;
    } else if (status == 'cancelled') {
      statusText = "Cancelled";
      statusColor = Colors.red;
    }

    return GestureDetector(
      onTap: () => _goToTracking(booking, isClient),
      child: Container(
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
                Expanded(
                  child: Row(
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
                      Expanded(
                        child: Column(
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
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.blue,
                        size: 22,
                      ),
                      onPressed: () => _goToChat(booking, isClient),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 8),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dateStr,
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Hero center content ──
            isSwap
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FF7), Color(0xFFE040FB)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Skill Swap",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    "\$${price.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),

            const SizedBox(height: 8),
            Text(
              "Service: $serviceName",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            if (isPrivateLocation)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Message provider for details",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.orange[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else if (locationInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locationInfo,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _goToTracking(booking, isClient),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Track Status",
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
      ),
    );
  }

  Widget _buildStandardBookingCard(dynamic booking, {required bool isClient}) {
    final serviceName = booking['services']['title'];
    final num price = booking['total_price'] ?? 0;
    final dateObj = DateTime.parse(booking['scheduled_time']);
    final dateStr = DateFormat('MMM dd, hh:mm a').format(dateObj);
    final status = booking['status'];

    final String type = booking['service_type'] ?? "Default";
    final String? note = booking['comments'];

    final String locationInfo = booking['location_details'] ?? "";
    final bool isPrivateLocation =
        locationInfo.isEmpty ||
        locationInfo.toLowerCase() == "user home address";

    final bool isSwap = (price == 0);

    final otherName = isClient
        ? (booking['profiles']?['full_name'] ?? "Provider")
        : (booking['profiles']?['full_name'] ?? "Client");

    final otherPic = booking['profiles']?['profile_picture_url'];

    return GestureDetector(
      onTap: () => _goToTracking(booking, isClient),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        otherName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Price or Skill Swap badge ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    isSwap
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7B2FF7), Color(0xFFE040FB)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Skill Swap",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            "\$${price.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _goToChat(booking, isClient),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    if (isClient || status != 'pending')
                      _buildStatusBadge(status),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // ── Time & service type ──
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── Client note ──
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Client Note:",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Location ──
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    isPrivateLocation
                        ? Icons.lock_outline
                        : Icons.location_on_outlined,
                    size: 14,
                    color: isPrivateLocation ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isPrivateLocation
                          ? "Message provider for details"
                          : (isSwap ? "Swap: $locationInfo" : locationInfo),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isPrivateLocation
                            ? Colors.orange[800]
                            : Colors.grey[700],
                        fontStyle: isPrivateLocation
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Provider accept/reject actions ──
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
