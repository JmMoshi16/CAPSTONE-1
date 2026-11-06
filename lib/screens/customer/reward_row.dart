import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

/// The rewards split the way a customer decides: what they can have now, what they are saving for, and what
/// has run out. Cheapest first in each group, like a menu; same price, A to Z.
({List<Reward> ready, List<Reward> saving, List<Reward> soldOut}) groupRewards(List<Reward> rewards, int points) {
  int byCost(Reward a, Reward b) {
    final c = a.pointsCost.compareTo(b.pointsCost);
    return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
  final open = rewards.where((r) => r.stock != 0);
  return (
    ready: open.where((r) => r.pointsCost <= points).toList()..sort(byCost),
    saving: open.where((r) => r.pointsCost > points).toList()..sort(byCost),
    soldOut: rewards.where((r) => r.stock == 0).toList()..sort(byCost),
  );
}

/// "50 pts", or "Free" when a reward costs nothing.
String rewardPrice(int cost) => cost <= 0 ? 'Free' : '${formatCount(cost)} pts';

/// One reward on the menu, as a tile in a grid: its photo (or icon) edge to edge, then its name, note and the price
/// set like a menu price. A reward still out of reach shows how far away it is (the group heading says which are
/// ready). Tap opens the detail page, where redeeming is a press-and-hold; long-press peeks.
class RewardTile extends StatelessWidget {
  const RewardTile({super.key, required this.reward, required this.points, required this.onTap, this.onLongPress,
      this.heroTag});

  final Reward reward;
  final int points;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final soldOut = reward.stock == 0;
    final ready = !soldOut && points >= reward.pointsCost;
    final short = reward.pointsCost - points;
    final lowStock = reward.stock > 0 && reward.stock <= 5;
    final status = soldOut ? 'sold out' : ready ? 'ready to redeem' : '$short more points needed';

    void open() {
      AppHaptics.tap();
      onTap();
    }

    void peek() {
      AppHaptics.primary();
      onLongPress!();
    }

    Widget picture = RewardPicture(title: reward.title, category: reward.category, muted: soldOut);
    if (heroTag != null) {
      picture = HeroMode(
        enabled: !AppMotion.reduced(context),
        child: Hero(tag: heroTag!, flightShuttleBuilder: heroMaterialFlight, child: picture),
      );
    }
    // Sold out and low stock sit on the photo, so every tile in a group keeps the same height.
    final flag = soldOut ? ('Sold out', c.textSecondary) : lowStock ? ('Only ${reward.stock} left', c.warning) : null;

    return Semantics(
      button: !soldOut,
      enabled: !soldOut,
      label: '${reward.title}, ${rewardPrice(reward.pointsCost)}, $status',
      onTap: soldOut ? null : open,
      onLongPress: onLongPress == null ? null : peek,
      onLongPressHint: onLongPress == null ? null : 'peek at this reward',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: soldOut ? null : open,
            onLongPress: onLongPress == null ? null : peek,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(fit: StackFit.expand, children: [
                  picture,
                  if (flag != null)
                    Positioned(
                      left: AppSpace.xs,
                      top: AppSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                        decoration: BoxDecoration(color: c.surface, borderRadius: AppRadius.all(AppRadius.pill)),
                        child: Text(flag.$1, style: t.labelSmall!.copyWith(color: flag.$2, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.sm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reward.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.titleSmall!.copyWith(color: soldOut ? c.textTertiary : c.textPrimary)),
                  Text(reward.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  const SizedBox(height: AppSpace.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _Price(cost: reward.pointsCost, muted: !ready),
                  ),
                  if (!ready && !soldOut) ...[
                    const SizedBox(height: AppSpace.xs),
                    AnimatedBar(progress: (points / reward.pointsCost).clamp(0.0, 1.0), color: c.primary, height: 4),
                    const SizedBox(height: AppSpace.xxs),
                    Text('$short pts to go', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A redemption ticket's picture: the reward's photo with its status (pending, claimed, expired) in a small badge
/// on the corner; a reward without a photo shows the status icon on its own, as before.
class RewardTicketArt extends StatelessWidget {
  const RewardTicketArt({super.key, required this.title, required this.icon, required this.color, this.muted = false});

  final String title;
  final IconData icon;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (rewardPhoto(title) == null) return IconBadge(icon: icon, color: color, size: 44);
    final c = context.colors;
    return SizedBox.square(
      dimension: 48,
      child: Stack(clipBehavior: Clip.none, children: [
        RewardArt(title: title, category: '', size: 44, muted: muted),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ]),
    );
  }
}

/// The price in the menu serif: "50 pts", or "Free".
class _Price extends StatelessWidget {
  const _Price({required this.cost, required this.muted});

  final int cost;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = muted ? c.textSecondary : c.textPrimary;
    final number = context.text.titleLarge!.copyWith(fontFamily: AppType.displayFamily, color: color, height: 1.1);
    if (cost <= 0) return Text('Free', style: number);
    return Text.rich(TextSpan(children: [
      TextSpan(text: formatCount(cost), style: number),
      TextSpan(text: ' pts', style: context.text.labelMedium!.copyWith(color: c.textSecondary)),
    ]));
  }
}
