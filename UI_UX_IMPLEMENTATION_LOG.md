# UI/UX implementation log

One entry per phase of `PROJECT_REDESIGN_ROADMAP.md`. "Verified" means a command was run; anything only
read in the code, or only checkable on a device, is labelled as such.

---

## Phase 0: baseline (2026-11-02)
- **Repo state:** branch `main` at `590d0e2` ("Premium & alive"). The working tree was clean, so there were no
  unrelated user changes to protect.
- **Verified checks:**
  - `flutter analyze`: no issues.
  - `flutter test`: 379 passed.
- **Audit check:** every bug in the UI/UX audit (§4a) was re-checked in the current code before fixing; the results
  are in the audit's "Verification (Phase 1)" table.
- **Documents:**
  - `PROJECT_DEEP_UI_UX_AUDIT.md` (git-ignored, like the earlier audit).
  - `PROJECT_REDESIGN_ROADMAP.md`.
  - This log.

## Phase 1: critical stability (2026-11-02)
Test-first: each test in `test/stability_test.dart` was run and seen failing for the expected reason before
its fix.

### Bugs fixed

| Bug | Root cause | Fix |
|---|---|---|
| Staff list crashed when sorted by Name | Name sort passes rank -1; `rank < 3` was true, so `medalColors[-1]` threw | `admin_users_screen.dart`: medals only for 0–2; no place number when sorted by name |
| Scanner stayed frozen after an error was closed by tapping outside or pressing back | The camera is stopped on error; only the "Scan again" button restarted it | `showScanErrorDialog` returns the choice; any close other than "Back to Home" scans again |
| "Verifying your code…" could spin forever | `claimScan` had no time limit | `.timeout(kScanClaimTimeout)` (15 s) leads to the existing "Couldn't reach ECOReward" message. The claim is a single transaction, so a late success is safe: a rescan says "Points already added" |
| Staff Add/Edit reward form overflowed with the keyboard open | A fixed `Column` in the sheet; the empty Rewards page behind it was a fixed `Column` too | The form scrolls (`SingleChildScrollView` plus bottom inset). The empty state scrolls and can be refreshed, and it also shows when every reward is waiting on Undo |
| Home quick actions overflowed on 320 dp phones (8 px) | Four fixed 72 dp actions in 280 dp | Equal `Expanded` shares |
| Android back closed the app from any tab | No back handling on the tab screens | New `TabBackScope` (`motion.dart`), used by customer Home and the staff dashboard: back goes to the first tab first |
| Scan History kept the old list after a scan started from it | It copied the logs once | `onScan` is awaited, then the list reloads |
| A redemption code could end in "…" | The ticket text used `TextOverflow.ellipsis` | New `RedemptionCode` (`surfaces.dart`): it shrinks instead of cutting. `spacedCode` moved there too |
| Sold-out reward said "scan to earn the rest" | Copy did not check for sold out | Sold-out copy: "out of stock right now…" |
| Activity showed "Bin: xxxx", which is really the start of the QR code | `binId` is a token prefix | Removed from the Activity row. The details sheet calls it "Code reference" |
| White place numbers on gold/silver medals (1.6:1) | Hard-coded `Colors.white` | `AppPalette.medalInk` (#1B1F1C, 5:1 or better on all three medals) on the podium and the staff list |
| Home and staff error screens had no way out | `ErrorState` had only Retry | `ErrorState` gains an optional second action. Home and staff show **Sign out**; the start-up error uses it for "Sign in with another account" (replaces a hand-made layout) |
| A failed staff refresh replaced good data with the error screen | The catch always set the error | Only a failed first load shows the error; a failed refresh keeps the data and shows a snackbar |
| "1 scans" in Scan History | No plural check | Singular/plural |

### Not reproduced, so left alone
- **Pull-to-refresh "Up to date" too early (Profile, staff Rewards, dashboard):** an `async` arrow returning the
  reload's Future awaits it, so these already waited.
- **Leaderboard can't be pulled when short:** a probe showed it can be.

Tests now guard both of these.

### Files changed
- **App code:**
  - `lib/core/tokens.dart`
  - `lib/main.dart`
  - `lib/widgets/ui/motion.dart`, `lib/widgets/ui/states.dart`, `lib/widgets/ui/surfaces.dart`
  - Customer screens: `customer_home_screen.dart`, `customer_home_widgets.dart`, `qr_scanner_screen.dart`, `scan_errors.dart`, `scan_history_screen.dart`, `rewards_screen.dart`, `reward_detail_screen.dart`, `impact_screen.dart`, `info_sheets.dart`, `leaderboard_screen.dart`
  - Admin screens: `admin_dashboard_screen.dart`, `admin_rewards_screen.dart`, `admin_users_screen.dart`
- **Tests:**
  - `test/stability_test.dart` (new, 18 tests).
  - `test/support/fonts.dart` (new: real-font loading shared with `layout_test.dart`).
  - `test/layout_test.dart` (uses the shared loader; Scan History's `onScan` is now async).
- **Other:** `.gitignore` (the UI/UX audit stays local).

### New or changed components
- `TabBackScope`
- `RedemptionCode` and `spacedCode`
- `ErrorState.secondaryLabel` / `onSecondary`
- `AppPalette.medalInk`
- `QRScannerScreen.claim` (test seam; defaults to `FirebaseService.claimScan`)
- `kScanClaimTimeout`

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **397 passed** (379 before + 18 new).
- Android debug build (`flutter build apk --debug --target-platform android-arm64`): **built**
  `app-debug.apk`. It ran before the final one-line change (the `mounted` guard in the scanner's error
  callbacks). The analyzer and the full suite were re-run after that change.
- Self-review (`ponytail-review`) found one gap: closing the dialog because the screen itself is being removed
  would have restarted a disposed camera. Both callbacks are now guarded with `mounted`.

### Remaining limits
- **Behaviour not tested end to end:** the staff "refresh failed, keep data" path needs a live Firestore failure, so
  it was checked by reading the code only.
- **Not yet seen on the emulator:** the new back behaviour, Sign out on the error screens and the scanner recovery
  were tested with widget tests, not yet tried by hand.

---

## Phase 2: unified design system (2026-11-02)
Tests for the new shared pieces are in `test/design_system_test.dart` (10 tests). They were written before the code,
but first run after it, so the only "red" step was a compile failure.

### One of each (new or merged)
| Shared piece | Replaces |
|---|---|
| `AppDates` (`lib/core/dates.dart`) | 5 hand-written month arrays and 7 different `DateFormat` patterns. List rows read "Today, 9:05 AM" / "Mar 4, 8:00 AM"; day headers "Today" / "Mon, Oct 12"; detail sheets "Thursday, Jul 9, 2026 at 2:03 PM" |
| `AppScanRow` (`scan_row.dart`) | Three different scan rows (Home `Medallion` 36, Scan History tinted badge, Activity filled badge 46) and three date formats |
| `showAppDialog` (`app_dialog.dart`) | Sign out, Discard changes, Change password, the hold-to-redeem accessible confirm, the scan error dialog and the redemption dialog. Before, two button styles were mixed (stacked `AppButton`s vs `TextButton`s) |
| `AppSheet.showContent` | The old unused `showForm`, plus four hand-built sheets: reward peek, code quick actions, photo picker, notification prompt. They had no handle, a Material handle, or a custom handle |
| `AppBackButton` (`headers.dart`) | `HeroBackButton`, a local `IconButton` copy, the scanner's black-square iOS chevron and the default `BackButton` |
| `AppSliverHeader` / `AppHeaderBar` | Hand-built headers on Scan History, Leaderboard and Badges, plus the Material `AppBar` on Edit profile. The collapsed bar now names the page |
| `Tap(scale:)` | `PressScale`, a near-copy of `Tap`. Deleted |
| `RedemptionCode` + `AppType.code` | The unbundled `'monospace'` family (7 places, customer and staff) and the staff search box's hard-coded `'Roboto'` hint |

### Tokens and type
- **New roles and styles:**
  - New role `displayMedium` (Fraunces 34).
  - `AppType.balance` (56), `AppType.stat` (26) and `AppType.code`.
  - `AppType.tabular()`.
  - `AppType.numeral` now uses tabular figures, so counting digits keep their width.
- **Literal font sizes removed:**
  - Customer and auth screens: 18 removed (badges, home, profile, activity, leaderboard, scanner, rewards, login,
    register, splash).
  - The one left is the avatar initial sized to its box, which is allowed.
- **Rank colours:** the gold, silver and bronze rank colours now come from the medal tokens instead of duplicating
  them.

### Dark mode
- **Danger button:** uses the theme's red, with dark text on the light dark-mode red (7.7:1 contrast). It was always
  the light-mode red.
- **Hold-to-redeem:**
  - Its fill was always the light-mode forest gradient. It now uses the theme's primary colour.
  - The label is drawn twice (primary on the empty part, onPrimary on the filled part), so no letter disappears as the
    fill passes under it. Before, forest text sat on a forest fill.
- **Chart bars:** start from `forestLight` in dark mode.
- **Animation fallbacks:** the Lottie fallbacks use the theme's primary colour.

### Copy
Sentence case everywhere in the customer app:
- "Points credited", "Badge unlocked", "Pending codes", "Camera permission required", "Retry camera access",
  "Scan QR code", "Scan history".
- Activity's "Disposal History" is now "Scan history", the same name as the page.
- "Your Redemption Code" is now "Your code".

### Removed after a search found no uses
- **Components:** `StatCard`, `PressScale`, `heroDecoration`, `EcoBrand`.
- **Tokens:** `AppGradients.coffeeCream` / `ring`, `AppPalette.soldOut`, `AppRadius.xxxl`.
- **Parameters and fields:** `EmptyState.emoji`, `RankInfo.icon`, `LevelInfo.emoji` / `bgColor`.

### Files
- **New:** `lib/core/dates.dart`, `lib/widgets/ui/{app_dialog,headers,scan_row}.dart`, `test/design_system_test.dart`.
- **Deleted:** `lib/widgets/ui/{press_scale,stat_card}.dart`.
- **Changed:**
  - `DESIGN_SYSTEM.md` (rewritten to match the code).
  - Tokens, theme, tap and the barrel file.
  - Components: button, sheet, hold, motion, states, surfaces.
  - `eco_animations.dart`, `notification_prompt.dart`.
  - Every customer screen, the three sign-in screens, and admin rewards (codes and dates only).
  - `test/scanner_permission_test.dart` (sentence-case copy).

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **407 passed**, including every screen at 360×640, 393×852 and 800×1280, text at 1.0x and 1.3x,
  light and dark.
- Not run this phase: an Android build and a look on the emulator.

### Left for later phases
- **Staff dialogs and sheets** keep their own dark styles until the console gets brand colours: `showAppDialog`
  reads `AppColors`, which the admin theme lacks. Phase 6.
- **Rewards and Activity** keep their forest header bars until their redesign. Phase 3.
- **The "Ranking" quick action** still names the Leaderboard differently. Phase 3, Home.
- **Snackbars** keep strong success and danger fills with white text in both themes. This is deliberate
  (AA-compliant, and readable on any background).

---

## Phase 3: customer screens (2026-11-02)
New tests are in `test/redesign_test.dart` (25 tests).
- **Seen failing before their fix:** Home, Rewards, Activity and the scanner frame.
- **Written after their fix:** the Register and Splash checks.

### What changed, screen by screen
| Screen | Change | Why |
|---|---|---|
| Home | A streak chip (flame and day count) beside the bell, only while a streak is alive; tapping it opens the streak sheet | The streak was only visible inside a card further down |
| Home | The goal card says "N of 10 scans in the last 7 days" and "N today" | It counted a rolling 7 days but said "this week". "Today" uses existing scan data; no daily goal is invented |
| Home | The "Ranking" shortcut is now "Leaderboard", the page's name. Labels shrink to fit a 320 dp phone | Inconsistent naming |
| Home | Notification titles in sentence case ("5-day streak", "You're in the top 10") | Copy consistency |
| Rewards | The page name fades into the collapsed header (`HeroHeaderSpace`) | A collapsed header showed only the tabs |
| Rewards | Swiping moves between Available and My codes; categories change with the chips | The hidden category swipe made tabs that could not be swiped |
| Rewards | Fresh rewards from Home replace the list (`didUpdateWidget`) | Stock and prices stayed as they were when the tab opened |
| Activity | Third header stat is "Last 7 days" instead of "Recyclable" | It repeated the recyclable card below it |
| Activity | "Recent scans" shows the latest 5, with "See all N scans" opening Scan history | The tab repeated the whole history, unfiltered and ungrouped |
| Activity | The page name appears in the collapsed header; the refresh pill sits under the header at any text size | Same header gap as Rewards; the pill offset was a fixed 160 |
| Scanner | The frame is at most 65 % of the width, 42 % of the height and 320 dp, a little above centre (`scanWindowRect`) | On 320 and 360 dp phones the status card covered the frame's bottom; tablets got a 520 dp frame |
| Leaderboard, Badges | Header and podium entrances play on the first visit of the session only | They replayed on every visit, unlike the rest of the app |
| Profile | The avatar is announced as "Edit profile" | It said "Edit profile photo" but opens the whole form |
| Register | `AutofillGroup` with username, email and new-password hints; the last field's keyboard action creates the account | Password managers could not save the account; the keyboard could not submit |
| Splash | Dark status-bar icons on the cream screen; announced as "Loading" | Light icons were nearly invisible; "Signing you in" was wrong when signed out |

### Files
- **Code:**
  - Screens: `customer_home_screen.dart`, `customer_home_widgets.dart`, `rewards_screen.dart`, `impact_screen.dart`, `qr_scanner_screen.dart`, `leaderboard_screen.dart`, `badges_screen.dart`, `customer_profile_screen.dart`, `register_screen.dart`, `splash_screen.dart`.
  - Shared: `widgets/ui/headers.dart` (`HeroHeaderSpace`).
- **Tests:** `test/redesign_test.dart` (new).

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **423 passed**, including layout at 360, 393 and 800 dp, 1.0x and 1.3x text, light and dark, and Home at 320 dp.
- **Not done this phase:** an Android build, and a look on the emulator. The visual result has been checked by tests only, not by eye.

### Left for later phases
- **Home is still the same layout, made more honest and complete.** The premium look (materials, depth, signature
  coin, custom icons) is Phase 4.
- **The success screen order** (points, then rank or badge, then the notification prompt) is Phase 5.
- **Width limits and two-column layouts on tablets** are Phase 7.

---

## Phase 4: premium visual and 3D system (2026-11-02)
New tests are in `test/premium_test.dart` (10 tests). They were written before the components and first run after
them, so the only "red" step was a compile failure.

### Built
| Piece | What it is | Where |
|---|---|---|
| `AppSurface` + `Depth` (`materials.dart`) | Three material levels. On the hero: frosted glass, brighter at the top, a hairline edge, and an outer shadow for floating. On the page: a lit gradient with a shadow in light mode and a lit top edge in dark mode. Solid under high contrast | Home balance (floating glass) |
| `TiltOnTouch` | Leans up to 5° towards a resting finger and springs back. Ignores touches that become scrolls; still under reduced motion | Home balance |
| `EcoCoin` (`coin.dart`) | The signature mark: a champagne coin with a struck forest leaf, a bevelled rim, a struck groove, a specular highlight and a contact shadow. A `CustomPainter`; no asset, no package. Turns face-on once on first appearance | Home balance (60), Rewards header (26) |
| Champagne tokens | `champagneLight` / `champagne` / `champagneDeep` | The coin only |
| `formatCount` | "1,240" everywhere (Rewards said "1240", Home said "1,240") | Balances, prices, Profile stat, reward detail |
| Reward art | A lit tile with an edge and a shadow in its own colour | Every reward picture |
| Tickets | Live codes use the raised material; expired ones stay flat | My codes |
| Tab bar | Lifts off the page with a soft upward shadow (light) or a lit edge (dark) | Customer nav |

### Removed
- **`GlassCard`:** its one use now goes through `AppSurface`, so there is a single glass implementation.

### Copy
- Home's section heading "This week" is now "Last 7 days", to match the card under it.

### Decided not to build
- **Custom waste icons:** the leaf, recycle loop and bin match the physical bins and the kiosk screen, so they stay
  as they are.
- **Particles, Rive and 3D packages:** one signature object is stronger than scattered effects, and no new
  dependency was needed.
- **Gyroscope parallax:** it would need `sensors_plus`; the touch tilt gives the depth cue without a new package.

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **433 passed**.
- **Screenshots:** rendered with the real fonts from a temporary widget test (since deleted) and checked by eye, for
  Home and Rewards in light and dark:
  - The coin reads as an object and the balance pane floats.
  - Nothing overlaps.
  - The two green bars in the shots are text-button labels the screenshot setup doesn't render, not an app bug.
- **Not done:** an emulator run and frame-time profiling. The blur (σ24 on one pane) is the one costly effect.

---

## Phase 5: animation and gamification (2026-11-02)

### Changed
| Change | Why |
|---|---|
| The notification question waits for **Done** on the success screen (`_done`), instead of a 1.6 s timer | The timer put a bottom sheet on top of the 2.2 s badge and rank confetti: two things at once |
| The success screen shows the signature `EcoCoin` on the balance pill (22) and on the points card (44, turns in as the points arrive) | Generic star icons; the coin is the brand's points mark |
| Named motion beats `beat` 300, `flight` 700, `linger` 900, `hold` 1100 ms replace 12 hand-written durations (scanner, success, charts, sheen, pull-to-refresh, hold-to-redeem) | One rhythm for every deliberate moment; the old token comment claimed nothing ran over 400 ms except confetti |

### Tests
- `test/stability_test.dart` gains two flow tests: a fake camera sees a code, the claim succeeds, and the success
  screen shows. They check that:
  - Nothing pops up over the celebration (4 s).
  - Done always returns to where the scan started, with or without the notification question already asked.
- **What the tests cannot see:** without the notification plugin, the question is never shown in tests. That it now
  appears after Done (not during the confetti) was checked by reading the code.
- **A failure that turned out not to be a bug:** a first test run failed at Done. Undoing the fix showed the cause was
  the test's own timing: plugin calls need real async in tests. `NotificationService` already catches plugin errors,
  so the extra guard I had added was removed again.

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **435 passed**.

### Not built (no real data for it)
- **Daily goals, streak protection, streak-milestone screens:** the data has no daily-goal or protection fields,
  and the success screen cannot tell whether a streak bonus was reached for the first time.
- **What existing data already supports:** rank-up and new-badge celebrations, the streak bonus breakdown, and the
  streak chip on Home.

---

## Phase 6: staff console (2026-11-02)

### Changed
| Change | Before |
|---|---|
| Brand palette: forest-black surfaces (#0B110E / #141B17), mint accent, the customer app's dark text colours | A separate GitHub-dark look with a neon #00E676 accent |
| Waste colours match the customer app and the physical bins; residual is charcoal | Residual was red, which means "error" in the customer app |
| Customer avatars use brand gradients (forest, bin blue, coffee, deep champagne) | Neon green, blue, orange and magenta |
| 73 literal font sizes moved onto the staff ramp (`AdminSize`); off-ramp sizes 16 / 17 / 22 / 28 moved to the nearest step; new `AdminType.display` | Only the Users screen used `AdminType` |
| 54 literal radii moved onto `AppRadius` (only 1–4 px rounding on thin bars remains) | Values 6, 10, 14, 18, 24 and 36, off the scale |
| One set of short colour names in `admin_theme.dart` | 25 duplicated alias lines across 4 screens |
| Sign out and Delete reward use `showAppDialog`, with clearer wording ("Delete "Latte"? Customers will no longer see it. You can undo for a few seconds.") | Hand-built dialogs ("Logout / Are you sure?") |
| Plain wording: "Last 7 days, and the next 3 days expected from that trend", legend "Expected", "Points held", "Most common waste" | "Linear Regression forecast", "Predicted Growth", "Pts Balance" |
| "Most common waste" is drawn in that bin's colour | Always purple |
| Counts grouped with `formatCount` (stat cards, list, detail) | "3215", "1385" |
| QR screen bottom space 110, as on the other tabs | 80, which the floating nav could cover |
| The on-screen paper receipt shows when the code was made, as the PDF does | The time of each redraw |
| A short `userId` can no longer crash the redemptions list | `substring(0, 8)` |

### Tests
- `test/staff_console_test.dart` (3 tests):
  - Same bin colours as the customer app, and residual is not red.
  - The accent is the brand mint.
  - The forecast is in plain words.
- `contrast_test.dart` re-checks every staff text colour on the new card and background.

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **438 passed**.
- Screenshots of the dashboard and customer list were rendered and checked by eye, and fixed where they showed
  ungrouped numbers, neon avatars and a purple waste card.

### Still hand-built (on tokens, not yet on the shared components)
- The add/edit reward sheet.
- The customer detail sheet.
- The "Hand over this reward?" dialog, which has a custom code-comparison layout.

---

## Phase 7: responsive and accessibility (2026-11-02)

### Layout tests widened
- **Matrix:** `test/layout_test.dart` now runs every screen at 320×568, 360×640, 393×852 and 800×1280, with text at
  1.0x, 1.3x and 2.0x. That is 512 combinations, up from 264.
- **First run:** **58 failures**, nearly all at 2.0x text (the largest size Android offers). None of these could be
  seen in the old matrix.

| Overflow | Fix |
|---|---|
| Tab bar fixed at 64 dp (80 reports, every screen with the nav) | Height `48 + 16 × text scale`: 64 at normal size |
| Reward rows: price squeezed off the row at 2.0x on small phones | Above 1.5x the price sits under the name |
| Reward detail: figures beside the 76 dp ring | Values may wrap; above 1.5x the ring sits above the figures |
| Hold-to-redeem label ("Need 1,080 more points") | The label shrinks to fit the button |
| Activity header stats (also at 1.3x on 320 dp) | Three equal shares; the text shrinks to fit |
| Success "Badge unlocked" heading | Wraps |
| Staff code page taller than the screen | Scrolls when needed, same layout otherwise |
| Badges "Earned" tag | Shrinks to fit the card |
| Staff Customers: heading row, sort chips, rank badge | The heading shortens first; chips scroll; the badge shrinks |
| Staff Rewards: Redemptions tab label, price tag | Shrink to fit |

No fix lowers the user's text size; only labels inside fixed-size controls scale down to fit.

### Tablets
- **`PageScaffold`:** customer pages keep a 600 dp reading width, centred (`AppLayout.readingWidth`). Used by Home and
  its tabs, Scan history, Leaderboard, Badges, Edit profile and the success screen.
- **Before:** carousel cards were about 800×178 on a tablet and rows ran edge to edge.
- **Grids:** `AppLayout.columns` counts grid columns on that width (Badges).
- **Staff console:** keeps its full width; its analytics grid adapts by itself.

### Screenshot tests
- **Location:** `test/golden_test.dart` with images in `test/goldens/`.
- **Coverage:** the coin, the glass balance pane, scan rows (light and dark) and Rewards (light and dark).
- **Skipped by default** (`dart_test.yaml`): the images come from this Windows PC, and the Linux CI renders text
  slightly differently. Run `flutter test --tags golden --run-skipped`.
- **Home and the dashboard are not full-screen goldens.** Their greeting, "Today" and 7-day counts follow the clock.

### Tests
- `redesign_test.dart`: Home on a 1024 dp tablet is ≤ 600 dp wide and centred.
- `layout_test.dart`: the widened matrix.

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **697 passed, 1 skipped** (the goldens, by design).
- Goldens: **6 passed** when run with `--tags golden --run-skipped`.
- The tablet Home image was checked by eye.

### Not covered
- **Landscape:** the app is locked to portrait.
- **Two-column tablet layouts:** the 600 dp column was chosen over a second layout for every screen.
- **Screen readers on a device:** TalkBack and VoiceOver walk-throughs were not done. Semantics labels are checked
  in widget tests only.

---

## Phase 8: final QA (2026-11-02)

### Final sweep
| Check | Result |
|---|---|
| `'monospace'` / hard-coded `'Roboto'` | none left |
| Hand-written month lists | none left |
| Literal font sizes | none in customer screens; none in the four staff screens. The staff code's 56 pt digits now use `AppType.balance` |
| Title Case labels | about 20 staff labels moved to sentence case ("Staff dashboard", "Rewards manager", "Add reward"…). "Smart Waste Recycling System" on the receipt is a product name and stays |
| Hand-built dialogs and sheets | 3 left, all staff, listed in Phase 6 |

### Bug found by the before/after screenshots and fixed
- **Duplicate chart label:** the staff chart printed "5" twice at the top of its y-axis. fl_chart also labels the
  chart's top edge (e.g. 5.4), and the label was rounded down.
- **Fix:** whole numbers only. It was present before the redesign too.

### Before and after
- **What:** the same screens rendered with the same data and fonts from the last commit (`590d0e2`, before this
  redesign) and from the final code.
- **Screens:** Home, Rewards, Activity and Profile in light and dark, plus the staff dashboard.
- **Where:** side-by-side images in the session scratchpad (`compare/side_by_side/`). They are not part of the repo.

### Verification
| Check | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **697 passed**, 1 skipped (the golden set, by design) |
| `flutter test --tags golden --run-skipped` | **6 passed** |
| `flutter build apk --release --target-platform android-arm64` | **built** `app-release.apk` (35.7 MB). The build started before the last two edits (staff label wording, chart axis); both were re-checked by the analyzer, the tests and a re-rendered screenshot |

### The whole redesign in numbers
- **Diff since `590d0e2`:** 69 files changed, +3,214 / −1,187 lines.
  - New: 22 files (components, tests, docs).
  - Removed: 2 (`press_scale.dart`, `stat_card.dart`).
- **Tests:** from 379 to **697**. That includes 18 regression tests (Phase 1), 10 for the design system, 25 for the
  customer screens, 10 for the premium components, 3 for the staff console, and the layout matrix grown to 512
  combinations.

### Remaining limitations (honest list)
- **Not seen on a device:** none of Phases 1–8 has been run on the emulator or a phone in this session. That
  includes the tilt, the coin's turn-in, the blur cost, the notification question after Done, and Android back on tabs.
- **No profiling:** no frame-time profiling (60 fps target) and no TalkBack or VoiceOver walk-through.
- **Three staff pieces still hand-built:** the add/edit reward sheet, the customer detail sheet and the "Hand over
  this reward?" dialog. They are on tokens and colours, but not on the shared components.
- **No landscape, no two-column tablet layouts:** the app is portrait-only, and tablets get a centred 600 dp column.
- **Goldens are Windows-only.** They are skipped on other machines, including the Linux CI. The CI workflow was
  already failing before this work and has not been investigated.
- **No gamification beyond the data:** no daily goal, streak protection or streak-milestone screen, because the data
  has nothing to drive them.
- **Nothing committed or pushed:** the iOS build (IPA) on GitHub is still the pre-redesign version.

---

## Follow-up: floating pill tab bar (2026-11-02)
Built from a reference image the user supplied (a capsule bar whose selected item rises in a circle through a
notch), adapted to ECOReward rather than copied.

### The component: `FloatingPillNav` (`lib/widgets/ui/floating_nav.dart`)
- **Same tabs, same behaviour:** Home, Rewards, Activity and Profile. Scan stays the middle action: tap opens the
  scanner, long-press opens it with the flashlight.
- **Unchanged around it:** tab state, Android back (`TabBackScope`) and screen-reader labels.
- **The bubble:**
  - The selected tab's icon sits in a bubble of the primary colour (forest in light mode, mint in dark).
  - The bubble rises above the bar through a notch, drawn with Flutter's `CircularNotchedRectangle` curve and
    trimmed to the capsule.
  - One animated value moves the bubble and the notch together (300 ms, `AppMotion.emphasized`, no bounce). A
    second tap mid-slide retargets from where the bubble is. Under reduce-motion it moves at once.
- **Labels:** the selected tab's name stays in the bar, bold, in the primary colour; the others are quiet outline
  icons.
- **Scan:** a mint circle in the bar (dark green in dark mode). It never rises and never takes the bubble's colour.
- **Surface:**
  - Light: white with a soft shadow and a hairline. The hairline is needed; without it the notch is hard to see on
    cream.
  - Dark: the raised dark surface with a lit edge.
- **Sizing:** at most 520 dp wide on tablets. Its height grows with text size; labels shrink rather than cut.

### Tests
- `test/floating_nav_test.dart` (9 tests):
  - Each slot does its job; Scan is never a tab.
  - The bubble follows the selected tab, including after quick taps and under reduce-motion.
  - The label styles are right, and screen readers hear "selected".
  - Scan never wears the bubble, in light and dark.
  - The tablet width is capped.
  - Home uses the new bar.
- **Updated:** `polish_test`'s check that Scan never looks like the selected tab, to the new colours.
- **Layout matrix:** every screen at 320–800 dp and 1.0–2.0x text passes with the new bar.

### Verification
- `flutter analyze`: no issues.
- `flutter test`: **706 passed**, 1 skipped (goldens).
- Goldens: 6 passed.
- **Rendered and checked by eye:** light and dark, 393 and 320 dp, with Home, Rewards and Profile selected. That
  check led to two changes: the bubble's wide glow was replaced by a tight shadow, and a hairline was added in
  light mode.

### Refinement: the tab bar in ECOReward's materials and motion (2026-11-02)
Seen on the TECNO phone and in close-up renders, then refined.

| Change | Why |
|---|---|
| The bubble **hops**: it lifts 9 dp and shrinks 6 % mid-way, arcs over and settles; the notch closes under it and opens as it lands. 400 ms (`AppMotion.slow`), `emphasized` curve, no bounce. A second tap mid-hop turns it in flight. Under reduced motion it moves at once | A sideways slide felt mechanical; the reference's charm is a physical, liquid feel |
| Bar in the raised material: white-to-cream gradient (dark: lit top edge), two-layer shadow | It was a flat fill, unlike every other raised surface in the app |
| Bubble lit from the top left (primary gradient), faint light rim, tight shadow; a soft mint glow in dark mode | Matches the coin and the glass balance; the old wide glow hazed the gap |
| The bar's shadow is kept out of the notch | The lowered shadow's own notch showed through the gap as a grey crescent under the bubble |
| Scan gets the same lit finish (mint gradient, light rim; dark: deep green with a mint rim) | The bar reads as one set of objects |

**Tests:**
- 3 added to `floating_nav_test.dart`: the bubble lifts mid-hop and lands at its resting height; it never lifts under
  reduced motion; the bubble and Scan are lit (gradients) in light and dark.
- The Scan colour check was updated for the gradient.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **708 passed**, 1 skipped.
- Goldens: 6 passed.
- **Release APK:** installed on the user's TECNO POVA 5 Pro (Android 14) over wireless debugging.

### Refinement 2: a cradle instead of a notch, and a truly floating bar (2026-11-02)

**What the user saw on the emulator:**
- **"A grey box" around Home.** On the end tabs the notch ate the capsule's rounded end, and the cream page showed
  through inside the bar's outline. The gap around the bubble also read as grey against the white bar.
- **The bar did not float.** It sat in its own strip, so the page was cut off in a hard line above it.

**Changes:**
- **`FloatingPillNav.barShape`:** the bar's surface rises in a collar around the bubble (the bar colour, 5 dp), with
  10 dp concave shoulders where it meets the flat top edge. On the end tabs the collar meets the rounded end
  directly, so nothing is cut away. During the hop the collar stretches after the bubble like a drop.
- **Floating over the page:** `extendBody: true` on Home (and its preview), so the page scrolls behind the bar.
  - Under the bar the page fades towards the bottom edge (background at 0 → 75 % → 100 %).
  - Every customer page ends with `AppLayout.bottomClearance` (the bar's height plus 24), so its last item scrolls
    clear above it. This applies to Home, Rewards (both tabs), Activity, Profile, Badges and Leaderboard.

**Tests (written first; seen failing):**
- The ring around the bubble is bar surface at 5 angles, on an end tab and on a middle tab, and the collar is not a
  block.
- Home extends behind the bar, and its last scan row scrolls fully above it.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **711 passed**, 1 skipped.
- Goldens: 6 passed.
- Rendered in light and dark with Home, Rewards and Profile selected and checked by eye.
- Installed on the emulator (screenshot checked) and on the TECNO phone.

### Refinement 3: no collar (2026-11-02)
- **Why:** the user found the white collar above the Home bubble ugly.
- **Change:** the bar is a plain capsule, and the bubble sits on its top edge, half above it. There is nothing around
  the bubble, neither a notch nor a collar.
- **Code:** `FloatingPillNav.barShape` and its two geometry tests are removed (their requirement was withdrawn). The
  bar is now built once, outside the hop animation, so only the bubble moves.
- **Verification:**
  - `flutter analyze`: no issues.
  - `flutter test`: **709 passed**, 1 skipped.
  - Rendered with Home, Rewards and Profile selected and checked by eye.
  - Installed on the emulator and the TECNO phone.

### Refinement 4: the bar in ECOReward's forest (2026-11-02)
**Why:** the user asked for a better design. The white bar on the cream page was low-contrast and flat. The mint
Scan circle competed with the green bubble (two "selected-looking" circles). The bubble rose high into the page.

| Change | Detail |
|---|---|
| Bar | Deep forest gradient (`c.hero`, the Home header's forest) lit from above, a 12 % white hairline, a soft forest shadow in light mode. The page now opens and closes in brand forest |
| Bubble | Lit mint gradient, white rim, soft mint glow, forest icon. It sits lower: its centre is 10 dp below the bar's top (it rises about 14 dp, was 18) |
| Labels | Selected: bold mint (`c.accent`, about 6:1 on the forest). Others: cream at 78 % (about 7:1) |
| Scan | A frosted-glass circle (white 20 % to 7 %) with a mint ring and icon, like the glass buttons on Home's header. Never the bubble's fill |

**Tests:**
- Updated to the design's intent rather than old colours:
  - The selected label is mint; the others are not.
  - Scan's colours share none of the bubble's.
  - The nav's own Scan label is neither mint nor extra-bold.
- One test now picks the nav's Scan icon specifically: Home has two.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **709 passed**, 1 skipped.
- Goldens: 6 passed.
- Rendered in light and dark with Home, Rewards and Profile selected and checked by eye.
- Installed on the emulator and the TECNO phone.

### Refinement 5: premium tab bar (2026-11-02)
**Brief:** the user's spec asked for a noticeably more refined bar (not a recolour), keeping all five destinations, the
forest pill, the raised mint indicator and the mint accents.

| Area | Before | After |
|---|---|---|
| Capsule | 64 dp stadium, flat forest gradient, even hairline | 60 dp, **continuous (superellipse) corners**, forest into emerald along its length, a sheen from above, a fine highlight on the top edge only, three layered shadows (dark mode: one ambient) |
| Indicator | 48 dp mint bubble, hop | 46 dp lit mint bubble with a fine rim, contact shadow and mint glow. A **pool of mint light** on the bar under it slides with it. The hop now **lands with a gentle ~5 % pop** and settles (no bounce) |
| Icons | Stock Material icons, mixed stroke weights (Activity's sparkles busy) | **`NavGlyph`, ECOReward's own set**: home, gift, trend, person and a scan viewfinder on a 24-unit grid with one stroke weight. Outline at rest; filled in the bubble (cut-out door, ribbon; the trend gains a lightly shaded area) |
| Scan | Glass circle with the stock QR icon | Glass circle with a mint viewfinder glyph: distinctive, still never the bubble's mint |
| Labels | Bold mint / cream | The selected name gains a touch of letter-spacing; cream at 74 % for the rest |
| Narrow phones | 20 dp side margins | 12 dp below 360 dp, so 320 dp phones keep room for five slots |

**Scan's behaviour is unchanged:** it is an action, not a tab. A tap opens the scanner; a long press opens it with the
flashlight. It has no selected state, so the screenshots show it pressed instead.

**Tests:**
- `test/floating_nav_test.dart` (now 20 tests):
  - The bubble is centred over each tab at 320, 360, 393, 430 and 1024 dp.
  - It pops within 1.02 to 1.08 and settles at exactly 1.
  - It never pops under reduced motion.
  - The bar is 60 dp at normal text size.
  - Every glyph draws outlined and filled at 16, 24 and 48.
- The tests find Scan by its key now that it has its own glyph.
- `layout_test.dart` gains 430×932, giving 640 combinations.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **847 passed**, 1 skipped.
- Goldens: 6 passed.
- **Screenshots:** every state (Home, Rewards, Activity, Profile, Scan pressed, mid-hop) in light and dark, checked by
  eye. A before/after sheet was made against the previous version. That check led to one fix: the filled Activity
  glyph's shading was lightened from 32 % to 18 %.
- **Installed on the emulator.** The phone was unreachable: wireless debugging was off.

## The whole Crave menu as rewards, and a new Home reward card (2026-11-04)

**What the owner chose:**
- Every Crave item costs **50 pts**, with no stock limit.
- Staff add the menu with **one tap** in the staff app; nothing is written to the database until they confirm.

**The menu** (`lib/core/crave_menu.dart`):
- 28 items, read off the posters:
  - 20 drinks (under Coffee, the customers' drinks chip).
  - 8 food items: Sweet Glazed Tocino, Smokey Garlic Tapa, the three Crunch Bowl flavours, The OG Burger, Pizza
    Burger and Samgy Burger.
- Each has a short note. The burgers' ingredients come from the Burger Series poster.
- `craveMenuToAdd` returns the items that are not rewards yet. It matches by name (any case or spacing) or by fixed
  id, so an item staff renamed is not added twice.
- `FirebaseService.addRewards` writes them in one batch, under fixed ids (`crave_<item>`). A double tap rewrites the
  same documents and never makes copies.

**Staff Rewards screen:**
- While any menu item is missing, a "Crave menu: N items aren't rewards yet" row offers "Add all".
- "Add all" asks first, then adds exactly the missing items. The row disappears once all are in.
- Staff also see each reward's photo in the list.

**New photos:** one per Crunch Bowl flavour, plus the Samgy Burger (the only Samgy photo is small, 252 px). There are
now 30 photos (405 KB) and 28 menu items, each with its own photo.

**Home reward card ("Ready to redeem"), redesigned:**
- **Before:** a tinted band with a small tile.
- **Now:** a menu card. The photo runs down the left two fifths:
  - A cup on its white backdrop sits straight on the white card.
  - Food photos fill the panel.
  - With no photo, the icon on the category's tint.
- Then the name (two lines), its note, and the price with a Redeem pill. Out of reach, a progress bar and "N to go"
  replace the pill.
- The price and the pill shrink to fit rather than overflow at 2× text on 320 dp phones (the layout matrix passes).

**Tests:** `test/crave_menu_test.dart` (8 tests):
- The menu is 28 items at 50 pts with no stock limit, each with its own photo.
- Items already there are skipped, by name or by id.
- Staff: "Add all" asks first and adds exactly the missing items; cancel adds nothing; the offer is gone once
  everything is in.
- Home card: a ready reward, an out-of-reach one, and one with no photo.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **862 passed**, 1 skipped.
- Goldens: 6 passed.
- **On the emulator:** the Home card with the live rewards (a drink and food).
- **Rendered, since there is no staff login on the emulator:** the staff list before and after adding the menu, the
  customer list with all 32 rewards, and Home in dark mode.

## Rewards menu as a photo grid (2026-11-04)

**Why:** with 32 rewards, each a photo, the one-column list made the photos small and the page long.

**What changed:**
- Each group (Ready to redeem, Keep saving, Sold out) is now a grid of `RewardTile`s: two per row on phones, three
  at 560 dp and up.
- A tile is the photo (or the icon on the category's tint), square and edge to edge, then the name, note and price.
  Out of reach, a progress bar and "N pts to go" follow.
- Sold out and "Only N left" show as a flag on the photo.
- The tile keeps the row's behaviour: the same screen-reader label, tap to open (the photo flies into the detail
  page), long-press to peek. A sold-out tile cannot be opened.
- `RewardTile` replaces `RewardRow`.
- `RewardPicture` (marks.dart) is the one "photo, else icon on tint" panel. The tile and Home's card share it.
- Same-price rewards sort A to Z.
- The loading skeleton is now a grid too.

**Tests:**
- The RewardRow tests in `polish_test.dart` now test RewardTile.
- `crave_menu_test.dart` adds two tests:
  - Two tiles per row on a phone, with a square photo as wide as its tile.
  - Three per row on a tablet.
- The Rewards goldens were updated for the new layout. I checked the new images by eye.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **864 passed**, 1 skipped.
- Goldens: 6 passed.
- **On the emulator with all 32 live rewards:** the grid and the Coffee/Food chips.

## Points by menu price, and clearer categories (2026-11-04)

**Points by menu price** (`craveMenuPoints` in `lib/core/crave_menu.dart`):
- Each menu item now carries its peso price from the posters.
- The owner's tiers: under ₱60 → 100, under ₱70 → 120, under ₱80 → 125, under ₱90 → 130, under ₱100 → 135.
- From ₱100 the owner gave a 140–160 range. I split it as: under ₱110 → 140, under ₱130 → 150, ₱130 and up → 160.
- Result on the menu: Tapa 140; Sweet Oat, OG Burger and Pizza Burger 150; Samgy Burger 160.

**Updating the live data:**
- The 28 items already in the database are at 50 pts.
- The staff "Crave menu" row now lists both kinds of change ("N to add, M prices to update") behind one Update
  button.
- `FirebaseService.saveMenu` runs the adds and the point changes in one batch.
- Only rewards with a menu id (`crave_*`) are repriced. Your own rewards, such as Dirty Matcha, are never touched.

**Categories:**
- The Coffee chip reads **Drinks**, because it also holds matcha and fruit drinks. The stored category stays
  "Coffee", so the staff form and Home's shortcuts are unchanged.
- The detail page's category label reads Drinks too.
- Each chip shows its count.
- The chips keep a fixed order: All, Drinks, Food, then deals and others.

**Tests:** `test/crave_menu_test.dart`:
- Every tier boundary, and real menu items at their tier.
- Repricing touches only menu items at the wrong price.
- Staff: the Update flow for adds and for reprices.
- The chips: Drinks label, counts, order, and the Food filter.
- The Rewards goldens were updated for the new chips. I checked them by eye.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **868 passed**, 1 skipped.
- Goldens: 6 passed.
- **On the emulator:** the chips read All 32, Drinks 23 and Food 9.

## Home shortcuts in the app's own icons (2026-11-04)

**Why:** the four shortcuts under the balance (Scan, My codes, Leaderboard, Badges) used stock Material icons that
read as generic.

**What changed:**
- They now use `NavGlyph`, the tab bar's own set: a 24-unit grid, one 1.8 stroke, round caps.
- Three new glyphs:
  - **codes:** a notched ticket with a dotted perforation.
  - **leaderboard:** a podium, first place in the middle, with a star above.
  - **badges:** a medal on a ribbon, with a star struck in it.
- Scan shares the tab bar's viewfinder.
- Glyph sizes: 28 in the mint Scan circle, 27 in the glass circles.

**Tests:** `floating_nav_test.dart`:
- New: Home's shortcuts use these glyphs, and none of the stock icons.
- The existing "every glyph draws" test now covers the new kinds.

**Verification:**
- `flutter test`: **869 passed**, 1 skipped.
- Goldens: 6 passed.
- **Checked by eye:** a large render and the emulator.

## Crave's logo on the Rewards tab (2026-11-04)

**What changed:** a slim band in Crave's own colours now heads the Available menu, above the chips: the wordmark in
navy (#0D1C77) on yellow (#F9C50D), with "Redeem at the counter".

**The logo file:** `assets/brand/crave_logo.png` (28 KB), cut from the logo image the owner supplied.
- Each pixel's alpha comes from where it falls between the yellow and the navy. Edges stay smooth.
- The coffee bean in the "c" stays see-through, so it shows the band's yellow, as in the original.

**Accessibility:** screen readers hear "Rewards from Crave, by Secret Cafe. Redeem at the counter."

**Fitting the space:** both sides of the band shrink to fit rather than overflow; the layout matrix passes.

**Tests:** `crave_menu_test.dart`:
- The logo sits above the chips.
- It has its screen-reader label.
- It is bundled and decodes.
- The Rewards goldens were updated for the new band.

**Verification:**
- `flutter test`: **870 passed**, 1 skipped.
- Goldens: 6 passed.
- **Checked by eye on the emulator.**

**Revised the same day, after the owner's feedback ("not good looking"):**
- **The problem:** the yellow block fought the app's forest and cream, and "BY: SECRET CAFE" was unreadable at that
  size.
- **The fix:** the band is now one quiet line, "Rewards from" plus the wordmark (20 dp tall). The wordmark is in
  Crave's navy in light mode and the app's cream in dark mode. There is no box.
- The logo was re-cut to the wordmark alone (596×140).
- **Verification:** 870 passed; goldens updated; checked by eye on the emulator and in the dark golden.

## Palette: Crave's navy and yellow (2026-11-04)

**What the owner asked:** match the app's colours to the café logo: navy #0D1C77 and yellow #F9C50D.

**What changed:**
- **Tokens (`AppPalette`):**
  - forest → **navy** (#0D1C77), forestDeep → navyDeep (#08124F), forestLight → navyLight (#23359E).
  - mint → **sun** (#F9C50D), plus a new sunDeep (#D9A800).
  - The gradients are renamed `brand` and `brandSun`.
- **Light theme:** the primary is navy (14:1 with white). Text neutrals are re-tuned cooler, still AA. The hero
  gradient is navy, and the hero accent is yellow.
- **Dark theme:** navy-black surfaces (#0C0F1A / #141827), with yellow as the primary and navy text on it.
- **Staff console:** navy-black surfaces, with Crave's yellow as the accent and navy text on it.
- **Brand colours outside the tokens:**
  - The nav capsule shades navy into royal blue, and its bubble is lit yellow.
  - Shadows are navy-tinted.
  - The scan accent, chart gradient, snackbar action and confetti now use yellow.
- **Comments** that named the old colours now name the new ones.
- **Lottie animations** (splash, loader, idle, success): forest and mint are swapped for navy and yellow.

**Kept on purpose:**
- The waste colours stay the physical bins' colours (green, blue, charcoal).
- Success stays green, and the rank colours stay as they were.

**Not changed:**
- The Android launcher icon is still the green leaf.
- The native splash colour is still cream.

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **871 passed**, 1 skipped, including the contrast tests.
- Goldens: all 6 regenerated, then re-run and passing.
- **Checked by eye:** Home and Rewards on the emulator, the dark goldens, and renders of the staff Rewards screen and
  sign-in.

## Home reward card: the glass the points fill (2026-11-04)

**What the owner asked:** make the card more unique, with more animation, and good-looking.

**The signature (`RewardFill`, lib/widgets/ui/reward_fill.dart):** the photo panel is a glass that the points fill
with Crave's yellow, from the bottom up to points ÷ cost. Full means ready.
- **Drawing:** the photo is drawn twice. Below the liquid's surface it is multiplied by the fill colour, so a cup's
  white backdrop turns yellow and the cup stands in it.
- **Surface:** a thin line marks where the light catches the liquid.
- **Rise:** the fill rises (1.1 s, ease-out) with a ripple that calms to a gentle meniscus. It replays when a card
  comes into view, and a level change animates from the level currently drawn.

**More motion:**
- **Price sticker:** the price is a tilted yellow sticker in the display serif that pops on with a slight overshoot.
- **Depth:** the photo drifts against the swipe, so it reads as deeper than the card.
- **Redeem:** the Redeem pill gains an arrow.

**Reduced motion:** no rise, no pop and no drift; the fill simply sits at its level.

**Tests:** `crave_menu_test.dart`, Home reward card:
- Ready means a full glass, with the price tag and Redeem.
- Out of reach, the glass fills to points ÷ cost, with "N pts to go".
- The fill rises from empty to its level, then rests.
- Under reduced motion the fill is static.
- Swiping drifts the photo.

**Verification:**
- `flutter test`: **874 passed**, 1 skipped.
- Goldens: 6 passed.
- **On the emulator:** three cards checked by eye.

## Improvement round from the "what still needs improvement" list (2026-11-04)

**Reward page:**
- The 112 dp tile became a large rounded photo card (320 dp header) in the same `RewardFill` glass as Home, filled to
  points ÷ cost.
- `fit: contain` keeps the whole cup in the wide frame (`RewardPicture` and `RewardFill` gained `fit`).
- Sold out shows the photo greyed, with no fill.
- The photo still flies in from the menu.

**My codes tickets:** `RewardTicketArt` shows the reward's photo with the status (pending, claimed, expired) as a
badge on its corner. Expired tickets are greyed. A reward without a photo keeps the status icon.

**Rewards header:** "Rewards from crave" is centred over the centred chips.

**Docs:** the last "forest" mentions in DESIGN_SYSTEM.md are updated. The roadmap's planned palette is marked as
since replaced.

**Visual pass in the new palette:** I rendered and checked Activity, Profile, Badges, Leaderboard, the scan success,
the reward page (light and dark), Activity (dark), the staff dashboard, the staff QR screen and the splash. No clashes.
The splash still shows the green leaf app icon (owner's choice).

**Goldens:**
- New `reward_photos`: three glasses at empty, half and full, plus the photo grid with real Crave photos.
- The golden helper now gives images real time to decode. Before, the Crave logo was sometimes missing from a
  capture, which would have made the goldens flaky.
- All goldens regenerated, then passed 3 runs in a row.

**Release build:** `flutter build apk --release --target-platform android-arm64` builds (36.2 MB).

**Tests:** `crave_menu_test.dart` adds 4:
- The reward page hero is a large photo, filled to points ÷ cost.
- A sold-out reward page shows the photo greyed, with no fill.
- The ticket art shows the photo with a status badge, else the status icon.
- The logo line is centred.

**Verification:**
- `flutter test`: **877 passed**, 1 skipped.
- Goldens: 7 passed.

## Official logo and animated splash (2026-11-05)

**What the owner asked:** use the official CRAVE by: SECRET CAFE logo as the app's brand, exactly as supplied. Also:
an animated splash (steam rising, then the cup, CRAVE and BY: SECRET CAFE revealed), the logo on sign in, register
and Home, a cup app icon, and the brand colours navy #142477, golden yellow #FFC914, cream #FFF8EC.

**The logo is never redrawn.**
- `assets/brand/crave_logo_full.webp` is the official PNG stored losslessly. It is identical pixel for pixel, and
  `tool/generate_icon.py` asserts that.
- Every other asset is cut from it by that same script:
  - the app icon (the logo's own steam, cup and saucer, no lettering), for Android, iOS and Home;
  - the CRAVE lettering on the Rewards tab, which replaces the older lowercase "crave".

**Splash** (`lib/screens/splash_screen.dart`, about 3 s):
- The splash shows the logo four times, each copy clipped to one band of its rows. The bands are cut along empty
  yellow rows (a test checks this): steam, cup and saucer, CRAVE, BY: SECRET CAFE. At rest the bands meet exactly,
  so the screen shows the untouched image.
- Sequence:
  1. A moment of plain yellow.
  2. The cup and saucer fade in and settle from 90 % scale.
  3. The steam rises out of the cup. Its band ends at the rim, so it seems to come from inside.
  4. CRAVE, then BY: SECRET CAFE.
  5. The finished logo holds, then the splash fades (0.4 s) into Login or Home.
- A soft, faint copy of the logo's own steam keeps drifting up behind it.
- A slow sign-in check holds on the finished logo.
- The yellow is alive (`SplashLight`). A warm light drifts slowly and endlessly over the screen: an 8 s loop that
  joins up seamlessly, breathing a little as it goes.
  - It falls over the logo too, like light on paper, so the image's own yellow square never shows as a box.
  - It only deepens colour, so yellow moves between bright and a deeper gold while the navy stays navy.
  - It grows in from flat yellow over the first 0.9 s, so the still launch screen hands over without a jump.
- With reduced motion, the whole logo shows still for 0.7 s, on still yellow.
- The background is the logo's own yellow (#FDCF09), so the image's edges vanish. The Android and iOS launch
  windows use the same yellow, so opening the app has no flash.

**Elsewhere:**
- The Sign in hero shows the logo instead of the leaf animation. That animation (`EcoBrandIntro`, `splash.json`)
  and `BrandMedallion` were removed.
- Register shows a small logo.
- Home's header leads with the cup mark, and the avatar moves to the right. Below 360 dp the mark steps aside so
  the name isn't cut short.
- The Rewards "Rewards from CRAVE" line scales down instead of overflowing at 320 dp with 2× text.

**Verification:**
- `flutter analyze`: clean.
- `flutter test`: **895 passed**, 1 skipped (brand_test.dart adds 18).
- Goldens: 7 passed, after re-recording 4 for the new navy and lettering.
- The debug APK was built and checked on the Pixel 8 emulator:
  - the system splash showed the cup icon on yellow, then the reveal, then the fade into Home;
  - the launcher icon was checked.
- The iOS icons and launch colour were generated, but no iOS build was run here (it runs in GitHub Actions).

## Home on the owner's phone: large text and a living fill (2026-11-05)

**Context:** the owner's phone, an OPPO CPH2799, is 360 dp wide with system text at **1.35×**. Their screenshots
showed:
- the shortcut labels running together ("My codesLeaderboard"), each shrunk on its own;
- "Silver, leve…" cut short;
- "Rewards to work towards" wrapping beside See all;
- scrolled text sitting under the clock;
- the reward card's yellow fill freezing once risen.

**Fixes** (test-first, `test/large_text_test.dart` at 1080×2372 @3x, 1.35× text):
- **Shortcuts:** the four labels share one size. If the longest doesn't fit its quarter with a gap, all four shrink
  together (`_QuickAction.sharedScaler`).
- **Balance card:** "Points balance" became "Balance" (the "85 pts" below says what of), so the rank pill shows in
  full.
- **Home's heading:** "Your next treat" (was "Rewards to work towards") fits one line beside See all. The test
  measures See all in DM Sans, because the harness draws button labels in a square fallback font.
- **Status bar:** once Home is scrolled, a navy band fades in behind the status bar.
- **Fill:** `RewardFill` keeps a gentle, rolling wave after it rises, with a second, smaller wave for a liquid look.
  The loop is seamless (2.6 s), and the fill is still under reduced motion. Tickers pause off-screen (TickerMode).

**Verification:**
- `flutter test`: **899 passed**, 1 skipped.
- Goldens: 7 passed. `reward_photos` was re-recorded for the new surface shape; stable over two runs.
- Release APK built (36.9 MB).

## The whole drink on Home's reward card (2026-11-05)

**Context:** on the owner's phone the Home card's photo looked close-up.
- The panel was 2/5 of the card wide and the card's full height, so a square photo was cropped to its middle 41 %
  (and zoomed 8 % more for the swipe drift).
- The café's photos are square, with the cup standing in the middle 62 % (x 75 to 324 of 400).

**Fix:**
- The photo now sits in its own "glass" inside the card: inset 8 dp, radius md, with a hairline.
- The glass has the drink's upright shape (`AspectRatio(0.7)`), so covering it shows the whole cup, lid to coaster.
- The extra zoom is gone; an upright glass leaves room at the sides for the drift.
- The carousel shows 84 % of the screen width (was 78 %).
- The card grows less with large text (`178 + 110 × (scale - 1)`), so the glass stays wide.
- **Tests:**
  - `large_text_test.dart` checks the visible share is at least 66 % at 1.35× text.
  - `crave_menu_test.dart` checks the same at 1×.

## Badges pay a one-time bonus (2026-11-05)

**Owner's decisions:**
- Only badges pay; there are no rank-up bonuses and no leaderboard prizes.
- Small bonuses, 140 in all.
- Only new unlocks pay.
- The bonus counts toward spending and toward rank, level and leaderboard (it is added to `lifetimePoints`).

**Table:** first_scan 5 · scan_5 10 · scan_10 15 · scan_25 20 · scan_50 25 · pts_50 5 · pts_100 10 · pts_500 20 ·
streak_3 10 · streak_7 20.

**How it works:**
- The bonus is paid inside the scan transaction that unlocks the badge.
- `creditScanFor` in `firebase_service.dart` is the pure credit, shared by `_creditScan`.
- Badges are checked once, on the scan's own result. A points badge reached only by the bonus unlocks on the next
  scan.
- `cappedBonus` keeps scan plus bonus within the rules' +100 per write. The largest real pile-up is 30 + 65 = 95,
  so it is paid in full.
- `waste_logs` records `pointsAwarded` (scan plus bonus, so Activity totals stay true) and `badgeBonus`.
- No security-rule, schema or kiosk change.

**Where customers see it:**
- Locked badges show "+N pts", and their sheet says "Unlocking it adds N pts".
  - Earned badges show no amount, because those held before bonuses existed were never paid.
- The scan success screen totals the scan and the bonus, with a "+N badge bonus" line and "+N pts" on each new badge.
- The badge notification says "+N pts".
- Scan details split the streak bonus from the badge bonus.
- The rank explainer says badges count toward the leaderboard too.

**Web console:** Manual Claim credits the same, from `config/rules.json`'s `bonus` (`lib/claim.ts`, tests in
`claim.test.ts`). The Badges page shows each bonus.

**Verification:**
- `flutter test`: **913 passed**, 1 skipped. `flutter analyze`: clean. Goldens: 7 passed.
- Web: `npm test` 24 passed, `tsc` clean, `npm run build` succeeded.
