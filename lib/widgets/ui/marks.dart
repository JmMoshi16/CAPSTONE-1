import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';

// Drawn marks for rank, level and badges, in place of emoji: emoji render differently on every phone and read
// as placeholder art. The data (labels, colours, thresholds) stays in core/theme.dart and the badge rules.

IconData rankIconData(String rankLabel) => switch (rankLabel) {
      'Platinum' => Icons.diamond_rounded,
      'Gold' => Icons.workspace_premium_rounded,
      'Silver' => Icons.military_tech_rounded,
      _ => Icons.shield_rounded,
    };

IconData levelIconData(int level) => switch (level) {
      1 => Icons.spa_rounded,
      2 => Icons.grass_rounded,
      3 => Icons.park_rounded,
      4 => Icons.forest_rounded,
      5 => Icons.emoji_events_rounded,
      _ => Icons.auto_awesome_rounded,
    };

/// Badge id -> icon (ids from the badge rules: first_scan, scan_N, pts_N, streak_N).
IconData badgeIconData(String id) {
  if (id == 'first_scan') return Icons.eco_rounded;
  if (id.startsWith('scan_')) return Icons.recycling_rounded;
  if (id.startsWith('pts_')) return Icons.stars_rounded;
  if (id.startsWith('streak_')) return Icons.local_fire_department_rounded;
  return Icons.verified_rounded;
}

/// A tier-coloured medallion with an icon: rank, level or badge.
class Medallion extends StatelessWidget {
  const Medallion({super.key, required this.icon, required this.color, this.size = 32, this.muted = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool muted;   // locked badge

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = muted ? c.textTertiary : color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: c.isDark ? 0.22 : 0.12),
        border: Border.all(color: tint.withValues(alpha: muted ? 0.25 : 0.45), width: size >= 40 ? 1.5 : 1),
      ),
      child: Icon(icon, size: size * 0.52, color: muted ? c.textTertiary : c.ink(color)),
    );
  }
}

class RankMark extends StatelessWidget {
  const RankMark({super.key, required this.lifetimePoints, this.size = 32});
  final int lifetimePoints;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = getRank(lifetimePoints);
    return Semantics(
      label: '${r.label} rank',
      child: ExcludeSemantics(child: Medallion(icon: rankIconData(r.label), color: r.color, size: size)),
    );
  }
}

class BadgeMark extends StatelessWidget {
  const BadgeMark({super.key, required this.id, required this.color, this.earned = true, this.size = 44});
  final String id;
  final Color color;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Medallion(icon: badgeIconData(id), color: color, size: size, muted: !earned);
}

/// The user's photo, or their initial on the brand colour. One component everywhere (Home, Profile, Edit).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photo, this.size = 44, this.onHero = false});

  final String name;
  final Uint8List? photo;
  final double size;
  final bool onHero;   // on the dark header: lighter ring

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.primaryContainer,
        border: Border.all(color: onHero ? Colors.white.withValues(alpha: 0.5) : c.border, width: 1),
      ),
      child: photo != null && photo!.isNotEmpty
          ? Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _initial(context, initial))
          : _initial(context, initial),
    );
  }

  Widget _initial(BuildContext context, String initial) => Center(
        child: Text(initial,
            style: AppType.numeral.copyWith(fontSize: size * 0.42, color: context.colors.onPrimaryContainer)),
      );
}

/// The app's wordmark: the recycling glyph on a forest tile, then "ECOReward". Used on the sign-in pages.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(AppRadius.md)),
        child: Icon(Icons.recycling_rounded, color: c.onPrimary, size: 20),
      ),
      const SizedBox(width: AppSpace.sm),
      Text('ECOReward', style: context.text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}
