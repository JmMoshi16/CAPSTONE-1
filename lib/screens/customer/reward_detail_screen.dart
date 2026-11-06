import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

/// One reward, opened from its row (the picture flies in). Redeeming is a press-and-hold,
/// so it can't happen by accident; the page returns `true` when the user confirmed.
/// Redemption itself (and its rules) stays in RewardsScreen / FirebaseService.
class RewardDetailScreen extends StatelessWidget {
  const RewardDetailScreen({super.key, required this.reward, required this.user, required this.heroTag});

  final Reward reward;
  final UserModel user;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final soldOut = reward.stock == 0;
    // With very large text the progress ring sits above the figures instead of squeezing them.
    final stacked = AppLayout.textScale(context) > 1.5;
    final canAfford = user.points >= reward.pointsCost && !soldOut;
    final missing = reward.pointsCost - user.points;
    final progress = reward.pointsCost <= 0 ? 1.0 : user.points / reward.pointsCost;
    final color = rewardColor(reward.category);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: AppLayout.headerHeight(context, 320, perScale: 40),
          // The reward large, in the same glass as on Home: filled as far as the points go. The picture from the
          // menu grows into it. Sold out: the photo greyed, no fill.
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          leading: AppBackButton(onPressed: () => Navigator.pop(context, false)),
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, kToolbarHeight, AppSpace.lg, AppSpace.xs),
                child: HeroMode(
                  enabled: !AppMotion.reduced(context),
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: heroMaterialFlight,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: cardDecoration(context, radius: AppRadius.xxl),
                      child: soldOut
                          ? RewardPicture(title: reward.title, category: reward.category, muted: true,
                              fit: BoxFit.contain)
                          : RewardFill(title: reward.title, category: reward.category,
                              level: progress.clamp(0.0, 1.0), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PointsPill(rewardCategoryLabel(reward.category), color: c.ink(color)),
                  const SizedBox(height: AppSpace.sm),
                  Text(reward.title, style: t.headlineMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(reward.description, style: t.bodyLarge!.copyWith(color: c.textSecondary)),
                  const SizedBox(height: AppSpace.sm),
                  if (soldOut)
                    PointsPill('Sold out', color: c.danger)
                  else if (reward.stock > 0 && reward.stock <= 5)
                    PointsPill('Only ${reward.stock} left', color: c.warning),
                  const SizedBox(height: AppSpace.lg),

                  // Balance vs cost
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: cardDecoration(context, borderColor: canAfford ? c.primary.withValues(alpha: 0.4) : null),
                    child: Flex(
                      direction: stacked ? Axis.vertical : Axis.horizontal,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      AnimatedProgressRing(
                        progress: progress,
                        size: 76,
                        stroke: 8,
                        gradient: canAfford ? AppGradients.brandSun : null,
                        color: c.warning,
                        semanticsLabel: 'Your points towards this reward',
                        child: Text('${(progress.clamp(0.0, 1.0) * 100).round()}%',
                            style: t.titleMedium!.copyWith(fontFamily: AppType.displayFamily)),
                      ),
                      const SizedBox(width: AppSpace.md, height: AppSpace.md),
                      _fill(stacked, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _line(context, 'Your balance', '${formatCount(user.points)} pts'),
                        _line(context, 'Cost', reward.pointsCost <= 0 ? 'Free' : '${formatCount(reward.pointsCost)} pts', strong: true),
                        const Divider(height: AppSpace.md),
                        if (canAfford)
                          _line(context, 'After redeeming', '${formatCount(user.points - reward.pointsCost)} pts')
                        else if (!soldOut)
                          Text('$missing more points needed', style: t.titleSmall!.copyWith(color: c.warning)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  HoldToConfirmButton(
                    label: soldOut ? 'Sold out' : canAfford ? 'Hold to redeem' : 'Need $missing more points',
                    icon: Icons.card_giftcard_rounded,
                    confirmQuestion: 'Redeem "${reward.title}" for ${reward.pointsCost} points?',
                    onConfirmed: canAfford ? () => Navigator.pop(context, true) : null,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    soldOut
                        ? "This reward is out of stock right now. Check back later; your points stay saved."
                        : canAfford
                            ? "You'll get a code to show at the counter. Codes stay valid for 7 days."
                            : 'Scan your waste at an ECOReward bin to earn the rest.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// Beside the ring the figures take the rest of the row; stacked under it they take the card's width.
  Widget _fill(bool stacked, Widget child) => stacked ? child : Expanded(child: child);

  Widget _line(BuildContext context, String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary))),
          Flexible(child: Text(v, textAlign: TextAlign.end,
              style: (strong ? context.text.titleMedium : context.text.titleSmall)!.copyWith(fontWeight: FontWeight.w700))),
        ]),
      );
}
