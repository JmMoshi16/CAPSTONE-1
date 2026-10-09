import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../widgets/ui.dart';
import '../../widgets/eco_animations.dart';

class ScanHistoryScreen extends StatefulWidget {
  final List<WasteLog> logs;
  /// Reloads from Firestore and returns the fresh list (pull-to-refresh).
  final Future<List<WasteLog>> Function()? onRefresh;
  final VoidCallback? onScan;
  const ScanHistoryScreen({super.key, required this.logs, this.onRefresh, this.onScan});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  String _filter = 'All';
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
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xxs, AppSpace.md, AppSpace.xl),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _logTile(filtered[i]),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withRefresh(Widget child) =>
      widget.onRefresh == null ? child : RefreshIndicator(onRefresh: _refresh, child: child);

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

  Widget _logTile(WasteLog log) {
    final c = context.colors;
    return AppListTile(
      margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      leading: IconBadge(icon: wasteIcon(log.wasteType), color: c.waste(log.wasteType)),
      title: log.wasteType,
      subtitle: Text(DateFormat('MMM d, yyyy · h:mm a').format(log.timestamp), style: context.text.bodySmall),
      trailing: PointsPill('+${log.pointsAwarded} pts'),
    );
  }
}
