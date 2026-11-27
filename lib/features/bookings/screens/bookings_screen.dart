import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifekit_frontend/core/widgets/celebrate.dart';
import 'package:lifekit_frontend/core/widgets/chunky.dart';
import 'package:lifekit_frontend/core/widgets/app_lottie.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../booking_progress.dart';
import '../widgets/booking_mini_progress.dart';
import '../../../core/utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_cache.dart';
import '../../../l10n/app_localizations.dart';

// IMPORT THE TRACKING & CHAT SCREENS
import 'booking_tracking_screen.dart';
import '../../home/screens/chat_detail_screen.dart';
import '../../services/screens/skill_swap_screens.dart';
import '../../../core/utils/dates.dart';

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
  // Swap requests as the swap card needs them (role tagged), and every booking
  // by id so a swap's two halves can open their own tracking screens.
  List<Map<String, dynamic>> _swaps = [];
  final Map<String, dynamic> _bookingById = {};
  int _incomingPendingCount = 0;
  int _pendingRequestCount = 0;
  bool _autoTabDone = false;
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
        bool isSwap(b) =>
            (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0) == 0;
        if (cb != null) clientBookings = cb.where((b) => !isSwap(b)).toList();
        if (pr != null) providerRequests = pr.where((b) => !isSwap(b)).toList();
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
      // Copies: these lists live in AppCache, and the swap split below
      // removes items. Editing the cached list made swaps vanish on the next visit.
      final cBookings = List<dynamic>.from(results[0]);
      final pRequests = List<dynamic>.from(results[1]);
      final incomingSwaps = results[2];
      final outgoingSwaps = results[3];
      _bookingById
        ..clear()
        ..addEntries(cBookings.map((b) => MapEntry('${b['id']}', {...b, '_swap_role': 'client'})))
        ..addEntries(pRequests.map((b) => MapEntry('${b['id']}', {...b, '_swap_role': 'provider'})));

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
          _swaps = [
            ...incomingSwaps.map((sw) => {...Map<String, dynamic>.from(sw as Map), '_incoming': true}),
            ...outgoingSwaps.map((sw) => {...Map<String, dynamic>.from(sw as Map), '_incoming': false}),
          ]..sort((a, b) => '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
          // Remove swaps from regular client/provider views
          cBookings.removeWhere(_isSwap);
          pRequests.removeWhere(_isSwap);
          cBookings.sort((a, b) {
            final dateA = parseApiDate(a['scheduled_time']);
            final dateB = parseApiDate(b['scheduled_time']);
            return dateB.compareTo(dateA);
          });

          pRequests.sort((a, b) {
            if (a['status'] == 'pending' && b['status'] != 'pending') return -1;
            if (a['status'] != 'pending' && b['status'] == 'pending') return 1;
            return parseApiDate(
              b['scheduled_time'],
            ).compareTo(parseApiDate(a['scheduled_time']));
          });

          clientBookings = cBookings;
          providerRequests = pRequests;
          _pendingRequestCount =
              pRequests.where((b) => b['status'] == 'pending').length;
          isLoading = false;
        });
        // Open straight on the tab that needs the user, the first time only.
        if (!_autoTabDone && _tabController.index == 0) {
          _autoTabDone = true;
          if (_pendingRequestCount > 0) {
            _tabController.animateTo(1);
          } else if (_incomingPendingCount > 0) {
            _tabController.animateTo(2);
          }
        }
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
        final l10n = AppLocalizations.of(context)!;
        if (status == 'confirmed') {
          Celebrate.show(context, title: l10n.bookingsRequestAccepted, anim: AppAnim.handshake);
        } else {
          AppToast.info(context, l10n.bookingsRequestRejected);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.bookingTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            height: 46,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECEE),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              splashBorderRadius: BorderRadius.circular(26),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12.5),
              tabs: [
                _pillTab(l10n.bookingsMyBookings, 0),
                _pillTab(l10n.bookingsClientRequests, _pendingRequestCount),
                _pillTab(l10n.bookingsMySwaps, _incomingPendingCount),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const SkeletonList()
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
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: clientBookings.isEmpty
          ? _buildEmptyState(l10n.bookingsNoneYet)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBookingCard(_heroBooking(), isClient: true)
                      .fadeSlideIn(),
                  ..._clientSections(),
                ],
              ),
            ),
    );
  }

  /// Bookings below the hero, grouped so finished ones don't crowd live ones.
  List<Widget> _clientSections() {
    final l10n = AppLocalizations.of(context)!;
    final hero = _heroBooking();
    final groups = <int, List<dynamic>>{0: [], 1: [], 2: []};
    for (final b in clientBookings) {
      if (identical(b, hero)) continue;
      final phase = computeBookingProgress(b as Map, isClient: true).phase;
      final k = switch (phase) {
        BookingPhase.completed || BookingPhase.cancelled => 2,
        BookingPhase.upcoming => 1,
        _ => 0,
      };
      groups[k]!.add(b);
    }
    final titles = {0: l10n.bookingsSecAttention, 1: l10n.bookingsSecUpcoming, 2: l10n.bookingsSecPast};
    final icons = {0: Icons.priority_high_rounded, 1: Icons.event_available_outlined, 2: Icons.history_rounded};
    final colors = {0: const Color(0xFFE08A00), 1: AppColors.primary, 2: Colors.grey};
    final out = <Widget>[const SizedBox(height: 10)];
    var n = 0;
    for (final k in [0, 1, 2]) {
      final items = groups[k]!;
      if (items.isEmpty) continue;
      out.add(_sectionHeader(titles[k]!, icons[k]!, colors[k]!, items.length));
      for (final b in items) {
        final card = k == 2 ? _buildPastRow(b, isClient: true) : _buildStandardBookingCard(b, isClient: true);
        out.add(card.fadeSlideIn(index: n++));
      }
    }
    out.add(const SizedBox(height: 90));
    return out;
  }

  Widget _buildProviderView() {
    final l10n = AppLocalizations.of(context)!;
    if (providerRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        child: _buildEmptyState(l10n.bookingsNoRequestsYet),
      );
    }
    final groups = <int, List<dynamic>>{0: [], 1: [], 2: []};
    for (final b in providerRequests) {
      final st = '${b['status']}';
      groups[st == 'pending' ? 0 : (st == 'completed' || st == 'cancelled') ? 2 : 1]!.add(b);
    }
    final titles = {0: l10n.bookingsSecNew, 1: l10n.bookingsSecUpcoming, 2: l10n.bookingsSecPast};
    final icons = {0: Icons.notifications_active_outlined, 1: Icons.event_available_outlined, 2: Icons.history_rounded};
    final colors = {0: const Color(0xFFE08A00), 1: AppColors.primary, 2: Colors.grey};
    final children = <Widget>[];
    var n = 0;
    for (final k in [0, 1, 2]) {
      final items = groups[k]!;
      if (items.isEmpty) continue;
      children.add(_sectionHeader(titles[k]!, icons[k]!, colors[k]!, items.length, first: children.isEmpty));
      for (final b in items) {
        final card = k == 2 ? _buildPastRow(b, isClient: false) : _buildStandardBookingCard(b, isClient: false);
        children.add(card.cascadeIn(n++));
      }
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  /// The booking most worth showing big: the soonest one still in play,
  /// else the most recent.
  dynamic _heroBooking() {
    final live = clientBookings.where((b) {
      final st = '${b['status']}';
      return st != 'completed' && st != 'cancelled';
    }).toList()
      ..sort((a, b) => parseApiDate(a['scheduled_time']).compareTo(parseApiDate(b['scheduled_time'])));
    return live.isNotEmpty ? live.first : clientBookings.first;
  }

  Widget _pillTab(String label, int badge) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (badge > 0) ...[
            const SizedBox(width: 5),
            Container(
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, first ? 4 : 18, 2, 10),
      child: Row(children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color == Colors.grey ? Colors.grey[600] : Colors.black87)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        EmptyState(icon: Icons.event_available_rounded, title: message, anim: AppAnim.emptyBox),
      ],
    );
  }

  Widget _buildHeroBookingCard(dynamic booking, {required bool isClient}) {
    final l10n = AppLocalizations.of(context)!;
    final dateObj = parseApiDate(booking['scheduled_time']);
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
        ? (booking['profiles']?['full_name'] ?? l10n.bookingsProviderFallback)
        : (booking['profiles']?['full_name'] ?? l10n.bookingsClientFallback);

    final otherPic = booking['profiles']?['profile_picture_url'];

    String statusText = l10n.bookingsUpcomingDue;
    Color statusColor = Colors.black87;
    if (status == 'pending') {
      statusText = l10n.bookingsWaitingApproval;
      statusColor = Colors.orange;
    } else if (status == 'completed') {
      statusText = l10n.bookingStatusCompleted;
      statusColor = Colors.green;
    } else if (status == 'cancelled') {
      statusText = l10n.bookingStatusCancelled;
      statusColor = Colors.red;
    } else if (status == 'confirmed' && dateObj.isBefore(DateTime.now())) {
      // Date has passed: it's waiting to be marked done, not "upcoming".
      statusText = l10n.bookingsHeroPastDue;
      statusColor = const Color(0xFFE08A00);
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
                          l10n.bookingsSkillSwap,
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
              '$serviceName',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
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
                      l10n.bookingsMessageForDetails,
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
                style: chunky(ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                )),
                child: Text(
                  l10n.bookingsTrackStatus,
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

  String _localiseServiceType(String type, AppLocalizations l10n) {
    switch (type) {
      case 'Home':
        return l10n.bookTypeHome;
      case 'Outdoor':
        return l10n.bookTypeOutdoor;
      case 'Default':
      default:
        return l10n.bookTypeDefault;
    }
  }

  Widget _buildStandardBookingCard(dynamic booking, {required bool isClient}) {
    final l10n = AppLocalizations.of(context)!;
    final serviceName = booking['services']['title'];
    final num price = booking['total_price'] ?? 0;
    final dateObj = parseApiDate(booking['scheduled_time']);
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
        ? (booking['profiles']?['full_name'] ?? l10n.bookingsProviderFallback)
        : (booking['profiles']?['full_name'] ?? l10n.bookingsClientFallback);

    final otherPic = booking['profiles']?['profile_picture_url'];

    return Pressable(
      pressedScale: 0.98,
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
                                  l10n.bookingsSkillSwap,
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
                    _localiseServiceType(type, l10n),
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
                            "${l10n.bookingsClientFallback}:",
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
                          ? l10n.bookingsMessageForDetails
                          : (isSwap
                                ? "${l10n.bookingsSkillSwap}: $locationInfo"
                                : locationInfo),
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
                      style: chunky(OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      )),
                      child: Text(
                        l10n.bookingsReject,
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
                      style: chunky(ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      )),
                      child: Text(
                        l10n.bookingsAccept,
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
            const SizedBox(height: 14),
            BookingMiniProgress(booking: booking as Map, isClient: isClient),
          ],
        ),
      ),
    );
  }

  /// Finished/cancelled booking as a slim row: who, what, when, outcome.
  Widget _buildPastRow(dynamic booking, {required bool isClient}) {
    final l10n = AppLocalizations.of(context)!;
    final name = '${booking['profiles']?['full_name'] ?? (isClient ? l10n.bookingsProviderFallback : l10n.bookingsClientFallback)}';
    final title = '${booking['services']?['title'] ?? l10n.bookingsServiceFallback}';
    final date = DateFormat('d MMM').format(parseApiDate(booking['scheduled_time']));
    final done = booking['status'] == 'completed';
    final color = done ? const Color(0xFF16A34A) : Colors.red.shade400;
    return Pressable(
      pressedScale: 0.98,
      onTap: () => _goToTracking(booking, isClient),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Opacity(opacity: 0.75, child: _buildAvatar(booking['profiles']?['profile_picture_url'], name, radius: 17)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
              Text('$name · $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(done ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 15, color: color),
          const SizedBox(width: 4),
          Text(done ? l10n.bookingStatusCompleted : l10n.bookingStatusCancelled,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isOverdue = false}) {
    final badgeText = isOverdue
        ? AppLocalizations.of(context)!.bookingsOverdue
        : status.toUpperCase();
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
    final l10n = AppLocalizations.of(context)!;
    // $0 bookings not linked to any swap request (older data) still show.
    final linked = <String>{
      for (final sw in _swaps) ...['${sw['booking_id']}', '${sw['reverse_booking_id']}'],
    };
    final orphans = swapBookings.where((b) => !linked.contains('${b['id']}')).toList();
    if (_swaps.isEmpty && orphans.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [SliverFillRemaining(child: _buildSwapsEmptyState())],
        ),
      );
    }
    final groups = <String, List<Map<String, dynamic>>>{'answer': [], 'waiting': [], 'active': [], 'past': []};
    for (final sw in _swaps) {
      groups[_swapGroup(sw)]!.add(sw);
    }
    final children = <Widget>[_swapBoardCta()];
    var n = 0;
    void section(String key, String title, IconData icon, Color color) {
      final items = groups[key]!;
      if (items.isEmpty) return;
      children.add(_sectionHeader(title, icon, color, items.length));
      for (final sw in items) {
        children.add(_buildSwapCard(sw, group: key).cascadeIn(n++));
      }
    }
    section('answer', l10n.swapSectionNeedsAnswer, Icons.mark_email_unread_outlined, const Color(0xFFE08A00));
    section('active', l10n.swapSectionActive, Icons.handshake_outlined, AppColors.primary);
    section('waiting', l10n.swapSectionAwaitingThem, Icons.hourglass_top_rounded, const Color(0xFF6B7280));
    section('past', l10n.swapSectionPast, Icons.history_rounded, Colors.grey);
    if (orphans.isNotEmpty) {
      children.add(_sectionHeader(l10n.bookingsSkillSwap, Icons.swap_horiz_rounded, Colors.grey, orphans.length));
      for (final b in orphans) {
        children.add(_buildSwapBookingCard(b));
      }
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  /// Where a swap belongs: needs my answer / waiting on them / active / past.
  String _swapGroup(Map<String, dynamic> sw) {
    final st = '${sw['status']}';
    if (st == 'pending') return sw['_incoming'] == true ? 'answer' : 'waiting';
    if (st != 'accepted') return 'past';
    final a = '${sw['booking']?['status'] ?? ''}';
    final b = '${sw['reverse_booking']?['status'] ?? ''}';
    final done = (a == 'completed' || a == 'cancelled') && (b.isEmpty || b == 'completed' || b == 'cancelled');
    return done ? 'past' : 'active';
  }

  void _openSwapBoard(int tab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SwapBoardScreen(initialTab: tab)),
    ).then((_) => _fetchData());
  }

  Widget _swapBoardCta() {
    final l10n = AppLocalizations.of(context)!;
    return Pressable(
      onTap: () => _openSwapBoard(0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7A1F3D), Color(0xFFB0306A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.bookingsBrowseSwapBoard,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(l10n.bookingsSwapCtaSub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }

  /// One card per swap: partner, status, and the two halves side by side.
  Widget _buildSwapCard(Map<String, dynamic> sw, {required String group}) {
    final l10n = AppLocalizations.of(context)!;
    final incoming = sw['_incoming'] == true;
    final partner = (incoming ? sw['proposer'] : sw['target_user']) as Map?;
    final partnerName = '${partner?['full_name'] ?? l10n.bookingsPartnerFallback}';
    final giveSvc = (incoming ? sw['target_service'] : sw['proposer_service']) as Map?;
    final getSvc = (incoming ? sw['proposer_service'] : sw['target_service']) as Map?;
    final giveTitle = '${giveSvc?['title'] ?? sw['target_category_name'] ?? l10n.bookingsServiceFallback}';
    final getTitle = '${getSvc?['title'] ?? sw['target_category_name'] ?? l10n.bookingsServiceFallback}';
    // proposer is provider on booking_id; acceptor is provider on reverse_booking_id
    final giveId = '${incoming ? sw['reverse_booking_id'] : sw['booking_id']}';
    final getId = '${incoming ? sw['booking_id'] : sw['reverse_booking_id']}';
    final giveStatus = '${(incoming ? sw['reverse_booking'] : sw['booking'])?['status'] ?? ''}';
    final getStatus = '${(incoming ? sw['booking'] : sw['reverse_booking'])?['status'] ?? ''}';
    final when = sw['scheduled_time'] != null ? parseApiDate(sw['scheduled_time']) : null;
    final past = group == 'past';

    final (Color pillColor, String pillText) = switch (group) {
      'answer' => (const Color(0xFFE08A00), l10n.bookingsSwapNeedsAnswer),
      'waiting' => (const Color(0xFF6B7280), l10n.bookingsAwaiting),
      'active' => (const Color(0xFF16A34A), l10n.bookingsSwapActive),
      _ => '${sw['status']}' == 'accepted'
          ? (const Color(0xFF3B82F6), l10n.bookingStatusCompleted)
          : (Colors.grey, '${sw['status']}' == 'declined' ? l10n.bookingsSwapDeclined : l10n.bookingStatusCancelled),
    };

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: group == 'answer' ? const Color(0xFFE08A00).withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.05),
          width: group == 'answer' ? 1.4 : 1,
        ),
        boxShadow: past
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _buildAvatar(partner?['profile_picture_url'], partnerName, radius: past ? 16 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(partnerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                [
                  incoming ? l10n.bookingsSwapProposedToYou : l10n.bookingsSwapProposedByYou,
                  if (when != null) DateFormat('d MMM, HH:mm').format(when),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black45),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: pillColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(pillText,
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: pillColor)),
          ),
        ]),
        if (!past) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8F5F6), borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _swapHalf(l10n.bookingsSwapYouGive, giveSvc, giveTitle,
                    status: group == 'active' ? giveStatus : null,
                    onTap: _bookingById.containsKey(giveId) ? () => _goToTracking(_bookingById[giveId], false) : null),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
                ),
              ),
              Expanded(
                child: _swapHalf(l10n.bookingsSwapYouGet, getSvc, getTitle,
                    status: group == 'active' ? getStatus : null,
                    alignEnd: true,
                    onTap: _bookingById.containsKey(getId) ? () => _goToTracking(_bookingById[getId], true) : null),
              ),
            ]),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text('$giveTitle  ⇄  $getTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          ),
        if (group == 'answer') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _openSwapBoard(1),
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(l10n.bookingsSwapReview, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: chunky(ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE08A00),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              )),
            ),
          ),
        ] else if (group == 'waiting') ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 14, color: Colors.black38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.bookingsSwapWaitingFor(partnerName),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
            ),
          ]),
        ] else if (group == 'active') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _bookingById.containsKey(getId)
                    ? () => _goToChat(_bookingById[getId], true)
                    : (_bookingById.containsKey(giveId) ? () => _goToChat(_bookingById[giveId], false) : null),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(l10n.bookingsMessage),
                style: chunky(OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _bookingById.containsKey(giveId)
                    ? () => _goToTracking(_bookingById[giveId], false)
                    : null,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(l10n.bookingsSwapMyPart),
                style: chunky(ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                )),
              ),
            ),
          ]),
        ],
      ]),
    );
    final tappable = Pressable(
      pressedScale: 0.98,
      onTap: () {
        if (group == 'answer') return _openSwapBoard(1);
        if (group == 'waiting') return _openSwapBoard(2);
        if (_bookingById.containsKey(giveId)) _goToTracking(_bookingById[giveId], false);
      },
      child: card,
    );
    return past ? Opacity(opacity: 0.65, child: tappable) : tappable;
  }

  Widget _swapHalf(String label, Map? svc, String title,
      {String? status, bool alignEnd = false, VoidCallback? onTap}) {
    final l10n = AppLocalizations.of(context)!;
    final imgs = (svc?['image_urls'] as List?) ?? const [];
    final done = status == 'completed';
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(crossAxisAlignment: cross, children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.black38)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imgs.isNotEmpty
              ? CachedNetworkImage(imageUrl: '${imgs.first}', width: 44, height: 44, fit: BoxFit.cover)
              : Container(
                  width: 44,
                  height: 44,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.handyman_outlined, size: 20, color: AppColors.primary),
                ),
        ),
        const SizedBox(height: 6),
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
        if (status != null && status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 12, color: done ? const Color(0xFF16A34A) : Colors.black38),
            const SizedBox(width: 3),
            Text(done ? l10n.bookingsSwapDone : l10n.bookingsSwapToDo,
                style: GoogleFonts.poppins(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: done ? const Color(0xFF16A34A) : Colors.black45)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildSwapBookingCard(dynamic booking) {
    final l10n = AppLocalizations.of(context)!;
    final dateObj =
        DateTime.tryParse(booking['scheduled_time'] ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM, h:mm a').format(dateObj);
    final serviceName =
        booking['services']?['title'] ?? l10n.bookingsServiceFallback;
    final status = booking['status'] as String? ?? 'pending';
    // _swap_role = 'client' if I accepted (I'm client_id), 'provider' if I proposed (I'm provider_id)
    final isClient = (booking['_swap_role'] ?? 'client') == 'client';
    // Partner profile is stored differently depending on role
    final partner = booking['profiles'];
    final partnerName = partner?['full_name'] ?? l10n.bookingsPartnerFallback;
    final partnerPic = partner?['profile_picture_url'];

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF22C55E);
        statusLabel = l10n.bookingsSwapActive;
        break;
      case 'completed':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = l10n.bookingStatusCompleted;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = l10n.bookingStatusCancelled;
        break;
      default:
        statusColor = const Color(0xFFE8A020);
        statusLabel = l10n.bookingsAwaiting;
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
                          child: Text(
                            l10n.bookingsSwapBadge,
                            style: const TextStyle(
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
                          label: Text(l10n.bookingsMessage),
                          style: chunky(OutlinedButton.styleFrom(
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
                          )),
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
                            label: Text(l10n.bookingsMarkDone),
                            style: chunky(ElevatedButton.styleFrom(
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
                            )),
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLottie(AppAnim.handshake, size: 160),
            const SizedBox(height: 16),
            Text(
              l10n.bookingsNoSwapsYet,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.swapEnableHint,
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
                l10n.bookingsBrowseSwapBoard,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: chunky(ElevatedButton.styleFrom(
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
              )),
            ),
          ],
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
