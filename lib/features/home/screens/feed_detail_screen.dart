import 'package:flutter/material.dart';
import '../../../core/utils/time_ago.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../widgets/comments_sheet.dart';
import '../../../core/widgets/skeleton.dart';
import '../widgets/photo_viewer.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/dates.dart';

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

  int _likeSeq = 0;

  // Instant: flip now, tell the server the wanted state, undo on failure.
  void _handleLike() {
    HapticFeedback.lightImpact();
    final want = !isLiked;
    final prevLiked = isLiked, prevCount = likeCount;
    setState(() {
      isLiked = want;
      likeCount = (likeCount + (want ? 1 : -1)).clamp(0, 1 << 30);
    });
    widget.post['is_liked_by_me'] = isLiked;
    widget.post['likes_count'] = likeCount;
    final seq = ++_likeSeq;
    _apiService.toggleLike(widget.post['id'], liked: want).then((result) {
      if (!mounted || seq != _likeSeq) return;
      setState(() {
        isLiked = result['is_liked_by_me'] ?? want;
        likeCount = result['likes_count'] ?? likeCount;
      });
    }).catchError((Object e) {
      if (!mounted || seq != _likeSeq) return;
      setState(() {
        isLiked = prevLiked;
        likeCount = prevCount;
      });
      widget.post['is_liked_by_me'] = prevLiked;
      widget.post['likes_count'] = prevCount;
      AppToast.error(context, appErrorMessage(context, e));
    });
  }

  /// Replies are written in the comments sheet (it handles threading).
  Future<void> _openThread() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(
        postId: widget.post['id'],
        onCommentPosted: () => setState(() => commentCount++),
        onCommentsDeleted: (n) => setState(() => commentCount = (commentCount - n).clamp(0, 1 << 30)),
      ),
    );
    _fetchComments();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    // Show it straight away; replace with the saved comment when the server answers.
    final tmp = <String, dynamic>{
      'id': 'tmp_${DateTime.now().microsecondsSinceEpoch}',
      'content': text,
      'parent_id': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'profiles': {'full_name': AppLocalizations.of(context).commentsYou},
      '_pending': true,
    };
    setState(() {
      comments = [...comments, tmp];
      commentCount++;
      _commentController.clear();
    });
    try {
      final saved = await _apiService.postComment(widget.post['id'], text);
      if (mounted) {
        setState(() {
          comments = [
            for (final c in comments)
              if (c['id'] == tmp['id'] && saved is Map) Map<String, dynamic>.from(saved) else c,
          ];
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        comments = comments.where((c) => c['id'] != tmp['id']).toList();
        commentCount = (commentCount - 1).clamp(0, 1 << 30);
        if (_commentController.text.isEmpty) _commentController.text = text;
      });
      AppToast.error(context, appErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return formatTimeAgo(context, parseApiDate(dateStr));
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
    // Photos live in image_urls; image_url is the old single-photo field.
    final List<String> images = [
      ...((widget.post['image_urls'] as List?)?.whereType<String>() ?? const <String>[]),
    ];
    if (images.isEmpty && widget.post['image_url'] is String) images.add(widget.post['image_url']);
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
                      AppLocalizations.of(context).txComments,
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
                  if (images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _DetailPhotos(images: images),
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
                          AppLocalizations.of(context).txNoCommentsYetBeTheFirst,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...() {
                      final top = comments.where((c) => c['parent_id'] == null).toList();
                      Widget row(dynamic c, {required bool divider, bool reply = false}) {
                        final u = c['profiles'] ?? {};
                        return Padding(
                          padding: EdgeInsets.only(left: reply ? 40 : 0),
                          child: Opacity(
                            opacity: c['_pending'] == true ? 0.55 : 1,
                            child: _PostRow(
                              avatar: u['profile_picture_url'],
                              name: u['full_name'] ?? 'User',
                              handle: u['username'] ?? 'user',
                              timeAgo: c['_pending'] == true
                                  ? AppLocalizations.of(context).commentsSending
                                  : _timeAgo(c['created_at']),
                              title: null,
                              content: c['content'] ?? '',
                              likeCount: null,
                              commentCount: null,
                              isLiked: false,
                              onLike: null,
                              showDivider: divider,
                              onReply: c['_pending'] == true ? null : _openThread,
                            ),
                          ),
                        );
                      }
                      return [
                        for (var i = 0; i < top.length; i++) ...[
                          row(top[i], divider: false),
                          for (final r in comments.where((x) => x['parent_id'] == top[i]['id']))
                            row(r, divider: false, reply: true),
                          if (i < top.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ];
                    }(),

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
                          hintText: AppLocalizations.of(context).commentsAddHint,
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
  final VoidCallback? onReply;

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
    this.onReply,
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
          if (onReply != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(66, 0, 16, 8),
              child: GestureDetector(
                onTap: onReply,
                child: Text(
                  AppLocalizations.of(context).commentsReply,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
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

/// Swipeable photos with page dots; tap opens the full-screen viewer.
class _DetailPhotos extends StatefulWidget {
  final List<String> images;
  const _DetailPhotos({required this.images});

  @override
  State<_DetailPhotos> createState() => _DetailPhotosState();
}

class _DetailPhotosState extends State<_DetailPhotos> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => PhotoViewer.open(context, widget.images, index: i),
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                fadeInDuration: const Duration(milliseconds: 250),
                placeholder: (_, __) => const SkeletonBox(height: 280, radius: 0),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
      if (widget.images.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
    ]);
  }
}
