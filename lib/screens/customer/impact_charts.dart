import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

/// Impact charts: the last 7 days as growing bars, the waste mix as a donut that sweeps
/// in, and CO₂ saved as comparisons people can picture. All display only, from the
/// customer's own scan history.
class ImpactCharts extends StatefulWidget {
  const ImpactCharts({super.key, required this.logs, this.animate = true});

  final List<WasteLog> logs;
  final bool animate;

  // Rough averages, labelled as estimates on screen.
  static const kgCo2PerRecyclable = 0.5;      // same factors as the Home "Your impact" tile
  static const kgCo2PerBiodegradable = 0.3;
  static const kgCo2PerPhoneCharge = 0.00822; // US EPA greenhouse-gas equivalencies
  static const kgCo2PerTreeDay = 21.77 / 365; // a mature tree absorbs ~22 kg CO₂ a year

  @override
  State<ImpactCharts> createState() => _ImpactChartsState();
}

class _ImpactChartsState extends State<ImpactCharts> {
  late bool _shown = !widget.animate;

  @override
  void initState() {
    super.initState();
    // First frame with empty charts, then the real data: fl_chart animates the change.
    if (!_shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _shown = true); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final perDay = [
      for (final d in days)
        widget.logs.where((l) => l.timestamp.year == d.year && l.timestamp.month == d.month && l.timestamp.day == d.day).length,
    ];
    final maxDay = perDay.fold(0, (a, b) => a > b ? a : b);
    final bio = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final total = bio + rec + res;
    final kg = rec * ImpactCharts.kgCo2PerRecyclable + bio * ImpactCharts.kgCo2PerBiodegradable;
    final duration = AppMotion.of(context, const Duration(milliseconds: 700));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Last 7 days ──
      _Card(
        title: 'Last 7 days',
        subtitle: '${perDay.fold(0, (a, b) => a + b)} scans',
        child: Semantics(
          label: 'Scans per day, last 7 days: '
              '${List.generate(7, (i) => '${DateFormat('EEEE').format(days[i])} ${perDay[i]}').join(', ')}',
          excludeSemantics: true,
          child: SizedBox(
            height: 150,
            child: RepaintBoundary(
              child: BarChart(
                duration: duration,
                curve: AppMotion.emphasized,
                BarChartData(
                  maxY: (maxDay + 1).toDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (v, _) => Text(_shown && perDay[v.toInt()] > 0 ? '${perDay[v.toInt()]}' : '',
                          style: t.labelSmall),
                    )),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxs),
                        child: Text(DateFormat('E').format(days[v.toInt()]).substring(0, 2),
                            style: t.labelSmall!.copyWith(
                                color: v.toInt() == 6 ? c.primary : c.textTertiary,
                                fontWeight: v.toInt() == 6 ? FontWeight.w800 : FontWeight.w600)),
                      ),
                    )),
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: _shown ? perDay[i].toDouble() : 0,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: const LinearGradient(
                            colors: [AppPalette.forest, AppPalette.mint],
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true, toY: (maxDay + 1).toDouble(), color: c.surfaceAlt),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.md),

      // ── Waste mix ──
      _Card(
        title: 'Waste mix',
        subtitle: 'All your scans',
        child: Row(children: [
          Semantics(
            label: 'Biodegradable $bio, Recyclable $rec, Residual $res',
            excludeSemantics: true,
            child: SizedBox(
              width: 120, height: 120,
              child: RepaintBoundary(
                child: Stack(alignment: Alignment.center, children: [
                  PieChart(
                    duration: duration,
                    curve: AppMotion.emphasized,
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        _slice(c.bio, _shown ? bio : 0),
                        _slice(c.rec, _shown ? rec : 0),
                        _slice(c.res, _shown ? res : 0),
                        // The filler shrinks to nothing, so the real slices sweep in.
                        _slice(Colors.transparent, _shown ? 0 : (total == 0 ? 1 : total)),
                      ],
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedCount(total, fromZero: widget.animate,
                        style: t.titleLarge!.copyWith(fontFamily: AppType.displayFamily)),
                    Text('scans', style: t.labelSmall),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (label, n, color) in [('Biodegradable', bio, c.bio), ('Recyclable', rec, c.rec), ('Residual', res, c.res)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(child: Text(label, style: t.bodySmall!.copyWith(color: c.textPrimary), overflow: TextOverflow.ellipsis)),
                  Text(total == 0 ? '0%' : '${(n / total * 100).round()}%', style: t.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
          ])),
        ]),
      ),
      const SizedBox(height: AppSpace.md),

      // ── CO₂ ──
      _Card(
        title: 'CO₂ you helped avoid',
        subtitle: '≈ ${kg.toStringAsFixed(1)} kg (estimate)',
        child: Column(children: [
          Row(children: [
            Expanded(child: _Equivalent(
              emoji: '📱',
              value: (kg / ImpactCharts.kgCo2PerPhoneCharge).round(),
              label: 'phone charges',
              animate: widget.animate,
            )),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: _Equivalent(
              emoji: '🌳',
              value: (kg / ImpactCharts.kgCo2PerTreeDay).round(),
              label: "days of a tree's work",
              animate: widget.animate,
            )),
          ]),
          const SizedBox(height: AppSpace.sm),
          Text('Rough estimates: about 0.5 kg CO₂ per recyclable and 0.3 kg per biodegradable item; '
              '8.2 g per smartphone charge (US EPA); a tree absorbs about 22 kg a year.',
              style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400)),
        ]),
      ),
    ]);
  }

  PieChartSectionData _slice(Color color, int value) =>
      PieChartSectionData(value: value.toDouble(), color: color, title: '', radius: 18);
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: context.text.titleMedium)),
            Flexible(child: Text(subtitle, style: context.text.labelSmall, textAlign: TextAlign.end)),
          ]),
          const SizedBox(height: AppSpace.sm),
          child,
        ]),
      );
}

/// A relatable equivalent: the emoji grows in, the number counts up.
class _Equivalent extends StatelessWidget {
  const _Equivalent({required this.emoji, required this.value, required this.label, required this.animate});
  final String emoji, label;
  final int value;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.lg)),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0.4 : 1, end: 1),
          duration: AppMotion.of(context, AppMotion.slow * 2),
          curve: AppMotion.spring,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 32))),
        ),
        AnimatedCount(value, fromZero: animate, duration: const Duration(milliseconds: 900),
            style: context.text.headlineSmall!.copyWith(color: c.onPrimaryContainer)),
        Text(label, textAlign: TextAlign.center,
            style: context.text.labelSmall!.copyWith(color: c.onPrimaryContainer)),
      ]),
    );
  }
}
