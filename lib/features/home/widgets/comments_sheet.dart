import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final bool isGroup; // <--- NEW FLAG
  final VoidCallback? onCommentPosted;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.isGroup = false, // Defaults to false (standard feed)
    this.onCommentPosted,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> comments = [];
  bool isLoading = true;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  // --- CONTENT SAFETY FILTER (For Groups) ---
  bool _isSafe(String text) {
    if (!widget.isGroup) return true; // Skip filter for main feed if preferred
    final clean = text.toLowerCase().replaceAll(' ', '');
    final hasEmail = clean.contains('@') || clean.contains('.com');
    final hasPhone = RegExp(r'\d{10,}').hasMatch(clean);
    final blacklist = [
      'whatsapp',
      'callme',
      'telegram',
      'zelle',
      'cashapp',
      'payme',
    ];
    return !hasEmail && !hasPhone && !hasBlacklisted(clean, blacklist);
  }

  bool hasBlacklisted(String text, List<String> list) {
    return list.any((word) => text.contains(word));
  }

  Future<void> _fetchComments() async {
    try {
      final List<dynamic> data;
      if (widget.isGroup) {
        // You created this method in step 3 of the group social update
        data = await _apiService.getGroupPostComments(widget.postId);
      } else {
        data = await _apiService.getComments(widget.postId);
      }

      if (mounted) {
        setState(() {
          comments = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!_isSafe(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Safety Warning: Contact details are not allowed in comments.",
          ),
        ),
      );
      return;
    }

    setState(() => isPosting = true);

    try {
      if (widget.isGroup) {
        await _apiService.postGroupComment(widget.postId, text);
      } else {
        await _apiService.postComment(widget.postId, text);
      }

      _commentController.clear();
      widget.onCommentPosted?.call();
      _fetchComments(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to post comment: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Comments",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : comments.isEmpty
                ? Center(
                    child: Text(
                      "No comments yet. Be the first!",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final user = c['profiles'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: CachedNetworkImageProvider(
                                user?['profile_picture_url'] ??
                                    'https://via.placeholder.com/50',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?['full_name'] ?? 'User',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c['content'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
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
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isPosting ? null : _postComment,
                  icon: isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
