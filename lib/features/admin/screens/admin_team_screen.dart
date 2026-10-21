import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Platform admin accounts (web: Settings → Admin team).
class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  final _api = ApiService();

  Future<(List<dynamic>, String?)> _load() async {
    final results = await Future.wait<Object?>([_api.adminTeam(), _api.getCurrentUserId()]);
    return (results[0] as List<dynamic>, results[1] as String?);
  }

  Future<void> _invite(Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final ok = await showAdminSheet<bool>(
      context,
      title: t('inviteAdmin'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('inviteAdminNote'), style: adminText(12, color: AdminPalette.textMuted, height: 1.4)),
          const SizedBox(height: 14),
          AdminTextInput(controller: name, label: t('fullName')),
          AdminTextInput(controller: email, label: t('email'), keyboardType: TextInputType.emailAddress),
          AdminTextInput(controller: password, label: t('tempPassword'), obscure: true),
          AdminButton(
            label: t('createAdmin'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () {
              final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());
              if (name.text.trim().isEmpty || !validEmail || password.text.length < 6) {
                adminToast(ctx, t('inviteValidation'), error: true);
              } else {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );
    final values = (name.text.trim(), email.text.trim(), password.text);
    name.dispose();
    email.dispose();
    password.dispose();
    if (ok != true || !mounted) return;
    final done = await adminRun(
      context,
      () => _api.adminInvite(fullName: values.$1, email: values.$2, password: values.$3),
      success: t('adminCreated'),
    );
    if (done) await reload();
  }

  Future<void> _remove(Map a, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final ok = await adminConfirm(
      context,
      title: t('removeAdmin'),
      message: t('removeAdminMessage', {'name': '${a['full_name'] ?? a['email'] ?? ''}'}),
      confirmLabel: t('remove'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await adminRun(context, () => _api.adminRemove('${a['id']}'), success: t('adminRemoved'));
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('team'),
      body: AdminLoader<(List<dynamic>, String?)>(
        load: _load,
        builder: (context, data, reload) {
          final admins = data.$1.whereType<Map>().toList();
          final me = data.$2;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  AdminSectionTitle(t('adminsCount', {'n': '${admins.length}'})),
                  AdminCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < admins.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 72, color: AdminPalette.border),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: AdminAvatar(
                              url: admins[i]['profile_picture_url'],
                              name: admins[i]['full_name'],
                            ),
                            title: Text(
                              '${admins[i]['full_name'] ?? t('unknown')}${admins[i]['id'] == me ? ' (${t('you')})' : ''}',
                              style: adminText(14, weight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${admins[i]['email'] ?? ''}',
                              style: adminText(12, color: AdminPalette.textMuted),
                            ),
                            trailing: admins[i]['id'] == me
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.person_remove_outlined),
                                    color: AdminPalette.danger,
                                    tooltip: t('remove'),
                                    onPressed: () => _remove(admins[i], reload),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'inviteAdmin',
                  backgroundColor: AdminPalette.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => _invite(reload),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(t('inviteAdmin'), style: adminText(13, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
