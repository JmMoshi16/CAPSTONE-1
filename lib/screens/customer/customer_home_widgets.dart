part of 'customer_home_screen.dart';

// ── Hero Header Card ──────────────────────────────────────────────────────────
class _HeroHeaderCard extends StatelessWidget {
  final UserModel user;
  final int myRank, pendingRedemptions, lifetimePoints, streak;
  final int points;                     // spendable balance, counted up when it changes
  final bool countFromZero;
  final VoidCallback onBell, onProfile, onRankInfo, onLeaderboard;
  /// The page's scroll position: the header content drifts slower than the page (parallax).
  final ScrollController? scroll;
  const _HeroHeaderCard({
    this.scroll,
    required this.onRankInfo, required this.onLeaderboard,
    required this.user, required this.myRank, required this.pendingRedemptions,
    required this.lifetimePoints, required this.points, required this.countFromZero, required this.streak,
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
    final reduced = AppMotion.reduced(context);
    // Parallax: decorations move at half the scroll speed, content at 30 % and fades.
    Widget drift(double factor, Widget child, {bool fade = false}) => scroll == null || reduced
        ? child
        : AnimatedBuilder(
            animation: scroll!,
            child: child,
            builder: (_, kid) {
              final off = scroll!.hasClients ? scroll!.offset.clamp(0.0, 400.0) : 0.0;
              final moved = Transform.translate(offset: Offset(0, off * factor), child: kid);
              if (!fade) return moved;
              final o = (1 - off / 320).clamp(0.0, 1.0);
              return o > 0.99 ? moved : Opacity(opacity: o, child: moved);
            },
          );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: heroDecoration(context,
          radius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxxl))),
      child: Stack(children: [
        Positioned.fill(child: drift(0.5, Stack(children: [
        Positioned(top: -40, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
        Positioned(bottom: 20, left: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)))),

        ]))),
        drift(0.3, fade: true, SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
          child: Column(children: [

            // ── Top row: avatar / name / bell ──────────────────────────────
            Row(children: [
              Tap(label: 'Open profile', tooltip: true,
                onTap: onProfile,
                child: Hero(
                  tag: 'avatar-${user.uid}',
                  flightShuttleBuilder: heroMaterialFlight,
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
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting, style: t.labelSmall!.copyWith(color: c.onHeroMuted)),
                Text(user.username, overflow: TextOverflow.ellipsis,
                    style: t.titleMedium!.copyWith(color: c.onHero)),
              ])),
              Tap(label: pendingRedemptions > 0 ? 'Notifications, $pendingRedemptions pending' : 'Notifications', tooltip: true,
                onTap: onBell,
                child: _WiggleBell(active: pendingRedemptions > 0, child: Stack(clipBehavior: Clip.none, children: [
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
                ])),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedCount(
                      points,
                      fromZero: countFromZero,
                      format: NumberFormat('#,###').format,
                      style: AppType.numeral.copyWith(color: c.onHero),
                    ),
                  ),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpace.xs, children: [
                    Text('points', style: t.bodySmall!.copyWith(color: c.onHeroMuted)),
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
              _pill(context, '${lv.emoji} Lv ${lv.level} ${lv.title}', onRankInfo, 'Level ${lv.level} ${lv.title}, explain levels'),
              _pill(context, '${rk.icon} ${rk.label}', onRankInfo, '${rk.label} rank, explain ranks'),
              if (myRank > 0) _pill(context, '🏆 #$myRank', onLeaderboard, 'Leaderboard position $myRank, open leaderboard'),
            ]),
          ]),
        ))),
      ]),
    );
  }

  Widget _pill(BuildContext context, String label, VoidCallback onTap, String semantics) =>
      Tap(label: semantics, onTap: onTap, child: _pillBody(context, label));

  Widget _pillBody(BuildContext context, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs + 1),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: AppRadius.all(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Text(label, style: context.text.labelSmall!.copyWith(color: context.colors.onHero)),
  );
}



// ── Rank / level ring card ────────────────────────────────────────────────────
class _RingCard extends StatelessWidget {
  final double progress;
  final Color color;
  final Widget center;
  final String title, subtitle;
  final bool fromZero;
  final VoidCallback onTap;
  const _RingCard({
    required this.progress, required this.color, required this.center,
    required this.title, required this.subtitle, required this.fromZero, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Tap(
      label: '$title, ${(progress * 100).round()} percent, $subtitle. Explain ranks and levels',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: cardDecoration(context, radius: AppRadius.lg + 2),
        child: Row(children: [
          RepaintBoundary(
            child: AnimatedProgressRing(
              progress: progress,
              size: 52,
              stroke: 6,
              color: color,
              fromZero: fromZero,
              child: center,
            ),
          ),
          const SizedBox(width: AppSpace.sm - 2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.labelMedium!.copyWith(color: c.ink(color), fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSmall),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Animated streak flame ─────────────────────────────────────────────────────
/// The streak flame flickers gently while a streak is alive; still otherwise and with
/// reduced motion.
class _Flame extends StatefulWidget {
  const _Flame({required this.active});
  final bool active;
  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Flame old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !AppMotion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = Curves.easeInOut.transform(_c.value);
            return Transform.rotate(
              angle: (v - 0.5) * 0.14,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: 1 + 0.12 * v,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: widget.active ? 1 : 0.45,
                  child: const Text('🔥', style: TextStyle(fontSize: 20)),
                ),
              ),
            );
          },
        ),
      );
}

// ── Weekly Goal Bar ───────────────────────────────────────────────────────────
class _WeeklyGoalBar extends StatelessWidget {
  final int scanCount;
  final int weeklyGoal;
  final bool fromZero;
  const _WeeklyGoalBar({required this.scanCount, required this.weeklyGoal, this.fromZero = true});

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
          Expanded(child: Text('7-day goal', style: t.labelMedium)),
          Text(
            done ? '✅ Goal reached!' : '$scanCount / $weeklyGoal scans',
            style: t.labelSmall!.copyWith(
              color: done ? c.success : c.textSecondary,
              fontWeight: done ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.xs - 2),
        AnimatedBar(progress: progress, color: done ? c.success : c.primary, height: 6, fromZero: fromZero),
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

  static const _slotOfTab = [0, 1, 3, 4];   // slot 2 is the scan button

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slot = _slotOfTab[selectedIndex];
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
          child: Stack(alignment: Alignment.center, children: [
            // Indicator that slides between tabs.
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(-1 + slot * 0.5, 0),
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.emphasized,
                child: FractionallySizedBox(
                  widthFactor: 1 / 5,
                  child: Center(
                    child: Container(
                      width: 60, height: 52,
                      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.lg)),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              _navItem(context, Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _navItem(context, Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards', 1),
              Expanded(
                // heightFactor 1: size to the button, not to all the height the bottom-bar slot allows.
                child: Center(
                  heightFactor: 1,
                  child: Tap(label: 'Scan QR code', tooltip: true,
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
                ),
              ),
              _navItem(context, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Impact', 2),
              _navItem(context, Icons.person_rounded, Icons.person_outlined, 'Profile', 3),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData active, IconData inactive, String label, int index) {
    final c = context.colors;
    final selected = selectedIndex == index;
    final fg = selected ? c.primary : c.textTertiary;
    return Expanded(
      child: Tap(label: label, selected: selected,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.fast),
              child: Icon(selected ? active : inactive, key: ValueKey(selected), color: fg, size: 22),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppMotion.of(context, AppMotion.fast),
              style: context.text.labelSmall!.copyWith(color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Bell wiggle ───────────────────────────────────────────────────────────────
/// A short wiggle (400 ms) every 5 s while there are pending codes. Off with reduced motion.
class _WiggleBell extends StatefulWidget {
  const _WiggleBell({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_WiggleBell> createState() => _WiggleBellState();
}

class _WiggleBellState extends State<_WiggleBell> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && widget.active && !AppMotion.reduced(context)) _c.forward(from: 0);
    });
    // First wiggle shortly after the screen settles.
    Future.delayed(AppMotion.slow * 2, () {
      if (mounted && widget.active && !AppMotion.reduced(context)) _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, child) => Transform.rotate(
            // Damped swing: about ±14 degrees, settling to rest.
            angle: math.sin(_c.value * math.pi * 4) * 0.25 * (1 - _c.value),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
}

// ── Offline banner ────────────────────────────────────────────────────────────
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xxs, AppSpace.xxs, AppSpace.xxs),
        decoration: BoxDecoration(
          color: c.warningContainer,
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(color: c.warning.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, color: c.warning, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text("Couldn't refresh. Showing your last saved data.",
              style: context.text.bodySmall!.copyWith(color: c.textPrimary))),
          _busy
              ? const Padding(
                  padding: EdgeInsets.all(AppSpace.md - 2),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : TextButton(onPressed: _retry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}

// ── Notification item data model ──────────────────────────────────────────────
class _NotifItem {
  /// Stable while the content is the same; used to remember dismissals.
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback? onTap;
  /// Close the sheet before running [onTap] (false for in-place actions such as copy).
  final bool closes;

  const _NotifItem({
    required this.id,
    this.closes = true,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });
}
