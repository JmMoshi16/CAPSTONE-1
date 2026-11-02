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
