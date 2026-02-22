import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../screens/group_detail_screen.dart';

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

  // Track liked groups locally
  final Set<String> _likedGroups = {};
  // Track which groups are currently joining (loading state)
  final Set<String> _joiningGroups = {};
  // Cache of group members: groupId -> list of member profiles
  final Map<String, List<dynamic>> _groupMembers = {};
  // Cache of membership status: groupId -> bool
  final Map<String, bool> _membershipStatus = {};

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  @override
  void didUpdateWidget(AllGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when group list changes (e.g. after refresh)
    if (oldWidget.groups.length != widget.groups.length) {
      _loadMemberData();
    }
  }

  /// Fetch members + membership status for every group in parallel
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
        setState(
          () => _membershipStatus[groupId] = detail['isMember'] ?? false,
        );
      }
    } catch (_) {}
  }

  Future<void> _handleJoin(String groupId) async {
    setState(() => _joiningGroups.add(groupId));
    try {
      await _apiService.joinGroup(groupId);
      // Immediately mark as member locally so UI updates without waiting for refresh
      if (mounted) setState(() => _membershipStatus[groupId] = true);
      await widget.onRefresh();
      await _fetchGroupMembers(groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningGroups.remove(groupId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: Colors.grey[300]),
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

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: widget.groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final g = widget.groups[index];
          final id = g['id'] as String;
          final isMember = _membershipStatus[id] ?? false;
          final members = _groupMembers[id] ?? [];

          return _GroupCard(
            group: g,
            isLiked: _likedGroups.contains(id),
            isJoining: _joiningGroups.contains(id),
            isMember: isMember,
            members: members,
            onLikeTap: () => setState(() {
              _likedGroups.contains(id)
                  ? _likedGroups.remove(id)
                  : _likedGroups.add(id);
            }),
            onJoinTap: () => _handleJoin(id),
            onCardTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(groupId: id),
                  ),
                ).then((_) {
                  // Refresh membership after returning from detail
                  _fetchMembershipStatus(id);
                }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GROUP CARD
// ─────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final dynamic group;
  final bool isLiked;
  final bool isJoining;
  final bool isMember;
  final List<dynamic> members;
  final VoidCallback onLikeTap;
  final VoidCallback onJoinTap;
  final VoidCallback onCardTap;

  const _GroupCard({
    required this.group,
    required this.isLiked,
    required this.isJoining,
    required this.isMember,
    required this.members,
    required this.onLikeTap,
    required this.onJoinTap,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = group['name'] ?? 'Group';
    final String desc = group['description'] ?? '';
    final String? imageUrl = group['image_url'];
    final int memberCount = group['members_count'] ?? 0;
    final bool anyoneCanPost = group['anyone_can_post'] ?? true;

    String memberLabel;
    if (memberCount >= 1000) {
      memberLabel = '+${(memberCount / 1000).toStringAsFixed(0)}k';
    } else if (memberCount > 0) {
      memberLabel = '+$memberCount';
    } else {
      memberLabel = 'New';
    }

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + stacked real member avatars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Group avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
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
                            name.isNotEmpty ? name[0].toUpperCase() : 'G',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),

                // Real member avatars stacked
                _StackedMemberAvatars(
                  members: members,
                  totalCount: memberLabel,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              desc.isNotEmpty ? desc : 'A community of like-minded people...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // Bottom row: heart + Public pill + Join/View button
            Row(
              children: [
                // Heart
                GestureDetector(
                  onTap: onLikeTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isLiked
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      color: isLiked
                          ? AppColors.primary.withOpacity(0.08)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.primary : Colors.grey,
                      size: 18,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Public/Restricted pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.public, color: AppColors.primary, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        anyoneCanPost ? 'Public' : 'Restricted',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── JOIN or VIEW button based on membership ──
                GestureDetector(
                  onTap: isMember ? onCardTap : (isJoining ? null : onJoinTap),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMember ? Colors.grey[100] : AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      border: isMember
                          ? Border.all(color: Colors.grey.shade300)
                          : null,
                    ),
                    child: isJoining
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isMember
                                  ? AppColors.primary
                                  : Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMember
                                    ? Icons.visibility_outlined
                                    : Icons.group_add_outlined,
                                color: isMember
                                    ? AppColors.primary
                                    : Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMember ? 'View group' : 'Join group',
                                style: GoogleFonts.poppins(
                                  color: isMember
                                      ? AppColors.primary
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
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
    );
  }
}

// ─────────────────────────────────────────────
// STACKED REAL MEMBER AVATARS
// ─────────────────────────────────────────────
class _StackedMemberAvatars extends StatelessWidget {
  final List<dynamic> members;
  final String totalCount;

  const _StackedMemberAvatars({
    required this.members,
    required this.totalCount,
  });

  // Fallback colors when no profile picture
  static const List<Color> _fallbackColors = [
    Color(0xFF8B4558),
    Color(0xFF5B7FA6),
    Color(0xFF6DAB8A),
  ];

  @override
  Widget build(BuildContext context) {
    // Show up to 3 avatars
    final displayMembers = members.take(3).toList();
    const double size = 32;
    const double overlap = 10;
    final int count = displayMembers.isEmpty ? 3 : displayMembers.length;
    final double totalWidth = size + (size - overlap) * (count - 1).toDouble();

    return Row(
      children: [
        SizedBox(
          width: totalWidth,
          height: size,
          child: Stack(
            children: List.generate(count, (i) {
              // Get real profile data if available
              final profile = i < displayMembers.length
                  ? (displayMembers[i]['profiles'] ?? displayMembers[i])
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
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          totalCount,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
