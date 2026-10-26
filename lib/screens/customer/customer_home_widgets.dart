part of 'customer_home_screen.dart';

// ── Header: greeting, avatar, notifications (on the page background, no gradient) ──
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user, required this.pending, required this.onProfile, required this.onBell});

  final UserModel user;
  final int pending;
  final VoidCallback onProfile, onBell;

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
    return Row(children: [
      Tap(label: 'Open profile', onTap: onProfile, child: UserAvatar(name: user.username, photo: user.photo, size: 44)),
      const SizedBox(width: AppSpace.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting, style: t.bodySmall),
        Text(user.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleLarge),
      ])),
      Tap(
        label: pending > 0 ? 'Notifications, $pending reward codes waiting' : 'Notifications',
        tooltip: true,
        onTap: onBell,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)),
            child: Icon(Icons.notifications_none_rounded, color: c.textPrimary, size: 22),
          ),
          if (pending > 0)
            Positioned(
              top: -2, right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.danger, borderRadius: AppRadius.all(AppRadius.pill),
                    border: Border.all(color: c.background, width: 2)),
                child: Text('$pending', style: t.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ── Balance card: the one place points, tier and the next reward live (Starbucks pattern) ──
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.user, required this.rewards, required this.countFromZero, required this.onTap});

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: heroDecoration(context, radius: AppRadius.all(AppRadius.xl)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Points balance', style: t.labelMedium!.copyWith(color: c.onHeroMuted)),
            const Spacer(),
            Icon(rankIconData(rank.label), size: 16, color: c.onHero),
            const SizedBox(width: AppSpace.xxs),
            Flexible(child: Text('${rank.label} · Level ${level.level}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: t.labelMedium!.copyWith(color: c.onHero))),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.onHeroMuted),
          ]),
          const SizedBox(height: AppSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCount(user.points, fromZero: countFromZero, format: NumberFormat('#,###').format,
                style: AppType.numeral.copyWith(color: c.onHero)),
          ),
          const SizedBox(height: AppSpace.md),
          AnimatedBar(progress: progress, color: c.heroAccent, height: 6, fromZero: countFromZero),
          const SizedBox(height: AppSpace.xs),
          Text(goal, style: t.bodySmall!.copyWith(color: c.onHero)),
        ]),
      ),
    );
  }
}

// ── Rewards strip: what the points can buy (affordable first, else the closest) ──
class _RewardStrip extends StatelessWidget {
  const _RewardStrip({required this.rewards, required this.points, required this.onOpen});

  final List<Reward> rewards;
  final int points;
  final ValueChanged<Reward> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final scale = AppLayout.textScale(context).clamp(1.0, 1.5);
    return SizedBox(
      height: 112 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        itemCount: rewards.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (_, i) {
          final r = rewards[i];
          final short = r.pointsCost - points;
          final price = r.pointsCost <= 0 ? 'Free' : '${r.pointsCost} pts';
          return Tap(
            label: '${r.title}, $price${short > 0 ? ', $short more points needed' : ', ready to redeem'}',
            onTap: () => onOpen(r),
            child: Container(
              width: 168 * scale,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: cardDecoration(context),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RewardArt(title: r.title, category: r.category, size: 36),
                const Spacer(),
                Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                const SizedBox(height: AppSpace.xxs),
                Row(children: [
                  Expanded(child: Text(price, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.labelMedium!.copyWith(color: c.textSecondary))),
                  Text(short > 0 ? '$short to go' : 'Redeem',
                      style: t.labelMedium!.copyWith(color: short > 0 ? c.textSecondary : c.primary,
                          fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── This week: streak and the 7-day goal in one row ──
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
      label: '${streak > 0 ? '$streak day streak' : 'No streak yet'}. $scansThisWeek of $goal scans this week. Streak details',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: cardDecoration(context),
        child: Row(children: [
          Medallion(icon: Icons.local_fire_department_rounded, color: streak > 0 ? c.warning : c.textTertiary, size: 40),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(streak > 0 ? '$streak-day streak' : 'Start a streak', style: t.titleSmall)),
              if (multiplier > 1) ...[
                const SizedBox(width: AppSpace.xs),
                PointsPill('${multiplier == 2 ? '2' : '1.5'}× points', color: c.warning),
              ],
            ]),
            const SizedBox(height: AppSpace.xs),
            AnimatedBar(progress: (scansThisWeek / goal).clamp(0.0, 1.0), color: done ? c.success : c.primary,
                height: 6, fromZero: fromZero),
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

// ── Bottom navigation: docked and labelled. The selected tab gets a pill; Scan is an action, not a tab,
// so it is a round button with an ordinary label and never looks selected. ──
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap, required this.onScan, required this.onScanWithLight});

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan, onScanWithLight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            _item(context, Icons.home_rounded, Icons.home_outlined, 'Home', 0),
            _item(context, Icons.redeem_rounded, Icons.redeem_outlined, 'Rewards', 1),
            Expanded(
              child: Tap(
                label: 'Scan the QR code at the bin',
                onTap: onScan,
                onLongPress: onScanWithLight,
                longPressHint: 'scan with the flashlight on',
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    height: _iconSlot,
                    child: Center(
                      child: Container(
                        width: _iconSlot, height: _iconSlot,
                        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                        child: Icon(Icons.qr_code_scanner_rounded, color: c.onPrimary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Scan', style: context.text.labelSmall!.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            _item(context, Icons.insights_rounded, Icons.insights_outlined, 'Activity', 2),
            _item(context, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', 3),
          ]),
        ),
      ),
    );
  }

  /// Height of the icon row, shared by the tabs and the Scan button so every label sits on one line.
  static const _iconSlot = 40.0;

  Widget _item(BuildContext context, IconData active, IconData inactive, String label, int index) {
    final c = context.colors;
    final selected = selectedIndex == index;
    return Expanded(
      child: Tap(
        label: label,
        selected: selected,
        onTap: () => onTap(index),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            height: _iconSlot,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.standard,
                width: 52, height: 32,
                decoration: BoxDecoration(
                  color: selected ? c.primaryContainer : Colors.transparent,
                  borderRadius: AppRadius.all(AppRadius.pill),
                ),
                // Outline to filled icon as a quick cross-fade.
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.fast),
                  child: Icon(selected ? active : inactive, key: ValueKey(selected),
                      color: selected ? c.onPrimaryContainer : c.textSecondary, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall!.copyWith(
                  color: selected ? c.textPrimary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
        ]),
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
