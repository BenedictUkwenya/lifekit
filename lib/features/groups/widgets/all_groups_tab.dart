import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../screens/group_detail_screen.dart';

// ─── Tier helpers ────────────────────────────────────────────────
const _tierOrder = {'business': 3, 'pro': 2, 'plus': 1, 'free': 0};

bool _isPremiumCreator(String? tier) {
  final t = (tier ?? 'free').toLowerCase();
  return t == 'pro' || t == 'business';
}

Color _tierBadgeColor(String? tier) {
  switch ((tier ?? 'free').toLowerCase()) {
    case 'business':
      return const Color(0xFF7C3AED); // purple
    case 'pro':
      return const Color(0xFFD97706); // gold
    case 'plus':
      return const Color(0xFF2563EB); // blue
    default:
      return Colors.grey;
  }
}

String _tierLabel(String? tier) {
  switch ((tier ?? 'free').toLowerCase()) {
    case 'business':
      return '👑 Business Hub';
    case 'pro':
      return '⭐ Pro Hub';
    case 'plus':
      return '💎 Plus Hub';
    default:
      return '';
  }
}

String _nextTierName(String? tier) {
  switch ((tier ?? 'free').toLowerCase()) {
    case 'free':
      return 'Plus';
    case 'plus':
      return 'Pro';
    default:
      return 'Business';
  }
}

// ─────────────────────────────────────────────────────────────────

class AllGroupsTab extends StatefulWidget {
  final List<dynamic> groups;
  final Future<void> Function() onRefresh;

  const AllGroupsTab({
    super.key,
    required this.groups,
    required this.onRefresh,
  });

  @override
  State<AllGroupsTab> createState() => _AllGroupsTabState();
}

class _AllGroupsTabState extends State<AllGroupsTab> {
  final ApiService _apiService = ApiService();
  final Set<String> _joiningGroups = {};
  final Map<String, List<dynamic>> _groupMembers = {};
  final Map<String, bool> _membershipStatus = {};

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  @override
  void didUpdateWidget(AllGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups.length != widget.groups.length) {
      _loadMemberData();
    }
  }

  Future<void> _loadMemberData() async {
    for (final g in widget.groups) {
      final id = g['id'] as String;
      _fetchGroupMembers(id);
      _fetchMembershipStatus(id);
    }
  }

  Future<void> _fetchGroupMembers(String groupId) async {
    try {
      final members = await _apiService.getGroupMembers(groupId);
      if (mounted) setState(() => _groupMembers[groupId] = members);
    } catch (_) {}
  }

  Future<void> _fetchMembershipStatus(String groupId) async {
    try {
      final detail = await _apiService.getGroupDetail(groupId);
      if (mounted) {
        setState(() => _membershipStatus[groupId] = detail['isMember'] ?? false);
      }
    } catch (_) {}
  }

  Future<void> _handleJoin(dynamic group) async {
    final id = group['id'] as String;
    setState(() => _joiningGroups.add(id));
    try {
      await _apiService.joinGroup(id);
      if (mounted) setState(() => _membershipStatus[id] = true);
      await widget.onRefresh();
      await _fetchGroupMembers(id);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('plan limit') || msg.contains('plan_limit_reached')) {
        _showPlanLimitSheet(group);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningGroups.remove(id));
    }
  }

  void _showPlanLimitSheet(dynamic group) {
    final String groupName = group['name'] ?? 'this hub';
    final String? imageUrl = group['image_url'];
    final int memberCount = group['members_count'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanLimitSheet(
        groupName: groupName,
        groupImageUrl: imageUrl,
        memberCount: memberCount,
      ),
    );
  }

  void _openGroup(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)),
    ).then((_) => _fetchMembershipStatus(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No communities yet.',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Create one to get started!',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final myGroups = widget.groups
        .where((g) => _membershipStatus[g['id']] == true)
        .toList();
    final discoverGroups = widget.groups
        .where((g) => _membershipStatus[g['id']] != true)
        .toList();

    // Sort discover by member count desc for trending logic
    discoverGroups.sort((a, b) =>
        (b['members_count'] ?? 0).compareTo(a['members_count'] ?? 0));
    final trendingGroup =
        discoverGroups.isNotEmpty ? discoverGroups.first : null;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // ── My Hubs ──────────────────────────────────────────
          if (myGroups.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'My Hubs',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${myGroups.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: myGroups.length,
                  itemBuilder: (context, i) =>
                      _MyHubChip(
                    group: myGroups[i],
                    onTap: () => _openGroup(myGroups[i]['id'] as String),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Divider(
                color: Colors.grey.shade100,
                thickness: 6,
                height: 28,
              ),
            ),
          ],

          // ── Trending Hub Spotlight (Invented Feature 1) ──────
          if (trendingGroup != null &&
              (trendingGroup['members_count'] ?? 0) > 1) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _TrendingSpotlightCard(
                  group: trendingGroup,
                  isJoining:
                      _joiningGroups.contains(trendingGroup['id']),
                  onJoin: () => _handleJoin(trendingGroup),
                  onTap: () =>
                      _openGroup(trendingGroup['id'] as String),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],

          // ── Discover header ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: Color(0xFFD97706),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Discover',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${discoverGroups.length} communities',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Discover list ─────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final g = discoverGroups[i];
                final id = g['id'] as String;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _VipGroupCard(
                    group: g,
                    isJoining: _joiningGroups.contains(id),
                    members: _groupMembers[id] ?? [],
                    onJoin: () => _handleJoin(g),
                    onTap: () => _openGroup(id),
                  ),
                );
              },
              childCount: discoverGroups.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MY HUB CHIP  (compact horizontal card)
// ─────────────────────────────────────────────
class _MyHubChip extends StatelessWidget {
  final dynamic group;
  final VoidCallback onTap;

  const _MyHubChip({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String name = group['name'] ?? 'Hub';
    final String? imageUrl = group['image_url'];
    final int memberCount = group['members_count'] ?? 0;
    final String tier = group['creator_tier'] ?? 'free';
    final bool isPremium = _isPremiumCreator(tier);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                    border: Border.all(
                      color: isPremium
                          ? _tierBadgeColor(tier)
                          : AppColors.primary.withOpacity(0.3),
                      width: isPremium ? 2.5 : 1.5,
                    ),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'H',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                // Live activity dot
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              '$memberCount members',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRENDING SPOTLIGHT CARD  (Invented Feature 1)
// ─────────────────────────────────────────────
class _TrendingSpotlightCard extends StatelessWidget {
  final dynamic group;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const _TrendingSpotlightCard({
    required this.group,
    required this.isJoining,
    required this.onJoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = group['name'] ?? 'Hub';
    final String desc = group['description'] ?? '';
    final String? imageUrl = group['image_url'];
    final int memberCount = group['members_count'] ?? 0;
    final String tier = group['creator_tier'] ?? 'free';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.78),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Background image overlay
              if (imageUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.25),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: imageUrl != null
                            ? CachedNetworkImageProvider(imageUrl)
                            : null,
                        child: imageUrl == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'H',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔥 badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🔥 Trending This Week',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (desc.isNotEmpty)
                            Text(
                              desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11.5,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people_outline,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              if (_isPremiumCreator(tier)) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _tierLabel(tier),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Join button
                    GestureDetector(
                      onTap: isJoining ? null : onJoin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: isJoining
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Text(
                                'Join',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
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
}

// ─────────────────────────────────────────────
// VIP GROUP CARD  (Discover list)
// ─────────────────────────────────────────────
class _VipGroupCard extends StatelessWidget {
  final dynamic group;
  final bool isJoining;
  final List<dynamic> members;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const _VipGroupCard({
    required this.group,
    required this.isJoining,
    required this.members,
    required this.onJoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = group['name'] ?? 'Hub';
    final String desc = group['description'] ?? '';
    final String? imageUrl = group['image_url'];
    final int memberCount = group['members_count'] ?? 0;
    final bool anyoneCanPost = group['anyone_can_post'] ?? true;
    final String tier = group['creator_tier'] ?? 'free';
    final bool isPremium = _isPremiumCreator(tier);
    final Color tierColor = _tierBadgeColor(tier);

    String memberLabel;
    if (memberCount >= 1000) {
      memberLabel = '${(memberCount / 1000).toStringAsFixed(1)}k';
    } else if (memberCount > 0) {
      memberLabel = '$memberCount';
    } else {
      memberLabel = 'New';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isPremium
              ? Border.all(color: tierColor.withOpacity(0.6), width: 1.8)
              : Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: isPremium
                  ? tierColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium top band
            if (isPremium)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tier.toLowerCase() == 'business'
                          ? Icons.workspace_premium_rounded
                          : Icons.verified_rounded,
                      color: tierColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tierLabel(tier),
                      style: GoogleFonts.poppins(
                        color: tierColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✓ Verified Hub',
                        style: GoogleFonts.poppins(
                          color: tierColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Group avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.08),
                          border: isPremium
                              ? Border.all(
                                  color: tierColor.withOpacity(0.4),
                                  width: 2,
                                )
                              : null,
                          image: imageUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl == null
                            ? Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'H',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 13, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  '$memberLabel members',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.public,
                                          color: AppColors.primary, size: 11),
                                      const SizedBox(width: 3),
                                      Text(
                                        anyoneCanPost ? 'Public' : 'Restricted',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Footer: member stacks + join
                  Row(
                    children: [
                      if (members.isNotEmpty)
                        _StackedMemberAvatars(members: members),
                      const Spacer(),
                      GestureDetector(
                        onTap: isJoining ? null : onJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: isJoining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Join Hub',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STACKED MEMBER AVATARS  (reused)
// ─────────────────────────────────────────────
class _StackedMemberAvatars extends StatelessWidget {
  final List<dynamic> members;

  const _StackedMemberAvatars({required this.members});

  static const List<Color> _fallbackColors = [
    Color(0xFF89273B),
    Color(0xFF5B7FA6),
    Color(0xFF6DAB8A),
  ];

  @override
  Widget build(BuildContext context) {
    final display = members.take(3).toList();
    const double size = 30;
    const double overlap = 10;
    final int count = display.length;
    if (count == 0) return const SizedBox.shrink();
    final double totalWidth = size + (size - overlap) * (count - 1).toDouble();

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: List.generate(count, (i) {
          final profile = i < display.length
              ? (display[i]['profiles'] ?? display[i])
              : null;
          final String? avatarUrl = profile?['profile_picture_url'];
          final String initials = profile?['full_name'] != null
              ? (profile['full_name'] as String)[0].toUpperCase()
              : '?';

          return Positioned(
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fallbackColors[i % _fallbackColors.length],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      )
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLAN LIMIT SHEET  (Invented Feature 2 — Hub Preview Lock)
// ─────────────────────────────────────────────
class _PlanLimitSheet extends StatelessWidget {
  final String groupName;
  final String? groupImageUrl;
  final int memberCount;

  const _PlanLimitSheet({
    required this.groupName,
    required this.groupImageUrl,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Lock icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.7),
                ],
              ),
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),

          Text(
            'Plan Limit Reached',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "You're trying to join \"$groupName\" but you've hit your hub limit. Upgrade to unlock more communities.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Blurred hub preview (Hub Preview Lock visual)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Preview card (blurred)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ImageFiltered(
                    imageFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.6),
                      BlendMode.srcOver,
                    ),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.15),
                            backgroundImage: groupImageUrl != null
                                ? CachedNetworkImageProvider(groupImageUrl!)
                                : null,
                            child: groupImageUrl == null
                                ? Text(
                                    groupName.isNotEmpty
                                        ? groupName[0].toUpperCase()
                                        : 'H',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(groupName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text('$memberCount members · Active now',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Upgrade to unlock this hub',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plan comparison
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _PlanPill(label: 'Free', detail: '1 hub', isCurrent: true),
                const SizedBox(width: 8),
                _PlanPill(label: 'Plus', detail: '3 hubs', color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _PlanPill(label: 'Pro', detail: '5 hubs', color: const Color(0xFFD97706)),
                const SizedBox(width: 8),
                _PlanPill(
                    label: 'Business',
                    detail: '∞ hubs',
                    color: const Color(0xFF7C3AED)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upgrade CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: navigate to subscription/upgrade screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade Now — Unlock More Hubs',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  final String label;
  final String detail;
  final Color? color;
  final bool isCurrent;

  const _PlanPill({
    required this.label,
    required this.detail,
    this.color,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.grey;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.grey.shade100
              : effectiveColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: Colors.grey.shade300)
              : Border.all(color: effectiveColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.grey : effectiveColor,
              ),
            ),
            Text(
              detail,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isCurrent ? Colors.grey[500] : effectiveColor,
              ),
            ),
            if (isCurrent)
              Text(
                'Current',
                style: GoogleFonts.poppins(
                    fontSize: 8.5, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }
}
