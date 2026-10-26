import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

/// The rewards split the way a customer decides: what they can have now, what they are saving for, and what
/// has run out. Cheapest first in each group, like a menu.
({List<Reward> ready, List<Reward> saving, List<Reward> soldOut}) groupRewards(List<Reward> rewards, int points) {
  int byCost(Reward a, Reward b) => a.pointsCost.compareTo(b.pointsCost);
  final open = rewards.where((r) => r.stock != 0);
  return (
    ready: open.where((r) => r.pointsCost <= points).toList()..sort(byCost),
    saving: open.where((r) => r.pointsCost > points).toList()..sort(byCost),
    soldOut: rewards.where((r) => r.stock == 0).toList()..sort(byCost),
  );
}

/// "50 pts", or "Free" when a reward costs nothing.
String rewardPrice(int cost) => cost <= 0 ? 'Free' : '$cost pts';

/// One reward on the menu: its picture, name and note, and the price set like a menu price. A reward still
/// out of reach shows how far away it is (the group heading says which are ready). Tap opens the detail page,
/// where redeeming is a press-and-hold; long-press peeks.
class RewardRow extends StatelessWidget {
  const RewardRow({super.key, required this.reward, required this.points, required this.onTap, this.onLongPress,
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

    return Semantics(
      button: !soldOut,
      enabled: !soldOut,
      label: '${reward.title}, ${rewardPrice(reward.pointsCost)}, $status',
      onTap: soldOut ? null : open,
      onLongPress: onLongPress == null ? null : peek,
      onLongPressHint: onLongPress == null ? null : 'peek at this reward',
      excludeSemantics: true,
      child: InkWell(
        onTap: soldOut ? null : open,
        onLongPress: onLongPress == null ? null : peek,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(children: [
            RewardArt(title: reward.title, category: reward.category, heroTag: heroTag, muted: soldOut),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reward.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.titleMedium!.copyWith(color: soldOut ? c.textTertiary : c.textPrimary)),
                if (reward.description.isNotEmpty)
                  Text(reward.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                if (!ready && !soldOut) ...[
                  const SizedBox(height: AppSpace.xs),
                  AnimatedBar(progress: (points / reward.pointsCost).clamp(0.0, 1.0), color: c.primary, height: 4),
                  const SizedBox(height: AppSpace.xxs),
                  Text('$short pts to go', style: t.labelSmall),
                ] else if (lowStock && !soldOut)
                  Text('Only ${reward.stock} left', style: t.labelSmall!.copyWith(color: c.warning)),
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _Price(cost: reward.pointsCost, muted: !ready),
              if (soldOut)
                Text('Sold out', style: t.labelMedium!.copyWith(color: c.textTertiary, fontWeight: FontWeight.w700)),
            ]),
            if (!soldOut) ...[
              const SizedBox(width: AppSpace.xxs),
              Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ]),
        ),
      ),
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
      TextSpan(text: '$cost', style: number),
      TextSpan(text: ' pts', style: context.text.labelMedium!.copyWith(color: c.textSecondary)),
    ]));
  }
}
