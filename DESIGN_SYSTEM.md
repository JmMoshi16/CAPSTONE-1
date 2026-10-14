# ECOReward design system

Two products share one codebase: the **customer app** (light and dark, café identity) and the **staff
console** (dark, dashboard identity). All values live in `lib/core/tokens.dart` (customer) and
`lib/core/admin_theme.dart` (staff). Screens import `lib/widgets/ui.dart`, which re-exports the tokens and the
component library.

## Identity
A café that turns sorting waste into rewards: forest green and coffee brown, with a soft serif for numbers
and headlines. The signature moment is the scan: the brackets lock on, then points fly into the balance.

## Colour (`AppPalette`, `AppColors`)
| Token | Hex | Use |
|---|---|---|
| forest | #2F5D3A | primary actions, brand |
| forestDeep | #1F3F27 | text on mint, pressed states |
| mint | #7CCFA5 | accents, scan line, success glow |
| coffee | #6B4A34 | secondary brand, rewards |
| cream | #F5EDE0 | warm surfaces |
| coin | #FFE566 → #B8860B | points coin only (decorative) |

Semantic colours (`context.colors`: ink, surface, success, warning, danger…) come from the `AppColors`
ThemeExtension, with light and dark variants. Screens use these, not raw hex values. Contrast is covered by
`test/contrast_test.dart`.

Staff console (`AdminColors`): background #0D1117, card #161B22, accent #00E676 with dark `onAccent` text (12:1), and
secondary text at ≥5.7:1 on cards.

## Type (`AppType`)
- **Fraunces** (display): headlines and big numbers, with lining figures for counters.
- **DM Sans** (body): everything else.
- Both are bundled (SIL OFL), never fetched at runtime. Material 3 roles from 44 (display) down to 11 (labelSmall); nothing is
  smaller than 11 sp.

## Space, radius, elevation
- Space: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40. Touch target 48. Bottom-nav clearance 112.
- Radius: 8 · 12 · 16 · 20 · 28 · 40 · pill.
- Shadows `e1`–`e3`, dropped automatically in dark mode (`AppShadows.of`).

## Motion (`AppMotion`)
fast 150 ms (press) · medium 250 ms (most) · page 300 ms · slow 400 ms (entrances) · stagger 50 ms · ambient
1500 ms (loops). Only celebrations run longer (1600 ms). Curves: `standard` easeOutCubic, `spring` easeOutBack
(playful moments only). `AppMotion.reduced(context)` turns loops into still frames when the system's reduce-motion
setting is on.

## Components (`lib/widgets/ui/`)
AppButton · fields (text field, password) · AppSheet · AppSnackbar · states (empty, error, offline) · skeleton
loaders · StatCard · surfaces (cards, glass) · PressScale and `Tap` (semantics plus minimum tap area) · EcoRefresh
(pull-to-refresh) · celebration (confetti) · glow, hold_and_shine, leaves (signature effects) · motion
(entrance gates, staggered reveals).

## Rules
1. No raw colours, durations or font sizes in customer screens; use tokens and `Theme.of(context).textTheme`.
2. Every tappable thing goes through `Tap` or a Material button (48 dp, labelled). This is covered by `min_tap_area_test`.
3. Errors explain what to do. Never show raw exception text (`auth_messages.dart`).
4. One celebration per action. Ambient loops stop under reduce-motion.

## Known debt
- Staff console screens use ~100 literal `fontSize:` values and a few `Colors.grey` shades instead of the text
  theme. They look consistent but don't scale with the type ramp. Migrate one screen at a time with a
  golden test.
- Some celebration and scanner timings use literal `Duration`s (600–950 ms). They belong to the celebration sequence
  and are intentional, but should become named `AppMotion` constants.
- `kGreen`-style aliases are duplicated in four admin screens; move them into `admin_theme.dart`.
