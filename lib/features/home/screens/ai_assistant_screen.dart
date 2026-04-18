import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../services/screens/service_booking_detail_screen.dart';
import '../../groups/screens/group_detail_screen.dart';
import '../../provider/screens/subscription_plans_screen.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Each message: { 'role': 'user'|'ai', 'text': string, 'actions': List? }
  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;
  String? _userAvatarUrl;
  String _userInitial = '?';

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'text':
          "Hello! I'm your LifeKit assistant — here to help you discover services, find your community, and make the most of your day. What can I do for you?",
      'actions': <dynamic>[],
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _apiService.getUserProfile();
      final profile = data['profile'] as Map<String, dynamic>?;
      if (profile != null && mounted) {
        setState(() {
          _userAvatarUrl = profile['profile_picture_url']?.toString();
          final name = (profile['full_name'] ?? profile['username'] ?? '')
              .toString()
              .trim();
          _userInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    _inputController.clear();

    final List<Map<String, String>> history = _messages
        .where((m) => m['text'] != null)
        .map(
          (m) => {
            'role': m['role'] == 'user' ? 'user' : 'model',
            'text': (m['text'] as String),
          },
        )
        .toList();

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'actions': <dynamic>[]});
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final response = await _apiService.sendAiChatMessage(text, history);
      final String reply =
          response['reply'] ?? 'Sorry, I could not get a response.';
      final List<dynamic> actions = response['actions'] ?? [];

      if (mounted) {
        setState(() {
          _isThinking = false;
          _messages.add({'role': 'ai', 'text': reply, 'actions': actions});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (e is UpgradeRequiredException) {
        if (mounted) {
          setState(() => _isThinking = false);
          _showUpgradeDialog();
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isThinking = false;
          _messages.add({
            'role': 'ai',
            'text': 'Something went wrong. Please try again.',
            'actions': <dynamic>[],
          });
        });
        _scrollToBottom();
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🔒', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'Pro Feature',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'The LifeKit AI Assistant is available on Pro and Business plans. Upgrade to unlock AI chat, smart recommendations, and more.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionPlansScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Upgrade Now ⚡',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(Map<String, dynamic> action) {
    final type = action['type'];
    final id = action['id']?.toString() ?? '';
    final label = action['label']?.toString() ?? '';

    if (type == 'service') {
      final providerId = action['provider_id']?.toString() ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceBookingDetailScreen(
            serviceId: id,
            serviceTitle: label,
            providerId: providerId,
          ),
        ),
      );
    } else if (type == 'community') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black12,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Logo avatar on subtle tinted circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(9),
            child: Image.asset(
              'assets/images/logo_black.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LifeKit AI',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'Always here for you',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
      itemCount: _messages.length + (_isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isThinking && index == _messages.length) {
          return _AnimatedMessageWrapper(
            key: const ValueKey('thinking'),
            child: _buildThinkingBubble(),
          );
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _AnimatedMessageWrapper(
          key: ValueKey('msg_$index'),
          child: isUser
              ? _buildUserBubble(msg['text'] as String)
              : _buildAiBubble(msg),
        );
      },
    );
  }

  Widget _buildUserBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 64),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildUserAvatar(radius: 15),
        ],
      ),
    );
  }

  Widget _buildUserAvatar({required double radius}) {
    if (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_userAvatarUrl!),
        backgroundColor: AppColors.primary.withOpacity(0.15),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF7C3AED),
      child: Text(
        _userInitial,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAiAvatar({double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.09),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.22),
      child: Image.asset('assets/images/logo_black.png', fit: BoxFit.contain),
    );
  }

  Widget _buildAiBubble(Map<String, dynamic> msg) {
    final text = msg['text'] as String;
    final actions = (msg['actions'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ),
                // Action chips
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: actions.map((a) {
                      final action = Map<String, dynamic>.from(a as Map);
                      final isService = action['type'] == 'service';
                      return GestureDetector(
                        onTap: () => _handleAction(action),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isService
                                    ? Icons.open_in_new_rounded
                                    : Icons.group_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                action['label']?.toString() ?? 'View',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _BouncingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 28,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message LifeKit AI…',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isThinking ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isThinking
                    ? const Color(0xFFE5E5EA)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: _isThinking ? Colors.grey[400] : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fade + slide in for every new message ──────────────────────────────────
class _AnimatedMessageWrapper extends StatefulWidget {
  final Widget child;
  const _AnimatedMessageWrapper({required this.child, super.key});

  @override
  State<_AnimatedMessageWrapper> createState() =>
      _AnimatedMessageWrapperState();
}

class _AnimatedMessageWrapperState extends State<_AnimatedMessageWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Bouncing typing indicator ──────────────────────────────────────────────
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _anims = _controllers.map((c) {
      return Tween<double>(
        begin: 0,
        end: -6,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    // Start each dot with a staggered delay
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
