import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/screens/group_detail_screen.dart';
import '../../provider/screens/subscription_plans_screen.dart';
import '../../services/screens/service_booking_detail_screen.dart';

/// Gracia — LifeKit's AI assistant.
///
/// Each message: { role: 'user'|'ai', text, actions?, failed?, animate? }.
/// The conversation is kept on the device (last [_maxStored] messages).
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  static const _maxStored = 40;

  final ApiService _apiService = ApiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;
  bool _restored = false;
  bool _upgradeShown = false;
  bool? _isPremium; // null until the profile loads
  String? _userAvatarUrl;
  String _userInitial = '?';
  String? _storeKey;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() => setState(() {}));
    _loadProfileAndHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Profile + saved conversation ─────────────────────────────────────────

  Future<void> _loadProfileAndHistory() async {
    try {
      final data = await _apiService.getUserProfile();
      final profile = data['profile'] as Map<String, dynamic>?;
      if (profile != null && mounted) {
        final tier = (profile['subscription_tier'] ?? '').toString().toLowerCase();
        final trialEnd = DateTime.tryParse('${profile['trial_end_date'] ?? ''}');
        setState(() {
          _userAvatarUrl = profile['profile_picture_url']?.toString();
          final name = (profile['full_name'] ?? profile['username'] ?? '').toString().trim();
          _userInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          _isPremium = tier == 'pro' ||
              tier == 'business' ||
              (trialEnd != null && trialEnd.isAfter(DateTime.now()));
        });
      }
    } catch (_) {}

    try {
      final uid = await _apiService.getCurrentUserId();
      _storeKey = 'gracia_chat_${uid ?? 'anon'}';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey!);
      if (raw != null && mounted) {
        final saved = (jsonDecode(raw) as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        setState(() => _messages.insertAll(0, saved));
        _scrollToBottom(jump: true);
      }
    } catch (_) {}
    if (mounted) setState(() => _restored = true);
  }

  Future<void> _persist() async {
    if (_storeKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keep = _messages
          .where((m) => m['failed'] != true)
          .map((m) => {'role': m['role'], 'text': m['text'], 'actions': m['actions'] ?? []})
          .toList();
      final trimmed = keep.length > _maxStored ? keep.sublist(keep.length - _maxStored) : keep;
      await prefs.setString(_storeKey!, jsonEncode(trimmed));
    } catch (_) {}
  }

  Future<void> _newChat() async {
    final l10n = AppLocalizations.of(context);
    if (_messages.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.aiNewChatConfirm, style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.aiNewChat)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(_messages.clear);
    _persist();
  }

  // ── Sending ──────────────────────────────────────────────────────────────

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(end, duration: Motion.medium, curve: Motion.curve);
      }
    });
  }

  Future<void> _send([String? preset, Map<String, dynamic>? retryOf]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _isThinking) return;
    if (preset == null) _inputController.clear();
    HapticFeedback.lightImpact();

    final history = _messages
        .where((m) => m['failed'] != true && m != retryOf)
        .map((m) => {'role': m['role'] == 'user' ? 'user' : 'model', 'text': '${m['text']}'})
        .toList();

    final userMsg = retryOf ?? <String, dynamic>{'role': 'user', 'text': text};
    setState(() {
      if (retryOf != null) {
        retryOf.remove('failed');
      } else {
        _messages.add(userMsg);
      }
      _isThinking = true;
    });
    _scrollToBottom();

    final l10n = AppLocalizations.of(context);
    try {
      final response = await _apiService.sendAiChatMessage(text, history);
      final reply = (response['reply'] ?? '').toString().trim();
      final actions = (response['actions'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add({
          'role': 'ai',
          'text': reply.isEmpty ? l10n.aiFallbackReply : reply,
          'actions': actions,
          'animate': true,
        });
      });
      _persist();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        userMsg['failed'] = true;
      });
      if (e is UpgradeRequiredException) {
        setState(() => _isPremium = false);
        if (!_upgradeShown) {
          _upgradeShown = true;
          _showUpgradeDialog();
        }
      }
    }
  }

  void _showUpgradeDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Flexible(child: Text(l10n.aiProFeatureTitle)),
          ],
        ),
        content: Text(l10n.aiProFeatureBody, style: GoogleFonts.poppins(fontSize: 13, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.aiMaybeLater, style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openPlans();
            },
            child: Text(l10n.aiUpgradeNow),
          ),
        ],
      ),
    );
  }

  void _openPlans() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
      );

  void _handleAction(Map<String, dynamic> action) {
    final id = action['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (action['type'] == 'service') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceBookingDetailScreen(
            serviceId: id,
            serviceTitle: (action['title'] ?? action['label'] ?? '').toString(),
            providerId: action['provider_id']?.toString() ?? '',
          ),
        ),
      );
    } else if (action['type'] == 'community') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const _GraciaAvatar(size: 40),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gracia', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Pulse(
                      active: _isThinking,
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                      ),
                    ),
                    Text(
                      l10n.aiAlwaysHereForYou,
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: l10n.aiNewChat,
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _newChat,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isPremium == false) _ProBanner(onTap: _openPlans).fadeSlideIn(),
          Expanded(child: _messages.isEmpty && _restored ? _buildWelcome(l10n) : _buildMessageList()),
          _buildInputBar(l10n),
        ],
      ),
    );
  }

  Widget _buildWelcome(AppLocalizations l10n) {
    final prompts = [
      (Icons.cleaning_services_rounded, l10n.aiSuggest1),
      (Icons.trending_up_rounded, l10n.aiSuggest2),
      (Icons.swap_horiz_rounded, l10n.aiSuggest3),
      (Icons.groups_rounded, l10n.aiSuggest4),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
            ),
            child: const _GraciaAvatar(size: 84),
          ).popIn(),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.aiGraciaGreeting,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 15, height: 1.5, color: AppColors.textDark),
        ).fadeSlideIn(index: 1),
        const SizedBox(height: 28),
        Text(
          l10n.aiTryAsking.toUpperCase(),
          style: GoogleFonts.poppins(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: Colors.grey[500]),
        ).fadeSlideIn(index: 2),
        const SizedBox(height: 10),
        for (var i = 0; i < prompts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              onTap: () => _send(prompts[i].$2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(prompts[i].$1, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(prompts[i].$2, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ),
                    Icon(Icons.north_east_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            ).fadeSlideIn(index: 3 + i),
          ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
      itemCount: _messages.length + (_isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const _Bubble(isUser: false, child: _BouncingDots()).fadeSlideIn();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final bubble = isUser ? _buildUserMessage(msg) : _buildAiMessage(msg);
        // Only freshly added messages animate in.
        return index >= _messages.length - 2 ? bubble.fadeSlideIn(dy: 0.15) : bubble;
      },
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> msg) {
    final failed = msg['failed'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Bubble(
          isUser: true,
          trailing: _buildUserAvatar(),
          onLongPress: () => _copy(msg['text']),
          child: Text(
            '${msg['text']}',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, height: 1.45),
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(right: 44, bottom: 8),
            child: GestureDetector(
              onTap: () => _send('${msg['text']}', msg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).aiTapRetry,
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFFDC2626), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ).animate().shakeX(hz: 4, amount: 3, duration: 400.ms),
      ],
    );
  }

  Widget _buildAiMessage(Map<String, dynamic> msg) {
    final actions = ((msg['actions'] as List?) ?? const [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final animate = msg['animate'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(
          isUser: false,
          onLongPress: () => _copy(msg['text']),
          child: animate
              ? _Typewriter(
                  text: '${msg['text']}',
                  onDone: () {
                    msg.remove('animate');
                    if (mounted) setState(() {});
                  },
                  onTick: _scrollToBottom,
                )
              : Text('${msg['text']}', style: _aiTextStyle),
        ),
        if (actions.isNotEmpty && !animate)
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 44, bottom: 14),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ActionCard(action: actions[i], onTap: () => _handleAction(actions[i]))
                  .fadeSlideIn(index: i, dy: 0.2),
            ),
          ),
      ],
    );
  }

  void _copy(dynamic text) {
    Clipboard.setData(ClipboardData(text: '$text'));
    HapticFeedback.selectionClick();
    AppToast.info(context, AppLocalizations.of(context).aiCopied);
  }

  Widget _buildUserAvatar() {
    if (_userAvatarUrl != null && _userAvatarUrl!.startsWith('http')) {
      return CircleAvatar(radius: 15, backgroundImage: CachedNetworkImageProvider(_userAvatarUrl!));
    }
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFF7C3AED),
      child: Text(_userInitial,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    final canSend = _inputController.text.trim().isNotEmpty && !_isThinking;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 24),
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
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.aiMessageHint,
                  hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: canSend ? () => _send() : null,
            child: AnimatedContainer(
              duration: Motion.fast,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(colors: [AppColors.primary, Color(0xFFBF3F5E)])
                    : null,
                color: canSend ? null : const Color(0xFFE5E5EA),
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: canSend ? 0 : -0.125,
                duration: Motion.fast,
                child: Icon(Icons.arrow_upward_rounded, color: canSend ? Colors.white : Colors.grey[400], size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _aiTextStyle = GoogleFonts.poppins(color: Colors.black87, fontSize: 14, height: 1.55);

// ── Pieces ─────────────────────────────────────────────────────────────────

class _GraciaAvatar extends StatelessWidget {
  final double size;
  const _GraciaAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: ClipOval(child: Image.asset('assets/ai/aihalfpic.jpg', fit: BoxFit.cover)),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onLongPress;

  const _Bubble({required this.isUser, required this.child, this.trailing, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          gradient: isUser ? const LinearGradient(colors: [AppColors.primary, Color(0xFFA8324D)]) : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 18 : 4),
            topRight: Radius.circular(isUser ? 4 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isUser
            ? [const SizedBox(width: 56), Flexible(child: bubble), const SizedBox(width: 8), ?trailing]
            : [const _GraciaAvatar(size: 34), const SizedBox(width: 10), Flexible(child: bubble), const SizedBox(width: 40)],
      ),
    );
  }
}

/// Reveals the reply a few characters at a time. Tap to show it all.
class _Typewriter extends StatefulWidget {
  final String text;
  final VoidCallback onDone;
  final VoidCallback onTick;

  const _Typewriter({required this.text, required this.onDone, required this.onTick});

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Longer replies type faster so nobody waits more than ~2.5 s.
    final step = (widget.text.length / 120).ceil().clamp(1, 8);
    _timer = Timer.periodic(const Duration(milliseconds: 18), (t) {
      if (!mounted) return t.cancel();
      setState(() => _shown = (_shown + step).clamp(0, widget.text.length));
      if (_shown % 40 < step) widget.onTick();
      if (_shown >= widget.text.length) _finish();
    });
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish,
      child: Text(widget.text.substring(0, _shown), style: _aiTextStyle),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Map<String, dynamic> action;
  final VoidCallback onTap;

  const _ActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isService = action['type'] == 'service';
    final image = action['image_url']?.toString();
    final price = num.tryParse('${action['price']}');
    final rating = num.tryParse('${action['rating']}');
    final title = (action['title'] ?? action['label'] ?? '').toString();

    return Pressable(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 84,
              width: double.infinity,
              child: image != null && image.startsWith('http')
                  ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_, _, _) => _placeholder(isService))
                  : _placeholder(isService),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                (isService ? l10n.aiCardService : l10n.aiCardCommunity).toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 9.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25)),
            ),
            const Spacer(),
            if (isService)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    if (price != null)
                      Text('\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const Spacer(),
                    if (rating != null && rating > 0) ...[
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                      Text(rating.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isService) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isService
                ? [AppColors.primary.withValues(alpha: 0.85), const Color(0xFFBF3F5E)]
                : [const Color(0xFF7C3AED), const Color(0xFF3B82F6)],
          ),
        ),
        child: Icon(isService ? Icons.handyman_rounded : Icons.groups_rounded, color: Colors.white, size: 30),
      );
}

class _ProBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ProBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFDF2F8)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.aiFreeBanner, style: GoogleFonts.poppins(fontSize: 12, height: 1.35, color: const Color(0xFF7C2D12))),
          ),
          TextButton(onPressed: onTap, child: Text(l10n.aiSeePlans)),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 150).ms)
            .moveY(begin: 0, end: -6, duration: 450.ms, curve: Curves.easeInOut);
      }),
    );
  }
}
