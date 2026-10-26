import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import 'motion.dart';

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

// ── Rewards ──────────────────────────────────────────────────────────────────

/// Words in a reward's name that pick a more specific picture than its category does.
final _rewardIcons = <(RegExp, IconData)>[
  (RegExp(r'\btea\b|matcha|\bchai\b'), Icons.emoji_food_beverage_rounded),
  (RegExp(r'\biced\b|frapp|shake|smoothie|juice|soda|lemonade|cold brew'), Icons.local_drink_rounded),
  (RegExp(r'cake|pastr|croissant|bread|muffin|waffle|donut|doughnut'), Icons.bakery_dining_rounded),
  (RegExp(r'cookie|brownie'), Icons.cookie_rounded),
  (RegExp(r'ice ?cream|sundae|gelato'), Icons.icecream_rounded),
  (RegExp(r'fries|burger|sandwich|takoyaki|meal'), Icons.lunch_dining_rounded),
  (RegExp(r'pasta|noodle|ramen'), Icons.ramen_dining_rounded),
  (RegExp(r'%|discount|\boff\b'), Icons.percent_rounded),
];

/// A reward's icon: from its name when a word gives it away (matcha, fries, croissant), else its category.
IconData rewardIconData(String title, String category) {
  final name = title.toLowerCase();
  for (final (words, icon) in _rewardIcons) {
    if (words.hasMatch(name)) return icon;
  }
  return switch (category) {
    'Coffee' => Icons.coffee_rounded,
    'Food' => Icons.restaurant_rounded,
    'Discount' => Icons.sell_rounded,
    _ => Icons.redeem_rounded,
  };
}

/// A reward category's accent (decorative; text in it goes through `colors.ink`).
Color rewardColor(String category) => AppPalette.categories[category] ?? AppPalette.forest;

/// A reward's picture: its icon on the category's tint, the same on Home, in Rewards and on the detail page.
/// [heroTag] lets the picture fly into the detail page; [muted] greys it out (sold out).
class RewardArt extends StatelessWidget {
  const RewardArt({super.key, required this.title, required this.category, this.size = 56, this.heroTag,
      this.muted = false});

  final String title, category;
  final double size;
  final String? heroTag;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = muted ? c.textTertiary : rewardColor(category);
    Widget art = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: c.isDark ? 0.22 : 0.12),
        borderRadius: AppRadius.all(size * 0.28),
      ),
      child: Icon(rewardIconData(title, category), size: size * 0.5, color: muted ? c.textTertiary : c.ink(accent)),
    );
    if (heroTag != null) {
      art = HeroMode(
        enabled: !AppMotion.reduced(context),
        child: Hero(tag: heroTag!, flightShuttleBuilder: heroMaterialFlight, child: art),
      );
    }
    return ExcludeSemantics(child: art);
  }
}
