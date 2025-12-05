import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  List<dynamic> comments = [];
  bool isLoading = true;
  bool isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await _apiService.getComments(widget.postId);
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
    if (_controller.text.isEmpty) return;
    setState(() => isPosting = true);
    try {
      final newComment = await _apiService.postComment(
        widget.postId,
        _controller.text,
      );
      if (mounted) {
        setState(() {
          comments.add(newComment); // Add locally
          _controller.clear();
          isPosting = false;
        });
      }
    } catch (e) {
      setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // 75% height
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Comments",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Comments List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : comments.isEmpty
                ? Center(
                    child: Text(
                      "No comments yet",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final profile = c['profiles'] ?? {};
                      final date = DateTime.parse(c['created_at']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              profile['profile_picture_url'] != null
                              ? CachedNetworkImageProvider(
                                  profile['profile_picture_url'],
                                )
                              : const AssetImage(
                                      'assets/images/onboarding1.png',
                                    )
                                    as ImageProvider,
                        ),
                        title: Text(
                          profile['full_name'] ?? 'User',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['content'],
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, h:mm a').format(date),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input Field
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Add a comment...",
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
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
        ],
      ),
    );
  }
}
