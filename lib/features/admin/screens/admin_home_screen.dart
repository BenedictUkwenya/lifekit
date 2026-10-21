import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';
import 'admin_analytics_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_catalog_screen.dart';
import 'admin_content_screen.dart';
import 'admin_services_screen.dart';
import 'admin_support_screen.dart';
import 'admin_team_screen.dart';
import 'admin_users_screen.dart';

/// Entry point of the in-app admin dashboard (web: Dashboard page + sidebar).
class AdminHomeScreen extends StatefulWidget {
  final String? adminName;

  const AdminHomeScreen({super.key, this.adminName});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _api = ApiService();
  int _generation = 0;

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // Counts may have changed — rebuild the loader to refetch.
    if (mounted) setState(() => _generation++);
  }

  String _greeting(AdminStrings t) {
    final h = DateTime.now().hour;
    if (h < 12) return t('goodMorning');
    if (h < 17) return t('goodAfternoon');
    return t('goodEvening');
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('adminPanel'),
      body: AdminLoader<Map<String, dynamic>>(
        key: ValueKey(_generation),
        load: _api.adminOverview,
        builder: (context, o, reload) {
          int n(String k) => (o[k] as num?)?.toInt() ?? 0;
          final attention = <_AttentionItem>[
            _AttentionItem(
              Icons.fact_check_outlined,
              t('serviceReviews'),
              n('pending_reviews'),
              () => _open(const AdminServicesScreen()),
            ),
            _AttentionItem(
              Icons.gavel_rounded,
              t('disputes'),
              n('open_disputes'),
              () => _open(const AdminDisputesScreen()),
            ),
            _AttentionItem(
              Icons.support_agent_rounded,
              t('support'),
              n('open_tickets') + n('pending_reports'),
              () => _open(const AdminSupportScreen()),
            ),
            _AttentionItem(
              Icons.playlist_add_check_rounded,
              t('categoryRequests'),
              n('pending_category_requests'),
              () => _open(const AdminCatalogScreen()),
            ),
            _AttentionItem(
              Icons.schedule_rounded,
              t('overdueJobs'),
              n('overdue_jobs'),
              () => _open(const AdminBookingsScreen()),
            ),
          ];
          final totalOpen = attention.fold<int>(0, (s, a) => s + a.count);
          final lang = Localizations.localeOf(context).languageCode;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Text(
                DateFormat('EEEE, d MMMM', lang).format(DateTime.now()),
                style: adminText(13, color: AdminPalette.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                '${_greeting(t)}, ${widget.adminName?.split(' ').first ?? t('admin')}',
                style: adminText(24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              _Banner(
                title: totalOpen == 0
                    ? t('allCaughtUp')
                    : t('itemsNeedAttention', {'n': '$totalOpen'}),
                subtitle: t('bannerSubtitle'),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  AdminStatTile(
                    icon: Icons.attach_money_rounded,
                    label: t('totalRevenue'),
                    value: adminMoney(o['total_revenue']),
                    tint: AdminPalette.tintRose,
                    caption: t('liveData'),
                    onTap: () => _open(const AdminAnalyticsScreen()),
                  ),
                  AdminStatTile(
                    icon: Icons.shopping_bag_outlined,
                    label: t('totalBookings'),
                    value: adminCompact(o['total_bookings']),
                    tint: AdminPalette.tintIndigo,
                    caption: t('liveData'),
                    onTap: () => _open(const AdminBookingsScreen()),
                  ),
                  AdminStatTile(
                    icon: Icons.pending_actions_rounded,
                    label: t('pendingReviews'),
                    value: '${n('pending_reviews')}',
                    tint: AdminPalette.tintAmber,
                    caption: t('liveData'),
                    onTap: () => _open(const AdminServicesScreen()),
                  ),
                  AdminStatTile(
                    icon: Icons.people_outline_rounded,
                    label: t('totalUsers'),
                    value: adminCompact(o['total_users']),
                    tint: AdminPalette.tintMint,
                    caption: t('liveData'),
                    onTap: () => _open(const AdminUsersScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AdminSectionTitle(t('needsAttention')),
              AdminCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < attention.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 60,
                          color: AdminPalette.border,
                        ),
                      _AttentionRow(item: attention[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AdminSectionTitle(t('manage')),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _ModuleTile(
                    Icons.pie_chart_outline_rounded,
                    t('analytics'),
                    () => _open(const AdminAnalyticsScreen()),
                  ),
                  _ModuleTile(
                    Icons.receipt_long_outlined,
                    t('transactions'),
                    () => _open(const AdminBookingsScreen()),
                  ),
                  _ModuleTile(
                    Icons.people_alt_outlined,
                    t('users'),
                    () => _open(const AdminUsersScreen()),
                  ),
                  _ModuleTile(
                    Icons.dynamic_feed_rounded,
                    t('content'),
                    () => _open(const AdminContentScreen()),
                  ),
                  _ModuleTile(
                    Icons.category_outlined,
                    t('catalog'),
                    () => _open(const AdminCatalogScreen()),
                  ),
                  _ModuleTile(
                    Icons.admin_panel_settings_outlined,
                    t('team'),
                    () => _open(const AdminTeamScreen()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Banner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 120,
        color: AdminPalette.banner,
        child: Stack(
          children: [
            // The web banner's skewed maroon stripe + accent line
            Positioned(
              left: -70,
              top: -20,
              bottom: -20,
              child: Transform(
                transform: Matrix4.skewX(0.2),
                child: Container(width: 110, color: AdminPalette.primary),
              ),
            ),
            Positioned(
              left: 58,
              top: 18,
              bottom: 18,
              child: Container(width: 3, color: const Color(0xFFD6ADAD)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(76, 16, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: adminText(17, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: adminText(12, color: AdminPalette.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionItem {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  _AttentionItem(this.icon, this.label, this.count, this.onTap);
}

class _AttentionRow extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasItems = item.count > 0;
    return ListTile(
      onTap: item.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasItems ? AdminPalette.tintRose : AdminPalette.neutralBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.icon,
          size: 20,
          color: hasItems ? AdminPalette.primary : AdminPalette.textFaint,
        ),
      ),
      title: Text(item.label, style: adminText(14, weight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasItems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AdminPalette.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${item.count}',
                style: adminText(
                  12,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          else
            const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AdminPalette.success,
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AdminPalette.textFaint,
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModuleTile(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminPalette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AdminPalette.primary, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: adminText(12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
