import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../widgets/ui.dart';
import 'info_sheets.dart';
import '../../widgets/eco_animations.dart';

class ScanHistoryScreen extends StatefulWidget {
  final List<WasteLog> logs;
  /// Reloads from Firestore and returns the fresh list (pull-to-refresh).
  final Future<List<WasteLog>> Function()? onRefresh;
  /// Opens the scanner; completes when it closes, then the list reloads to show the new scan.
  final Future<void> Function()? onScan;
  /// Filter to open with ('All' or a waste type), e.g. from an Impact type card.
  final String initialFilter;
  const ScanHistoryScreen({super.key, required this.logs, this.onRefresh, this.onScan, this.initialFilter = 'All'});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  late String _filter = widget.initialFilter;
  late List<WasteLog> _logs = widget.logs;

  Future<void> _refresh() async {
    final fresh = await widget.onRefresh!();
    if (mounted) setState(() => _logs = fresh);
  }

  Future<void> _scan() async {
    await widget.onScan!();
    if (widget.onRefresh != null) await _refresh();
  }

  static const _types = ['All', 'Biodegradable', 'Recyclable', 'Residual'];

  List<WasteLog> get _filtered =>
      _filter == 'All' ? _logs : _logs.where((l) => l.wasteType == _filter).toList();

  int get _totalPoints => _logs.fold(0, (s, l) => s + l.pointsAwarded);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final filtered = _filtered;

    return PageScaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          const AppSliverHeader(title: 'Scan history'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_logs.length} scan${_logs.length == 1 ? '' : 's'} · $_totalPoints pts total',
                    style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.md),
                // Summary chips: one row that scrolls on narrow phones.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final type in const ['Biodegradable', 'Recyclable', 'Residual']) ...[
                      _summaryChip(type, '${_logs.where((l) => l.wasteType == type).length}'),
                      const SizedBox(width: AppSpace.xs),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ],
        body: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xxs),
                itemCount: _types.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
                itemBuilder: (_, i) {
                  final type = _types[i];
                  return AppChip(
                    label: type,
                    semanticLabel: 'Show $type scans',
                    selected: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  );
                },
              ),
            ),

            // List
            Expanded(
              child: _withRefresh(filtered.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [SliverFillRemaining(hasScrollBody: false, child: EmptyState(
                        icon: Icons.history_rounded,
                        // The idle brand animation (previously unused) welcomes a brand-new user.
                        illustration: _filter == 'All' ? const EcoIdle(size: 140) : null,
                        title: _filter == 'All' ? 'No scans yet' : 'No $_filter scans',
                        message: _filter == 'All' ? 'Your scans will appear here.' : null,
                        actionLabel: _filter != 'All' ? 'Show all scans'
                            : (widget.onScan != null ? 'Scan a QR code' : null),
                        onAction: _filter != 'All'
                            ? () => setState(() => _filter = 'All')
                            : (widget.onScan != null ? _scan : null),
                        dense: true,
                      ))],
                    )
                  // Changing the filter cross-fades and slides the list.
                  : AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.medium),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: CustomScrollView(
                        key: ValueKey(_filter),
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          for (final day in _groupByDay(filtered))
                            SliverMainAxisGroup(slivers: [
                              SliverPersistentHeader(pinned: true, delegate: _DayHeader(day, AppLayout.textScale(context))),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                                sliver: SliverList.builder(
                                  itemCount: day.logs.length,
                                  itemBuilder: (_, i) => _swipeable(day.logs[i], i),
                                ),
                              ),
                            ]),
                          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
                        ],
                      ),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withRefresh(Widget child) =>
      widget.onRefresh == null ? child : EcoRefresh(onRefresh: _refresh, child: child);

  Widget _summaryChip(String type, String count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(wasteIcon(type), size: 16, color: context.colors.ink(context.colors.waste(type))),
          const SizedBox(width: AppSpace.xxs),
          Text('$count $type', style: context.text.labelMedium),
        ]),
      );

  /// Logs are newest first; group them into days, keeping that order.
  List<_Day> _groupByDay(List<WasteLog> logs) {
    final days = <_Day>[];
    for (final l in logs) {
      final d = DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day);
      if (days.isEmpty || days.last.date != d) days.add(_Day(d, []));
      days.last.logs.add(l);
    }
    return days;
  }

  /// Swipe left to open the details (the row springs back); a tap does the same.
  Widget _swipeable(WasteLog log, int i) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey('${log.timestamp.millisecondsSinceEpoch}-$i'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      confirmDismiss: (_) async {
        AppHaptics.tap();
        showScanDetailSheet(context, log);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
        padding: const EdgeInsets.only(right: AppSpace.lg),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.lg)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline_rounded, color: c.onPrimaryContainer),
          const SizedBox(width: AppSpace.xs),
          Text('Details', style: context.text.labelMedium!.copyWith(color: c.onPrimaryContainer)),
        ]),
      ),
      child: _logTile(log),
    );
  }

  Widget _logTile(WasteLog log) => AppScanRow(log: log, onTap: () => showScanDetailSheet(context, log));
}

class _Day {
  _Day(this.date, this.logs);
  final DateTime date;
  final List<WasteLog> logs;
}

/// Sticky day header: "Today · 3 scans · +38 pts".
class _DayHeader extends SliverPersistentHeaderDelegate {
  // The text scale is passed in; a delegate must not keep a BuildContext (audit O).
  _DayHeader(this.day, this.textScale);
  final _Day day;
  final double textScale;

  static const _height = 40.0;

  String get _label => AppDates.dayLabel(day.date);

  double get _extent => _height * textScale.clamp(1.0, 1.6);

  @override
  double get minExtent => _extent;
  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;
    final pts = day.logs.fold(0, (s, l) => s + l.pointsAwarded);
    return Container(
      color: c.background.withValues(alpha: overlapsContent || shrinkOffset > 0 ? 0.96 : 1),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      alignment: Alignment.centerLeft,
      child: Semantics(
        header: true,
        child: Row(children: [
          Text(_label, style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: AppSpace.xs),
          Flexible(child: Text('· ${day.logs.length} scan${day.logs.length == 1 ? '' : 's'} · +$pts pts',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall)),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeader old) => old.day != day || old.textScale != textScale;
}
