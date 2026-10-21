import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../admin_strings.dart';
import '../widgets/admin_ui.dart';

/// Deep analysis (web: Analytics page) + category activity (web: Activities).
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _api = ApiService();
  bool _showRevenue = true;

  static Color _hex(dynamic v, Color fallback) {
    final s = '${v ?? ''}'.replaceFirst('#', '');
    final parsed = int.tryParse(s, radix: 16);
    return parsed == null || s.length != 6 ? fallback : Color(0xFF000000 | parsed);
  }

  Future<void> _withdraw(double available, Future<void> Function() reload) async {
    final t = AdminStrings.of(context);
    final amountCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final confirmed = await showAdminSheet<bool>(
      context,
      title: t('withdrawFunds'),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminField(
            t('availableBalance'),
            adminMoney(available),
            valueColor: AdminPalette.success,
          ),
          AdminTextInput(
            controller: amountCtrl,
            label: t('amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          AdminTextInput(controller: destCtrl, label: t('destination')),
          const SizedBox(height: 4),
          AdminButton(
            label: t('confirmWithdrawal'),
            icon: Icons.account_balance_outlined,
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) {
                adminToast(ctx, t('invalidAmount'), error: true);
              } else if (amount > available) {
                adminToast(ctx, t('exceedsBalance'), error: true);
              } else {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    final dest = destCtrl.text.trim();
    amountCtrl.dispose();
    destCtrl.dispose();
    if (confirmed != true || amount == null || !mounted) return;
    final ok = await adminRun(
      context,
      () => _api.adminWithdraw(amount, dest.isEmpty ? 'Bank' : dest),
      success: t('withdrawalRecorded'),
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return AdminScaffold(
      title: t('analytics'),
      body: AdminLoader<Map<String, dynamic>>(
        load: _api.adminAnalytics,
        builder: (context, data, reload) {
          final cards = (data['cards'] as Map?) ?? const {};
          final available = (cards['available_balance'] as num?)?.toDouble() ?? 0;
          final chart = (data['chart'] as List?)?.whereType<Map>().toList() ?? [];
          final devices = (data['device_stats'] as List?)?.whereType<Map>().toList() ?? [];
          final categories = (data['categories'] as List?)?.whereType<Map>().toList() ?? [];
          final countries = (data['demographics'] as List?)?.whereType<Map>().toList() ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Balance hero
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AdminPalette.primary, Color(0xFFA03348)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('availableBalance'),
                      style: adminText(13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminMoney(available),
                      style: adminText(30, weight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('commissionNote'),
                      style: adminText(11, color: Colors.white60),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: available > 0 ? () => _withdraw(available, reload) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AdminPalette.primary,
                        disabledBackgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.north_east_rounded, size: 18),
                      label: Text(
                        t('withdraw'),
                        style: adminText(13, weight: FontWeight.w600, color: AdminPalette.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  AdminStatTile(
                    icon: Icons.payments_outlined,
                    label: t('grossVolume'),
                    value: adminMoney(cards['total_revenue']),
                    tint: AdminPalette.tintRose,
                  ),
                  AdminStatTile(
                    icon: Icons.trending_up_rounded,
                    label: t('netProfit'),
                    value: adminMoney(cards['net_profit']),
                    tint: AdminPalette.tintMint,
                  ),
                  AdminStatTile(
                    icon: Icons.event_available_outlined,
                    label: t('bookings6m'),
                    value: adminCompact(cards['total_bookings']),
                    tint: AdminPalette.tintIndigo,
                  ),
                  AdminStatTile(
                    icon: Icons.people_outline_rounded,
                    label: t('totalUsers'),
                    value: adminCompact(cards['total_users']),
                    tint: AdminPalette.tintAmber,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('last6Months'),
                            style: adminText(15, weight: FontWeight.w700),
                          ),
                        ),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AdminPalette.primary,
                            selectedForegroundColor: Colors.white,
                            textStyle: adminText(11, weight: FontWeight.w600),
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            ButtonSegment(value: true, label: Text(t('revenue'))),
                            ButtonSegment(value: false, label: Text(t('bookings'))),
                          ],
                          selected: {_showRevenue},
                          onSelectionChanged: (v) => setState(() => _showRevenue = v.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 190,
                      child: _TrendChart(
                        points: chart,
                        field: _showRevenue ? 'revenue' : 'bookings',
                        money: _showRevenue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ActivitySection(api: _api),
              const SizedBox(height: 12),
              if (devices.isNotEmpty)
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('signupPlatforms'), style: adminText(15, weight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                sections: [
                                  for (final d in devices)
                                    if (((d['value'] as num?) ?? 0) > 0)
                                      PieChartSectionData(
                                        value: (d['value'] as num).toDouble(),
                                        color: _hex(d['color'], AdminPalette.textFaint),
                                        radius: 26,
                                        showTitle: false,
                                      ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final d in devices)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _hex(d['color'], AdminPalette.textFaint),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('${d['name']}', style: adminText(13)),
                                        ),
                                        Text(
                                          '${d['value'] ?? 0}',
                                          style: adminText(13, weight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _BreakdownCard(
                title: t('servicesByCategory'),
                rows: [
                  for (final c in categories)
                    (
                      '${c['name']}',
                      (c['value'] as num?)?.toDouble() ?? 0,
                      _hex(c['color'], AdminPalette.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _BreakdownCard(
                title: t('topCountries'),
                rows: [
                  for (final c in countries)
                    (
                      '${c['country']}',
                      (c['users'] as num?)?.toDouble() ?? 0,
                      AdminPalette.primary,
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

class _TrendChart extends StatelessWidget {
  final List<Map> points;
  final String field;
  final bool money;

  const _TrendChart({required this.points, required this.field, required this.money});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(AdminStrings.of(context)('noData'), style: adminText(13, color: AdminPalette.textMuted)),
      );
    }
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), ((points[i][field] as num?) ?? 0).toDouble()),
    ];
    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AdminPalette.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    money ? adminMoney(s.y) : s.y.toInt().toString(),
                    adminText(12, weight: FontWeight.w600, color: Colors.white),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      money ? '\$${adminCompact(v)}' : adminCompact(v),
                      style: adminText(10, color: AdminPalette.textFaint),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length || v != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${points[i]['name']}',
                    style: adminText(10, color: AdminPalette.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AdminPalette.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AdminPalette.primary.withValues(alpha: 0.25),
                  AdminPalette.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// New services per category for a selectable period (web: Activities chart).
class _ActivitySection extends StatefulWidget {
  final ApiService api;

  const _ActivitySection({required this.api});

  @override
  State<_ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<_ActivitySection> {
  String _period = 'monthly';
  late Future<List<dynamic>> _future = widget.api.adminActivityChart(_period);

  @override
  Widget build(BuildContext context) {
    final t = AdminStrings.of(context);
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        final rows = [
          for (final r in (snap.data ?? const []).whereType<Map>())
            ('${r['name']}', ((r['value'] as num?) ?? 0).toDouble(), AdminPalette.primary),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        return _BreakdownCard(
          title: t('newServicesActivity'),
          loading: snap.connectionState != ConnectionState.done,
          header: AdminFilterBar(
            selected: _period,
            onSelected: (p) => setState(() {
              _period = p;
              _future = widget.api.adminActivityChart(p);
            }),
            options: {
              'weekly': t('thisWeek'),
              'monthly': t('thisMonth'),
              'yearly': t('thisYear'),
            },
          ),
          rows: rows,
        );
      },
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final List<(String, double, Color)> rows;
  final Widget? header;
  final bool loading;

  const _BreakdownCard({
    required this.title,
    required this.rows,
    this.header,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + r.$2);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminText(15, weight: FontWeight.w700)),
          if (header != null) ...[const SizedBox(height: 12), header!],
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AdminPalette.primary, strokeWidth: 2),
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                AdminStrings.of(context)('noData'),
                style: adminText(13, color: AdminPalette.textMuted),
              ),
            )
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: adminText(13),
                          ),
                        ),
                        Text(
                          '${r.$2.toInt()}',
                          style: adminText(13, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : r.$2 / total,
                        minHeight: 7,
                        color: r.$3,
                        backgroundColor: AdminPalette.neutralBg,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
