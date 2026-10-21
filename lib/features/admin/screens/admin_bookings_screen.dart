import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Booking monitor with overdue nudges (web: Transactions page).
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _api = ApiService();
  String _filter = 'all';
  String _query = '';

  Future<void> _details(Map b) async {
    final t = AdminStrings.of(context);
    final overdue = b['is_overdue'] == true;
    final nudge = await showAdminSheet<bool>(
      context,
      title: t('bookingDetails'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: AdminField(t('reference'), adminRef(b['id']))),
              AdminStatusPill('${b['status']}'),
            ],
          ),
          AdminField(t('service'), '${b['services']?['title'] ?? '—'}'),
          AdminField(t('client'), '${b['profiles']?['full_name'] ?? t('unknown')}'),
          AdminField(
            t('provider'),
            '${b['services']?['profiles']?['full_name'] ?? t('unknown')}',
          ),
          AdminField(
            t('amount'),
            adminMoney(b['total_price']),
            valueColor: AdminPalette.primary,
          ),
          AdminField(t('scheduledFor'), adminDate(ctx, b['scheduled_time'], withTime: true)),
          AdminField(t('created'), adminDate(ctx, b['created_at'], withTime: true)),
          if (overdue) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AdminPalette.warningBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AdminPalette.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('overdueExplainer'),
                      style: adminText(12, color: AdminPalette.warning),
                    ),
                  ),
                ],
              ),
            ),
            AdminButton(
              label: t('sendNudge'),
              icon: Icons.notifications_active_outlined,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ],
      ),
    );
    if (nudge == true && mounted) {
      await adminRun(
        context,
        () => _api.adminNudgeBooking('${b['id']}'),
        success: t('nudgeSent'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('transactions'),
      body: AdminLoader<Map<String, dynamic>>(
        load: _api.adminBookings,
        builder: (context, data, reload) {
          final all = (data['bookings'] as List?)?.whereType<Map>().toList() ?? [];
          final overdueCount = all.where((b) => b['is_overdue'] == true).length;
          final volume = all.fold<double>(
            0,
            (s, b) => s + ((num.tryParse('${b['total_price']}') ?? 0)).toDouble(),
          );
          final q = _query.toLowerCase();
          final items = all.where((b) {
            if (_filter == 'overdue' && b['is_overdue'] != true) return false;
            if (_filter != 'all' && _filter != 'overdue' && b['status'] != _filter) {
              return false;
            }
            if (q.isEmpty) return true;
            return '${b['services']?['title']} ${b['profiles']?['full_name']} ${b['services']?['profiles']?['full_name']} ${b['id']}'
                .toLowerCase()
                .contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: AdminStatTile(
                      icon: Icons.receipt_long_outlined,
                      label: t('recentVolume'),
                      value: adminMoney(volume),
                      tint: AdminPalette.tintIndigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdminStatTile(
                      icon: Icons.schedule_rounded,
                      label: t('overdueJobs'),
                      value: '$overdueCount',
                      tint: overdueCount > 0 ? AdminPalette.warningBg : AdminPalette.tintMint,
                      onTap: () => setState(() => _filter = 'overdue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminSearchField(
                hint: t('searchBookings'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              AdminFilterBar(
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
                options: {
                  'all': t('all'),
                  'overdue': t.status('overdue'),
                  for (final s in ['pending', 'confirmed', 'completed', 'disputed', 'cancelled'])
                    s: t.status(s),
                },
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                AdminEmptyState(icon: Icons.receipt_long_outlined, message: t('noResults')),
              for (final b in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminCard(
                    onTap: () => _details(b),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${b['services']?['title'] ?? '—'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: adminText(14, weight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              adminMoney(b['total_price']),
                              style: adminText(14, weight: FontWeight.w700, color: AdminPalette.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${b['profiles']?['full_name'] ?? t('unknown')} → ${b['services']?['profiles']?['full_name'] ?? t('unknown')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: adminText(12, color: AdminPalette.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            AdminStatusPill('${b['status']}'),
                            if (b['is_overdue'] == true) ...[
                              const SizedBox(width: 6),
                              const AdminStatusPill('overdue'),
                            ],
                            const Spacer(),
                            Text(
                              adminDate(context, b['scheduled_time'] ?? b['created_at']),
                              style: adminText(11, color: AdminPalette.textFaint),
                            ),
                          ],
                        ),
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

/// Disputed bookings awaiting an admin verdict (web: Disputes page).
class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  final _api = ApiService();
  final Set<String> _busy = {};

  Future<void> _resolve(Map d, String verdict, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final booking = (d['bookings'] as Map?) ?? const {};
    final refund = verdict == 'refund_client';
    final party = (booking[refund ? 'client' : 'provider'] as Map?)?['full_name'];
    final ok = await adminConfirm(
      context,
      title: refund ? t('refundClient') : t('payProvider'),
      message: t('resolveConfirm', {
        'amount': adminMoney(booking['total_price']),
        'name': '${party ?? t('unknown')}',
      }),
      confirmLabel: t('resolve'),
      destructive: refund,
    );
    if (!ok || !mounted) return;
    final id = '${d['booking_id']}';
    setState(() => _busy.add(id));
    final done = await adminRun(
      context,
      () => _api.adminResolveDispute(id, verdict),
      success: t('disputeResolved'),
    );
    if (mounted) setState(() => _busy.remove(id));
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('disputes'),
      body: AdminLoader<List<dynamic>>(
        load: _api.adminDisputes,
        builder: (context, all, reload) {
          final items = all.whereType<Map>().toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (items.isEmpty)
                AdminEmptyState(icon: Icons.gavel_rounded, message: t('noDisputes')),
              for (final d in items) _disputeCard(context, d, reload),
            ],
          );
        },
      ),
    );
  }

  Widget _disputeCard(BuildContext context, Map d, Future<void> Function() reload) {
    final t = AdminStrings.of(context);
    final b = (d['bookings'] as Map?) ?? const {};
    final busy = _busy.contains('${d['booking_id']}');
    Widget party(String role, Map? p) => Expanded(
      child: Row(
        children: [
          AdminAvatar(url: p?['profile_picture_url'], name: p?['full_name'], radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: adminText(10, color: AdminPalette.textFaint)),
                Text(
                  '${p?['full_name'] ?? t('unknown')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(12, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${b['services']?['title'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminText(15, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  adminMoney(b['total_price']),
                  style: adminText(15, weight: FontWeight.w700, color: AdminPalette.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${adminRef(d['booking_id'])} · ${adminDate(context, d['created_at'])}',
              style: adminText(11, color: AdminPalette.textFaint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                party(t('client'), b['client'] as Map?),
                party(t('provider'), b['provider'] as Map?),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminPalette.dangerBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                d['reason'] == null
                    ? t('noReasonGiven')
                    : '“${d['reason']}”${d['initiator'] != null ? '\n— ${d['initiator']['full_name']}' : ''}',
                style: adminText(13, color: AdminPalette.textDark, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminButton(
                    label: t('refundClient'),
                    outlined: true,
                    destructive: true,
                    busy: busy,
                    onPressed: () => _resolve(d, 'refund_client', reload),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AdminButton(
                    label: t('payProvider'),
                    busy: busy,
                    onPressed: () => _resolve(d, 'pay_provider', reload),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
