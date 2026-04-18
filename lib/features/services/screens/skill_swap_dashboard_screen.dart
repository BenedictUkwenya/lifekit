import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'skill_swap_screens.dart';
import 'service_booking_detail_screen.dart';
import '../../provider/screens/subscription_plans_screen.dart';

const _kGold = Color(0xFFE8A020);
const _kDark = Color(0xFF0A0A14);
const _kNavy = Color(0xFF1A1A2E);

class SkillSwapDashboardScreen extends StatefulWidget {
  const SkillSwapDashboardScreen({super.key});

  @override
  State<SkillSwapDashboardScreen> createState() =>
      _SkillSwapDashboardScreenState();
}

class _SkillSwapDashboardScreenState extends State<SkillSwapDashboardScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  List<dynamic> _incoming = [];
  List<dynamic> _outgoing = [];
  List<dynamic> _swappable = [];
  bool _isLoading = true;

  int get _pendingIncoming =>
      _incoming.where((s) => s['status'] == 'pending').length;
  int get _pendingOutgoing =>
      _outgoing.where((s) => s['status'] == 'pending').length;
  int get _activeSwaps =>
      _incoming.where((s) => s['status'] == 'confirmed').length +
      _outgoing.where((s) => s['status'] == 'confirmed').length;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 8.0,
      end: 22.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getIncomingSwaps(),
        _apiService.getOutgoingSwaps(),
        _apiService.getPopularServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _incoming = results[0];
        _outgoing = results[1];
        _swappable = results[2]
            .where((s) => s['is_skill_swap_available'] == true)
            .take(12)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSwapAction(String swapId, String action) async {
    try {
      if (action == 'accept') {
        await _apiService.acceptSwap(swapId);
      } else {
        await _apiService.declineSwap(swapId);
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept' ? '✅ Swap accepted!' : 'Proposal declined',
            ),
            backgroundColor: action == 'accept'
                ? const Color(0xFF22C55E)
                : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kGold,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeroAppBar(),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _kGold)),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildAiMatchCta(),
                      if (_pendingIncoming > 0) ...[
                        const SizedBox(height: 28),
                        _buildPendingSection(),
                      ],
                      const SizedBox(height: 24),
                      _buildBrowseBoardCard(),
                      if (_swappable.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildSwappableSection(),
                      ],
                      const SizedBox(height: 28),
                      _buildHowItWorks(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── HERO APP BAR ───────────────────────────────────────────────
  SliverAppBar _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _kDark,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kDark, _kNavy, Color(0xFF0D1B2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative dots
              _dot(30, 25, 5), _dot(340, 45, 8), _dot(60, 150, 4),
              _dot(300, 115, 6), _dot(175, 18, 4), _dot(260, 175, 5),
              _dot(110, 80, 3), _dot(200, 190, 7),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kGold.withOpacity(0.45),
                              blurRadius: _glowAnim.value,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_kGold, Color(0xFFD97706)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Skill Swap Hub',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trade skills. Build your world.',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(double left, double top, double size) => Positioned(
    left: left,
    top: top,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        shape: BoxShape.circle,
      ),
    ),
  );

  // ── STATS ROW ─────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          'Incoming',
          _pendingIncoming,
          Icons.call_received_rounded,
          _kGold,
          highlight: _pendingIncoming > 0,
        ),
        const SizedBox(width: 12),
        _statCard(
          'Outgoing',
          _pendingOutgoing,
          Icons.call_made_rounded,
          const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        _statCard(
          'Active',
          _activeSwaps,
          Icons.swap_horiz_rounded,
          const Color(0xFF22C55E),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    int count,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SwapBoardScreen()),
        ).then((_) => _load()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: highlight
                ? Border.all(color: color.withOpacity(0.45), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: highlight
                    ? color.withOpacity(0.14)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI MATCH CTA ───────────────────────────────────────────────
  Widget _buildAiMatchCta() {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const SkillSwapBottomSheet(),
      ).then((_) => _load()),
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, child) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kDark, _kNavy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kNavy.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kGold, Color(0xFFD97706)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kGold.withOpacity(0.5),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find My AI Match',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI ranks the best swap partners for your skills',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PENDING PROPOSALS ─────────────────────────────────────────
  Widget _buildPendingSection() {
    final pending = _incoming.where((s) => s['status'] == 'pending').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: _kGold,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  'Pending Proposals',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SwapBoardScreen()),
              ).then((_) => _load()),
              child: Text(
                'See All',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...pending.take(3).map((swap) => _buildPendingCard(swap)),
      ],
    );
  }

  Widget _buildPendingCard(dynamic swap) {
    final proposer = swap['proposer'] ?? {};
    final name = (proposer['full_name'] ?? 'Someone').toString();
    final pic = proposer['profile_picture_url']?.toString();
    final offerTitle = (swap['proposer_service']?['title'] ?? 'Their Service')
        .toString();
    final wantTitle =
        (swap['target_category_name'] ??
                swap['target_service']?['title'] ??
                'Your Service')
            .toString();
    final score = ((swap['ai_match_score'] ?? 0) as num).toInt();
    final swapId = swap['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[200],
                backgroundImage: (pic != null && pic.isNotEmpty)
                    ? NetworkImage(pic)
                    : null,
                child: (pic == null || pic.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip('Offers: $offerTitle', const Color(0xFF3B82F6)),
                        _chip('Wants: $wantTitle', _kGold),
                      ],
                    ),
                  ],
                ),
              ),
              if (score > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$score%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _scoreColor(score),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleSwapAction(swapId, 'decline'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Decline',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleSwapAction(swapId, 'accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: Text(
                    'Accept ✓',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return AppColors.primary;
    return _kGold;
  }

  // ── BROWSE BOARD CARD ─────────────────────────────────────────
  Widget _buildBrowseBoardCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SwapBoardScreen()),
      ).then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.9), AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse the Swap Board',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'See all open swap proposals & post your own',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── SWAPPABLE SERVICES ────────────────────────────────────────
  Widget _buildSwappableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔄 Swappable Services',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Services open to skill trading',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _swappable.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final s = _swappable[i];
              final title = (s['title'] ?? 'Service').toString();
              final rawImages = s['image_urls'];
              final img = (rawImages is List && rawImages.isNotEmpty)
                  ? rawImages[0]?.toString()
                  : null;
              final sId = s['id']?.toString();
              final pId = s['provider_id']?.toString();
              final providerName = (s['profiles']?['full_name'] ?? 'Provider')
                  .toString();
              final price = s['price'] ?? 0;

              return GestureDetector(
                onTap: () {
                  if (sId == null || pId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceBookingDetailScreen(
                        serviceId: sId,
                        providerId: pId,
                        providerName: providerName,
                        providerPic: s['profiles']?['profile_picture_url'],
                        serviceTitle: title,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 140,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: img != null
                                ? CachedNetworkImage(
                                    imageUrl: img,
                                    height: 90,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 90,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 6,
                            left: 7,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF22C55E,
                                    ).withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                '🔄 Swap',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(9, 8, 9, 4),
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
                        child: Text(
                          '\$$price',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ✨ AI Pitch button
                      GestureDetector(
                        onTap: () => _showAiPitchDialog(
                          targetServiceTitle: title,
                          targetUserName: providerName,
                        ),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kNavy, _kDark],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '✨ AI Pitch',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── AI PITCH DIALOG ───────────────────────────────────────────
  void _showAiPitchDialog({
    required String targetServiceTitle,
    required String targetUserName,
  }) {
    final myServiceCtrl = TextEditingController();
    String? generatedProposal;
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> generate() async {
            final myTitle = myServiceCtrl.text.trim();
            if (myTitle.isEmpty) return;
            setDialogState(() => isGenerating = true);
            try {
              final proposal = await _apiService.generateSwapProposal(
                myServiceTitle: myTitle,
                targetServiceTitle: targetServiceTitle,
                targetUserName: targetUserName,
              );
              setDialogState(() {
                generatedProposal = proposal;
                isGenerating = false;
              });
            } catch (e) {
              setDialogState(() => isGenerating = false);
              if (e is UpgradeRequiredException && mounted) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPlansScreen(),
                  ),
                );
                return;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to generate proposal.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            title: Row(
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'AI Pitch Generator',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip('To: $targetUserName', _kNavy),
                      _chip('Service: $targetServiceTitle', _kGold),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'What service are you offering?',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: myServiceCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Logo Design, Guitar Lessons\u2026',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  if (generatedProposal != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        generatedProposal!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.55,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (generatedProposal != null)
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(
                    'Copy',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: generatedProposal!));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '\ud83d\udccb Copied to clipboard!',
                        ),
                        backgroundColor: const Color(0xFF22C55E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
              ElevatedButton(
                onPressed: isGenerating ? null : generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        generatedProposal == null
                            ? 'Generate \u2728'
                            : 'Regenerate \u2728',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── HOW IT WORKS ──────────────────────────────────────────────
  Widget _buildHowItWorks() {
    final steps = [
      [
        '1',
        '🔍 Discover',
        'Browse services open to swapping or let AI find the perfect match for your skills.',
      ],
      [
        '2',
        '📋 Propose',
        'Send a swap proposal: offer your service, request theirs. Zero cash needed.',
      ],
      [
        '3',
        '🤝 Swap',
        'Both parties complete their services. Grow your skill network for free.',
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                'How Skill Swap Works',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: _kDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        step[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step[1],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          step[2],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
