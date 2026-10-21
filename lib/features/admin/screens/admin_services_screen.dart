import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Service approval queue (web: Dashboard table + Activities review panel).
class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final _api = ApiService();
  String _filter = 'pending';
  String _query = '';

  static String? firstImage(Map s) {
    final urls = s['image_urls'];
    dynamic first = urls is List && urls.isNotEmpty ? urls.first : null;
    if (first is List) first = first.isNotEmpty ? first.first : null;
    first ??= s['image_url'];
    return first is String && first.startsWith('http') ? first : null;
  }

  Future<void> _review(Map s, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final reasonCtrl = TextEditingController();
    final status = '${s['status']}';
    final image = firstImage(s);

    final decision = await showAdminSheet<String>(
      context,
      title: t('reviewService'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: image,
                height: 180,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: AdminField(t('serviceTitle'), '${s['title'] ?? '—'}')),
              AdminStatusPill(status),
            ],
          ),
          AdminField(
            t('price'),
            '${adminMoney(s['price'])} / ${t('perHour')}',
            valueColor: AdminPalette.primary,
          ),
          AdminField(
            t('provider'),
            [s['profiles']?['full_name'], s['profiles']?['email']]
                .whereType<String>()
                .join(' · '),
          ),
          AdminField(
            t('category'),
            '${s['service_categories']?['name'] ?? t('general')}',
          ),
          if ('${s['description'] ?? ''}'.isNotEmpty)
            AdminField(t('description'), '${s['description']}'),
          AdminField(t('submitted'), adminDate(ctx, s['created_at'])),
          const Divider(height: 24),
          AdminTextInput(
            controller: reasonCtrl,
            label: t('reviewNotes'),
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (status != 'rejected')
                Expanded(
                  child: AdminButton(
                    label: t('reject'),
                    outlined: true,
                    destructive: true,
                    onPressed: () {
                      if (reasonCtrl.text.trim().isEmpty) {
                        adminToast(ctx, t('rejectReasonRequired'), error: true);
                        return;
                      }
                      Navigator.pop(ctx, 'rejected');
                    },
                  ),
                ),
              if (status != 'rejected' && status != 'active')
                const SizedBox(width: 12),
              if (status != 'active')
                Expanded(
                  child: AdminButton(
                    label: t('approve'),
                    onPressed: () => Navigator.pop(ctx, 'active'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (decision == null || !mounted) return;
    final ok = await adminRun(
      context,
      () => _api.adminReviewService(
        '${s['id']}',
        decision,
        reason: reason.isEmpty ? null : reason,
      ),
      success: decision == 'active' ? t('serviceApproved') : t('serviceRejected'),
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('serviceReviews'),
      body: AdminLoader<List<dynamic>>(
        load: _api.adminServicesQueue,
        builder: (context, all, reload) {
          final q = _query.toLowerCase();
          final items = all.whereType<Map>().where((s) {
            if (_filter != 'all' && s['status'] != _filter) return false;
            if (q.isEmpty) return true;
            return '${s['title']} ${s['profiles']?['full_name']} ${s['service_categories']?['name']}'
                .toLowerCase()
                .contains(q);
          }).toList();
          int count(String st) => all.where((s) => s is Map && s['status'] == st).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              AdminSearchField(
                hint: t('searchServices'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              AdminFilterBar(
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
                options: {
                  'pending': '${t.status('pending')} (${count('pending')})',
                  'active': '${t.status('active')} (${count('active')})',
                  'rejected': '${t.status('rejected')} (${count('rejected')})',
                  'all': '${t('all')} (${all.length})',
                },
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                AdminEmptyState(
                  icon: Icons.fact_check_outlined,
                  message: _filter == 'pending' && q.isEmpty
                      ? t('noPendingServices')
                      : t('noResults'),
                ),
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ServiceCard(
                    service: s,
                    image: firstImage(s),
                    onTap: () => _review(s, reload),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map service;
  final String? image;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    final s = service;
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: image == null
                  ? Container(
                      color: AdminPalette.tintRose,
                      child: const Icon(
                        Icons.design_services_outlined,
                        color: AdminPalette.primary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          Container(color: AdminPalette.tintRose),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['title'] ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s['profiles']?['full_name'] ?? t('unknown')} · ${s['service_categories']?['name'] ?? t('general')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(12, color: AdminPalette.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AdminStatusPill('${s['status']}'),
                    const Spacer(),
                    Text(
                      '${adminRef(s['id'])} · ${adminDate(context, s['created_at'])}',
                      style: adminText(10, color: AdminPalette.textFaint),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
