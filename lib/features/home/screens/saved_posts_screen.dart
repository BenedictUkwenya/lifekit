import 'package:lifekit_frontend/core/widgets/skeleton.dart';
import 'package:lifekit_frontend/core/widgets/motion.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_lottie.dart';
import '../../../core/widgets/app_toast.dart';
import 'feed_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  List<dynamic> posts = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final data = await _apiService.getSavedPosts();
      if (mounted) {
        setState(() {
          posts = data;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Unsave instantly; put it back if the server refuses.
  Future<void> _unsave(dynamic post) async {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final index = posts.indexOf(post);
    setState(() => posts.removeAt(index));
    AppToast.success(context, l10n.feedsRemovedFromBookmarks);
    try {
      await _apiService.toggleBookmark('${post['id']}', saved: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => posts.insert(index.clamp(0, posts.length), post));
      AppToast.error(context, l10n.feedsBookmarkFailed(appErrorMessage(context, e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          AppLocalizations.of(context).txSavedPosts,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      body: isLoading
          ? const SkeletonList()
          : posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLottie(AppAnim.emptyBox, size: 150),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).txNoSavedPostsYet,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSaved,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => Builder(builder: (context) {
                      final post = posts[index];
                      final profile = post['profiles'] ?? {};
                      final name = profile['full_name'] ?? 'User';
                      final handle = profile['username'] ?? 'user';
                      final pic = profile['profile_picture_url'];
                      final title = post['title'] ?? '';
                      final content = post['content'] ?? '';
                      // Posts store photos in image_urls; image_url is the old single field.
                      final urls = (post['image_urls'] as List?)?.whereType<String>().toList() ?? const <String>[];
                      final String? image = urls.isNotEmpty ? urls.first : post['image_url'];

                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FeedDetailScreen(post: post))),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey[100],
                                    backgroundImage: pic != null
                                        ? CachedNetworkImageProvider(pic)
                                        : null,
                                    child: pic == null
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                            size: 18,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '@$handle',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppLocalizations.of(context).feedsRemovedFromBookmarks,
                                    onPressed: () => _unsave(post),
                                    icon: const Icon(Icons.bookmark_rounded, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (image != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: image,
                                        width: 100,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 100,
                                          height: 90,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(width: image != null ? 12 : 0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (title.isNotEmpty)
                                          Text(
                                            title,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              height: 1.3,
                                            ),
                                          ),
                                        if (content.isNotEmpty) ...[
                                          SizedBox(
                                            height:
                                                title.isNotEmpty ? 4 : 0,
                                          ),
                                          Text(
                                            content,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      );
                    }).cascadeIn(index),
                  ),
                ),
    );
  }
}

