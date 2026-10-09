import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../widgets/ui.dart';
import 'info_sheets.dart';
import '../../widgets/eco_animations.dart';

class ScanHistoryScreen extends StatefulWidget {
  final List<WasteLog> logs;
  /// Reloads from Firestore and returns the fresh list (pull-to-refresh).
  final Future<List<WasteLog>> Function()? onRefresh;
  final VoidCallback? onScan;
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

  static const _types = ['All', 'Biodegradable', 'Recyclable', 'Residual'];

  List<WasteLog> get _filtered =>
      _filter == 'All' ? _logs : _logs.where((l) => l.wasteType == _filter).toList();

  int get _totalPoints => _logs.fold(0, (s, l) => s + l.pointsAwarded);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final filtered = _filtered;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: AppLayout.headerHeight(context, 180),
            pinned: true,
            backgroundColor: c.hero[1],
            leading: IconButton(
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back_ios_new, color: c.onHero, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: heroDecoration(context),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpace.xxxl),
                        Text('Scan History', style: t.headlineSmall!.copyWith(color: c.onHero, fontSize: 24)),
                        const SizedBox(height: AppSpace.xxs),
                        Text('${_logs.length} scans · $_totalPoints pts total',
                            style: t.bodyMedium!.copyWith(color: c.onHeroMuted)),
                        const SizedBox(height: AppSpace.md),
                        // Summary chips
                        Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                          _summaryChip('🌿', '${_logs.where((l) => l.wasteType == 'Biodegradable').length}', 'Bio'),
                          _summaryChip('♻️', '${_logs.where((l) => l.wasteType == 'Recyclable').length}', 'Rec'),
                          _summaryChip('🗑️', '${_logs.where((l) => l.wasteType == 'Residual').length}', 'Res'),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
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
                        onAction: _filter != 'All' ? () => setState(() => _filter = 'All') : widget.onScan,
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
                              SliverPersistentHeader(pinned: true, delegate: _DayHeader(day, context)),
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

  Widget _summaryChip(String emoji, String count, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs - 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: AppRadius.all(AppRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: AppSpace.xxs),
          Text('$count $label', style: context.text.labelMedium!.copyWith(color: context.colors.onHero)),
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

  Widget _logTile(WasteLog log) {
    final c = context.colors;
    return AppListTile(
      margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      leading: IconBadge(icon: wasteIcon(log.wasteType), color: c.waste(log.wasteType)),
      title: log.wasteType,
      subtitle: Text(DateFormat('MMM d, yyyy · h:mm a').format(log.timestamp), style: context.text.bodySmall),
      trailing: PointsPill('+${log.pointsAwarded} pts'),
      onTap: () => showScanDetailSheet(context, log),
      semanticLabel: '${log.wasteType} scan, +${log.pointsAwarded} points, details',
    );
  }
}

class _Day {
  _Day(this.date, this.logs);
  final DateTime date;
  final List<WasteLog> logs;
}

/// Sticky day header: "Today · 3 scans · +38 pts".
class _DayHeader extends SliverPersistentHeaderDelegate {
  _DayHeader(this.day, this.ctx);
  final _Day day;
  final BuildContext ctx;

  static const _height = 40.0;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day.date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(day.date.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d yyyy').format(day.date);
  }

  double get _extent => _height * AppLayout.textScale(ctx).clamp(1.0, 1.6);

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
  bool shouldRebuild(_DayHeader old) => old.day != day;
}
