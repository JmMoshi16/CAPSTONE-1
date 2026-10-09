import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../widgets/ui.dart';

class ScanHistoryScreen extends StatefulWidget {
  final List<WasteLog> logs;
  const ScanHistoryScreen({super.key, required this.logs});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  String _filter = 'All';

  static const _types = ['All', 'Biodegradable', 'Recyclable', 'Residual'];

  List<WasteLog> get _filtered =>
      _filter == 'All' ? widget.logs : widget.logs.where((l) => l.wasteType == _filter).toList();

  int get _totalPoints => widget.logs.fold(0, (s, l) => s + l.pointsAwarded);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final filtered = _filtered;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 180,
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
                        Text('${widget.logs.length} scans · $_totalPoints pts total',
                            style: t.bodyMedium!.copyWith(color: c.onHeroMuted)),
                        const SizedBox(height: AppSpace.md),
                        // Summary chips
                        Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                          _summaryChip('🌿', '${widget.logs.where((l) => l.wasteType == 'Biodegradable').length}', 'Bio'),
                          _summaryChip('♻️', '${widget.logs.where((l) => l.wasteType == 'Recyclable').length}', 'Rec'),
                          _summaryChip('🗑️', '${widget.logs.where((l) => l.wasteType == 'Residual').length}', 'Res'),
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
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.history_rounded,
                      title: _filter == 'All' ? 'No scans yet' : 'No $_filter scans',
                      dense: true,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xxs, AppSpace.md, AppSpace.xl),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _logTile(filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
