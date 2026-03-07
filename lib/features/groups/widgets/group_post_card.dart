import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class GroupPostCard extends StatefulWidget {
  final dynamic post;
  final VoidCallback? onRefresh;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLikeTap;

  const GroupPostCard({
    super.key,
    required this.post,
    this.onRefresh,
    this.onCommentTap,
    this.onLikeTap,
  });

  @override
  State<GroupPostCard> createState() => _GroupPostCardState();
}

class _GroupPostCardState extends State<GroupPostCard> {
  final ApiService _apiService = ApiService();
  late bool isLiked;
  late int likesCount;
  String? myId;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post['is_liked_by_me'] ?? false;
    likesCount = widget.post['likes_count'] ?? 0;
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await _apiService.getCurrentUserId();
    if (mounted) setState(() => myId = id);
  }

  void _handleInternalLike() {
    setState(() {
      isLiked = !isLiked;
      isLiked ? likesCount++ : likesCount--;
    });
    widget.onLikeTap?.call();
  }

  void _handleShare() {
    final String content = widget.post['content'] ?? '';
    Share.share(
      'Check out this post on LifeKit:\n\n"$content"\n\nJoin the community on LifeKit!',
    );
  }

  void _showPostOptions() {
    final bool isOwner = widget.post['user_id'] == myId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwner)
              _OptionTile(
                icon: Icons.delete_outline,
                label: 'Delete Post',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  await _handleDelete();
                },
              ),
            _OptionTile(
              icon: Icons.flag_outlined,
              label: 'Report Post',
              color: Colors.grey[700]!,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post reported. Thank you.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    try {
      await _apiService.deleteGroupPost(widget.post['id']);
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return DateFormat('MMM dd').format(date);
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'] ?? {};
    final String name = profile['full_name'] ?? 'Member';
    final String handle = profile['username'] ?? '';
    final String? avatar = profile['profile_picture_url'];
    final String content = widget.post['content'] ?? '';
    final String? imageUrl = widget.post['image_url'];
    final int commentsCount = widget.post['comments_count'] ?? 0;
    final DateTime createdAt = DateTime.parse(widget.post['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // ── Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: avatar != null
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'M',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          if (handle.isNotEmpty)
                            Text(
                              '@$handle',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          if (handle.isNotEmpty)
                            Text(
                              ' · ',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          Text(
                            _timeAgo(createdAt),
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                  onPressed: _showPostOptions,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Content ─────────────────────────────
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                content,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),

          // ── Image ───────────────────────────────
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 140,
                    color: Colors.grey[100],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Divider ─────────────────────────────
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Action bar ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like
                _ActionBtn(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '$likesCount',
                  color: isLiked ? Colors.red : Colors.grey[600]!,
                  onTap: _handleInternalLike,
                ),

                // Comment
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '$commentsCount',
                  color: Colors.grey[600]!,
                  onTap: widget.onCommentTap ?? () {},
                ),

                const Spacer(),

                // Share
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: _handleShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OPTION TILE (for bottom sheet)
// ─────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}
