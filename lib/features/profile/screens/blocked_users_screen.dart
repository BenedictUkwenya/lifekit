import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';

/// People the user has blocked, with one-tap unblock.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _api = ApiService();
  final _listKey = GlobalKey<AnimatedListState>();
  final Set<String> _busy = {};
  List<Map<String, dynamic>>? _users;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _api.getBlockedUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _unblock(int index) async {
    final l10n = AppLocalizations.of(context);
    final user = _users![index];
    final id = '${user['id']}';
    setState(() => _busy.add(id));
    try {
      await _api.unblockUser(id);
      if (!mounted) return;
      final removed = _users!.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: _UserRow(user: removed, busy: false)),
        ),
        duration: Motion.medium,
      );
      setState(() => _busy.remove(id));
      AppToast.success(context, l10n.userUnblocked(_name(removed, l10n)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  static String _name(Map u, AppLocalizations l10n) =>
      (u['full_name'] ?? u['username'] ?? l10n.blockedUserFallbackName).toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: AnimatedSwitcher(
        duration: Motion.medium,
        child: _body(l10n),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_error != null && _users == null) {
      return _Message(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        title: appErrorMessage(context, _error),
        action: TextButton.icon(
          onPressed: () {
            setState(() => _error = null);
            _load();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      );
    }
    if (_users == null) return const SkeletonList(key: ValueKey('loading'), count: 4, thumbSize: 48);
    if (_users!.isEmpty) {
      return _Message(
        key: const ValueKey('empty'),
        icon: Icons.verified_user_outlined,
        title: l10n.blockedUsersEmpty,
        subtitle: l10n.blockedUsersEmptySub,
      );
    }
    return AnimatedList(
      key: _listKey,
      padding: const EdgeInsets.all(16),
      initialItemCount: _users!.length,
      itemBuilder: (context, i, anim) {
        final u = _users![i];
        return _UserRow(
          user: u,
          busy: _busy.contains('${u['id']}'),
          onUnblock: () => _unblock(i),
        ).fadeSlideIn(index: i);
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool busy;
  final VoidCallback? onUnblock;

  const _UserRow({required this.user, required this.busy, this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pic = user['profile_picture_url'] as String?;
    final name = (user['full_name'] ?? user['username'] ?? l10n.blockedUserFallbackName).toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              backgroundImage: pic != null && pic.startsWith('http') ? CachedNetworkImageProvider(pic) : null,
              child: pic != null && pic.startsWith('http')
                  ? null
                  : Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (user['username'] != null)
                    Text('@${user['username']}',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: busy
                  ? const SizedBox(
                      key: ValueKey('busy'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      key: const ValueKey('btn'),
                      onPressed: onUnblock,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: Text(l10n.unblock, style: GoogleFonts.poppins(fontSize: 13)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const _Message({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ).popIn(),
            const SizedBox(height: 18),
            Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))
                .fadeSlideIn(index: 1),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]))
                  .fadeSlideIn(index: 2),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
