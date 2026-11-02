# ECOReward redesign roadmap

**Goal:** an eco-premium, futuristic but warm ECOReward. Customer app and staff console are one product.
Same features, data, rules and QR/redemption flows as today.
**Started:** 2026-11-02. Progress, files and test results per phase: `UI_UX_IMPLEMENTATION_LOG.md`.
The findings behind this plan: `PROJECT_DEEP_UI_UX_AUDIT.md` (kept local).

## Ground rules (every phase)
- **Presentation layer only.** No changes to Firestore schema, security rules, authentication, points
  (15/10/5), streak multipliers (1.5x/2x), QR payload `ECOBIN:<Type>:<uuid>`, 20-minute expiry or the
  redemption workflow.
  - If a visual idea needs a logic change, it is written down as a proposal, not built.
- **No fake data.** A goal, streak or statistic is shown only if the current data supports it.
- **Tokens first.**
  - `lib/core/tokens.dart` (colours, type, spacing, radius, motion, shadows) stays the single source of truth.
  - Screens use tokens and shared components from `lib/widgets/ui/`, never literal colours or font sizes.
- **Tests and checks.**
  - Bug fixes are test-first.
  - Every phase ends with `flutter analyze` clean and the full `flutter test` green.
  - Layout tests catch overflows.
- **Dependencies.**
  - No new packages unless a phase shows a real need; any addition gets a written reason.
  - The visual system is planned with `BackdropFilter`, `CustomPainter`, `Transform` (perspective) and fragment
    shaders, plus the `lottie` and `animations` packages already installed.
- **Accessibility and motion.**
  - Accessibility (48 dp targets, semantics, unclamped text scale, contrast tests) and reduce-motion
    are kept.
  - Expensive effects get a cheap fallback.

## Phases

| # | Phase | Scope | Status |
|---|---|---|---|
| 0 | Baseline | Repo state, analyzer, tests, audit re-verification | **Done** 2026-11-02 |
| 1 | Critical stability | The 12 audit bugs, test-first | **Done** 2026-11-02 |
| 2 | Unified design system | See "Phase 2" below | **Done** 2026-11-02 |
| 3 | Customer redesign | Home, Rewards, Scanner, Activity, Scan History, Leaderboard, Badges, Profile, Auth, sheets and dialogs, in that order | **Done** 2026-11-02 |
| 4 | Premium visual and 3D system | See "Phase 4" below | **Done** 2026-11-02 |
| 5 | Animation and gamification | See "Phase 5" below | **Done** 2026-11-02 |
| 6 | Staff console | See "Phase 6" below | **Done** 2026-11-02 |
| 7 | Responsive and accessibility | See "Phase 7" below | **Done** 2026-11-02 |
| 8 | Final QA | See "Phase 8" below | **Done** 2026-11-02 |

### Phase 2: unified design system
- **Tokens:**
  - The refined palette: forest, emerald, mint, cream, botanical white, charcoal, sage, champagne gold.
  - A 9-role type scale with tabular numerals.
- **One of each:**
  - `AppHeader` (large title that collapses into a titled bar), back button, sheet, dialog, scan row, date format.
  - Press-scale primitive (today `Tap`, `PressScale` and `AppButton` each have their own).
- **Codes:** a bundled monospace-free code style.
- **Clean-up:**
  - Remove verified-dead code.
  - Make snackbar, danger button, hold fill and Lottie colours dark-mode aware.

### Phase 4: premium visual and 3D system
- **Three materials:** base surface, raised glass, floating glass.
- **Signature object:** a 3D-styled reward coin and leaf mark, drawn in code.
- **Custom icons:** waste-type and main-action glyphs.
- **Other:** reward art, parallax on hero cards, dark-mode materials.

### Phase 5: animation and gamification
- **Sequenced scan payoff:** points, then rank or badge, then the prompt.
- **Gamification:** visible streak on Home, milestone moments, rank progression.
- **Motion:** consistent timing.

### Phase 6: staff console
- **Theme:** the brand applied to the staff console as a forest-black base with emerald and mint.
- **Shared parts:** `AdminType`, tokens and shared components everywhere.
- **Content:**
  - Readable charts, with a plain-language forecast.
  - The 80 mm receipt keeps its QR payload.

### Phase 7: responsive and accessibility
- **Layout tests** at 320, 360, 393 and 800 dp, with text at 1.0x, 1.3x and 2.0x.
- **Wide screens:** a content width of about 600 dp, and two columns where it helps.
- **Golden tests** for key screens.

### Phase 8: final QA
- Analyzer and the full test suite.
- Android build.
- Emulator screenshots in light and dark.
- `DESIGN_SYSTEM.md` updated to match the code.
- A list of what is left.

## Known limits (decided up front)
- **Daily goal.**
  - The data has scan dates and a streak, but no daily-goal field, and the "weekly goal of 10" is a display constant.
  - A daily goal can be shown only as a presentation of existing counts (e.g. "scans today"). It is not a stored target.
- **No real 3D engine.** Depth comes from layered materials, perspective transforms and shaders. Rive or a 3D
  renderer would be a new dependency and is not planned unless a phase proves the need.
- **Physical-device checks are user-side.** 60 fps profiling and real-device checks need the user's phone or
  emulator; tests cover layout and behaviour, not frame timing.
