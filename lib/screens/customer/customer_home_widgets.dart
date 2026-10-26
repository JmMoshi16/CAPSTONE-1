part of 'customer_home_screen.dart';

// ── Hero: the forest surface carrying who you are, your points and the four things you do most ──
class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.user,
    required this.rewards,
    required this.pending,
    required this.countFromZero,
    required this.onProfile,
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
  final bool countFromZero;
  final VoidCallback onProfile, onBell, onBalance, onScan, onMyCodes, onLeaderboard, onBadges;

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
    return AuroraBackground(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Tap(
                  label: 'Open profile',
                  onTap: onProfile,
                  child: UserAvatar(name: user.username, photo: user.photo, size: 44, onHero: true)),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting, style: t.bodySmall!.copyWith(color: c.onHeroMuted)),
                Text(user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge!.copyWith(color: AppPalette.cream)),
              ])),
              Tap(
                label: pending > 0 ? 'Notifications, $pending reward codes waiting' : 'Notifications',
                tooltip: true,
                onTap: onBell,
                child: Stack(clipBehavior: Clip.none, children: [
                  _GlassCircle(size: 44, child: Icon(Icons.notifications_none_rounded, color: c.onHero, size: 22)),
                  if (pending > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.heroAccent, borderRadius: AppRadius.all(AppRadius.pill)),
                        child: Text('$pending',
                            style: t.labelSmall!.copyWith(color: AppPalette.forestDeep, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpace.lg),
            _GlassBalance(user: user, rewards: rewards, countFromZero: countFromZero, onTap: onBalance),
            const SizedBox(height: AppSpace.lg),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _QuickAction(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  primary: true,
                  onTap: onScan,
                  semantics: 'Scan the QR code at the bin'),
              _QuickAction(
                  icon: Icons.confirmation_number_outlined, label: 'My codes', onTap: onMyCodes, badge: pending),
              _QuickAction(
                  icon: Icons.leaderboard_outlined, label: 'Ranking', onTap: onLeaderboard, semantics: 'Leaderboard'),
              _QuickAction(icon: Icons.military_tech_outlined, label: 'Badges', onTap: onBadges),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A frosted circle for icons on the forest surface.
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
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Points balance', style: t.labelMedium!.copyWith(color: c.onHeroMuted)),
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
          FittedBox(
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
                        format: NumberFormat('#,###').format,
                        style: AppType.numeral.copyWith(color: AppPalette.cream, fontSize: 56)),
                    const SizedBox(width: AppSpace.xs),
                    Text('pts', style: t.titleMedium!.copyWith(color: c.onHeroMuted)),
                  ]),
            ),
          ),
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
      ),
    );
  }
}

/// One of the four shortcuts under the balance: a circle and a word. Scan is the filled one.
class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false,
      this.badge = 0,
      this.semantics});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final int badge;
  final String? semantics;

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
            child: Icon(icon, color: AppPalette.forestDeep, size: 26),
          )
        : _GlassCircle(size: 56, child: Icon(icon, color: c.onHero, size: 24));
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
                          context.text.labelSmall!.copyWith(color: AppPalette.forestDeep, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium!.copyWith(color: c.onHero)),
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
  late final PageController _pages = PageController(viewportFraction: 0.78);
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
        height: 178 * scale,
        child: PageView.builder(
          controller: _pages,
          itemCount: rewards.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => AnimatedBuilder(
            animation: _pages,
            // Cards beside the one in focus sit back a little (smaller, dimmer).
            builder: (_, child) {
              final page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? 0) : 0.0;
              final d = (page - i).abs().clamp(0.0, 1.0);
              return Opacity(opacity: 1 - d * 0.35, child: Transform.scale(scale: 1 - d * 0.06, child: child));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              child: _RewardCard(reward: rewards[i], points: widget.points, onTap: () => widget.onOpen(rewards[i])),
            ),
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

/// A reward in the carousel: a band in its category's colour holding the picture and the price, then the name
/// and whether it is ready.
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.points, required this.onTap});

  final Reward reward;
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final short = reward.pointsCost - points;
    final price = reward.pointsCost <= 0 ? 'Free' : '${reward.pointsCost}';
    final accent = rewardColor(reward.category);
    return Tap(
      label: '${reward.title}, ${reward.pointsCost <= 0 ? 'free' : '$price points'}'
          '${short > 0 ? ', $short more points needed' : ', ready to redeem'}',
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: c.isDark ? 0.30 : 0.18),
                    accent.withValues(alpha: c.isDark ? 0.12 : 0.05)
                  ],
                ),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RewardArt(title: reward.title, category: reward.category, size: 52),
                const Spacer(),
                Text.rich(TextSpan(children: [
                  TextSpan(text: price, style: t.headlineSmall!.copyWith(color: c.textPrimary)),
                  if (reward.pointsCost > 0)
                    TextSpan(text: ' pts', style: t.labelMedium!.copyWith(color: c.textSecondary)),
                ])),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
            child: Row(children: [
              Expanded(child: Text(reward.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall)),
              const SizedBox(width: AppSpace.xs),
              Text(short > 0 ? '$short to go' : 'Redeem',
                  style: t.labelMedium!
                      .copyWith(color: short > 0 ? c.textSecondary : c.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── This week: a ring for the 10-scan goal, the streak beside it ──
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.streak, required this.scansThisWeek, required this.fromZero, required this.onTap});

  final int streak, scansThisWeek;
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
          '${streak > 0 ? '$streak day streak' : 'No streak yet'}. $scansThisWeek of $goal scans this week. Streak details',
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
            gradient: AppGradients.forestMint,
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
            Text(done ? 'Weekly goal reached' : '$scansThisWeek of $goal scans this week', style: t.bodySmall),
          ])),
          const SizedBox(width: AppSpace.xs),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ]),
      ),
    );
  }
}

// ── Bottom navigation: docked and labelled. One pill slides to the selected tab; Scan is an action, not a tab,
// so it is a round button with an ordinary label and never looks selected. ──
class _BottomNav extends StatelessWidget {
  const _BottomNav(
      {required this.selectedIndex, required this.onTap, required this.onScan, required this.onScanWithLight});

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan, onScanWithLight;

  /// Height of the icon row, shared by the tabs and the Scan button so every label sits on one line.
  static const _iconSlot = 40.0;
  static const _top = 0.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Five slots; Scan holds the middle one, so tabs 2 and 3 sit in slots 3 and 4.
    final slot = selectedIndex >= 2 ? selectedIndex + 1 : selectedIndex;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (context, box) {
            final slotWidth = box.maxWidth / 5;
            return Stack(children: [
              AnimatedPositioned(
                key: const ValueKey('nav-pill'),
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.emphasized,
                left: slot * slotWidth + (slotWidth - 52) / 2,
                top: _top + (_iconSlot - 32) / 2,
                width: 52,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.pill)),
                ),
              ),
              Row(children: [
                _item(context, Icons.home_rounded, Icons.home_outlined, 'Home', 0),
                _item(context, Icons.redeem_rounded, Icons.redeem_outlined, 'Rewards', 1),
                Expanded(
                  child: Tap(
                    label: 'Scan the QR code at the bin',
                    onTap: onScan,
                    onLongPress: onScanWithLight,
                    longPressHint: 'scan with the flashlight on',
                    child: Padding(
                      padding: const EdgeInsets.only(top: _top),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: _iconSlot,
                          height: _iconSlot,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                          child: Icon(Icons.qr_code_scanner_rounded, color: c.onPrimary, size: 20),
                        ),
                        const SizedBox(height: 2),
                        Text('Scan',
                            style:
                                context.text.labelSmall!.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
                _item(context, Icons.insights_rounded, Icons.insights_outlined, 'Activity', 2),
                _item(context, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', 3),
              ]),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData active, IconData inactive, String label, int index) {
    final c = context.colors;
    final selected = selectedIndex == index;
    return Expanded(
      child: Tap(
        label: label,
        selected: selected,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.only(top: _top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: _iconSlot,
              child: Center(
                // Outline to filled icon as a quick cross-fade, while the pill slides in behind it.
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.fast),
                  child: Icon(selected ? active : inactive,
                      key: ValueKey(selected), color: selected ? c.onPrimaryContainer : c.textSecondary, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(
                    color: selected ? c.textPrimary : c.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
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
