import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../widgets/ui.dart';

class ImpactScreen extends StatefulWidget {
  final List<WasteLog> logs;
  const ImpactScreen({super.key, required this.logs});
  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _bodyCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: AppMotion.countUp);
    _bodyCtrl   = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard);
    _headerCtrl.forward();
    Future.delayed(AppMotion.medium, () { if (mounted) _bodyCtrl.forward(); });
  }

  @override
  void dispose() { _headerCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final bio      = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec      = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res      = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final totalPts = widget.logs.fold(0, (s, l) => s + l.pointsAwarded);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: c.hero[1],
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _headerFade,
                child: Container(
                  decoration: heroDecoration(context),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Personal Impact', style: t.headlineSmall!.copyWith(color: c.onHero)),
                        const SizedBox(height: AppSpace.xs - 2),
                        Text('Your recycling contribution', style: t.bodyMedium!.copyWith(color: c.onHeroMuted)),
                        const SizedBox(height: AppSpace.md),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _CountUpStat(end: widget.logs.length, label: 'Total Logs', ctrl: _headerCtrl),
                          _CountUpStat(end: totalPts, label: 'Points Earned', ctrl: _headerCtrl),
                          _CountUpStat(end: rec, label: 'Recyclable', ctrl: _headerCtrl),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _PopInCard(index: 0,
                      child: _typeCard('Biodegradable', bio, wasteIcon('Biodegradable'), c.bio))),
                  const SizedBox(width: AppSpace.sm - 2),
                  Expanded(child: _PopInCard(index: 1,
                      child: _typeCard('Recyclable', rec, wasteIcon('Recyclable'), c.rec))),
                  const SizedBox(width: AppSpace.sm - 2),
                  Expanded(child: _PopInCard(index: 2,
                      child: _typeCard('Residual', res, wasteIcon('Residual'), c.res))),
                ]),
                const SizedBox(height: AppSpace.lg),
                Text('Disposal History', style: t.titleMedium!.copyWith(color: c.primary)),
                const SizedBox(height: AppSpace.sm),
              ]),
            ),
          ),

          if (widget.logs.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.recycling_rounded,
                title: 'No disposal history yet',
                message: 'Scan a bin QR code to start!',
                dense: true,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FadeSlideItem(index: i, child: _logTile(widget.logs[i])),
                  childCount: widget.logs.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.navClearance)),
        ],
      ),
    );
  }

  Widget _typeCard(String label, int count, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.md - 2, horizontal: AppSpace.xs),
    decoration: cardDecoration(context, radius: AppRadius.lg),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(AppSpace.sm - 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: AppSpace.xs - 2),
      Text('$count', style: context.text.titleLarge),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: context.text.labelSmall, textAlign: TextAlign.center)),
    ]),
  );

  Widget _logTile(WasteLog log) {
    final c = context.colors;
    return AppListTile(
      margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      leading: IconBadge(icon: wasteIcon(log.wasteType), color: c.wasteFill(log.wasteType), size: 46, filled: true),
      title: log.wasteType,
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEE, MMM d yyyy · h:mm a').format(log.timestamp),
            style: context.text.bodySmall!.copyWith(color: c.textPrimary)),
        Text('Bin: ${log.binId}', style: context.text.bodySmall),
      ]),
      trailing: PointsPill('+${log.pointsAwarded} pts'),
    );
  }
}

// ── Count-up stat widget ──────────────────────────────────────────────────────
class _CountUpStat extends StatelessWidget {
  final int end;
  final String label;
  final AnimationController ctrl;
  const _CountUpStat({required this.end, required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final anim = Tween<double>(begin: 0, end: end.toDouble())
        .animate(CurvedAnimation(parent: ctrl, curve: AppMotion.standard));
    return Column(children: [
      AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Text('${anim.value.toInt()}',
            style: context.text.titleLarge!.copyWith(color: c.onHero, fontSize: 20)),
      ),
      Text(label, style: context.text.labelSmall!.copyWith(color: c.onHeroMuted)),
    ]);
  }
}

// ── Pop-in card wrapper ───────────────────────────────────────────────────────
class _PopInCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _PopInCard({required this.index, required this.child});
  @override
  State<_PopInCard> createState() => _PopInCardState();
}

class _PopInCardState extends State<_PopInCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppMotion.slow);
    _scale = Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: _c, curve: AppMotion.spring));
    Future.delayed(AppMotion.fast + AppMotion.stagger * (widget.index * 2), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _c, child: ScaleTransition(scale: _scale, child: widget.child));
}

// ── Fade+slide list item ──────────────────────────────────────────────────────
class _FadeSlideItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _FadeSlideItem({required this.index, required this.child});
  @override
  State<_FadeSlideItem> createState() => _FadeSlideItemState();
}

class _FadeSlideItemState extends State<_FadeSlideItem> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppMotion.slow);
    _fade  = CurvedAnimation(parent: _c, curve: AppMotion.standard);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: AppMotion.standard));
    final delay = AppMotion.stagger * widget.index;
    Future.delayed(AppMotion.medium + (delay > AppMotion.slow ? AppMotion.slow : delay), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
