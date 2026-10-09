// Explainer sheets opened from cards that used to look tappable but did nothing.
// Display only: every number comes from the existing rules (gamification.dart, theme.dart,
// the badge definitions), so nothing here can drift from what is credited.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/gamification.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

String _x(double m) => m == m.roundToDouble() ? '${m.toStringAsFixed(0)}×' : '$m×';

Future<void> _sheet(BuildContext context, String title, List<Widget> children) => AppSheet.show(
      context,
      title: title,
      initialSize: 0.55,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
        children: children,
      ),
    );

// ── Streak ────────────────────────────────────────────────────────────────────
Future<void> showStreakSheet(BuildContext context, {required int streak, VoidCallback? onScan}) {
  final c = context.colors;
  final t = context.text;
  // The tiers, read from the rule itself: the first streak length where the multiplier rises.
  final tiers = <(int, double)>[];
  for (var d = 1, last = 0.0; d <= 30; d++) {
    final m = streakMultiplier(d);
    if (m != last) { tiers.add((d, m)); last = m; }
  }
  final now = streakMultiplier(streak);
  final next = tiers.where((e) => e.$1 > streak).firstOrNull;
  return _sheet(context, 'Your streak', [
    Row(children: [
      const ExcludeSemantics(child: Text('🔥', style: TextStyle(fontSize: 44))),
      const SizedBox(width: AppSpace.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(streak == 0 ? 'No streak yet' : '$streak day${streak == 1 ? '' : 's'} in a row',
            style: t.headlineSmall),
        Text(now > 1 ? 'Every scan earns ${_x(now)} points right now' : 'Scan on consecutive days to earn bonus points',
            style: t.bodyMedium!.copyWith(color: c.textSecondary)),
      ])),
    ]),
    const SizedBox(height: AppSpace.lg),
    for (final (days, m) in tiers)
      AppListTile(
        title: days == 1 ? 'Any scan' : '$days days in a row',
        subtitle: Text(m == 1 ? 'Base points' : '${_x(m)} points on every scan', style: t.bodySmall),
        leading: IconBadge(icon: Icons.local_fire_department_rounded, color: streak >= days ? c.warning : c.textTertiary),
        trailing: streak >= days ? Icon(Icons.check_circle_rounded, color: c.success) : null,
      ),
    if (next != null) ...[
      const SizedBox(height: AppSpace.xs),
      Text('${next.$1 - streak} more day${next.$1 - streak == 1 ? '' : 's'} to reach ${_x(next.$2)}',
          style: t.titleSmall!.copyWith(color: c.primary)),
      const SizedBox(height: AppSpace.xs),
      AnimatedBar(progress: streak / next.$1, color: c.warning),
    ],
    const SizedBox(height: AppSpace.md),
    Text('Miss a day and the streak starts again from 1.', style: t.bodySmall),
    if (onScan != null) ...[
      const SizedBox(height: AppSpace.lg),
      AppButton(label: 'Scan now', icon: Icons.qr_code_scanner_rounded, onPressed: () {
        Navigator.pop(context);
        onScan();
      }),
    ],
  ]);
}

// ── Rank and level ────────────────────────────────────────────────────────────
Future<void> showRankLevelSheet(BuildContext context, {required int lifetimePoints}) {
  final c = context.colors;
  final t = context.text;
  // Walk the rank ladder through each rank's own "next" threshold.
  final ranks = <RankInfo>[];
  for (var p = 0;;) {
    final r = getRank(p);
    ranks.add(r);
    if (r.next == null) break;
    p = r.nextPts;
  }
  final rank = getRank(lifetimePoints);
  final level = getLevel(lifetimePoints);
  return _sheet(context, 'Rank and level', [
    Text('Both grow with your lifetime points ($lifetimePoints), so redeeming rewards never lowers them.',
        style: t.bodyMedium!.copyWith(color: c.textSecondary)),
    const SizedBox(height: AppSpace.lg),
    Text('Rank', style: t.titleMedium),
    const SizedBox(height: AppSpace.xs),
    for (final r in ranks)
      AppListTile(
        title: '${r.icon}  ${r.label}',
        subtitle: Text('From ${r.minPts} pts', style: t.bodySmall),
        borderColor: r.label == rank.label ? c.ink(r.color) : null,
        trailing: r.label == rank.label ? PointsPill('You', color: c.ink(r.color)) : null,
      ),
    if (rank.next != null) ...[
      AnimatedBar(progress: rankProgress(lifetimePoints), color: rank.color),
      const SizedBox(height: AppSpace.xxs),
      Text('${rank.nextPts - lifetimePoints} pts to ${rank.next}', style: t.bodySmall),
    ],
    const SizedBox(height: AppSpace.lg),
    Text('Level', style: t.titleMedium),
    const SizedBox(height: AppSpace.xs),
    for (final l in allLevels)
      AppListTile(
        title: '${l.emoji}  Lv ${l.level} ${l.title}',
        subtitle: Text(l.maxPts == -1 ? 'From ${l.minPts} pts' : '${l.minPts}–${l.maxPts} pts', style: t.bodySmall),
        borderColor: l.level == level.level ? c.ink(l.color) : null,
        trailing: l.level == level.level ? PointsPill('You', color: c.ink(l.color)) : null,
      ),
  ]);
}

// ── Eco Rate ──────────────────────────────────────────────────────────────────
Future<void> showEcoRateSheet(BuildContext context, {required int bio, required int rec, required int res}) {
  final c = context.colors;
  final t = context.text;
  final total = bio + rec + res;
  final rate = total == 0 ? 0 : ((bio + rec) / total * 100).round();
  Widget row(String k, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(children: [
          IconBadge(icon: wasteIcon(k), color: c.wasteFill(k), size: 32),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(k, style: t.bodyMedium)),
          Text('$n', style: t.titleSmall),
        ]),
      );
  return _sheet(context, 'Eco Rate', [
    Text('$rate%', style: t.displaySmall!.copyWith(color: c.success)),
    const SizedBox(height: AppSpace.xs),
    Text('The share of your scans that were Biodegradable or Recyclable, the waste that '
        'can be composted or recycled instead of going to landfill.',
        style: t.bodyMedium!.copyWith(color: c.textSecondary)),
    const SizedBox(height: AppSpace.lg),
    row('Biodegradable', bio),
    row('Recyclable', rec),
    row('Residual', res),
    const SizedBox(height: AppSpace.sm),
    Text(total == 0
        ? 'Scan your first bin to start your Eco Rate.'
        : 'Residual scans still earn points; sorting more into the other bins raises the rate.',
        style: t.bodySmall),
  ]);
}

// ── One scan ──────────────────────────────────────────────────────────────────
Future<void> showScanDetailSheet(BuildContext context, WasteLog log) {
  final c = context.colors;
  final t = context.text;
  final bonus = log.pointsAwarded - log.pointsEarned;
  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(children: [
          Expanded(child: Text(k, style: t.bodyMedium!.copyWith(color: c.textSecondary))),
          Text(v, style: t.titleSmall),
        ]),
      );
  return _sheet(context, 'Scan details', [
    Row(children: [
      IconBadge(icon: wasteIcon(log.wasteType), color: c.wasteFill(log.wasteType), size: 56, filled: true),
      const SizedBox(width: AppSpace.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(log.wasteType, style: t.headlineSmall),
        Text(DateFormat('EEEE, MMM d yyyy · h:mm a').format(log.timestamp), style: t.bodySmall),
      ])),
    ]),
    const SizedBox(height: AppSpace.lg),
    row('Base points', '+${log.pointsEarned}'),
    if (bonus > 0) row('Streak bonus', '+$bonus'),
    row('Credited', '+${log.pointsAwarded} pts'),
    row('Bin', log.binId),
  ]);
}

// ── One badge ─────────────────────────────────────────────────────────────────
Future<void> showBadgeSheet(BuildContext context, {required Map<String, dynamic> def, required UserModel user}) {
  final c = context.colors;
  final t = context.text;
  final earned = user.badges.contains(def['id']);
  final target = (def['value'] as num).toInt();
  final req = def['req'] as String;
  final current = switch (req) {
    'scans' => user.scanCount,
    'points' => user.lifetimePoints,
    'streak' => effectiveStreak(user.streak, user.lastScanDate, DateTime.now()),
    _ => 0,
  };
  final unit = switch (req) { 'scans' => 'scans', 'points' => 'lifetime points', 'streak' => 'day streak', _ => '' };
  return _sheet(context, def['label'] as String, [
    Center(child: Text(def['icon'] as String, style: const TextStyle(fontSize: 64))),
    const SizedBox(height: AppSpace.sm),
    Center(child: Text(def['desc'] as String, style: t.titleMedium, textAlign: TextAlign.center)),
    const SizedBox(height: AppSpace.lg),
    if (earned)
      Center(child: PointsPill('✓ Earned', color: c.gold))
    else ...[
      Row(children: [
        Expanded(child: Text('Progress', style: t.bodyMedium!.copyWith(color: c.textSecondary))),
        Text('${current.clamp(0, target)} / $target $unit', style: t.titleSmall),
      ]),
      const SizedBox(height: AppSpace.xs),
      AnimatedBar(progress: target == 0 ? 0 : current / target, color: c.primary),
      const SizedBox(height: AppSpace.sm),
      Text(current >= target
          ? 'You qualify: it unlocks with your next scan.'
          : '${target - current} more to unlock.', style: t.bodySmall),
    ],
  ]);
}
