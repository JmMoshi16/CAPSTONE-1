// Design tokens: the single source for colour, type, spacing, radii, elevation and motion.
//
// Screens read colours through `context.colors` (an [AppColors] theme extension) so the
// customer app follows the system light/dark setting. Admin screens use [AdminColors]
// (always dark). Every text colour here meets WCAG AA (4.5:1) on the surface it is meant for.

import 'package:flutter/material.dart';

// ── Brand palette (raw values; prefer the semantic colours in AppColors) ─────
class AppPalette {
  static const forest = Color(0xFF2F5D3A);     // primary, matches the splash and Lottie files
  static const forestDeep = Color(0xFF1F3F27);
  static const forestLight = Color(0xFF3E7A4C);
  static const mint = Color(0xFF7CCFA5);
  static const coffee = Color(0xFF6B4A34);
  static const cream = Color(0xFFF5EDE0);
  static const coin = [Color(0xFFFFE566), Color(0xFFFFD700), Color(0xFFB8860B)]; // decorative points coin

  // Decorative accents (icons, fills, confetti). Text drawn in them goes through colors.ink().
  static const categories = {
    'Coffee': Color(0xFF795548),
    'Food': Color(0xFFFF7043),
    'Discount': Color(0xFF7C4DFF),
  };
  static const medalSilver = Color(0xFF9E9E9E);
  static const medalGold = Color(0xFFFFC107);
  static const medalBronze = Color(0xFFCD7F32);
  static const confetti = [mint, Color(0xFF66BB6A), Color(0xFF29B6F6), Color(0xFFFF7043), Color(0xFFAB47BC)];
  static const confettiGold = [Color(0xFFFFD700), Color(0xFFFFE566), Color(0xFFFFB300)];
  static const goldWash = Color(0xFFFFF8E1);   // light background behind badge news
  static const soldOut = Color(0xFF424242);     // white text 10:1
}

// ── Spacing: 4/8 grid ────────────────────────────────────────────────────────
class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Bottom padding at the end of scrolling content.
  static const double navClearance = 24;   // the tab bar is docked, so it never covers content

  /// Minimum touch target (Material / WCAG 2.5.5).
  static const double touch = 48;
}

// ── Gradients ────────────────────────────────────────────────────────────────
// Decorative. Text sits only on [forest] (white text >= 4.8:1 on every stop); the mint and
// cream ends are too light for white text, so they are used for rings, glows and fills.
class AppGradients {
  static const forest = LinearGradient(
    colors: [AppPalette.forestDeep, AppPalette.forest, Color(0xFF33643F)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const forestMint = LinearGradient(
    colors: [AppPalette.forest, Color(0xFF4E9A6B), AppPalette.mint],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const coffeeCream = LinearGradient(
    colors: [AppPalette.coffee, Color(0xFFA57E5F), AppPalette.cream],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const SweepGradient ring = SweepGradient(colors: [AppPalette.mint, AppPalette.forest, AppPalette.mint]);
}

// ── Responsive helpers ───────────────────────────────────────────────────────
class AppLayout {
  /// Current text scale (1.0 = default; users can raise it in system settings).
  static double textScale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

  /// A header height that grows with the text inside it, so large text never runs
  /// under the tabs or off the header ([perScale] extra px per +1.0 of text scale).
  /// On narrow phones (< 380 dp) enlarged text also wraps onto extra lines, so it grows faster.
  static double headerHeight(BuildContext context, double base, {double perScale = 100}) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return base + perScale * (textScale(context).clamp(1.0, 2.0) - 1) * (narrow ? 2.3 : 1);
  }

  /// Grid columns for card grids: 2 on phones, more on tablets ([minTile] = narrowest card).
  static int columns(BuildContext context, {double minTile = 180, int max = 5}) =>
      (MediaQuery.sizeOf(context).width / minTile).floor().clamp(2, max);
}

// ── Radii ────────────────────────────────────────────────────────────────────
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

// ── Motion ───────────────────────────────────────────────────────────────────
class AppMotion {
  static const fast = Duration(milliseconds: 150);     // press feedback, chip/colour changes
  static const medium = Duration(milliseconds: 250);   // most transitions
  static const slow = Duration(milliseconds: 400);     // entrances, page-level changes

  static const countUp = Duration(milliseconds: 400);  // numbers counting up / bars filling
  static const celebration = Duration(milliseconds: 1600); // confetti; the only motion allowed over 400 ms
  static const stagger = Duration(milliseconds: 50);   // delay between list items
  static const ambient = Duration(milliseconds: 1500); // looping hints (scan line, pulse)
  static const page = Duration(milliseconds: 300);     // page / tab / dialog-route transitions

  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const spring = Curves.easeOutBack;            // playful moments only

  /// True when the user turned on "Remove animations" (Android) / "Reduce motion" (iOS).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static final Set<String> _played = {};

  /// True the first time [key] is asked for in this app session, so entrance
  /// animations play on first load only, not every time a tab is revisited.
  static bool firstTime(String key) => _played.add(key);

  /// [d], or zero when the user asked for reduced motion.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

// ── Elevation ────────────────────────────────────────────────────────────────
class AppShadows {
  static const List<BoxShadow> none = [];
  // Two layers each: a tight contact shadow plus a soft ambient one (reads as depth, not smudge).
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0A1F3F27), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F1F3F27), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x0D1F3F27), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x141F3F27), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x101F3F27), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x1F1F3F27), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Coloured halo for primary buttons and "can afford" cards.
  static List<BoxShadow> glow(Color c, {double strength = 1}) => [
        BoxShadow(color: c.withValues(alpha: 0.28 * strength), blurRadius: 18, offset: const Offset(0, 6)),
        BoxShadow(color: c.withValues(alpha: 0.12 * strength), blurRadius: 40, spreadRadius: 2),
      ];

  /// Shadows read as dirt on dark surfaces; there a border does the separating instead.
  static List<BoxShadow> of(BuildContext context, List<BoxShadow> light) =>
      Theme.of(context).brightness == Brightness.dark ? none : light;
}

// ── Typography ───────────────────────────────────────────────────────────────
// Material 3 names; nothing smaller than 11 sp. Colours come from the theme.
class AppType {
  /// Headlines and big numbers: Fraunces, a soft café serif. Everything else: DM Sans.
  /// Both are bundled in assets/fonts (SIL OFL), never downloaded at runtime.
  static const displayFamily = 'Fraunces';
  static const bodyFamily = 'DMSans';

  static const display = TextStyle(fontFamily: displayFamily, fontSize: 44, fontWeight: FontWeight.w800,
      letterSpacing: -1.0, height: 1.05);
  static const numeral = TextStyle(fontFamily: displayFamily, fontSize: 44, fontWeight: FontWeight.w800,
      letterSpacing: -1.0, height: 1.0, fontFeatures: [FontFeature.liningFigures()]);

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: display.copyWith(color: primary),
        headlineMedium: TextStyle(fontFamily: displayFamily, fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, color: primary),
        headlineSmall: TextStyle(fontFamily: displayFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: primary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: primary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: primary),
        bodySmall: TextStyle(fontSize: 12, height: 1.35, color: secondary),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: primary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: secondary),
      );
}

// ── Semantic colours (customer app) ──────────────────────────────────────────
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Brightness brightness;
  final Color background, surface, surfaceAlt, border;
  final Color textPrimary, textSecondary, textTertiary;
  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color accent, coffee;
  final Color success, warning, danger, info, gold;
  final Color warningContainer, dangerContainer;
  final List<Color> hero;                // gradient behind white header text
  final Color onHero, onHeroMuted;       // text on [hero]
  final Color heroAccent;                // highlight text on [hero] (streak bonus)
  final Color bio, rec, res;             // waste-type accents (icons, bars)
  final Color bioFill, recFill, resFill; // solid fills that carry white text

  const AppColors({
    required this.brightness,
    required this.background, required this.surface, required this.surfaceAlt, required this.border,
    required this.textPrimary, required this.textSecondary, required this.textTertiary,
    required this.primary, required this.onPrimary, required this.primaryContainer, required this.onPrimaryContainer,
    required this.accent, required this.coffee,
    required this.success, required this.warning, required this.danger, required this.info, required this.gold,
    required this.warningContainer, required this.dangerContainer,
    required this.hero, required this.onHero, required this.onHeroMuted, required this.heroAccent,
    required this.bio, required this.rec, required this.res,
    required this.bioFill, required this.recFill, required this.resFill,
  });

  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EFEA),
    border: Color(0xFFE2E0D8),
    textPrimary: Color(0xFF1B1F1C),
    textSecondary: Color(0xFF5B635D),   // 6.1:1 on white
    textTertiary: Color(0xFF666D67),    // 5.3:1 on white, 4.9:1 on background
    primary: AppPalette.forest,         // 7.6:1 with white
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3F1E6),
    onPrimaryContainer: Color(0xFF1F3F27),
    accent: AppPalette.mint,
    coffee: AppPalette.coffee,
    success: Color(0xFF2E7D32),
    warning: Color(0xFFB45309),         // 5.0:1 on white
    danger: Color(0xFFC62828),          // 5.6:1 on white
    info: Color(0xFF0277BD),
    gold: Color(0xFF8A6500),            // 5.3:1 on white
    warningContainer: Color(0xFFFFF3E0),
    dangerContainer: Color(0xFFFDECEC),
    hero: [AppPalette.forestDeep, AppPalette.forest, Color(0xFF33643F)],
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xE6FFFFFF),
    heroAccent: Color(0xFFFFD08A),
    bio: Color(0xFF7CB342), rec: Color(0xFF0288D1), res: Color(0xFFE53935),
    bioFill: Color(0xFF33691E), recFill: Color(0xFF01579B), resFill: Color(0xFFC62828),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0F1411),
    surface: Color(0xFF171D19),
    surfaceAlt: Color(0xFF1F2722),
    border: Color(0xFF2C3530),
    textPrimary: Color(0xFFE8ECE9),
    textSecondary: Color(0xFFA9B3AD),   // 7.9:1 on surface
    textTertiary: Color(0xFF8A948E),    // 5.3:1 on surface
    primary: AppPalette.mint,
    onPrimary: Color(0xFF0B2416),
    primaryContainer: Color(0xFF1E3A2A),
    onPrimaryContainer: Color(0xFFBEEBD3),
    accent: AppPalette.mint,
    coffee: Color(0xFFC8A68B),
    success: Color(0xFF81C784),
    warning: Color(0xFFF5B36B),
    danger: Color(0xFFFF8A80),
    info: Color(0xFF6CC7F5),
    gold: Color(0xFFE6C25A),
    warningContainer: Color(0xFF3A2A14),
    dangerContainer: Color(0xFF3A1A1A),
    hero: [Color(0xFF15281C), Color(0xFF1E3A2A), Color(0xFF26493A)],
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xDDFFFFFF),
    heroAccent: Color(0xFFFFD08A),
    bio: Color(0xFFA5D67A), rec: Color(0xFF6CC7F5), res: Color(0xFFFF8A80),
    bioFill: Color(0xFF33691E), recFill: Color(0xFF01579B), resFill: Color(0xFFC62828),
  );

  bool get isDark => brightness == Brightness.dark;

  Color waste(String type) => type == 'Biodegradable' ? bio : type == 'Recyclable' ? rec : res;
  Color wasteFill(String type) => type == 'Biodegradable' ? bioFill : type == 'Recyclable' ? recFill : resFill;

  /// [c] adjusted (darker in light mode, lighter in dark mode) until it reads at 4.5:1 on [surface].
  /// Use for text drawn in a decorative colour such as a rank, level or category colour.
  Color ink(Color c) {
    var hsl = HSLColor.fromColor(c);
    for (var i = 0; i < 20 && _contrast(hsl.toColor(), surface) < 4.5; i++) {
      final l = isDark ? hsl.lightness + 0.04 : hsl.lightness - 0.04;
      hsl = hsl.withLightness(l.clamp(0.0, 1.0));
    }
    return hsl.toColor();
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background), surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt), border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary), textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      primary: l(primary, other.primary), onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      accent: l(accent, other.accent), coffee: l(coffee, other.coffee),
      success: l(success, other.success), warning: l(warning, other.warning), danger: l(danger, other.danger),
      info: l(info, other.info), gold: l(gold, other.gold),
      warningContainer: l(warningContainer, other.warningContainer),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      hero: [for (var i = 0; i < hero.length; i++) l(hero[i], other.hero[i])],
      onHero: l(onHero, other.onHero), onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      heroAccent: l(heroAccent, other.heroAccent),
      bio: l(bio, other.bio), rec: l(rec, other.rec), res: l(res, other.res),
      bioFill: l(bioFill, other.bioFill), recFill: l(recFill, other.recFill), resFill: l(resFill, other.resFill),
    );
  }
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
