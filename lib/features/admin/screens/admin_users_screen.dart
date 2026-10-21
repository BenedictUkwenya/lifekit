import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// User directory with moderation + direct alerts (web: User Monitor page).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = ApiService();
  String _filter = 'all';
  String _query = '';

  static String _statusOf(Map u) => '${u['status'] ?? 'active'}';

  Future<void> _open(Map u, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final action = await showAdminSheet<String>(
      context,
      title: t('userDetails'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AdminAvatar(url: u['profile_picture_url'], name: u['full_name'], radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${u['full_name'] ?? t('unknown')}',
                      style: adminText(17, weight: FontWeight.w700),
                    ),
                    Text(
                      '${u['email'] ?? ''}',
                      style: adminText(13, color: AdminPalette.textMuted),
                    ),
                  ],
                ),
              ),
              AdminStatusPill(_statusOf(u)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: AdminField(t('role'), t.status('${u['role'] ?? 'user'}'))),
              Expanded(
                child: AdminField(t('plan'), t.status('${u['subscription_tier'] ?? 'free'}')),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: AdminField(t('country'), '${u['country'] ?? '—'}')),
              Expanded(child: AdminField(t('joined'), adminDate(ctx, u['created_at']))),
            ],
          ),
          if (u['phone_number'] != null) AdminField(t('phone'), '${u['phone_number']}'),
          const Divider(height: 24),
          Text(t('accountStatus'), style: adminText(13, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in ['active', 'suspended', 'blocked']) ...[
                if (s != 'active') const SizedBox(width: 8),
                Expanded(
                  child: AdminButton(
                    label: t.status(s),
                    outlined: _statusOf(u) != s,
                    destructive: s == 'blocked',
                    onPressed: _statusOf(u) == s ? null : () => Navigator.pop(ctx, 'status:$s'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AdminButton(
            label: t('sendAlert'),
            icon: Icons.campaign_outlined,
            outlined: true,
            onPressed: () => Navigator.pop(ctx, 'notify'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    if (action.startsWith('status:')) {
      final status = action.substring(7);
      if (status != 'active') {
        final ok = await adminConfirm(
          context,
          title: t('changeStatusTitle', {'status': t.status(status)}),
          message: t('changeStatusMessage', {'name': '${u['full_name'] ?? ''}'}),
          confirmLabel: t.status(status),
          destructive: true,
        );
        if (!ok || !mounted) return;
      }
      final done = await adminRun(
        context,
        () => _api.adminSetUserStatus('${u['id']}', status),
        success: t('statusUpdated'),
      );
      if (done) await reload();
    } else if (action == 'notify') {
      await _notify(u);
    }
  }

  Future<void> _notify(Map u) async {
    final t = AdminStrings.of(context);
    final titleCtrl = TextEditingController(text: t('adminAlert'));
    final msgCtrl = TextEditingController();
    final send = await showAdminSheet<bool>(
      context,
      title: t('sendAlertTo', {'name': '${u['full_name'] ?? ''}'}),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTextInput(controller: titleCtrl, label: t('title')),
          AdminTextInput(controller: msgCtrl, label: t('message'), maxLines: 4),
          AdminButton(
            label: t('send'),
            icon: Icons.send_rounded,
            onPressed: () {
              if (msgCtrl.text.trim().isEmpty) {
                adminToast(ctx, t('messageRequired'), error: true);
              } else {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final message = msgCtrl.text.trim();
    titleCtrl.dispose();
    msgCtrl.dispose();
    if (send != true || !mounted) return;
    await adminRun(
      context,
      () => _api.adminNotifyUser('${u['id']}', title, message),
      success: t('alertSent'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('users'),
      body: AdminLoader<List<dynamic>>(
        load: _api.adminUsers,
        builder: (context, all, reload) {
          final users = all.whereType<Map>().toList();
          final q = _query.toLowerCase();
          final items = users.where((u) {
            if (_filter == 'admin' && u['role'] != 'admin') return false;
            if (_filter != 'all' && _filter != 'admin' && _statusOf(u) != _filter) {
              return false;
            }
            if (q.isEmpty) return true;
            return '${u['full_name']} ${u['email']} ${u['username']}'.toLowerCase().contains(q);
          }).toList();
          int count(String s) => users.where((u) => _statusOf(u) == s).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              AdminSearchField(
                hint: t('searchUsers'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              AdminFilterBar(
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
                options: {
                  'all': '${t('all')} (${users.length})',
                  'active': '${t.status('active')} (${count('active')})',
                  'suspended': '${t.status('suspended')} (${count('suspended')})',
                  'blocked': '${t.status('blocked')} (${count('blocked')})',
                  'admin': t('admins'),
                },
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                AdminEmptyState(icon: Icons.person_search_outlined, message: t('noResults')),
              for (final u in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () => _open(u, reload),
                    child: Row(
                      children: [
                        AdminAvatar(url: u['profile_picture_url'], name: u['full_name']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${u['full_name'] ?? t('unknown')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: adminText(14, weight: FontWeight.w600),
                                    ),
                                  ),
                                  if (u['role'] == 'admin') ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_user_rounded,
                                      size: 15,
                                      color: AdminPalette.primary,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${u['email'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: adminText(12, color: AdminPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AdminStatusPill(_statusOf(u)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
