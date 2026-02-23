import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
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
  String? myId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMyId();
    _startPolling();
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

  Future<void> _refreshPosts() async {
    try {
      final postList = await _apiService.getGroupPosts(widget.groupId);
      if (mounted) {
        setState(() {
          posts = postList;
        });
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshPosts();
    });
  }

  Future<void> _loadMyId() async {
    final id = await _apiService.getCurrentUserId();
    if (mounted) {
      setState(() {
        myId = id;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _postController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    if (!_isContentSafe(content)) {
      _showErrorSnackBar("Safety Alert: Please do not share contact details.");
      return;
    }

    setState(() => isPosting = true);

    try {
      await _apiService.createGroupPost(widget.groupId, content, null);

      if (mounted) {
        _postController.clear();
        setState(() {
          isPosting = false;
        });
        await _refreshPosts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isPosting = false);
        _showErrorSnackBar("Failed to send message.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: LifeKitLoader()));
    if (groupData == null) {
      return const Scaffold(body: Center(child: Text("Group not found")));
    }

    final messages = posts.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(
                groupData!['image_url'] ??
                    "https://images.unsplash.com/photo-1529156069898-49953e39b3ac",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    groupData!['name'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isMember ? "You are a member" : "Tap Join to participate",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isMember)
            TextButton(
              onPressed: _handleJoinGroup,
              child: const Text(
                "Join",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final post = messages[index];
                      final bool isMine =
                          myId != null && post['user_id'] == myId;
                      final profile = post['profiles'] ?? {};
                      final name =
                          profile['full_name'] ??
                          profile['username'] ??
                          'Someone';
                      final createdAtString = post['created_at'] as String?;
                      DateTime? createdAt;
                      if (createdAtString != null) {
                        createdAt = DateTime.tryParse(createdAtString);
                      }
                      final content = (post['content'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? AppColors.primary
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16)
                                      .copyWith(
                                        bottomLeft: isMine
                                            ? const Radius.circular(16)
                                            : const Radius.circular(4),
                                        bottomRight: isMine
                                            ? const Radius.circular(4)
                                            : const Radius.circular(16),
                                      ),
                                ),
                                child: Text(
                                  content,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isMine
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    left: 4,
                                    right: 4,
                                  ),
                                  child: Text(
                                    _timeAgo(createdAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey[500],
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
          if (isMember)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Type a message",
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: isPosting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      color: AppColors.primary,
                      onPressed: isPosting
                          ? null
                          : () => _checkMembershipAction(_sendMessage),
                    ),
                  ],
                ),
              ),
            ),
          if (!isMember)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _handleJoinGroup,
                  child: const Text(
                    "Join group to send messages",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) {
      return DateFormat('MMM dd').format(date);
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
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
