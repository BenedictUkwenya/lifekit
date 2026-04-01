import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/screens/service_profile_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';
import 'group_settings_screen.dart';
import '../../home/widgets/comments_sheet.dart';

// ─── Soft Pastel Design Tokens ──────────────────────────────────
class _T {
  static const bg = Color(0xFFFDF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFF5EE);
  static const elevated = Color(0xFFFFF0E8);

  static const rose = Color(0xFFFF8FAB);
  static const peach = Color(0xFFFFB49A);
  static const lavender = Color(0xFFB5A8F5);
  static const mint = Color(0xFF8ED8C0);
  static const butter = Color(0xFFFFD97D);

  static const textPri = Color(0xFF3A2E2A);
  static const textSec = Color(0xFF8E7E77);
  static const textMuted = Color(0xFFBBA9A1);

  static const border = Color(0xFFF0E4DC);
  static const divider = Color(0xFFF5EAE2);

  static const myBubble = Color(0xFFFFE4EE);
  static const likeColor = Color(0xFFFF6B8A);

  static const gradStart = Color(0xFFFFB49A);
  static const gradEnd = Color(0xFFFF8FAB);

  static const headerBg = Color(0xFFFFF5EE);
}
// ────────────────────────────────────────────────────────────────

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _groupPostsChannel;
  Timer? _activityTicker;

  bool isLoading = true;
  bool isSending = false;
  bool _showScrollToBottom = false;

  Map<String, dynamic>? groupData;
  List<dynamic> posts = [];
  bool isMember = false;
  bool isAdmin = false;
  String? myId;

  File? _selectedImage;
  Map<String, dynamic>? _selectedService;
  dynamic _replyingTo;
  final Map<String, DateTime> _memberActivity = {};
  static const int _activeWindowMinutes = 15;

  // Post-type filter (All / Gigs / Tips / Showcase)
  String _activeFilter = 'All';

  List<dynamic> get _filteredPosts {
    switch (_activeFilter) {
      case 'Gigs':
        return posts.where((p) => p['service_id'] != null).toList();
      case 'Tips':
        return posts
            .where((p) => p['service_id'] == null && p['image_url'] == null)
            .toList();
      case 'Showcase':
        return posts
            .where(
                (p) => p['image_url'] != null && p['service_id'] == null)
            .toList();
      default:
        return posts;
    }
  }

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadMyId();
    _loadData();
    _subscribeToGroupPosts();
    _activityTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 300;
      if (show != _showScrollToBottom)
        setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_groupPostsChannel != null) {
      _supabase.removeChannel(_groupPostsChannel!);
    }
    _activityTicker?.cancel();
    _postController.dispose();
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribeToGroupPosts();
      _refreshPosts();
    }
  }

  Future<void> _loadMyId() async {
    final id = await _apiService.getCurrentUserId();
    if (mounted) setState(() => myId = id);
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
          _rebuildMemberActivity(postList);
          isLoading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _refreshPosts({bool force = false}) async {
    try {
      final postList = await _apiService.getGroupPosts(widget.groupId);
      if (mounted) {
        setState(() {
          posts = postList;
          _rebuildMemberActivity(postList);
        });
      }
    } catch (_) {}
  }

  void _rebuildMemberActivity(List<dynamic> postList) {
    _memberActivity.clear();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: _activeWindowMinutes));
    for (final post in postList) {
      final userId = post['user_id']?.toString();
      final createdRaw = post['created_at']?.toString();
      if (userId == null || createdRaw == null) continue;
      try {
        final createdAt = DateTime.parse(createdRaw).toLocal();
        if (createdAt.isAfter(cutoff)) {
          final existing = _memberActivity[userId];
          if (existing == null || createdAt.isAfter(existing)) {
            _memberActivity[userId] = createdAt;
          }
        }
      } catch (_) {}
    }
  }

  int _activeMembersNowCount() {
    final cutoff = DateTime.now().subtract(
      const Duration(minutes: _activeWindowMinutes),
    );
    _memberActivity.removeWhere((_, lastSeen) => lastSeen.isBefore(cutoff));
    return _memberActivity.length;
  }

  Future<void> _subscribeToGroupPosts() async {
    if (_groupPostsChannel != null) {
      await _supabase.removeChannel(_groupPostsChannel!);
    }

    _groupPostsChannel = _supabase.channel(
      'public:group_posts:${widget.groupId}',
    );
    _groupPostsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_posts',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'group_id',
        value: widget.groupId,
      ),
      callback: (payload) {
        if (!mounted) return;
        final record = payload.newRecord;
        final recordId = record['id'];
        final userId = record['user_id']?.toString();
        if (userId != null) {
          setState(() {
            _memberActivity[userId] = DateTime.now();
          });
        }
        if (recordId != null && posts.any((p) => p['id'] == recordId)) {
          return;
        }
        _refreshPosts();
      },
    );

    await _groupPostsChannel!.subscribe();
  }

  void _vibrate() => HapticFeedback.lightImpact();

  Future<void> _handleJoinGroup() async {
    try {
      await _apiService.joinGroup(widget.groupId);
      _showSnack("You're in! Welcome 🌸", isSuccess: true);
      _loadData();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('plan limit') || msg.contains('plan_limit_reached')) {
        _showPlanLimitSheet();
      } else {
        _showSnack("Couldn't join. Try again!", isError: true);
      }
    }
  }

  void _showPlanLimitSheet() {
    final String groupName = groupData?['name'] ?? 'this hub';
    final String? imageUrl = groupData?['image_url'];
    final int memberCount = groupData?['member_count'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanLimitDetailSheet(
        groupName: groupName,
        groupImageUrl: imageUrl,
        memberCount: memberCount,
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _pickService() async {
    try {
      final services = await _apiService.getMyServices();
      if (!mounted) return;
      if (services.isEmpty) {
        _showSnack("No services yet — create one first!");
        return;
      }
      showModalBottomSheet(
        context: context,
        backgroundColor: _T.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _T.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _T.elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _T.peach,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Share a Service",
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _T.textPri,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: services.length,
                itemBuilder: (context, i) {
                  final s = services[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            s['image_url'] ?? "https://via.placeholder.com/150",
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      s['title'] ?? 'Untitled',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: _T.textPri,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "\$${s['price'] ?? '0'}",
                      style: const TextStyle(
                        color: _T.mint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedService = s);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    } catch (e) {
      _showSnack("Couldn't load services.", isError: true);
    }
  }

  Future<void> _sendMessage() async {
    final content = _postController.text.trim();
    if (content.isEmpty && _selectedImage == null && _selectedService == null)
      return;
    if (content.isNotEmpty && !_isContentSafe(content)) {
      _showSnack(
        "Safety alert: contact info isn't allowed here 🚫",
        isError: true,
      );
      return;
    }
    setState(() => isSending = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _apiService.uploadServiceImage(_selectedImage!);
      }
      await _apiService.createGroupPost(
        widget.groupId,
        content,
        imageUrl,
        serviceId: _selectedService?['id'],
        parentId: _replyingTo?['id'],
      );
      if (mounted) {
        _postController.clear();
        setState(() {
          _selectedImage = null;
          _selectedService = null;
          _replyingTo = null;
          isSending = false;
        });
        _refreshPosts(force: true);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSending = false);
        _showSnack("Oops, couldn't send. Try again!", isError: true);
      }
    }
  }

  void _showMessageOptions(dynamic post) {
    _vibrate();
    bool isMine = post['user_id'] == myId;
    bool isLiked = post['is_liked_by_me'] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _T.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _optionTile(
                emoji: isLiked ? "💔" : "🩷",
                label: isLiked ? "Unlike" : "Like",
                color: _T.likeColor,
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    final idx = posts.indexWhere((p) => p['id'] == post['id']);
                    if (idx != -1) {
                      final cur = posts[idx]['likes_count'] ?? 0;
                      posts[idx]['is_liked_by_me'] = !isLiked;
                      posts[idx]['likes_count'] = !isLiked ? cur + 1 : cur - 1;
                    }
                  });
                  try {
                    await _apiService.toggleGroupPostLike(post['id']);
                    _refreshPosts(force: true);
                  } catch (_) {
                    _refreshPosts(force: true);
                  }
                },
              ),
              _optionTile(
                emoji: "↩️",
                label: "Reply",
                color: _T.lavender,
                onTap: () {
                  _vibrate();
                  Navigator.pop(context);
                  setState(() => _replyingTo = post);
                },
              ),
              _optionTile(
                emoji: "💬",
                label: "View All Replies",
                color: _T.mint,
                onTap: () {
                  Navigator.pop(context);
                  _showComments(post);
                },
              ),
              if (isMine || isAdmin)
                _optionTile(
                  emoji: "🗑️",
                  label: "Delete",
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _apiService.deleteGroupPost(post['id']);
                      _refreshPosts(force: true);
                    } catch (_) {
                      _showSnack("Couldn't delete.", isError: true);
                    }
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
      ),
      title: Text(
        label,
        style: GoogleFonts.nunito(
          color: _T.textPri,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showComments(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: post['id'], isGroup: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _T.bg,
        body: const Center(child: LifeKitLoader()),
      );
    }
    if (groupData == null) {
      return Scaffold(
        backgroundColor: _T.bg,
        body: Center(
          child: Text(
            "Couldn't find this group 🌿",
            style: GoogleFonts.nunito(color: _T.textSec),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _showScrollToBottom
          ? Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: _T.surface,
                elevation: 3,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _T.peach,
                  size: 22,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          _buildFilterPills(),
          Expanded(child: _buildFeed()),
          if (isMember) _buildInputArea() else _buildJoinBanner(),
        ],
      ),
    );
  }

  Widget _buildFilterPills() {
    const filters = [
      {'id': 'All', 'emoji': '🌐', 'label': 'All'},
      {'id': 'Gigs', 'emoji': '💼', 'label': 'Gigs/Leads'},
      {'id': 'Tips', 'emoji': '💡', 'label': 'Tips'},
      {'id': 'Showcase', 'emoji': '📸', 'label': 'Showcase'},
    ];

    return Container(
      color: _T.headerBg,
      // Extra bottom padding prevents the 1-2px vertical clip on pill shadows
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: filters.map((f) {
            final isActive = _activeFilter == f['id'];
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = f['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : _T.border,
                    width: 1.4,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f['emoji']!,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      f['label']!,
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : _T.textSec,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final memberCount = groupData!['member_count'] ?? 0;
    final activeNowCount = _activeMembersNowCount();
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: const BoxDecoration(
          color: _T.headerBg,
          border: Border(bottom: BorderSide(color: _T.border, width: 1.2)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _T.textSec,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_T.peach, _T.rose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _T.surface,
                    backgroundImage: CachedNetworkImageProvider(
                      groupData!['image_url'] ??
                          "https://via.placeholder.com/150",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: isMember
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GroupSettingsScreen(group: groupData!),
                            ),
                          ).then((_) => _loadData())
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          groupData!['name'],
                          style: GoogleFonts.nunito(
                            color: _T.textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isMember
                              ? "🌸 $memberCount members"
                              : "Join to participate",
                          style: GoogleFonts.nunito(
                            color: _T.textSec,
                            fontSize: 11.5,
                          ),
                        ),
                        if (isMember)
                          Text(
                            "$activeNowCount members active now",
                            style: GoogleFonts.nunito(
                              color: _T.peach,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: _T.textSec,
                    size: 22,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final filtered = _filteredPosts;
    if (filtered.isEmpty) {
      if (_activeFilter == 'All') return _buildEmptyState();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              'No ${_activeFilter} posts yet',
              style: GoogleFonts.nunito(
                  color: _T.textSec, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeCtrl,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final post = filtered[index];
          final current = DateTime.parse(post['created_at']);
          bool showDate = false;
          if (index == filtered.length - 1) {
            showDate = true;
          } else {
            final next = DateTime.parse(filtered[index + 1]['created_at']);
            if (current.day != next.day ||
                current.month != next.month ||
                current.year != next.year)
              showDate = true;
          }
          return Column(
            children: [
              if (showDate) _buildDateHeader(current),
              _buildBubble(post),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);
    String text;
    if (check == today)
      text = "Today";
    else if (check == yesterday)
      text = "Yesterday";
    else if (now.difference(check).inDays < 7)
      text = DateFormat('EEEE').format(date);
    else
      text = DateFormat('MMM d, yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: _T.divider, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _T.elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _T.border, width: 1.2),
              ),
              child: Text(
                text,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _T.textSec,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: _T.divider, thickness: 1.5)),
        ],
      ),
    );
  }

  // Tier badge shown next to poster name in bubbles
  Widget _buildTierBadge(String tier) {
    Color color;
    String emoji;
    switch (tier) {
      case 'business':
        color = const Color(0xFF7C3AED);
        emoji = '👑';
        break;
      case 'pro':
        color = const Color(0xFFD97706);
        emoji = '⭐';
        break;
      case 'plus':
        color = const Color(0xFF2563EB);
        emoji = '💎';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 9),
      ),
    );
  }

  // Rating badge shown next to poster name in bubbles
  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              size: 9, color: Color(0xFFD97706)),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(dynamic post) {
    final bool isMine = myId != null && post['user_id'] == myId;
    final profile = post['profiles'] ?? {};
    final String name = profile['full_name'] ?? 'Someone';
    final String? pic = profile['profile_picture_url'];
    final String content = post['content'] ?? '';
    final String? image = post['image_url'];
    final DateTime time = DateTime.parse(post['created_at']);
    final String timeStr = DateFormat('h:mm a').format(time);
    final service = post['services'];
    final parent = post['parent'];
    final int likes = post['likes_count'] ?? 0;
    final bool isLiked = post['is_liked_by_me'] ?? false;
    final int comments = post['comments_count'] ?? 0;

    // Tier comes from the poster's profile; rating comes from the attached service
    // (average_rating does not exist on the profiles table).
    final String posterTier =
        (profile['subscription_tier'] ?? 'free').toString().toLowerCase();
    final double? avgRating = service != null
        ? (service['average_rating'] as num?)?.toDouble()
        : null;

    final userColors = [_T.rose, _T.peach, _T.lavender, _T.mint, _T.butter];
    final nameColor = userColors[name.hashCode.abs() % userColors.length];

    return GestureDetector(
      onLongPress: () => _showMessageOptions(post),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[
              _buildAvatar(pic, name, nameColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isMine ? _T.myBubble : _T.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMine
                          ? const Radius.circular(20)
                          : const Radius.circular(5),
                      bottomRight: isMine
                          ? const Radius.circular(5)
                          : const Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isMine ? _T.rose.withOpacity(0.3) : _T.border,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _T.peach.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMine
                          ? const Radius.circular(20)
                          : const Radius.circular(5),
                      bottomRight: isMine
                          ? const Radius.circular(5)
                          : const Radius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: nameColor,
                                    ),
                                  ),
                                ),
                                if (posterTier != 'free') ...[
                                  const SizedBox(width: 5),
                                  _buildTierBadge(posterTier),
                                ],
                                if (avgRating != null && avgRating > 0) ...[
                                  const SizedBox(width: 5),
                                  _buildRatingBadge(avgRating),
                                ],
                              ],
                            ),
                          ),
                        if (parent != null) _buildReplyPreview(parent),
                        if (image != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: image,
                                width: double.infinity,
                                height: 195,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (service != null) _buildServiceCard(service),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                            child: Text(
                              content,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                height: 1.45,
                                color: _T.textPri,
                              ),
                            ),
                          ),
                        _buildMetaRow(
                          isMine,
                          timeStr,
                          likes,
                          isLiked,
                          comments,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 8),
              _buildAvatar(pic, name, _T.rose),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? pic, String name, Color ringColor) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ringColor.withOpacity(0.35),
      ),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: ringColor.withOpacity(0.15),
        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
        child: pic == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ringColor,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildReplyPreview(dynamic parent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _T.elevated,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _T.lavender, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parent['profiles']?['full_name'] ?? 'someone',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _T.lavender,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parent['content']?.toString().isNotEmpty == true
                ? parent['content']
                : (parent['image_url'] != null ? "📷 Image" : "💼 Service"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 11.5, color: _T.textSec),
          ),
        ],
      ),
    );
  }

  Widget _serviceImagePlaceholder() {
    return Container(
      height: 105,
      width: double.infinity,
      color: _T.elevated,
      child: const Center(
        child: Icon(Icons.storefront_outlined, color: _T.textMuted, size: 36),
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    // Services use provider_id; image may come as image_urls array or image_url string.
    final String? rawImage = service['image_url']?.toString() ??
        (service['image_urls'] is List && (service['image_urls'] as List).isNotEmpty
            ? (service['image_urls'] as List).first?.toString()
            : null);
    final bool hasImage = rawImage != null && rawImage.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border, width: 1.2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Guard against null/missing image
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: rawImage,
                  height: 105,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _serviceImagePlaceholder(),
                )
              else
                _serviceImagePlaceholder(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['title']?.toString() ?? 'Service',
                        style: GoogleFonts.nunito(
                          color: _T.textPri,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "\$${service['price'] ?? '0'}",
                        style: GoogleFonts.nunito(
                          color: _T.mint,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final provider = service['profiles'];
                    // Use provider_id first; fall back to user_id; final fallback ''
                    final String resolvedProviderId =
                        service['provider_id']?.toString() ??
                        service['user_id']?.toString() ??
                        '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceProfileScreen(
                          service: service,
                          providerName:
                              provider?['full_name']?.toString() ?? 'Provider',
                          providerPic:
                              provider?['profile_picture_url']?.toString(),
                          providerId: resolvedProviderId,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: _T.peach.withOpacity(0.18),
                    foregroundColor: _T.peach,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(60, 30),
                  ),
                  child: Text(
                    "View",
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(
    bool isMine,
    String timeStr,
    int likes,
    bool isLiked,
    int comments,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (likes > 0) ...[
            Text(isLiked ? "🩷" : "🤍", style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(
              "$likes",
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: _T.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (comments > 0) ...[
            const Text("💬", style: TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(
              "$comments",
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: _T.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            timeStr,
            style: GoogleFonts.nunito(
              fontSize: 10.5,
              color: _T.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 5),
            const Icon(Icons.done_all_rounded, size: 14, color: _T.mint),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: _T.surface,
        border: const Border(top: BorderSide(color: _T.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: _T.peach.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedImage != null)
            _previewCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _selectedImage!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Image attached 📎",
                      style: GoogleFonts.nunito(
                        color: _T.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _xBtn(() => setState(() => _selectedImage = null)),
                ],
              ),
            ),
          if (_selectedService != null)
            _previewCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl:
                          _selectedService!['image_url'] ??
                          "https://via.placeholder.com/150",
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedService!['title'] ?? 'Service',
                          style: GoogleFonts.nunito(
                            color: _T.textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "\$${_selectedService!['price'] ?? '0'}",
                          style: const TextStyle(
                            color: _T.mint,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _xBtn(() => setState(() => _selectedService = null)),
                ],
              ),
            ),
          if (_replyingTo != null)
            _previewCard(
              accent: _T.lavender,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "↩ ${_replyingTo['profiles']?['full_name'] ?? 'someone'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _T.lavender,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyingTo['content']?.toString().isNotEmpty == true
                              ? _replyingTo['content']
                              : (_replyingTo['image_url'] != null
                                    ? "📷 Image"
                                    : "💼 Service"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: _T.textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _xBtn(() => setState(() => _replyingTo = null)),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _T.elevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _T.border, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: IconButton(
                          icon: const Icon(Icons.storefront_outlined, size: 20),
                          color: _T.peach,
                          onPressed: _pickService,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _postController,
                          maxLines: 4,
                          minLines: 1,
                          style: GoogleFonts.nunito(
                            color: _T.textPri,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Share something ✨",
                            hintStyle: GoogleFonts.nunito(
                              color: _T.textMuted,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: IconButton(
                          icon: const Icon(Icons.image_outlined, size: 20),
                          color: _T.textSec,
                          onPressed: _pickImage,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isSending ? null : _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSending
                        ? null
                        : const LinearGradient(
                            colors: [_T.gradStart, _T.gradEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isSending ? _T.border : null,
                    boxShadow: isSending
                        ? []
                        : [
                            BoxShadow(
                              color: _T.rose.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: _T.rose,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard({required Widget child, Color accent = _T.border}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _T.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3.5)),
      ),
      child: child,
    );
  }

  Widget _xBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 14,
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildJoinBanner() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_T.gradStart, _T.gradEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _T.rose.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleJoinGroup,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("🌸 ", style: TextStyle(fontSize: 16)),
                  Text(
                    "Join this Community",
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _T.elevated,
            ),
            child: const Text("🌿", style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 16),
          Text(
            "Nothing here yet",
            style: GoogleFonts.nunito(
              color: _T.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Start the conversation ✨",
            style: GoogleFonts.nunito(color: _T.textSec, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFE57373)
            : (isSuccess ? _T.mint : _T.textPri),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  bool _isContentSafe(String text) {
    final clean = text.toLowerCase();
    if (clean.contains('@') || clean.contains('.com')) return false;
    if (RegExp(r'\d{10,}').hasMatch(clean.replaceAll(' ', ''))) return false;
    final blacklist = ['whatsapp', 'call me', 'phone', 'pay outside'];
    return !blacklist.any((w) => clean.contains(w));
  }
}

// ──────────────────────────────────────────────────────────────────────
// PLAN LIMIT DETAIL SHEET  (shown when joining from GroupDetailScreen)
// ──────────────────────────────────────────────────────────────────────
class _PlanLimitDetailSheet extends StatelessWidget {
  final String groupName;
  final String? groupImageUrl;
  final int memberCount;

  const _PlanLimitDetailSheet({
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Gradient icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.65)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 18),

          Text(
            'Hub Limit Reached',
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
              'Upgrade your plan to join "$groupName" and unlock access to more exclusive communities.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
          ),
          const SizedBox(height: 28),

          // Plan comparison row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _TierCell(label: 'Free', detail: '1 hub', isCurrent: true),
                const SizedBox(width: 8),
                _TierCell(
                    label: 'Plus',
                    detail: '3 hubs',
                    color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _TierCell(
                    label: 'Pro',
                    detail: '5 hubs',
                    color: const Color(0xFFD97706)),
                const SizedBox(width: 8),
                _TierCell(
                    label: 'Business',
                    detail: '∞ hubs',
                    color: const Color(0xFF7C3AED)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CTA
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
                          fontSize: 14, fontWeight: FontWeight.w700),
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
                  color: Colors.grey[500], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCell extends StatelessWidget {
  final String label;
  final String detail;
  final Color? color;
  final bool isCurrent;

  const _TierCell({
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
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.grey : effectiveColor)),
            Text(detail,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isCurrent ? Colors.grey[500] : effectiveColor)),
            if (isCurrent)
              Text('Current',
                  style: GoogleFonts.poppins(
                      fontSize: 8.5, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
