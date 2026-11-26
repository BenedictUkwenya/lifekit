import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_lottie.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';

/// Comments for a feed post (or group post).
///
/// Posting is optimistic: your comment appears at once (faded while sending),
/// and is removed again with your text restored if the server refuses it.
/// Feed comments support one level of replies.
class CommentsSheet extends StatefulWidget {
  final String postId;
  final bool isGroup;
  final VoidCallback? onCommentPosted;
  /// Called with how many comments were removed (a comment plus its replies).
  final ValueChanged<int>? onCommentsDeleted;

  const CommentsSheet({
    super.key,
    required this.postId,
    this.isGroup = false,
    this.onCommentPosted,
    this.onCommentsDeleted,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _failed = false;
  String? _myId;
  Map<String, dynamic>? _me; // name + photo for optimistic comments
  Map<String, dynamic>? _replyTo; // the top-level comment being replied to
  final Set<String> _justAdded = {}; // animate only new rows
  int _tmpSeq = 0;

  bool get _repliesEnabled => !widget.isGroup;

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadMe();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      _myId = await _api.getCurrentUserId();
      final p = await _api.getUserProfile();
      final profile = p['profile'];
      if (profile is Map && mounted) setState(() => _me = Map<String, dynamic>.from(profile));
    } catch (_) {}
  }

  Future<void> _fetch() async {
    try {
      final data = widget.isGroup
          ? await _api.getGroupPostComments(widget.postId)
          : await _api.getComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = data.map((c) => Map<String, dynamic>.from(c as Map)).toList();
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  // Groups keep their public-space safety filter.
  bool _isSafe(String text) {
    if (!widget.isGroup) return true;
    final clean = text.toLowerCase().replaceAll(' ', '');
    final hasEmail = clean.contains('@') || clean.contains('.com');
    final hasPhone = RegExp(r'\d{10,}').hasMatch(clean);
    const blacklist = ['whatsapp', 'callme', 'telegram', 'zelle', 'cashapp', 'payme'];
    return !hasEmail && !hasPhone && !blacklist.any(clean.contains);
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context);
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (!_isSafe(text)) {
      AppToast.info(context, l10n.commentsSafetyWarning);
      return;
    }
    HapticFeedback.lightImpact();

    final parent = _replyTo;
    final tmpId = 'tmp_${++_tmpSeq}';
    final optimistic = <String, dynamic>{
      'id': tmpId,
      'content': text,
      'user_id': _myId,
      'parent_id': parent?['id'],
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'profiles': {
        'full_name': _me?['full_name'] ?? l10n.commentsYou,
        'profile_picture_url': _me?['profile_picture_url'],
      },
      '_pending': true,
    };
    setState(() {
      _comments.add(optimistic);
      _justAdded.add(tmpId);
      _replyTo = null;
      _input.clear();
    });
    if (parent == null) _scrollToEnd();

    try {
      dynamic saved;
      if (widget.isGroup) {
        await _api.postGroupComment(widget.postId, text); // returns nothing
      } else {
        saved = await _api.postComment(widget.postId, text, parentId: parent?['id']?.toString());
      }
      if (!mounted) return;
      setState(() {
        final i = _comments.indexWhere((c) => c['id'] == tmpId);
        if (i >= 0) {
          _comments[i] = saved is Map
              ? {...Map<String, dynamic>.from(saved), 'profiles': (saved['profiles'] ?? optimistic['profiles'])}
              : {...optimistic, '_pending': false};
        }
      });
      widget.onCommentPosted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c['id'] == tmpId);
        if (_input.text.isEmpty) _input.text = text; // give the text back
        _replyTo = parent;
      });
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final id = c['id']?.toString();
    if (id == null || id.startsWith('tmp_')) return;
    HapticFeedback.mediumImpact();
    // Replies go with their parent.
    final removed = _comments.where((x) => x['id'] == id || x['parent_id'] == id).toList();
    setState(() => _comments.removeWhere((x) => removed.contains(x)));
    try {
      widget.isGroup
          ? await _api.deleteGroupComment(widget.postId, id)
          : await _api.deleteComment(widget.postId, id);
      widget.onCommentsDeleted?.call(removed.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _comments.addAll(removed));
      _comments.sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  void _startReply(Map<String, dynamic> c) {
    HapticFeedback.selectionClick();
    // Replies to a reply attach to the same top-level comment.
    final top = c['parent_id'] == null
        ? c
        : _comments.firstWhere((x) => x['id'] == c['parent_id'], orElse: () => c);
    setState(() => _replyTo = {...top, '_replyName': c['profiles']?['full_name']});
    _focus.requestFocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  String _ago(BuildContext context, dynamic createdAt) {
    final l10n = AppLocalizations.of(context);
    try {
      final diff = DateTime.now().difference(parseApiDate(createdAt));
      if (diff.inMinutes < 1) return l10n.feedsJustNow;
      if (diff.inMinutes < 60) return l10n.feedsMinAgo(diff.inMinutes);
      if (diff.inHours < 24) return l10n.feedsHourAgo(diff.inHours);
      if (diff.inDays < 7) return l10n.feedsDayAgo(diff.inDays);
      return DateFormat('MMM d').format(parseApiDate(createdAt));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final top = _comments.where((c) => c['parent_id'] == null).toList();
    List<Map<String, dynamic>> repliesOf(String id) =>
        _comments.where((c) => c['parent_id']?.toString() == id).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                Text(l10n.txComments, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_comments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${_comments.length}',
                      style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                ],
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SkeletonBox(width: 34, height: 34, radius: 17),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                                SkeletonBox(width: 110, height: 12),
                                SizedBox(height: 8),
                                SkeletonBox(height: 12),
                              ]),
                            ),
                          ]),
                        ),
                    ],
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const AppLottie(AppAnim.chat, size: 120),
                          const SizedBox(height: 8),
                          Text(_failed ? l10n.commentsLoadFailed : l10n.txNoCommentsYetBeTheFirst,
                              style: GoogleFonts.poppins(color: Colors.grey[600])),
                          if (_failed)
                            TextButton(onPressed: () { setState(() => _loading = true); _fetch(); }, child: Text(l10n.retry)),
                        ]),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: top.length,
                        itemBuilder: (context, i) {
                          final c = top[i];
                          final replies = repliesOf('${c['id']}');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row(context, c),
                              for (final r in replies)
                                Padding(
                                  padding: const EdgeInsets.only(left: 44),
                                  child: _row(context, r, small: true),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          // Replying-to bar
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _replyTo == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    color: AppColors.primary.withValues(alpha: 0.06),
                    padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                    child: Row(children: [
                      const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.commentsReplyingTo('${_replyTo!['_replyName'] ?? _replyTo!['profiles']?['full_name'] ?? ''}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _replyTo = null),
                      ),
                    ]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _avatar(_me?['full_name'], _me?['profile_picture_url'], 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        key: const Key('comment_input'),
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _replyTo == null ? l10n.commentsAddHint : l10n.commentsReplyHint,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedScale(
                    scale: _input.text.trim().isEmpty ? 0.85 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: IconButton(
                      key: const Key('comment_send'),
                      onPressed: _input.text.trim().isEmpty ? null : _post,
                      icon: Icon(Icons.send_rounded,
                          color: _input.text.trim().isEmpty ? Colors.grey[400] : AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(dynamic name, dynamic url, double radius) {
    final u = (url ?? '').toString();
    final initial = (name ?? '').toString().trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: u.isNotEmpty ? CachedNetworkImageProvider(u) : null,
      child: u.isNotEmpty
          ? null
          : Text(initial.isEmpty ? '?' : initial[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: radius * 0.85, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> c, {bool small = false}) {
    final l10n = AppLocalizations.of(context);
    final user = c['profiles'] as Map?;
    final pending = c['_pending'] == true;
    final isOwn = _myId != null && c['user_id'] == _myId;
    final id = '${c['id']}';

    Widget row = Opacity(
      opacity: pending ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: small ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(user?['full_name'], user?['profile_picture_url'], small ? 13 : 17),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${user?['full_name'] ?? 'User'}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: small ? 12 : 13)),
                      const SizedBox(height: 2),
                      Text('${c['content'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: small ? 12.5 : 13.5, color: Colors.black87, height: 1.4)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Row(children: [
                      Text(pending ? l10n.commentsSending : _ago(context, c['created_at']),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                      if (_repliesEnabled && !pending) ...[
                        const SizedBox(width: 14),
                        GestureDetector(
                          key: Key('reply_$id'),
                          onTap: () => _startReply(c),
                          child: Text(l10n.commentsReply,
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                        ),
                      ],
                      if (isOwn && !pending) ...[
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () => _delete(c),
                          child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[400]),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_justAdded.contains(id)) {
      row = row.animate().fadeIn(duration: 220.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic);
    }
    return row;
  }
}
