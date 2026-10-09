import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

/// One reward, opened from its card (the icon flies in). Redeeming is a press-and-hold,
/// so it can't happen by accident; the page returns `true` when the user confirmed.
/// Redemption itself (and its rules) stays in RewardsScreen / FirebaseService.
class RewardDetailScreen extends StatelessWidget {
  const RewardDetailScreen({
    super.key,
    required this.reward,
    required this.user,
    required this.heroTag,
    required this.icon,
    required this.color,
  });

  final Reward reward;
  final UserModel user;
  final String heroTag;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final soldOut = reward.stock == 0;
    final canAfford = user.points >= reward.pointsCost && !soldOut;
    final missing = reward.pointsCost - user.points;
    final progress = reward.pointsCost == 0 ? 1.0 : user.points / reward.pointsCost;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: AppLayout.headerHeight(context, 230, perScale: 40),
          backgroundColor: color,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context, false),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.lerp(color, Colors.black, 0.15)!, color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: heroMaterialFlight,
                    child: Container(
                      width: 104, height: 104,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                      ),
                      child: Icon(icon, color: Colors.white, size: 52),
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
                  PointsPill(reward.category, color: c.ink(color)),
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
                    child: Row(children: [
                      AnimatedProgressRing(
                        progress: progress,
                        size: 76,
                        stroke: 8,
                        gradient: canAfford ? AppGradients.forestMint : null,
                        color: c.warning,
                        semanticsLabel: 'Your points towards this reward',
                        child: Text('${(progress.clamp(0.0, 1.0) * 100).round()}%',
                            style: t.titleMedium!.copyWith(fontFamily: AppType.displayFamily)),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _line(context, 'Your balance', '${user.points} pts'),
                        _line(context, 'Cost', '${reward.pointsCost} pts', strong: true),
                        const Divider(height: AppSpace.md),
                        if (canAfford)
                          _line(context, 'After redeeming', '${user.points - reward.pointsCost} pts')
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
                    canAfford
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

  Widget _line(BuildContext context, String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary))),
          Text(v, style: (strong ? context.text.titleMedium : context.text.titleSmall)!.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}
