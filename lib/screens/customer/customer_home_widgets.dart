part of 'customer_home_screen.dart';

// ── Hero Header Card ──────────────────────────────────────────────────────────
class _HeroHeaderCard extends StatelessWidget {
  final UserModel user;
  final int myRank, pendingRedemptions, lifetimePoints, streak;
  final Animation<double> pointsAnim;   // animates the spendable balance
  final VoidCallback onBell, onProfile;
  const _HeroHeaderCard({
    required this.user, required this.myRank, required this.pendingRedemptions,
    required this.lifetimePoints, required this.pointsAnim, required this.streak,
    required this.onBell, required this.onProfile,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final lv = getLevel(lifetimePoints);
    final rk = getRank(lifetimePoints);
    final multiplier = streakMultiplier(streak);
    return Container(
      decoration: heroDecoration(context,
          radius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxxl))),
      child: Stack(children: [
        Positioned(top: -40, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
        Positioned(bottom: 20, left: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)))),

        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
          child: Column(children: [

            // ── Top row: avatar / name / bell ──────────────────────────────
            Row(children: [
              Tap(label: 'Open profile', tooltip: true,
                onTap: onProfile,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                    style: t.titleLarge!.copyWith(color: c.onHero),
                  )),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting, style: t.labelSmall!.copyWith(color: c.onHeroMuted)),
                Text(user.username, overflow: TextOverflow.ellipsis,
                    style: t.titleMedium!.copyWith(color: c.onHero)),
              ])),
              Tap(label: pendingRedemptions > 0 ? 'Notifications, $pendingRedemptions pending' : 'Notifications', tooltip: true,
                onTap: onBell,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.notifications_rounded, color: c.onHero, size: 20),
                  ),
                  if (pendingRedemptions > 0)
                    Positioned(top: -2, right: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('$pendingRedemptions',
                            style: t.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      )),
                ]),
              ),
            ]),

            const SizedBox(height: AppSpace.xl),

            // ── Points display (centered, no box) ──────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(colors: AppPalette.coin, stops: [0.0, 0.5, 1.0]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppPalette.coin[1].withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpace.md - 2),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedBuilder(
                    animation: pointsAnim,
                    builder: (_, __) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        NumberFormat('#,###').format(pointsAnim.value.toInt()),
                        style: AppType.numeral.copyWith(color: c.onHero),
                      ),
                    ),
                  ),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpace.xs, children: [
                    Text('eco credits', style: t.bodySmall!.copyWith(color: c.onHeroMuted)),
                    if (multiplier > 1.0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: AppRadius.all(AppRadius.md),
                          border: Border.all(color: c.heroAccent.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          streak >= 7 ? '🔥 2× Bonus' : '🔥 1.5× Bonus',
                          style: t.labelSmall!.copyWith(color: c.heroAccent, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                ]),
              ),
            ]),

            const SizedBox(height: AppSpace.lg),

            // ── Rank + Level pills ─────────────────────────────────────────
            Wrap(alignment: WrapAlignment.center, spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
              _pill(context, '${lv.emoji} Lv ${lv.level} ${lv.title}'),
              _pill(context, '${rk.icon} ${rk.label}'),
              if (myRank > 0) _pill(context, '🏆 #$myRank'),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _pill(BuildContext context, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs + 1),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: AppRadius.all(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Text(label, style: context.text.labelSmall!.copyWith(color: context.colors.onHero)),
  );
}



// ── Progress Bar Row (labeled) ────────────────────────────────────────────────

class _ProgressBarRow extends StatelessWidget {
  final String leftLabel, rightLabel;
  final double progress;
  final Color color;
  const _ProgressBarRow({
    required this.leftLabel, required this.rightLabel,
    required this.progress, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(leftLabel,
            style: context.text.labelMedium!.copyWith(color: c.ink(color), fontWeight: FontWeight.w700))),
        Text(rightLabel, style: context.text.labelSmall!.copyWith(color: c.textTertiary)),
      ]),
      const SizedBox(height: AppSpace.xs - 2),
      _AnimatedProgressBar(progress: progress, color: color),
    ]);
  }
}

// ── Animated Progress Bar ─────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  const _AnimatedProgressBar({required this.progress, required this.color});
  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.countUp);
    _anim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.standard));
    Future.delayed(AppMotion.slow, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => ClipRRect(
      borderRadius: AppRadius.all(6),
      child: LinearProgressIndicator(
        value: _anim.value,
        backgroundColor: context.colors.surfaceAlt,
        valueColor: AlwaysStoppedAnimation(widget.color),
        minHeight: 8,
      ),
    ),
  );
}

// ── Weekly Goal Bar ───────────────────────────────────────────────────────────
class _WeeklyGoalBar extends StatelessWidget {
  final int scanCount;
  final int weeklyGoal;
  const _WeeklyGoalBar({required this.scanCount, required this.weeklyGoal});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final progress = (scanCount / weeklyGoal).clamp(0.0, 1.0);
    final done = scanCount >= weeklyGoal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md - 2, vertical: AppSpace.sm),
      decoration: cardDecoration(context, radius: AppRadius.lg - 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const ExcludeSemantics(child: Text('🎯', style: TextStyle(fontSize: 13))),
          const SizedBox(width: AppSpace.xs - 2),
          Expanded(child: Text('Weekly Goal · last 7 days', style: t.labelMedium)),
          Text(
            done ? '✅ Goal reached!' : '$scanCount / $weeklyGoal scans',
            style: t.labelSmall!.copyWith(
              color: done ? c.success : c.textSecondary,
              fontWeight: done ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.xs - 2),
        ClipRRect(
          borderRadius: AppRadius.all(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: c.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(done ? c.success : c.primary),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ── Floating Nav Bar ──────────────────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;
  const _FloatingNavBar({required this.selectedIndex, required this.onTap, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.all(AppRadius.pill),
            border: c.isDark ? Border.all(color: c.border) : null,
            boxShadow: AppShadows.of(context, AppShadows.e3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _navItem(context, Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards', 1),
              Tap(label: 'Scan QR code', tooltip: true,
                onTap: onScan,
                child: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.of(context,
                        [BoxShadow(color: c.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: c.onPrimary, size: 26),
                ),
              ),
              _navItem(context, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Insight', 2),
              _navItem(context, Icons.person_rounded, Icons.person_outlined, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData active, IconData inactive, String label, int index) {
    final c = context.colors;
    final selected = selectedIndex == index;
    final fg = selected ? c.primary : c.textTertiary;
    return Tap(label: label, selected: selected,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm - 2, vertical: AppSpace.xs),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.all(AppRadius.lg - 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? active : inactive, color: fg, size: 22),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelSmall!.copyWith(color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Notification item data model ──────────────────────────────────────────────
class _NotifItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback? onTap;

  const _NotifItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });
}
