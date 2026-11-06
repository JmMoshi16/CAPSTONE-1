# ECOReward design system

Two products share one codebase:
- **Customer app:** light and dark, eco-premium identity. Values live in `lib/core/tokens.dart`.
- **Staff console:** dark, dashboard identity. Values live in `lib/core/admin_theme.dart`.

Screens import `lib/widgets/ui.dart`. It re-exports the tokens, `AppDates`, `Tap` and the component library.
The redesign plan and per-phase progress are in `PROJECT_REDESIGN_ROADMAP.md` and `UI_UX_IMPLEMENTATION_LOG.md`.

## Identity
Every recycled item creates value.
- **Colours:** Crave's navy and yellow (from the café's logo), with cream.
- **Type:** a soft serif (Fraunces) for numbers and headings.
- **Signature moment:** the scan. The brackets lock on, then points fly into the balance.

## Colour (`AppPalette`, `AppColors`)

| Token | Hex | Use |
|---|---|---|
| navy | #142477 | primary actions, brand (Crave by: Secret Cafe navy) |
| navyDeep | #08124F | hero gradient start, text on yellow |
| navyLight | #23359E | chart bars in dark mode |
| sun | #FFC914 | accents, scan line, dark-mode primary (Crave's golden yellow); never text on light surfaces |
| sunDeep | #D9A800 | the shaded side of yellow fills |
| coffee | #6B4A34 | secondary brand, splash tagline |
| cream | #FFF8EC | warm surfaces, text on the navy hero |
| coin | #FFE566 → #B8860B | small points stars on the scan screens (decorative) |
| champagneLight / champagne / champagneDeep | #F6E7BF / #D9B76A / #9A7432 | the signature coin `EcoCoin` only (decorative, never behind text) |
| medalGold / Silver / Bronze | #FFC107 / #9E9E9E / #CD7F32 | podium, rank colours |
| medalInk | #1B1F1C | numbers on medals (5:1 or better on all three) |

**Semantic colours.** `context.colors` gives text, surface, primary, success, warning, danger, waste colours and
others, from the `AppColors` theme extension in light and dark variants.
- Screens use these, not raw hex values.
- `AppColors.ink(c)` darkens or lightens a decorative colour until text in it reads at 4.5:1.
- Contrast is covered by `test/contrast_test.dart` and `test/stability_test.dart`.

**Waste colours** match the physical bins: biodegradable green, recyclable blue, residual charcoal. Residual is
never red, because red means an error.

**Staff console (`AdminColors`, `AdminType`, `AdminSize`)**
- **Surfaces:** navy-black background #0A0D18, card #131726.
- **Accent:** Crave's yellow, with navy `onAccent` text.
- **Waste colours:** the same bin colours as the customer app (residual is charcoal).
- **Avatars:** brand-derived gradients.
- **Type:** sizes come from the staff ramp. Use `AdminType` styles, or `AdminSize` for styles built at the call site
  (caption 11, label 12, body 13, title 14, stat 15, heading 18, display 26).
- **Radii:** use the shared `AppRadius` scale.

## Type (`AppType`, Material 3 roles; nothing below 11 sp)

| Role | Size | Family | Used for |
|---|---|---|---|
| displayLarge | 44 | Fraunces 800 | big numbers |
| displayMedium | 34 | Fraunces 700 | the wordmark on sign-in |
| displaySmall | 30 | Fraunces 700 | sign-in titles |
| headlineMedium | 26 | Fraunces 700 | page titles (large header, splash) |
| headlineSmall | 22 | Fraunces 700 | section headings, podium initials |
| titleLarge / Medium / Small | 18 / 16 / 14 | DM Sans 700 / 700 / 600 | card titles, list rows |
| bodyLarge / Medium / Small | 15 / 14 / 12 | DM Sans | running text |
| labelLarge / Medium / Small | 15 / 12 / 11 | DM Sans | buttons, chips, captions |

**Counts:** `formatCount(n)` groups digits ("1,240") on every screen: balances, prices, stats.

**Number and code styles**
- `AppType.balance` (56): the Home balance.
- `AppType.numeral` (44) and `AppType.stat` (26): stat cards.
- All of these use tabular figures, so digits keep their width while counting.
- `AppType.tabular(style)` adds tabular figures to any role.
- `AppType.code`: redemption codes in DM Sans with tabular figures and 2 px spacing. There is no `monospace`
  family: it is not bundled, and iOS has none by that name.

**Fonts.** Both families are bundled (SIL OFL) and never fetched at runtime.

## Screen sizes and large text
- **Supported range:** from 320 dp phones to tablets, with text from 1.0x to 2.0x. `test/layout_test.dart` renders
  every screen at:
  - 320×568, 360×640, 393×852 and 800×1280;
  - text at 1.0x, 1.3x and 2.0x;
  - light and dark.
- **`PageScaffold`:** customer pages keep a reading width of `AppLayout.readingWidth` (600), centred, on tablets.
  App bars and the tab bar still span the screen. `AppLayout.columns` counts grid columns on that width.
- **Large text never shrinks the user's chosen size globally.** Instead, layouts adapt:
  - The tab bar grows taller.
  - Reward prices move under the name and the reward detail's ring moves above the figures (above 1.5x).
  - Labels in fixed-size controls (hold button, chips, stat tiles) shrink to fit their control.
  - The staff code page scrolls.
- **Golden tests** (`test/golden_test.dart`) cover the coin, the glass pane, scan rows and Rewards. They are skipped
  by default (`dart_test.yaml`). Run them on the Windows dev PC with `flutter test --tags golden --run-skipped`.

## Space, radius, elevation
- **Space:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
  - Touch target: 48.
  - `navClearance` is 24, because the tab bar is docked and never covers content.
- **Radius:** 8 · 12 · 16 · 20 · 28 · pill.
- **Shadows:** `e1`–`e3`, dropped automatically in dark mode (`AppShadows.of`).

## Motion (`AppMotion`)

| Token | Duration | Used for |
|---|---|---|
| fast | 150 ms | press |
| medium | 250 ms | most transitions |
| page | 300 ms | pages and tabs |
| slow | 400 ms | entrances |
| stagger | 50 ms | between list items |
| cascade | 60 ms | between items of one entrance |
| ambient | 1500 ms | loops |
| celebration | 1600 ms | confetti |
| beat | 300 ms | between steps of a celebration (rank card, then badges) |
| flight | 700 ms | points flying into the balance, charts growing, counts on the success screen |
| linger | 900 ms | a highlight meant to be noticed (sheen, "Up to date") |
| hold | 1100 ms | press-and-hold to confirm |
| aurora | 12 s | two slow drifts of the hero, then rest |

- **Curves:** `standard` (easeOutCubic), `emphasized`, and `spring` (easeOutBack, playful moments only).
- **Reduce motion:** `AppMotion.reduced(context)` / `AppMotion.of(context, d)` turn motion off when the system
  setting is on.
- **Entrances** play once per session (`EntranceGate`, `AppMotion.firstTime`).
- **One thing at a time after a scan.** First the success screen plays: points fly into the balance, the coin turns
  in, then the rank card and badges flip in on the `beat`. Questions, such as the notification prompt, wait until
  Done.

## Materials and the signature mark (`materials.dart`, `coin.dart`)

**Depth levels** (`AppSurface(depth: …)`)

| Depth | Use |
|---|---|
| `Depth.base` | Most cards: solid, hairline edge |
| `Depth.raised` | Things to pick out: lit from above; a shadow in light mode, a lit top edge in dark mode |
| `Depth.floating` | The one thing a screen is about (the Home balance) |

**Glass and fallback**
- `onHero: true` makes it frosted glass over the navy header: blurred (σ16 / σ24), a white tint that is brighter at
  the top, and a hairline edge.
- With the system's high-contrast setting on, glass turns solid (navyDeep).

**Other pieces**
- **`TiltOnTouch`:** the card leans up to 5° towards a resting finger and settles back on release. A touch that becomes
  a scroll does not tilt it. It stays still under reduced motion. Used on the Home balance.
- **`EcoCoin`:** the brand's signature, a champagne-gold coin with a navy leaf struck into it ("every recycled item
  creates value").
  - Drawn in code; no image or package.
  - `turnIn` turns it face-on once when it first appears.
  - Screen readers skip it.
  - Used on the Home balance (60) and the Rewards header (26). Keep it to places that show the points balance.
- **`RewardArt`:** the café's product photo when the reward's name matches one (`rewardPhoto`, bundled in
  `assets/rewards/`), else a lit tile with its icon (gradient, edge, soft shadow in its own colour). A photo keeps
  the tile's shape, hairline and shadow; sold out turns it black and white.
- **The Rewards menu** is a grid of photo tiles (`RewardTile`): two per row on phones, three at 560 dp and up.
  Each tile has a square photo edge to edge, then name, note and price. Sold out and low stock show as a flag on
  the photo, so tiles in a group keep one height. Same price sorts A to Z.
- **Home's reward card** is a menu card: the photo runs down its left side (or the icon on the category's
  tint), then the name, note and price, with a Redeem pill, or a progress bar and "N to go".
- **Live tickets:** live redemption tickets use the raised material; expired ones lie flat.

## Dates (`AppDates`, `lib/core/dates.dart`)
The only place dates are formatted. Screens never write month names themselves.

| Function | Example |
|---|---|
| `moment` (list rows) | "Today, 9:05 AM", "Mar 4, 8:00 AM", "Dec 31, 2025, 11:59 PM" |
| `dayLabel` (day headers) | "Today", "Mon, Oct 12" |
| `full` (detail sheets) | "Thursday, Jul 9, 2026 at 2:03 PM" |
| `day` | "Jul 9" |
| `dayYear` | "Jul 9, 2026" |
| `monthYear` | "Jul 2026" |
| `time` | "2:03 PM" |

## Components (`lib/widgets/ui/`)

| Need | Use |
|---|---|
| Anything tappable | `Tap`: button semantics with a label, 48 dp target, press-in (`scale`: 0.94 icons, 0.98 cards), haptic |
| Buttons | `AppButton` (primary, secondary, danger; the danger kind is theme-aware) |
| Back | `AppBackButton` (`onImage: true` over the camera or photos) |
| Page header | `AppSliverHeader`: a large title that collapses into a bar that still names the page. `AppHeaderBar` for pages that do not scroll |
| Dialog | `showAppDialog`: icon, title, message, stacked actions. Returns true (confirm), false (cancel) or null (closed) |
| Sheet | `AppSheet.show` (draggable list) or `AppSheet.showContent` (sized to content: quick actions, previews, forms) |
| A scan in a list | `AppScanRow` (`grouped: true` inside one card on Home) |
| Redemption code | `RedemptionCode`: shrinks to fit, never cut off with "…" |
| Pages | `PageScaffold` (customer pages: reading width on tablets) |
| Cards and rows | `cardDecoration`, `AppListTile`, `SettingsGroup` / `SettingsRow`, `SectionHeader`, `AppChip`, `PointsPill`, `IconBadge` |
| Marks | `Medallion`, `RankMark`, `BadgeMark`, `UserAvatar`, `RewardArt` (photo or drawn, never emoji) |
| States | `EmptyState`, `ErrorState` (Retry, plus an optional second way out such as Sign out), skeletons |
| Feedback | `AppSnackbar`, `EcoRefresh` (pull-to-refresh), `ConfettiBurst`, `FlipReveal`, `HoldToConfirmButton` |
| Premium | `AppSurface`, `TiltOnTouch`, `EcoCoin`, `AuroraBackground`, `AnimatedProgressRing`, `StaggeredEntrance`, `SheenOnChange` |
| Tab bar | `FloatingPillNav` + `NavGlyph`: a slim (60 dp) capsule with continuous superellipse corners, navy shading into royal blue, a sheen from above, a fine top-edge highlight and layered shadows (contact, mid, ambient), floating over the page. The selected tab's filled glyph rides in a lit yellow bubble (46 dp) low on the bar, over a soft pool of yellow light that slides with it; changing tabs it hops (lifts, arcs, lands with a ~5 % pop; 400 ms; still under reduced motion). Own icon family (`NavGlyph`: 24-unit grid, 1.8 stroke, outline at rest, filled when selected). Quiet cream names; the selected name bold yellow. Scan: frosted glass with a yellow viewfinder glyph, never the bubble's fill. At most 520 dp wide; grows with text size |
| Tabs | `FadeIndexedStack`, `NavIconMorph`, `TabBackScope` (system back returns to the first tab) |

## Rules
1. **Tokens only.** No raw colours, durations or font sizes in customer screens; use tokens and the theme's text
   roles.
   - **Allowed:** sizes tied to a box, such as avatar initials. The camera overlay and the staff code screen may
     use white and black, because they sit on a camera image and must stay bright for scanning.
2. **Taps.** Every tappable thing goes through `Tap`, a Material button or a shared component (48 dp, labelled).
   This is covered by `min_tap_area_test`.
3. **One of each.** One header, back button, dialog, sheet, scan row and date format. Do not hand-build another.
4. **Errors explain what to do.** Never show raw exception text (`auth_messages.dart`). A full-screen error always
   has a way out.
5. **Motion.**
   - One celebration per action.
   - Ambient loops stop under reduce-motion.
6. **Sentence case** for every label, title and button.

## Known debt (tracked in the roadmap)
- **Staff screens still built by hand:** the add/edit reward sheet, the customer detail sheet and the "Hand over this
  reward?" dialog. They are dark and on tokens, but not yet on `AppSheet` / `showAppDialog`.
- **Headers on Rewards and Activity:** they keep their navy headers until their redesign. Phase 3.
