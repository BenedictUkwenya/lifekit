import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../widgets/group_post_card.dart';
import '../../home/widgets/comments_sheet.dart';
import 'group_settings_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _postController = TextEditingController();

  bool isLoading = true;
  bool isPosting = false;
  Map<String, dynamic>? groupData;
  List<dynamic> posts = [];
  bool isMember = false;
  bool isAdmin = false;

  File? _postImageFile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final detail = await _apiService.getGroupDetail(widget.groupId);
      final postList = await _apiService.getGroupPosts(widget.groupId);

      if (mounted) {
        setState(() {
          groupData = detail['group'];
          isMember = detail['isMember'] ?? false;
          isAdmin = detail['isAdmin'] ?? false;
          posts = postList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- NEW: MEMBERSHIP GUARD ---
  // This wraps any action and prevents non-members from interacting
  void _checkMembershipAction(VoidCallback action) {
    if (isMember) {
      action();
    } else {
      _showErrorSnackBar("Please join the group to interact with posts.");
    }
  }

  Future<void> _handleJoinGroup() async {
    try {
      await _apiService.joinGroup(widget.groupId);
      _showSuccessSnackBar("Welcome to the group!");
      _loadData();
    } catch (e) {
      _showErrorSnackBar("Failed to join group.");
    }
  }

  void _showCommentsSheet(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: post['id'], isGroup: true),
    );
  }

  Future<void> _pickPostImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _postImageFile = File(image.path));
    }
  }

  bool _isContentSafe(String text) {
    final cleanText = text.toLowerCase();
    if (cleanText.contains('@') ||
        cleanText.contains('.com') ||
        cleanText.contains('.net'))
      return false;
    final phoneRegex = RegExp(r'(\+?\d{1,4}[\s-]?)?(\d{10,13})');
    if (phoneRegex.hasMatch(cleanText.replaceAll(' ', ''))) return false;

    final blacklist = [
      'whatsapp',
      'call me',
      'contact me',
      'phone',
      'number',
      'telegram',
      'dm me',
      'pay outside',
      'zelle',
      'cashapp',
    ];
    for (var word in blacklist) {
      if (cleanText.contains(word)) return false;
    }
    return true;
  }

  void _handleCreatePost() async {
    final content = _postController.text.trim();
    if (content.isEmpty && _postImageFile == null) return;

    if (!_isContentSafe(content)) {
      _showErrorSnackBar("Safety Alert: Please do not share contact details.");
      return;
    }

    setState(() => isPosting = true);

    try {
      String? imageUrl;
      if (_postImageFile != null) {
        imageUrl = await _apiService.uploadServiceImage(_postImageFile!);
      }

      await _apiService.createGroupPost(widget.groupId, content, imageUrl);

      if (mounted) {
        _postController.clear();
        setState(() {
          _postImageFile = null;
          isPosting = false;
        });
        Navigator.pop(context);
        _loadData();
      }
    } catch (e) {
      setState(() => isPosting = false);
      _showErrorSnackBar("Failed to post: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: LifeKitLoader()));
    if (groupData == null)
      return const Scaffold(body: Center(child: Text("Group not found")));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
        ],
        body: posts.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  // --- UPDATED CARD WITH MEMBERSHIP CHECKS ---
                  return GroupPostCard(
                    post: post,
                    onRefresh: _loadData,
                    onCommentTap: () =>
                        _checkMembershipAction(() => _showCommentsSheet(post)),
                    onLikeTap: () => _checkMembershipAction(() async {
                      try {
                        await _apiService.toggleGroupPostLike(post['id']);
                        _loadData();
                      } catch (e) {
                        _showErrorSnackBar("Action failed");
                      }
                    }),
                  );
                },
              ),
      ),
      floatingActionButton: isMember
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _showCreatePostSheet,
              child: const Icon(Icons.add_comment, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: const BackButton(color: Colors.white),
      actions: [
        if (!isMember)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _handleJoinGroup,
              child: Text(
                "Join",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (isMember && isAdmin)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupSettingsScreen(group: groupData!),
              ),
            ).then((_) => _loadData()),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          groupData!['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl:
                  groupData!['image_url'] ??
                  "https://images.unsplash.com/photo-1529156069898-49953e39b3ac",
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Create Post",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _postController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    await _pickPostImage();
                    setSheetState(() {});
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _postImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _postImageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo,
                                color: Colors.grey,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Add a photo",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isPosting ? null : _handleCreatePost,
                    child: isPosting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Post to Group",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => setState(() => _postImageFile = null));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No posts yet. Be the first!",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
