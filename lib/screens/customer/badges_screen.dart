import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';
import 'info_sheets.dart';

class BadgesScreen extends StatefulWidget {
  final UserModel user;
  const BadgesScreen({super.key, required this.user});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl  = AnimationController(vsync: this, duration: AppMotion.slow);
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard));
    _headerCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _headerCtrl.value = 1;
  }

  @override
  void dispose() { _headerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final allDefs    = FirebaseService.getAllBadgeDefs();
    final earned     = widget.user.badges;
    final earnedDefs = allDefs.where((b) => earned.contains(b['id'])).toList();
    final lockedDefs = allDefs.where((b) => !earned.contains(b['id'])).toList();
    // Taller cards when the user enlarges text, so descriptions are not clipped.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: AppLayout.columns(context, minTile: 160, max: 6), crossAxisSpacing: AppSpace.sm, mainAxisSpacing: AppSpace.sm,
      childAspectRatio: 1.05 / textScale,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Container(
                  decoration: heroDecoration(context,
                      radius: const BorderRadius.vertical(bottom: Radius.circular(AppSpace.xxl))),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.lg, AppSpace.xl + 4),
                      child: Column(children: [
                        Row(children: [
                          HeroBackButton(onTap: () => Navigator.pop(context)),
                          const SizedBox(width: AppSpace.xs),
                          Text('My Badges', style: t.headlineSmall!.copyWith(color: c.onHero, fontSize: 20)),
                        ]),
                        const SizedBox(height: AppSpace.md),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: AppRadius.all(AppRadius.lg),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _headerStat('${earnedDefs.length}', 'Earned'),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                            _headerStat('${lockedDefs.length}', 'Locked'),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                            _headerStat('${allDefs.length}', 'Total'),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (earnedDefs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
                child: Row(children: [
                  Icon(Icons.emoji_events_rounded, color: c.gold, size: 18),
                  const SizedBox(width: AppSpace.xs),
                  Text('Earned (${earnedDefs.length})', style: t.titleMedium!.copyWith(fontSize: 15)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              sliver: SliverGrid(
                gridDelegate: gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Tap(
                    label: '${earnedDefs[i]['label']}, earned, details',
                    onTap: () => showBadgeSheet(context, def: earnedDefs[i], user: widget.user),
                    child: _AnimatedBadgeCard(def: earnedDefs[i], earned: true, index: i),
                  ),
                  childCount: earnedDefs.length,
                ),
              ),
            ),
          ],

          if (lockedDefs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded, color: c.textTertiary, size: 18),
                  const SizedBox(width: AppSpace.xs),
                  Text('Locked (${lockedDefs.length})', style: t.titleMedium!.copyWith(fontSize: 15)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.navClearance),
              sliver: SliverGrid(
                gridDelegate: gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Tap(
                    label: '${lockedDefs[i]['label']}, locked, how to unlock',
                    onTap: () => showBadgeSheet(context, def: lockedDefs[i], user: widget.user),
                    child: _AnimatedBadgeCard(def: lockedDefs[i], earned: false, index: i + earnedDefs.length),
                  ),
                  childCount: lockedDefs.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) => Column(children: [
    Text(value, style: context.text.headlineSmall!.copyWith(color: context.colors.onHero)),
    Text(label, style: context.text.labelSmall!.copyWith(color: context.colors.onHeroMuted)),
  ]);
}

class _AnimatedBadgeCard extends StatefulWidget {
  final Map<String, dynamic> def;
  final bool earned;
  final int index;
  const _AnimatedBadgeCard({required this.def, required this.earned, required this.index});
  @override
  State<_AnimatedBadgeCard> createState() => _AnimatedBadgeCardState();
}

class _AnimatedBadgeCardState extends State<_AnimatedBadgeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: AppMotion.slow);
    _scale = Tween<double>(begin: 0.85, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.spring));
    _fade  = CurvedAnimation(parent: _ctrl, curve: AppMotion.standard);
    final delay = AppMotion.stagger * widget.index;
    Future.delayed(AppMotion.fast + (delay > AppMotion.slow ? AppMotion.slow : delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _ctrl.value = 1;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Semantics(
          label: '${widget.def['label']}, ${widget.earned ? 'earned' : 'locked'}. ${widget.def['desc']}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: widget.earned
                ? cardDecoration(context, borderColor: c.gold.withValues(alpha: 0.5))
                : BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: AppRadius.all(AppRadius.xl),
                    border: Border.all(color: c.border),
                  ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              widget.earned
                  ? Text(widget.def['icon'] as String, style: const TextStyle(fontSize: 36))
                  : Stack(alignment: Alignment.center, children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      0.4, 0,
                        ]),
                        child: Text(widget.def['icon'] as String, style: const TextStyle(fontSize: 36)),
                      ),
                      Icon(Icons.lock_rounded, color: c.textSecondary, size: 18),
                    ]),
              const SizedBox(height: AppSpace.xs),
              Text(widget.def['label'] as String,
                  style: t.labelMedium!.copyWith(fontWeight: FontWeight.w700,
                      color: widget.earned ? c.textPrimary : c.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.xxs),
              Text(widget.def['desc'] as String,
                  style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (widget.earned) ...[
                const SizedBox(height: AppSpace.xs - 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.gold.withValues(alpha: 0.12),
                    borderRadius: AppRadius.all(AppRadius.sm),
                    border: Border.all(color: c.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text('✓ Earned', style: t.labelSmall!.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
