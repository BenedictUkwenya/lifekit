import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_cache.dart';
import '../../../core/constants/app_colors.dart';
import 'select_main_category_screen.dart';
import 'my_services_list_screen.dart';
import '../../bookings/screens/bookings_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;

  // Stats
  double totalEarnings = 0.0;
  int completedJobs = 0;
  String avgRating = "0.0";
  int reviewCount = 0;
  List<double> weeklyData = [0, 0, 0, 0, 0, 0, 0];

  // Trial
  bool isTrialActive = false;
  int trialDaysLeft = 0;

  // AI Opportunity Radar
  List<dynamic> opportunities = [];
  bool isAiLoading = true;

  // Theme Color
  final Color primaryColor = const Color(0xFF89273B);

  @override
  void initState() {
    super.initState();
    // SWR: paint cached stats instantly, then revalidate
    _loadFromCache();
    _fetchStats();
    _fetchOpportunities();
  }

  void _loadFromCache() {
    final cachedStats = AppCache.instance.get<Map<String, dynamic>>(
      'provider_stats',
    );
    final cachedOpps = AppCache.instance.get<Map<String, dynamic>>(
      'ai_opportunities',
    );
    if (cachedStats != null) {
      _applyStats(cachedStats);
    }
    if (cachedOpps != null) {
      opportunities = (cachedOpps['opportunities'] as List<dynamic>?) ?? [];
      isAiLoading = false;
    }
  }

  void _applyStats(Map<String, dynamic> data) {
    totalEarnings = (data['totalEarnings'] ?? 0).toDouble();
    completedJobs = data['completedJobs'] ?? 0;
    avgRating = data['avgRating'].toString();
    reviewCount = data['reviewCount'] ?? 0;
    final List<dynamic> rawChart = data['chartData'] ?? [];
    weeklyData = rawChart.isEmpty
        ? [0, 0, 0, 0, 0, 0, 0]
        : rawChart.map((e) => (e as num).toDouble()).toList();
    final String? trialEndDateStr = data['trialEndDate']?.toString();
    final DateTime? trialEndDate =
        (trialEndDateStr != null && trialEndDateStr.isNotEmpty)
        ? DateTime.tryParse(trialEndDateStr)
        : null;
    isTrialActive =
        trialEndDate != null && trialEndDate.isAfter(DateTime.now());
    trialDaysLeft = isTrialActive
        ? trialEndDate!.difference(DateTime.now()).inDays + 1
        : 0;
    isLoading = false;
  }

  Future<void> _fetchStats() async {
    try {
      final data = await _apiService.getProviderStats();
      if (mounted) {
        setState(() => _applyStats(data));
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOpportunities() async {
    try {
      final data = await _apiService.getAiOpportunities();
      if (mounted) {
        setState(() {
          opportunities = (data['opportunities'] as List<dynamic>?) ?? [];
          isAiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isAiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F9),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF89273B)),
            )
          : RefreshIndicator(
              onRefresh: _fetchStats,
              color: primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTrialActive) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: _buildTrialBanner(),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _buildEarningsCard(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildSectionLabel("Quick Actions"),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _buildQuickActions(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildSectionLabel("Performance"),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _buildStatsRow(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildSectionLabel("Income Analytics"),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _buildChartSection(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                          child: _buildOpportunityRadarHeader(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: _buildOpportunityRadar(),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Dashboard",
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: primaryColor, size: 22),
          onPressed: _fetchStats,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 0.1,
      ),
    );
  }

  // 1. EARNINGS CARD (Redesigned — split totals + action row)
  Widget _buildEarningsCard() {
    final double thisMonth = weeklyData.fold(0.0, (a, b) => a + b);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF6B1829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.38),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Wallet',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Total Earnings",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "\$${totalEarnings.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 18),
                // Sub-metrics row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _buildEarningsSubMetric(
                        "This Week",
                        "\$${thisMonth.toStringAsFixed(0)}",
                      ),
                      _buildEarningsVertDivider(),
                      _buildEarningsSubMetric("Jobs Done", "$completedJobs"),
                      _buildEarningsVertDivider(),
                      _buildEarningsSubMetric("Avg Rating", avgRating),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildEarningsButton(
                        icon: Icons.arrow_upward_rounded,
                        label: "Withdraw",
                        onTap: () {
                          // Navigate to wallet/withdrawal
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningsButton(
                        icon: Icons.receipt_long_rounded,
                        label: "History",
                        onTap: () {
                          // Navigate to payment history
                        },
                      ),
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

  Widget _buildEarningsSubMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsVertDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildEarningsButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.add_circle_outline_rounded,
        label: "Add\nService",
        color: const Color(0xFF89273B),
        bgColor: const Color(0xFFFDF0F2),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SelectMainCategoryScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.handyman_outlined,
        label: "My\nServices",
        color: Colors.blue.shade600,
        bgColor: Colors.blue.shade50,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.calendar_today_rounded,
        label: "Bookings",
        color: Colors.purple.shade600,
        bgColor: Colors.purple.shade50,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingsScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.star_outline_rounded,
        label: "Reviews",
        color: Colors.amber.shade700,
        bgColor: Colors.amber.shade50,
        onTap: () {
          // TODO: Navigate to reviews screen
        },
      ),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: GestureDetector(
                onTap: a.onTap,
                child: Container(
                  margin: EdgeInsets.only(right: a == actions.last ? 0 : 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: a.bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(a.icon, color: a.color, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            label: "Jobs Done",
            value: "$completedJobs",
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
            label: "Reviews",
            value: "$reviewCount",
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
            label: "Rating",
            value: avgRating,
            icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B),
            suffix: const Icon(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFFF59E0B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              if (suffix != null) ...[const SizedBox(width: 2), suffix],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 3. CHART SECTION (with day labels + real trend)
  Widget _buildChartSection() {
    // Compute real trend: first half vs second half
    final first = weeklyData.take(3).fold(0.0, (a, b) => a + b);
    final second = weeklyData.skip(4).fold(0.0, (a, b) => a + b);
    final bool trending = second >= first;
    final String trendLabel = first == 0
        ? "No data yet"
        : trending
        ? "+${((second - first) / (first == 0 ? 1 : first) * 100).abs().toStringAsFixed(0)}% trend ↑"
        : "-${((first - second) / (first == 0 ? 1 : first) * 100).abs().toStringAsFixed(0)}% trend ↓";
    final Color trendColor = trending
        ? Colors.green.shade600
        : Colors.red.shade400;
    final Color trendBg = trending ? Colors.green.shade50 : Colors.red.shade50;

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = weeklyData.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Last 7 Days",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: trendBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trendLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: trendColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 100 : maxY * 1.25,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 0 ? 50 : (maxY * 1.25 / 4),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.08),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[idx],
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateSpots(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: primaryColor,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.22),
                          primaryColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '\$${s.y.toStringAsFixed(0)}',
                            GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < weeklyData.length; i++) {
      spots.add(FlSpot(i.toDouble(), weeklyData[i]));
    }
    return spots;
  }

  // ── AI OPPORTUNITY RADAR ─────────────────────────────────────────────────

  Widget _buildOpportunityRadarHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Opportunity Radar',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Services you could offer right now',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityRadar() {
    if (isAiLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (opportunities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.grey.shade300,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'No opportunities found right now.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: opportunities.map((opp) {
        final map = Map<String, dynamic>.from(opp as Map);
        final isHigh =
            (map['demand_level']?.toString() ?? '').toLowerCase() == 'high';
        return _buildOpportunityCard(map, isHigh);
      }).toList(),
    );
  }

  Widget _buildTrialBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFFAB00), Color(0xFFFFD000)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 Launch Special — Limited Time',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only 3% commission & up to 5 services!',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildBannerPerk('💰 3% Fee'),
                    const SizedBox(width: 8),
                    _buildBannerPerk('💼 5 Services'),
                    const SizedBox(width: 8),
                    _buildBannerPerk('✨ Pro AI'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$trialDaysLeft',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      'days left',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPerk(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> opp, bool isHigh) {
    final title = opp['title']?.toString() ?? '';
    final reason = opp['reason']?.toString() ?? '';
    final price = opp['suggested_price']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHigh
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: isHigh
                ? AppColors.primary.withOpacity(0.07)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top gradient strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHigh
                    ? [AppColors.primary, const Color(0xFF7C3AED)]
                    : [Colors.grey.shade300, Colors.grey.shade200],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + demand badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHigh
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isHigh
                            ? '\uD83D\uDD25 High Demand'
                            : '\uD83D\uDCC8 Medium',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isHigh
                              ? AppColors.primary
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Reason
                Text(
                  reason,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                // Price + CTA row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          Text(
                            price,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SelectMainCategoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: Text(
                        'Create Service',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
