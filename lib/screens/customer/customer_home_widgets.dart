part of 'customer_home_screen.dart';

// ── Hero: the navy surface carrying who you are, your points and the four things you do most ──
class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.user,
    required this.rewards,
    required this.pending,
    required this.newCodes,
    required this.streak,
    required this.countFromZero,
    required this.onProfile,
    required this.onStreak,
    required this.onBell,
    required this.onBalance,
    required this.onScan,
    required this.onMyCodes,
    required this.onLeaderboard,
    required this.onBadges,
  });

  final UserModel user;
  final List<Reward> rewards;
  final int pending;
  /// Codes the bell hasn't shown yet: opening the bell clears it (My codes keeps [pending]).
  final int newCodes;
  /// Days in a row with a scan (0 = none or broken).
  final int streak;
  final bool countFromZero;
  final VoidCallback onProfile, onBell, onBalance, onScan, onMyCodes, onLeaderboard, onBadges, onStreak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return AuroraBackground(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // The café's mark leads, as on a menu board; you and your notifications sit on the right. Below 360 dp
            // the mark steps aside so the name is not cut short.
            Row(children: [
              if (MediaQuery.sizeOf(context).width >= 360) ...[
                const CraveMark(size: 40),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                HomeGreeting(style: t.bodySmall!.copyWith(color: c.onHeroMuted)),
                Text(user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge!.copyWith(color: AppPalette.cream)),
              ])),
              if (streak > 0) ...[
                _StreakChip(streak: streak, onTap: onStreak),
                const SizedBox(width: AppSpace.xs),
              ],
              Tap(
                label: newCodes > 0 ? 'Notifications, $newCodes new' : 'Notifications',
                tooltip: true,
                onTap: onBell,
                child: Stack(clipBehavior: Clip.none, children: [
                  _GlassCircle(size: 44, child: Icon(Icons.notifications_none_rounded, color: c.onHero, size: 22)),
                  if (newCodes > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.heroAccent, borderRadius: AppRadius.all(AppRadius.pill)),
                        child: Text('$newCodes',
                            style: t.labelSmall!.copyWith(color: AppPalette.navyDeep, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: AppSpace.xs),
              Tap(
                  label: 'Open profile',
                  onTap: onProfile,
                  child: UserAvatar(name: user.username, photo: user.photo, size: 44, onHero: true)),
            ]),
            const SizedBox(height: AppSpace.lg),
            _GlassBalance(user: user, rewards: rewards, countFromZero: countFromZero, onTap: onBalance),
            const SizedBox(height: AppSpace.lg),
            // Equal shares of the width, so four actions fit a 320 dp phone. The labels share one size: if the
            // longest would not fit its share with a gap either side (large system text), all four shrink together.
            LayoutBuilder(builder: (context, box) {
              final scaler = _QuickAction.sharedScaler(context, box.maxWidth / 4 - AppSpace.xs,
                  const ['Scan', 'My codes', 'Leaderboard', 'Badges']);
              return Row(children: [
                for (final action in [
                  _QuickAction(
                      glyph: NavGlyphKind.scan,
                      label: 'Scan',
                      primary: true,
                      onTap: onScan,
                      labelScaler: scaler,
                      semantics: 'Scan the QR code at the bin'),
                  _QuickAction(
                      glyph: NavGlyphKind.codes, label: 'My codes', onTap: onMyCodes, badge: pending, labelScaler: scaler),
                  _QuickAction(
                      glyph: NavGlyphKind.leaderboard, label: 'Leaderboard', onTap: onLeaderboard, labelScaler: scaler),
                  _QuickAction(glyph: NavGlyphKind.badges, label: 'Badges', onTap: onBadges, labelScaler: scaler),
                ])
                  Expanded(child: action),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}

/// The streak, where it is seen every day: a flame and the day count on frosted glass. Opens the streak details.
String greetingFor(DateTime t) => t.hour < 12 ? 'Good morning' : t.hour < 17 ? 'Good afternoon' : 'Good evening';

/// "Good morning" that becomes "Good evening" by itself: Home can stay open from morning to night without a rebuild.
class HomeGreeting extends StatefulWidget {
  const HomeGreeting({super.key, this.style, this.clock = DateTime.now});
  final TextStyle? style;
  final DateTime Function() clock;
  @override
  State<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<HomeGreeting> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(greetingFor(widget.clock()), maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style);
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, required this.onTap});
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tap(
      label: '$streak-day streak, details',
      tooltip: true,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_rounded, size: 20, color: c.heroAccent),
          const SizedBox(width: AppSpace.xxs),
          Text('$streak', style: AppType.tabular(context.text.titleMedium!).copyWith(color: c.onHero)),
        ]),
      ),
    );
  }
}

/// A frosted circle for icons on the navy surface.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Center(child: child),
      );
}

// ── Balance: points, tier and the next reward on frosted glass (Wallet-pass feel) ──
class _GlassBalance extends StatelessWidget {
  const _GlassBalance({required this.user, required this.rewards, required this.countFromZero, required this.onTap});

  final UserModel user;
  final List<Reward> rewards;
  final bool countFromZero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final rank = getRank(user.lifetimePoints);
    final level = getLevel(user.lifetimePoints);
    final open = rewards.where((r) => r.isActive && r.stock != 0).toList()
      ..sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
    final next = open.where((r) => r.pointsCost > user.points).firstOrNull;
    final ready = open.where((r) => r.pointsCost <= user.points).length;
    final goal = next == null
        ? (ready > 0 ? 'You can redeem $ready reward${ready == 1 ? '' : 's'} now' : 'Scan at the bin to earn points')
        : '${next.pointsCost - user.points} pts to ${next.title}';
    final progress = next == null ? (ready > 0 ? 1.0 : 0.0) : (user.points / next.pointsCost).clamp(0.0, 1.0);

    return Tap(
      label: '${user.points} points. ${rank.label} member, level ${level.level}. $goal. Explain ranks and levels',
      onTap: onTap,
      scale: 0.98,
      child: TiltOnTouch(child: AppSurface(
        depth: Depth.floating,
        onHero: true,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Balance', style: t.labelMedium!.copyWith(color: c.onHeroMuted)),   // "85 pts" below says what of
            const SizedBox(width: AppSpace.sm),
            // The rank pill takes what is left, right-aligned; its text shortens before anything wraps.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xxs, AppSpace.xxs, AppSpace.xxs),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: AppRadius.all(AppRadius.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(rankIconData(rank.label), size: 14, color: c.heroAccent),
                    const SizedBox(width: AppSpace.xxs),
                    Flexible(
                        child: Text('${rank.label}, level ${level.level}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium!.copyWith(color: c.onHero))),
                    Icon(Icons.chevron_right_rounded, size: 16, color: c.onHeroMuted),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.xs),
          Row(children: [
          Expanded(child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SheenOnChange(
              value: user.points,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedCount(user.points,
                        fromZero: countFromZero,
                        format: formatCount,
                        style: AppType.balance.copyWith(color: AppPalette.cream)),
                    const SizedBox(width: AppSpace.xs),
                    Text('pts', style: t.titleMedium!.copyWith(color: c.onHeroMuted)),
                  ]),
            ),
          )),
          const SizedBox(width: AppSpace.sm),
          // The signature coin: what the points are, beside how many.
          EcoCoin(size: 60, turnIn: countFromZero),
          ]),
          const SizedBox(height: AppSpace.md),
          AnimatedBar(
              progress: progress,
              color: c.accent,
              trackColor: Colors.white.withValues(alpha: 0.16),
              height: 6,
              fromZero: countFromZero),
          const SizedBox(height: AppSpace.xs),
          Text(goal, style: t.bodySmall!.copyWith(color: c.onHero)),
        ]),
      )),
    );
  }
}

/// One of the four shortcuts under the balance: a circle with one of the app's own icons (the tab bar's family),
/// and a word. Scan is the filled one.
class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.glyph,
      required this.label,
      required this.onTap,
      this.primary = false,
      this.badge = 0,
      this.semantics,
      required this.labelScaler});

  final NavGlyphKind glyph;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final int badge;
  final String? semantics;
  final TextScaler labelScaler;

  static TextStyle _labelStyle(BuildContext context) => context.text.labelMedium!;

  /// The phone's text scale, reduced just enough that the longest label fits [width].
  static TextScaler sharedScaler(BuildContext context, double width, List<String> labels) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = _labelStyle(context);
    var widest = 0.0;
    for (final l in labels) {
      final p = TextPainter(text: TextSpan(text: l, style: style), textDirection: TextDirection.ltr, textScaler: scaler)
        ..layout();
      widest = widest > p.width ? widest : p.width;
      p.dispose();
    }
    if (widest <= width) return scaler;
    final size = style.fontSize!;
    return TextScaler.linear(scaler.scale(size) / size * width / widest);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = primary
        ? Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.accent,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Center(child: NavGlyph(glyph, color: AppPalette.navyDeep, size: 28, filled: true)),
          )
        : _GlassCircle(size: 56, child: Center(child: NavGlyph(glyph, color: c.onHero, size: 27)));
    return Tap(
      label: semantics ?? (badge > 0 ? '$label, $badge waiting' : label),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            circle,
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.heroAccent, shape: BoxShape.circle),
                  child: Text('$badge',
                      style:
                          context.text.labelSmall!.copyWith(color: AppPalette.navyDeep, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(height: AppSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, textScaler: labelScaler, style: _labelStyle(context).copyWith(color: c.onHero)),
          ),
        ]),
      ),
    );
  }
}

// ── Rewards carousel: what the points can buy, one card in focus, the next ones peeking ──
class _RewardCarousel extends StatefulWidget {
  const _RewardCarousel({required this.rewards, required this.points, required this.onOpen});

  final List<Reward> rewards;
  final int points;
  final ValueChanged<Reward> onOpen;

  @override
  State<_RewardCarousel> createState() => _RewardCarouselState();
}

class _RewardCarouselState extends State<_RewardCarousel> {
  late final PageController _pages = PageController(viewportFraction: 0.84);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppLayout.textScale(context).clamp(1.0, 1.5);
    final rewards = widget.rewards;
    return Column(children: [
      SizedBox(
        // Grows with large text, but less than the text does: a taller card is a taller glass, and so a wider one.
        height: 178 + 110 * (scale - 1),
        child: PageView.builder(
          controller: _pages,
          itemCount: rewards.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => AnimatedBuilder(
            animation: _pages,
            // Cards beside the one in focus sit back a little (smaller, dimmer); their photos drift for depth.
            builder: (_, __) {
              final page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? 0) : 0.0;
              final delta = (page - i).clamp(-1.0, 1.0);
              final d = delta.abs();
              return Opacity(
                opacity: 1 - d * 0.35,
                child: Transform.scale(
                  scale: 1 - d * 0.06,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                    child: _RewardCard(reward: rewards[i], points: widget.points,
                        parallax: AppMotion.reduced(context) ? 0 : delta, onTap: () => widget.onOpen(rewards[i])),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      if (rewards.length > 1) ...[
        const SizedBox(height: AppSpace.sm),
        ExcludeSemantics(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < rewards.length; i++)
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.standard,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? context.colors.primary : context.colors.border,
                  borderRadius: AppRadius.all(AppRadius.pill),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }
}

/// A reward in the carousel, like a café menu card: the drink (or dish) in a glass that the points fill with Crave's
/// yellow ([RewardFill]), then its name and note, a tilted price sticker that pops on, and Redeem once the points
/// cover it, else how far is left. [parallax] is the card's distance from the carousel's centre.
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.points, required this.onTap, this.parallax = 0});

  final Reward reward;
  final int points;
  final VoidCallback onTap;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final short = reward.pointsCost - points;
    final price = reward.pointsCost <= 0 ? 'Free' : formatCount(reward.pointsCost);
    final level = reward.pointsCost <= 0 ? 1.0 : (points / reward.pointsCost).clamp(0.0, 1.0);
    final pop = AppMotion.of(context, AppMotion.slow);
    return Tap(
      label: '${reward.title}, ${reward.pointsCost <= 0 ? 'free' : '$price points'}'
          '${short > 0 ? ', $short more points needed' : ', ready to redeem'}',
      onTap: onTap,
      child: Container(
        key: const ValueKey('reward-card'),
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: cardDecoration(context),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The glass, set inside the card in the drink's own upright shape: the photos are square with the cup in
          // their middle, so covering this the whole cup shows, lid to coaster.
          AspectRatio(
            aspectRatio: 0.7,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: AppRadius.all(AppRadius.md)),
              foregroundDecoration:
                  BoxDecoration(borderRadius: AppRadius.all(AppRadius.md), border: Border.all(color: c.border)),
              child: RewardFill(title: reward.title, category: reward.category, level: level, parallax: parallax),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xxs, AppSpace.xxs, AppSpace.xxs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reward.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                const SizedBox(height: AppSpace.xxs),
                Expanded(
                  child: Text(reward.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(color: c.textSecondary)),
                ),
                // The price as a sticker: Crave's yellow, a slight tilt, popping on as the card arrives.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: pop == Duration.zero ? 1 : 0.5, end: 1),
                  duration: pop,
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
                  child: Transform.rotate(
                    angle: -0.06,
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs),
                        decoration: BoxDecoration(
                          color: AppPalette.sun,
                          borderRadius: AppRadius.all(AppRadius.sm),
                          boxShadow: AppShadows.of(context, AppShadows.e1),
                        ),
                        child: Text(reward.pointsCost <= 0 ? price : '$price pts',
                            style: t.titleMedium!.copyWith(fontFamily: AppType.displayFamily,
                                color: AppPalette.navyDeep, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: short > 0
                      ? Text('$short pts to go',
                          style: t.labelMedium!.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs),
                          decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(AppRadius.pill)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Redeem', style: t.labelMedium!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: c.onPrimary),
                          ]),
                        ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── This week: a ring for the 10-scan goal, the streak beside it ──
class _WeekCard extends StatelessWidget {
  const _WeekCard(
      {required this.streak, required this.scansThisWeek, required this.scansToday, required this.fromZero,
      required this.onTap});

  final int streak, scansThisWeek, scansToday;
  final bool fromZero;
  final VoidCallback onTap;
  static const goal = 10;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final multiplier = streakMultiplier(streak);
    final done = scansThisWeek >= goal;
    return Tap(
      label:
          '${streak > 0 ? '$streak day streak' : 'No streak yet'}. $scansThisWeek of $goal scans in the last 7 days, '
          '$scansToday today. Streak details',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: cardDecoration(context),
        child: Row(children: [
          AnimatedProgressRing(
            progress: scansThisWeek / goal,
            size: 60,
            stroke: 6,
            fromZero: fromZero,
            gradient: AppGradients.brandSun,
            child: Text('$scansThisWeek', style: t.titleLarge!.copyWith(fontFamily: AppType.displayFamily)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.local_fire_department_rounded, size: 18, color: streak > 0 ? c.warning : c.textTertiary),
              const SizedBox(width: AppSpace.xxs),
              Flexible(child: Text(streak > 0 ? '$streak-day streak' : 'Start a streak', style: t.titleSmall)),
              if (multiplier > 1) ...[
                const SizedBox(width: AppSpace.xs),
                PointsPill('${multiplier == 2 ? '2' : '1.5'}× points', color: c.warning),
              ],
            ]),
            const SizedBox(height: AppSpace.xxs),
            Text(done ? 'Goal of $goal reached in the last 7 days' : '$scansThisWeek of $goal scans in the last 7 days',
                style: t.bodySmall),
            Text('$scansToday today', style: t.bodySmall!.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(width: AppSpace.xs),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ]),
      ),
    );
  }
}

// ── Bottom navigation: the floating pill (FloatingPillNav). Four tabs; Scan is the action in the middle. ──
class _BottomNav extends StatelessWidget {
  const _BottomNav(
      {required this.selectedIndex, required this.onTap, required this.onScan, required this.onScanWithLight});

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan, onScanWithLight;

  static const _tabs = [
    FloatingNavTab(glyph: NavGlyphKind.home, label: 'Home'),
    FloatingNavTab(glyph: NavGlyphKind.rewards, label: 'Rewards'),
    FloatingNavTab(glyph: NavGlyphKind.activity, label: 'Activity'),
    FloatingNavTab(glyph: NavGlyphKind.profile, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => FloatingPillNav(
        tabs: _tabs,
        selectedIndex: selectedIndex,
        onTap: onTap,
        action: FloatingNavAction(
          glyph: NavGlyphKind.scan,
          label: 'Scan',
          semanticLabel: 'Scan the QR code at the bin',
          onTap: onScan,
          onLongPress: onScanWithLight,
          longPressHint: 'scan with the flashlight on',
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
          Expanded(
              child: Text("Couldn't refresh. Showing your last saved data.",
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
