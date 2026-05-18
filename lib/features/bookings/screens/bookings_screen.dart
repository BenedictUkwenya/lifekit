import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_cache.dart';
import '../../../core/widgets/lifekit_loader.dart';

// IMPORT THE TRACKING & CHAT SCREENS
import 'booking_tracking_screen.dart';
import '../../home/screens/chat_detail_screen.dart';
import '../../services/screens/skill_swap_screens.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<dynamic> clientBookings = [];
  List<dynamic> providerRequests = [];
  List<dynamic> swapBookings = [];
  List<dynamic> pendingSwaps = [];
  int _incomingPendingCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadFromCache();
    _fetchData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Paint from cache immediately so the screen never feels blank on return
  void _loadFromCache() {
    final cb = AppCache.instance.get<List<dynamic>>('client_bookings');
    final pr = AppCache.instance.get<List<dynamic>>('provider_requests');
    if ((cb != null || pr != null) && mounted) {
      setState(() {
        if (cb != null) clientBookings = List<dynamic>.from(cb);
        if (pr != null) providerRequests = List<dynamic>.from(pr);
        isLoading = false;
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _apiService.getClientBookings(),
        _apiService.getProviderRequests(),
        _apiService.getIncomingSwaps(),
        _apiService.getOutgoingSwaps(),
      ]);
      final cBookings = results[0];
      final pRequests = results[1];
      final incomingSwaps = results[2];
      final outgoingSwaps = results[3];

      if (mounted) {
        setState(() {
          bool _isSwap(b) =>
              (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0) == 0;

          // Swap bookings = $0 bookings from BOTH sides
          // - As client (acceptor): from getClientBookings
          // - As provider (proposer): from getProviderRequests
          final clientSwaps = (cBookings as List)
              .where(_isSwap)
              .map((b) => {...b, '_swap_role': 'client'})
              .toList();
          final providerSwaps = (pRequests as List)
              .where(_isSwap)
              .map((b) => {...b, '_swap_role': 'provider'})
              .toList();

          // Merge, deduplicate by id
          final seenIds = <String>{};
          swapBookings =
              [
                  ...clientSwaps,
                  ...providerSwaps,
                ].where((b) => seenIds.add(b['id'].toString())).toList()
                ..sort((a, b) {
                  final ta =
                      DateTime.tryParse(a['scheduled_time'] ?? '') ??
                      DateTime(2000);
                  final tb =
                      DateTime.tryParse(b['scheduled_time'] ?? '') ??
                      DateTime(2000);
                  return tb.compareTo(ta);
                });

          // Pending swap proposals (not yet accepted)
          final incomingPending = incomingSwaps
              .where((s) => s['status'] == 'pending')
              .toList();
          pendingSwaps = [
            ...incomingPending,
            ...outgoingSwaps.where((s) => s['status'] == 'pending'),
          ];
          _incomingPendingCount = incomingPending.length;
          // Remove swaps from regular client/provider views
          cBookings.removeWhere(_isSwap);
          pRequests.removeWhere(_isSwap);
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
          tabs: [
            const Tab(text: "My Bookings"),
            const Tab(text: "Client Requests"),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("My Swaps"),
                  if (pendingSwaps.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8A020),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pendingSwaps.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClientView(),
                _buildProviderView(),
                _buildSwapsView(),
              ],
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

  // ── Profile Avatar ─────────────────────────────────────────────────────────
  // Shows the network image when available; falls back to a coloured circle
  // with the user's first initial — never shows a generic asset image.
  Widget _buildAvatar(String? picUrl, String name, {double radius = 22}) {
    final hasImage = picUrl != null && picUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: hasImage ? CachedNetworkImageProvider(picUrl) : null,
      child: hasImage
          ? null
          : Text(
              initial,
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.75,
              ),
            ),
    );
  }

  // ── Rounded-square avatar (standard card) ──────────────────────────────────
  // Matches the original 50×50 ClipRRect shape used in _buildStandardBookingCard.
  Widget _buildRoundedAvatar(String? picUrl, String name) {
    final hasImage = picUrl != null && picUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 50,
        color: AppColors.primary.withOpacity(0.10),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: picUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
      ),
    );
  }

  // ── Integrated Chat Button ──────────────────────────────────────────────────
  Widget _buildChatBtn(dynamic booking, bool isClient) {
    return GestureDetector(
      onTap: () => _goToChat(booking, isClient),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.primary,
          size: 17,
        ),
      ),
    );
  }

  // ── Relative-time label for upcoming confirmed bookings ─────────────────
  Map<String, dynamic>? _getRelativeTimeLabel(DateTime scheduledTime) {
    final now = DateTime.now();
    final diff = scheduledTime.difference(now);

    // Don't show badge for past bookings beyond a short grace window.
    if (diff.inMinutes < -30) return null;

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final scheduledMidnight = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );
    final dayDiff = scheduledMidnight.difference(todayMidnight).inDays;

    if (diff.inMinutes <= 120) {
      // < 2 h away (or just started) → Happening Now
      return {'text': '🔴 Happening Now!', 'color': Colors.red, 'pulse': true};
    } else if (dayDiff == 0) {
      // Same calendar day, more than 2 h away
      final timeStr = DateFormat('h:mm a').format(scheduledTime);
      return {
        'text': 'Today at $timeStr',
        'color': AppColors.primary,
        'pulse': false,
      };
    } else if (dayDiff == 1) {
      return {
        'text': '⏰ Tomorrow',
        'color': Colors.orange[700],
        'pulse': false,
      };
    } else if (dayDiff == 2) {
      return {
        'text': '📅 In 2 Days',
        'color': Colors.blue[700],
        'pulse': false,
      };
    }
    return null;
  }

  // ── Time badge pill widget ───────────────────────────────────────────────
  Widget _buildTimeBadge(DateTime scheduledTime) {
    final label = _getRelativeTimeLabel(scheduledTime);
    if (label == null) return const SizedBox.shrink();

    final bool pulse = label['pulse'] == true;
    final Color color = label['color'] as Color;
    final String text = label['text'] as String;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );

    if (pulse) {
      return ScaleTransition(scale: _pulseAnimation, child: pill);
    }
    return pill;
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
                      _buildAvatar(otherPic, otherName, radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              otherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    _buildChatBtn(booking, isClient),
                    const SizedBox(width: 8),
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
            // ── Countdown badge (confirmed bookings only) ──
            if (status == 'confirmed') ...[
              const SizedBox(height: 10),
              _buildTimeBadge(dateObj),
            ],
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
    final isOverdue = _isOverdueBooking(booking);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar with initials fallback ──
                _buildRoundedAvatar(otherPic, otherName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right column: price/swap + chat + status ──
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
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                    const SizedBox(height: 6),
                    _buildChatBtn(booking, isClient),
                    if (isClient || status != 'pending') ...[
                      const SizedBox(height: 6),
                      _buildStatusBadge(status, isOverdue: isOverdue),
                    ],
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
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

            // ── Countdown badge (confirmed bookings only) ──
            if (status == 'confirmed') ...[
              const SizedBox(height: 8),
              Row(children: [_buildTimeBadge(dateObj)]),
            ],

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

  Widget _buildStatusBadge(String status, {bool isOverdue = false}) {
    final badgeText = isOverdue ? 'OVERDUE' : status.toUpperCase();
    final badgeColor = isOverdue ? Colors.red : _getStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badgeText,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  bool _isOverdueBooking(dynamic booking) {
    if (booking['is_overdue'] == true) return true;
    final status = (booking['status'] ?? '').toString().toLowerCase();
    if (status != 'confirmed') return false;
    final rawTime = booking['scheduled_time'];
    if (rawTime == null) return false;
    final scheduledTime = DateTime.tryParse(rawTime.toString());
    if (scheduledTime == null) return false;
    return scheduledTime.isBefore(DateTime.now());
  }

  // ── My Swaps Tab ───────────────────────────────────────────────────────────
  Widget _buildSwapsView() {
    final hasData = swapBookings.isNotEmpty || pendingSwaps.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFE8A020),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Pending proposals banner
          if (pendingSwaps.isNotEmpty)
            SliverToBoxAdapter(child: _buildPendingBanner()),
          // Confirmed/Active swap bookings
          if (swapBookings.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Active & Past Swaps',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildSwapBookingCard(swapBookings[i]),
                  childCount: swapBookings.length,
                ),
              ),
            ),
          ],
          if (!hasData) SliverFillRemaining(child: _buildSwapsEmptyState()),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8A020).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SwapBoardScreen(
                initialTab: _incomingPendingCount > 0 ? 1 : 2,
              ),
            ),
          ).then((_) => _fetchData()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFFE8A020),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pendingSwaps.length} Pending Swap ${pendingSwaps.length == 1 ? "Proposal" : "Proposals"}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _incomingPendingCount > 0
                            ? 'Tap to view and respond'
                            : 'Tap to view your sent proposals',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFE8A020),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapBookingCard(dynamic booking) {
    final dateObj =
        DateTime.tryParse(booking['scheduled_time'] ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM, h:mm a').format(dateObj);
    final serviceName = booking['services']?['title'] ?? 'Service';
    final status = booking['status'] as String? ?? 'pending';
    // _swap_role = 'client' if I accepted (I'm client_id), 'provider' if I proposed (I'm provider_id)
    final isClient = (booking['_swap_role'] ?? 'client') == 'client';
    // Partner profile is stored differently depending on role
    final partner = booking['profiles'];
    final partnerName = partner?['full_name'] ?? 'Partner';
    final partnerPic = partner?['profile_picture_url'];

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF22C55E);
        statusLabel = 'Swap Active';
        break;
      case 'completed':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = const Color(0xFFE8A020);
        statusLabel = 'Awaiting';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _goToTracking(booking, isClient),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        _buildAvatar(partnerPic, partnerName, radius: 26),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8A020),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'with $partnerName',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Colors.black38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8A020), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SWAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Message + Mark Done buttons for active swaps
                if (status == 'confirmed' || status == 'completed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _goToChat(booking, isClient),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                          ),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (status == 'confirmed') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _goToTracking(booking, isClient),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: const Text('Mark Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8A020),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE8A020).withOpacity(0.15),
                    const Color(0xFFE8A020).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 40,
                color: Color(0xFFE8A020),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Swaps Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Exchange skills with others.\nBrowse the Swap Board to find your first match.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black45,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SwapBoardScreen()),
              ).then((_) => _fetchData()),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(
                'Browse Swap Board',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8A020),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
            ),
          ],
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
