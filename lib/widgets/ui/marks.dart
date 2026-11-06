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

/// Crave's own product photos (assets/rewards/, cropped from the café's menu posters), picked by words in a reward's
/// name. Order matters: food first, because the crunch flavours share words with drinks (Smokey Classic, Spicy
/// Mango), and two-word names before the words inside them (Strawberry Matcha before matcha and strawberry).
final _rewardPhotos = <(RegExp, String)>[
  (RegExp(r'tocino'), 'tocino'),
  (RegExp(r'tapa'), 'tapa'),
  (RegExp(r'buzz'), 'crunch_buzz_n_burn'),
  (RegExp(r'smokey classic'), 'crunch_smokey_classic'),
  (RegExp(r'spicy mango'), 'crunch_spicy_mango'),
  (RegExp(r'crunch'), 'crunch_bowl'),
  (RegExp(r'pizza ?burger'), 'pizza_burger'),
  (RegExp(r'samgy'), 'samgy_burger'),
  (RegExp(r'burger'), 'og_burger'),
  (RegExp(r'fries'), 'fries'),
  (RegExp(r'strawberry matcha'), 'strawberry_matcha'),
  (RegExp(r'matcha cookie'), 'matcha_cookies'),
  (RegExp(r'matcha'), 'matcha_dream'),
  (RegExp(r'chocnut'), 'chocnut_cloud'),
  (RegExp(r'choco ?berry'), 'choco_berry'),
  (RegExp(r'choco|cocoa'), 'dark_choco_dream'),
  (RegExp(r'strawberry'), 'strawberry_dream'),
  (RegExp(r'blueberry'), 'blueberry_haze'),
  (RegExp(r'mango'), 'mango_mirage'),
  (RegExp(r'sunrise'), 'sunrise'),
  (RegExp(r'signature'), 'signature_blend'),
  (RegExp(r'americano'), 'orange_americano'),
  (RegExp(r'mocha'), 'mocha'),
  (RegExp(r'caramel'), 'caramel_drip'),
  (RegExp(r'cookies? ?(&|and|n)? ?brew'), 'cookies_and_brew'),
  (RegExp(r'\boat\b'), 'sweet_oat'),
  (RegExp(r'sweet ?(&|and|n)? ?salty'), 'sweet_and_salty'),
  (RegExp(r'salted'), 'salted_classic'),
  (RegExp(r'sweet classic'), 'sweet_classic'),
  (RegExp(r'classic'), 'classic'),
];

/// A reward's product photo when its name is (or shares a flavour with) something Crave sells, else null.
String? rewardPhoto(String title) {
  final name = title.toLowerCase();
  for (final (words, photo) in _rewardPhotos) {
    if (words.hasMatch(name)) return 'assets/rewards/$photo.webp';
  }
  return null;
}

/// A category as customers read it. The data keeps "Coffee", but that group holds matcha and fruit drinks too.
String rewardCategoryLabel(String category) => category == 'Coffee' ? 'Drinks' : category;

/// A reward category's accent (decorative; text in it goes through `colors.ink`).
Color rewardColor(String category) => AppPalette.categories[category] ?? AppPalette.navy;

/// A reward's picture: the café's photo of it when there is one ([rewardPhoto]), else its icon on the category's
/// tint; the same on Home, in Rewards and on the detail page.
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
    final photo = rewardPhoto(title);
    final shape = AppRadius.all(size * 0.28);
    final edge = Border.all(color: accent.withValues(alpha: c.isDark ? 0.40 : 0.22));
    final icon = Icon(rewardIconData(title, category), size: size * 0.5, color: muted ? c.textTertiary : c.ink(accent));
    Widget art = Container(
      width: size,
      height: size,
      clipBehavior: photo == null ? Clip.none : Clip.antiAlias,
      // Lit from the top left, with a hairline edge and (light mode) a soft shadow in its own colour.
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: c.isDark ? 0.32 : 0.20), accent.withValues(alpha: c.isDark ? 0.14 : 0.07)],
        ),
        border: photo == null ? edge : null,
        boxShadow: muted
            ? null
            : AppShadows.of(context, [
                BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: size * 0.22, offset: Offset(0, size * 0.08)),
              ]),
      ),
      // Over a photo the hairline goes on top, so a cup on its white backdrop still has an edge on a white card.
      foregroundDecoration: photo == null ? null : BoxDecoration(borderRadius: shape, border: edge),
      child: photo == null
          ? icon
          : _muted(
              muted,
              Image.asset(
                photo,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, __, ___) => icon,
              ),
            ),
    );
    if (heroTag != null) {
      art = HeroMode(
        enabled: !AppMotion.reduced(context),
        child: Hero(tag: heroTag!, flightShuttleBuilder: heroMaterialFlight, child: art),
      );
    }
    return ExcludeSemantics(child: art);
  }

  /// A sold-out photo in black and white, like the greyed icon.
  static Widget _muted(bool muted, Widget photo) =>
      muted ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: photo) : photo;
}

/// A reward's picture filling whatever box it is given (a menu tile, the Home card's side panel): the café's photo,
/// else its icon large on the category's tint. [muted] greys it out (sold out).
class RewardPicture extends StatelessWidget {
  const RewardPicture({super.key, required this.title, required this.category, this.muted = false,
      this.fit = BoxFit.cover});

  final String title, category;
  final bool muted;

  /// How the photo fills the box: cover (tiles, panels), or contain where the whole cup must show in a wide frame.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = muted ? c.textTertiary : rewardColor(category);
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: c.isDark ? 0.30 : 0.18), accent.withValues(alpha: c.isDark ? 0.12 : 0.05)],
        ),
      ),
      child: Center(
        child: Icon(rewardIconData(title, category), size: 44, color: muted ? c.textTertiary : c.ink(accent)),
      ),
    );
    final photo = rewardPhoto(title);
    if (photo == null) return ExcludeSemantics(child: tint);
    return ExcludeSemantics(
      child: RewardArt._muted(muted, Image.asset(photo, fit: fit, errorBuilder: (_, __, ___) => tint)),
    );
  }
}
