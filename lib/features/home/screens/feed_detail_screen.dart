import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class FeedDetailScreen extends StatefulWidget {
  final dynamic post;

  const FeedDetailScreen({super.key, required this.post});

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> comments = [];
  bool isLoadingComments = true;
  bool isPosting = false;
  late bool isLiked;
  late int likeCount;
  late int commentCount;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes_count'] ?? 0;
    isLiked = widget.post['is_liked_by_me'] ?? false;
    commentCount = widget.post['comments_count'] ?? 0;
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await _apiService.getComments(widget.post['id']);
      if (mounted) {
        setState(() {
          comments = data;
          isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingComments = false);
    }
  }

  void _handleLike() {
    _apiService
        .toggleLike(widget.post['id'])
        .then((result) {
          if (!mounted) return;
          setState(() {
            isLiked = result['is_liked_by_me'] ?? isLiked;
            likeCount = result['likes_count'] ?? likeCount;
          });
        })
        .catchError((e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
        });
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => isPosting = true);
    try {
      await _apiService.postComment(widget.post['id'], text);
      _commentController.clear();
      await _fetchComments();
      if (mounted) {
        setState(() {
          commentCount++;
        });
      }
      // Scroll to bottom after posting
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1) return DateFormat('MMM d').format(dt);
      if (diff.inHours >= 1) return '${diff.inHours}hrs ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'] ?? {};
    final name = profile['full_name'] ?? 'User';
    final handle = profile['username'] ?? 'user';
    final pic = profile['profile_picture_url'];
    final title = widget.post['title'] ?? '';
    final content = widget.post['content'] ?? '';
    final image = widget.post['image_url'];
    final createdAt = widget.post['created_at'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Comments',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // balance
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────
            Expanded(
              child: ListView(
                controller: _scrollController,
                children: [
                  // Post image
                  if (image != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: image,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // ── Post itself (first "comment" row) ─
                  _PostRow(
                    avatar: pic,
                    name: name,
                    handle: handle,
                    timeAgo: _timeAgo(createdAt),
                    title: title,
                    content: content,
                    likeCount: likeCount,
                    commentCount: commentCount,
                    isLiked: isLiked,
                    onLike: _handleLike,
                    showDivider: true,
                  ),

                  // ── Comments ────────────────────────
                  if (isLoadingComments)
                    ..._skeletonComments()
                  else if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...comments.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final u = c['profiles'] ?? {};
                      return _PostRow(
                        avatar: u['profile_picture_url'],
                        name: u['full_name'] ?? 'User',
                        handle: u['username'] ?? 'user',
                        timeAgo: _timeAgo(c['created_at']),
                        title: null,
                        content: c['content'] ?? '',
                        likeCount: null,
                        commentCount: null,
                        isLiked: false,
                        onLike: null,
                        showDivider: i < comments.length - 1,
                      );
                    }),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Comment input ─────────────────────────
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isPosting ? null : _postComment,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: isPosting
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _skeletonComments() {
    return List.generate(3, (_) => _SkeletonCommentRow());
  }
}

// ─────────────────────────────────────────────
// POST ROW  — used for both the original post
// and each comment in the list
// ─────────────────────────────────────────────
class _PostRow extends StatelessWidget {
  final String? avatar;
  final String name;
  final String handle;
  final String timeAgo;
  final String? title;
  final String content;
  final int? likeCount;
  final int? commentCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final bool showDivider;

  const _PostRow({
    required this.avatar,
    required this.name,
    required this.handle,
    required this.timeAgo,
    required this.title,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.onLike,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: avatar != null
                          ? CachedNetworkImageProvider(avatar!)
                          : null,
                      child: avatar == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@$handle',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Title
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Content
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Action row (only for the main post)
                if (likeCount != null) ...[
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likeCount',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
                      const Spacer(),
                      Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          if (showDivider) Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

// Skeleton shimmer-style placeholder
class _SkeletonCommentRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
