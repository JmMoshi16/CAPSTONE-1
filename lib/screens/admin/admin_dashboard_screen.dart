import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../login_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_users_screen.dart';
import 'admin_qr_screen.dart';
import '../../core/admin_theme.dart';
import '../../widgets/ui.dart';
import '../../core/app_theme.dart';

const kGreen = kAdminGreen;
const kDarkGreen = kAdminDGreen;
const kBlue = kAdminBlue;
const kPurple = kAdminPurple;
const kOrange = kAdminOrange;
const kDark = kAdminDark;
const kCard = kAdminCard;
const kBorder = kAdminBorder;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  List<WasteLog> _logs = [];
  List<UserModel> _customers = [];
  List<Reward> _rewards = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    // Full-screen skeleton only on the first load; pull-to-refresh keeps the current data visible.
    final firstLoad = _logs.isEmpty && _customers.isEmpty && _rewards.isEmpty;
    if (mounted) setState(() { _loading = firstLoad; _loadError = null; });
    try {
      final logs = await FirebaseService.getAllWasteLogs();
      final customers = await FirebaseService.getAllCustomers();
      final rewards = await FirebaseService.getAllRewards();
      if (mounted) setState(() { _logs = logs; _customers = customers; _rewards = rewards; _loading = false; });
    } catch (_) {
      // Never show raw exception text; the error state explains what to do.
      if (mounted) setState(() { _loading = false; _loadError = 'failed'; });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure?', style: TextStyle(color: AdminColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.dangerFill, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Logout', style: TextStyle(color: AdminColors.textPrimary))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardTab(logs: _logs, customers: _customers, onRefresh: _loadData, onLogout: _logout,
          onOpenUsers: () => setState(() => _selectedIndex = 2)),
      AdminRewardsScreen(rewards: _rewards, onChanged: _loadData),
      AdminUsersScreen(customers: _customers, logs: _logs, onRefresh: _loadData),
      const AdminQRScreen(),
    ];

    // Admin screens always use the dark admin theme (dialogs and sheets inherit it).
    return Theme(
      data: AppTheme.admin,
      child: Scaffold(
      backgroundColor: kDark,
      extendBody: true,
      body: _loading
          ? const SafeArea(child: SkeletonList(count: 7))
          : _loadError != null
              ? ErrorState(
                  title: "Couldn't load the dashboard",
                  message: 'Check the connection, then try again. If it keeps failing, sign out and back in.',
                  onRetry: _loadData,
                )
              : FadeIndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: _AdminFloatingNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    ));
  }
}

/// The dashboard tab without Firebase, for layout tests.
@visibleForTesting
Widget dashboardTabPreview({required List<WasteLog> logs, required List<UserModel> customers}) =>
    Scaffold(body: _DashboardTab(logs: logs, customers: customers, onRefresh: () {}, onLogout: () {}, onOpenUsers: () {}));

class _DashboardTab extends StatelessWidget {
  final List<WasteLog> logs;
  final List<UserModel> customers;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final VoidCallback onOpenUsers;
  const _DashboardTab({required this.logs, required this.customers, required this.onRefresh, required this.onLogout,
      required this.onOpenUsers});

  static const _typeColors = {'Biodegradable': AdminColors.bio, 'Recyclable': AdminColors.rec, 'Residual': AdminColors.res};

  /// Count per waste type, largest first.
  List<(String, int)> _byType() {
    final m = <String, int>{};
    for (final l in logs) { m[l.wasteType] = (m[l.wasteType] ?? 0) + 1; }
    return m.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  }

  String _hourLabel(int h) => h == 0 ? '12 AM' : h < 12 ? '$h AM' : h == 12 ? '12 PM' : '${h - 12} PM';


  List<double> _linearRegression(List<double> y) {
    final n = y.length;
    if (n == 0) return List.filled(10, 0);
    final xMean = (n - 1) / 2;
    final yMean = y.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (i - xMean) * (y[i] - yMean);
      den += (i - xMean) * (i - xMean);
    }
    final slope = den == 0 ? 0.0 : num / den;
    final intercept = yMean - slope * xMean;
    return List.generate(n + 3, (i) => (slope * i + intercept).clamp(0, double.infinity));
  }

  String _peakHour() {
    if (logs.isEmpty) return 'N/A';
    final hourCount = <int, int>{};
    for (final l in logs) { hourCount[l.timestamp.hour] = (hourCount[l.timestamp.hour] ?? 0) + 1; }
    final peak = hourCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final end = (peak + 2) % 24;
    String fmt(int h) => h == 0 ? '12 AM' : h < 12 ? '$h AM' : h == 12 ? '12 PM' : '${h - 12} PM';
    return '${fmt(peak)} – ${fmt(end)}';
  }

  String _mostCommonWaste() {
    if (logs.isEmpty) return 'N/A';
    final count = <String, int>{};
    for (final l in logs) { count[l.wasteType] = (count[l.wasteType] ?? 0) + 1; }
    return count.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final actual = days.map((d) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      return logs.where((l) => DateFormat('yyyy-MM-dd').format(l.timestamp) == key).length.toDouble();
    }).toList();
    final predicted = _linearRegression(actual);
    final allDays = [...days, ...List.generate(3, (i) => days.last.add(Duration(days: i + 1)))];

    final bio = logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = logs.where((l) => l.wasteType == 'Residual').length;
    final total = logs.length;
    final totalPoints = customers.fold(0, (s, u) => s + u.points);
    final binLevel = (total % 100) / 100.0;
    final binPct = (binLevel * 100).round();
    final binColor = binPct > 75 ? AdminColors.danger : binPct > 50 ? kOrange : kGreen;
    final nextDay = predicted.length > 7 ? predicted[7].round() : 0;
    final today = actual.isNotEmpty ? actual.last.round() : 0;
    final diff = nextDay - today;

    return RefreshIndicator(
      color: kGreen, backgroundColor: kCard,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: kCard,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                  border: Border(bottom: BorderSide(color: kBorder))),
              child: SafeArea(bottom: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
                child: Column(children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [kGreen, kDarkGreen]),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: AdminColors.onAccent, size: 20)),
                    const SizedBox(width: AppSpace.sm),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Admin Dashboard', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('ECOReward Business Intelligence', style: TextStyle(color: AdminColors.textTertiary, fontSize: 11)),
                    ])),
                    Tap(label: 'Logout', tooltip: true, onTap: onLogout,
                        child: Container(padding: const EdgeInsets.all(AppSpace.sm - 1),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                            child: const Icon(Icons.logout_rounded, color: AdminColors.textTertiary, size: 18))),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  Row(children: [
                    Expanded(child: _statCard('$total', 'Disposals', Icons.recycling_rounded, kGreen,
                        onTap: () => _detail(context, 'Disposals', [
                          for (final (type, n) in _byType()) _DetailRow(type, '$n', fraction: total == 0 ? 0 : n / total, color: _typeColors[type]),
                          for (var i = 6; i >= 0; i--) _DetailRow(DateFormat('EEE, MMM d').format(days[i]), '${actual[i].round()}'),
                        ], note: 'All logged disposals by waste type, then the last 7 days.'))),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('${customers.length}', 'Customers', Icons.people_rounded, kBlue, onTap: onOpenUsers)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('$totalPoints', 'Pts Balance', Icons.stars_rounded, kOrange, onTap: onOpenUsers)),
                  ]),
                ]),
              )),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),

          // ── Large Line Chart ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: kBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Daily Waste Volume', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('7-day trend + Linear Regression forecast', style: TextStyle(color: AdminColors.textTertiary, fontSize: 11)),
                    ])),
                    const SizedBox(width: AppSpace.xs),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpace.xxs),
                        decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Last 7 days', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: AppSpace.sm),
                  Row(children: [
                    _legendDot(kGreen), const SizedBox(width: AppSpace.xxs),
                    const Text('Actual', style: TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 14),
                    _legendDash(kBlue), const SizedBox(width: AppSpace.xxs),
                    const Text('Predicted Growth', style: TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  Semantics(
                    // Screen readers get the numbers the chart shows.
                    label: 'Daily disposals, last 7 days: '
                        '${List.generate(7, (i) => '${DateFormat('EEEE').format(allDays[i])} ${actual[i].round()}').join(', ')}. '
                        'Forecast for the next 3 days: '
                        '${List.generate(3, (i) => '${DateFormat('EEEE').format(allDays[7 + i])} about ${predicted[7 + i].round()}').join(', ')}.',
                    excludeSemantics: true,
                    child: SizedBox(
                    height: 200,
                    child: LineChart(LineChartData(
                      minY: 0,
                      maxY: ([...actual, ...predicted].reduce((a, b) => a > b ? a : b) + 2).clamp(5.0, double.infinity),
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(show: true, drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11)))),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1,
                            getTitlesWidget: (val, _) {
                              final i = val.toInt();
                              if (i < 0 || i >= allDays.length) return const SizedBox.shrink();
                              return Padding(padding: const EdgeInsets.only(top: AppSpace.xxs),
                                  child: Text(DateFormat('E').format(allDays[i]),
                                      style: TextStyle(color: i >= 7 ? kBlue.withValues(alpha: 0.7) : AdminColors.textTertiary, fontSize: 11)));
                            })),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(actual.length, (i) => FlSpot(i.toDouble(), actual[i])),
                          isCurved: true, color: kGreen, barWidth: 2.5,
                          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(radius: 3, color: kGreen, strokeWidth: 0)),
                          belowBarData: BarAreaData(show: true,
                              gradient: LinearGradient(colors: [kGreen.withValues(alpha: 0.25), Colors.transparent],
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                        ),
                        LineChartBarData(
                          spots: List.generate(predicted.length, (i) => FlSpot(i.toDouble(), predicted[i])),
                          isCurved: true, color: kBlue, barWidth: 2, dashArray: [6, 4],
                          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, i) =>
                              FlDotCirclePainter(radius: i >= 7 ? 4 : 0, color: kBlue, strokeWidth: 0)),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    )),
                  )),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),

          // ── Side panels row: Peak Hours + Most Common ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Row(children: [
                Expanded(child: _infoCard(
                  icon: Icons.access_time_rounded, color: kOrange,
                  title: 'Peak Disposal Hours',
                  value: _peakHour(),
                  sub: 'Highest activity window',
                  onTap: () {
                    final byHour = List.filled(24, 0);
                    for (final l in logs) { byHour[l.timestamp.hour]++; }
                    final top = [for (var h = 0; h < 24; h++) (h, byHour[h])]..sort((a, b) => b.$2.compareTo(a.$2));
                    final most = top.isEmpty ? 1 : (top.first.$2 == 0 ? 1 : top.first.$2);
                    _detail(context, 'Busiest hours', [
                      for (final (h, n) in top.take(8).where((e) => e.$2 > 0))
                        _DetailRow('${_hourLabel(h)} – ${_hourLabel((h + 1) % 24)}', '$n', fraction: n / most, color: kOrange),
                    ], note: 'Disposals per hour of the day, all logged data.');
                  },
                )),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: _infoCard(
                  icon: Icons.category_rounded, color: kPurple,
                  title: 'Most Common Waste',
                  value: _mostCommonWaste(),
                  sub: 'Across all logged disposals',
                  onTap: () => _detail(context, 'Waste by type', [
                    for (final (type, n) in _byType())
                      _DetailRow(type, '$n (${total == 0 ? 0 : (n / total * 100).round()}%)',
                          fraction: total == 0 ? 0 : n / total, color: _typeColors[type]),
                  ]),
                )),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),

          // ── BI Grid tiles ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Analytics Overview', style: TextStyle(color: AdminColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: AppSpace.sm),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // Taller tiles when text is enlarged, so nothing is clipped.
                  childAspectRatio: 1.05 / AppLayout.textScale(context).clamp(1.0, 1.6),
                  children: [
                    _biTile(
                      icon: Icons.show_chart_rounded, color: kGreen,
                      title: 'Waste Trend',
                      value: '${diff >= 0 ? '+' : ''}$diff',
                      sub: 'forecast tomorrow vs today',
                      chart: _miniLineChart(actual, kGreen),
                      onTap: () => _detail(context, 'Waste trend', [
                        for (var i = 6; i >= 0; i--) _DetailRow(DateFormat('EEE, MMM d').format(days[i]), '${actual[i].round()}',
                            fraction: actual.reduce((a, b) => a > b ? a : b) == 0 ? 0 : actual[i] / actual.reduce((a, b) => a > b ? a : b),
                            color: kGreen),
                      ], note: 'Disposals per day. The tile compares the forecast for tomorrow with today.'),
                    ),
                    _biTile(
                      icon: Icons.delete_rounded, color: binColor,
                      title: 'Bin Status (demo)',
                      value: '$binPct%',
                      sub: 'simulated, no fill sensor',
                      chart: _binLevelBar(binLevel, binColor),
                      onTap: () => _detail(context, 'Bin Status (demo)', const [],
                          note: 'This tile is a demonstration: it is computed from the number of logged disposals '
                              '(total modulo 100), not measured. The bin has no fill-level sensor yet.'),
                    ),
                    _biTile(
                      icon: Icons.pie_chart_rounded, color: kBlue,
                      title: 'Waste Split',
                      value: total > 0 ? '${(rec / total * 100).round()}%' : '0%',
                      sub: 'recyclable',
                      chart: _miniPieChart(bio, rec, res),
                      onTap: () => _detail(context, 'Waste split', [
                        for (final (type, n) in _byType())
                          _DetailRow(type, '${total == 0 ? 0 : (n / total * 100).round()}%',
                              fraction: total == 0 ? 0 : n / total, color: _typeColors[type]),
                      ]),
                    ),
                    _biTile(
                      icon: Icons.trending_up_rounded, color: kPurple,
                      title: 'Forecast',
                      value: '~$nextDay',
                      sub: 'disposals tomorrow',
                      chart: _miniLineChart(predicted.take(7).toList(), kPurple),
                      onTap: () => _detail(context, 'Forecast', [
                        for (var i = 0; i < 3; i++)
                          _DetailRow(DateFormat('EEE, MMM d').format(allDays[7 + i]), '~${predicted[7 + i].round()}'),
                      ], note: 'A straight-line (least-squares) trend through the last 7 days, extended 3 days. '
                          'It is a rough guide, not a prediction of events.'),
                    ),
                  ],
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _statCard(String v, String l, IconData icon, Color c, {required VoidCallback onTap}) =>
      Tap(label: '$l: $v, details', onTap: onTap, child: _statCardBody(v, l, icon, c));

  Widget _statCardBody(String v, String l, IconData icon, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm, horizontal: AppSpace.xs),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(height: AppSpace.xxs),
          Text(v, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(l, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11), textAlign: TextAlign.center),
        ]),
      );

  Widget _infoCard({required IconData icon, required Color color, required String title, required String value,
      required String sub, required VoidCallback onTap}) =>
      Tap(label: '$title: $value, details', onTap: onTap, child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: AppSpace.xs),
            Expanded(child: Text(title, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11)),
        ]),
      ));

  Widget _biTile({required IconData icon, required Color color, required String title,
      required String value, required String sub, required Widget chart, required VoidCallback onTap}) =>
      // One spoken summary per tile; the mini chart is decorative.
      Tap(
        label: '$title: $value, $sub, details',
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          Text(sub, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11)),
          const Spacer(),
          SizedBox(height: 36, child: chart),
        ]),
      ));

  Widget _miniLineChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxY = data.reduce((a, b) => a > b ? a : b);
    return LineChart(LineChartData(
      minY: 0, maxY: maxY == 0 ? 1 : maxY + 1,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [LineChartBarData(
        spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
        isCurved: true, color: color, barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true,
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), Colors.transparent],
                begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      )],
    ));
  }

  Widget _binLevelBar(double level, Color color) => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: level, backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
          ),
        ],
      );

  Widget _miniPieChart(int bio, int rec, int res) {
    final total = bio + rec + res;
    if (total == 0) return const SizedBox.shrink();
    return PieChart(PieChartData(
      sectionsSpace: 2, centerSpaceRadius: 10,
      sections: [
        PieChartSectionData(value: bio.toDouble(), color: AdminColors.bio, title: '', radius: 14),
        PieChartSectionData(value: rec.toDouble(), color: kBlue, title: '', radius: 14),
        PieChartSectionData(value: res.toDouble(), color: AdminColors.res, title: '', radius: 14),
      ],
    ));
  }

  Widget _legendDot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  Widget _legendDash(Color c) => Container(width: 16, height: 2, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)));
}

/// One line in an admin detail sheet, with an optional proportion bar.
class _DetailRow {
  const _DetailRow(this.label, this.value, {this.fraction, this.color});
  final String label, value;
  final double? fraction;
  final Color? color;
}

void _detail(BuildContext context, String title, List<_DetailRow> rows, {String? note}) {
  AppSheet.show(
    context,
    title: title,
    initialSize: 0.5,
    builder: (ctx, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
      children: [
        if (rows.isEmpty && note == null)
          const Text('No data yet.', style: TextStyle(color: AdminColors.textSecondary)),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.label, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14))),
                Text(r.value, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              if (r.fraction != null) ...[
                const SizedBox(height: AppSpace.xxs),
                AnimatedBar(progress: r.fraction!, color: r.color ?? AdminColors.accent, height: 6,
                    trackColor: Colors.white.withValues(alpha: 0.06)),
              ],
            ]),
          ),
        if (note != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(note, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 12, height: 1.4)),
        ],
      ],
    ),
  );
}

// ── Admin Floating Nav ────────────────────────────────────────────────────────
class _AdminFloatingNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _AdminFloatingNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
      (Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards'),
      (Icons.people_rounded, Icons.people_outlined, 'Users'),
      (Icons.qr_code_rounded, Icons.qr_code_outlined, 'QR Codes'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(36),
            border: Border.all(color: kBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Stack(children: [
            // Indicator that slides between tabs.
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(-1 + selectedIndex * (2 / (items.length - 1)), 0),
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.emphasized,
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: Center(
                    child: Container(
                      width: 72, height: 52,
                      decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(items.length, (i) {
                final selected = selectedIndex == i;
                final fg = selected ? kGreen : AdminColors.textTertiary;
                return Expanded(
                  child: Tap(
                    label: items[i].$3,
                    selected: selected,
                    onTap: () => onTap(i),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(selected ? items[i].$1 : items[i].$2, color: fg, size: 22),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.of(context, AppMotion.fast),
                        style: TextStyle(fontSize: 11, color: fg, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                        child: Text(items[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}
