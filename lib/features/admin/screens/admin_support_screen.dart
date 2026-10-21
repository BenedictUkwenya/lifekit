import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Support tickets and user reports (web: Support page).
class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return DefaultTabController(
      length: 2,
      child: AdminScaffold(
        title: t('support'),
        bottom: TabBar(
          labelColor: AdminPalette.primary,
          unselectedLabelColor: AdminPalette.textMuted,
          indicatorColor: AdminPalette.primary,
          labelStyle: adminText(14, weight: FontWeight.w600),
          tabs: [Tab(text: t('tickets')), Tab(text: t('reports'))],
        ),
        body: const TabBarView(children: [_TicketsTab(), _ReportsTab()]),
      ),
    );
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  String _filter = 'open';

  @override
  bool get wantKeepAlive => true;

  Future<void> _open(Map ticket, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final replyCtrl = TextEditingController();
    final isOpen = ticket['status'] == 'open';
    final send = await showAdminSheet<bool>(
      context,
      title: '${ticket['subject'] ?? t('ticket')}',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminField(
                  t('from'),
                  [ticket['profiles']?['full_name'], ticket['profiles']?['email']]
                      .whereType<String>()
                      .join(' · '),
                ),
              ),
              AdminStatusPill('${ticket['status']}'),
            ],
          ),
          AdminField(t('received'), adminDate(ctx, ticket['created_at'], withTime: true)),
          _Bubble(text: '${ticket['message'] ?? ''}', mine: false),
          if (ticket['admin_reply'] != null) ...[
            const SizedBox(height: 10),
            _Bubble(text: '${ticket['admin_reply']}', mine: true),
          ],
          if (isOpen) ...[
            const SizedBox(height: 16),
            AdminTextInput(controller: replyCtrl, label: t('yourReply'), maxLines: 4),
            AdminButton(
              label: t('replyAndClose'),
              icon: Icons.send_rounded,
              onPressed: () {
                if (replyCtrl.text.trim().isEmpty) {
                  adminToast(ctx, t('messageRequired'), error: true);
                } else {
                  Navigator.pop(ctx, true);
                }
              },
            ),
          ],
        ],
      ),
    );
    final reply = replyCtrl.text.trim();
    replyCtrl.dispose();
    if (send != true || !mounted) return;
    final ok = await adminRun(
      context,
      () => _api.adminReplyTicket('${ticket['id']}', reply),
      success: t('replySent'),
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminSupportTickets,
      builder: (context, all, reload) {
        final tickets = all.whereType<Map>().toList();
        final items = tickets.where((x) => _filter == 'all' || x['status'] == _filter).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AdminFilterBar(
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
              options: {
                'open': '${t.status('open')} (${tickets.where((x) => x['status'] == 'open').length})',
                'closed': t.status('closed'),
                'all': t('all'),
              },
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              AdminEmptyState(icon: Icons.support_agent_rounded, message: t('noTickets')),
            for (final x in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  onTap: () => _open(x, reload),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${x['subject'] ?? t('ticket')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: adminText(14, weight: FontWeight.w600),
                            ),
                          ),
                          AdminStatusPill('${x['status']}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${x['message'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: adminText(12, color: AdminPalette.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${x['profiles']?['full_name'] ?? t('unknown')} · ${adminDate(context, x['created_at'])}',
                        style: adminText(11, color: AdminPalette.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  String _filter = 'pending';

  @override
  bool get wantKeepAlive => true;

  Future<void> _resolve(Map r, Future<void> Function() reload, {bool suspend = false}) async {
    final t = AdminStrings.of(context);
    if (suspend) {
      final ok = await adminConfirm(
        context,
        title: t('suspendAndResolve'),
        message: t('changeStatusMessage', {'name': '${r['reported']?['full_name'] ?? ''}'}),
        confirmLabel: t.status('suspended'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final done = await adminRun(context, () async {
      if (suspend) {
        await _api.adminSetUserStatus('${r['reported_user_id']}', 'suspended');
      }
      await _api.adminResolveReport('${r['id']}');
    }, success: t('reportResolved'));
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AdminStrings.of(context);
    return AdminLoader<List<dynamic>>(
      load: _api.adminReports,
      builder: (context, all, reload) {
        final reports = all.whereType<Map>().toList();
        final items = reports.where((x) => _filter == 'all' || x['status'] == _filter).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AdminFilterBar(
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
              options: {
                'pending': '${t.status('pending')} (${reports.where((x) => x['status'] == 'pending').length})',
                'resolved': t.status('resolved'),
                'all': t('all'),
              },
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              AdminEmptyState(icon: Icons.flag_outlined, message: t('noReports')),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded, color: AdminPalette.danger, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${r['reason'] ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: adminText(14, weight: FontWeight.w600),
                            ),
                          ),
                          AdminStatusPill('${r['status']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: adminText(12, color: AdminPalette.textMuted),
                          children: [
                            TextSpan(text: '${t('reported')}: '),
                            TextSpan(
                              text: '${r['reported']?['full_name'] ?? t('unknown')}',
                              style: adminText(12, weight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: '  ·  ${t('by')} ${r['reporter']?['full_name'] ?? t('unknown')}',
                            ),
                          ],
                        ),
                      ),
                      if ('${r['details'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${r['details']}',
                          style: adminText(13, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        adminDate(context, r['created_at']),
                        style: adminText(11, color: AdminPalette.textFaint),
                      ),
                      if (r['status'] == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AdminButton(
                                label: t('suspendUser'),
                                outlined: true,
                                destructive: true,
                                onPressed: () => _resolve(r, reload, suspend: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AdminButton(
                                label: t('markResolved'),
                                onPressed: () => _resolve(r, reload),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;

  const _Bubble({required this.text, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? AdminPalette.primary : AdminPalette.neutralBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: adminText(13, height: 1.4, color: mine ? Colors.white : AdminPalette.textDark),
        ),
      ),
    );
  }
}
