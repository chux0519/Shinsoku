# U4 implementation: iPhone Duo adaptive shell, division-region bridge, posture-safe capture

Branch `ios-ui-01-u4-duo`, PR #6. Tested source: `c013685` (the last code commit; later commits are docs only).

## Commits
| Unit | Commit | What |
|---|---|---|
| 1 | `82b218b` | Division-region bridge (Swift + `lib/platform/division_regions.dart`) + tests |
| 2 | `a74950d` | Adaptive `ShellScaffold` (two panes at the fold), `SkTitledByChrome`, shell tests |
| 3 | `e75386e` | Posture-safe capture: invariants D1/D2, `holdRecord`, `DebugCapture` seam, model test |
| 4 | `c013685` | Host-render fold devices |

## 1. Division-region bridge
- Native (`ios/Runner/AppDelegate.swift`): the Shinphony `DivisionRegionObserver` / `DivisionRegionStream` code,
  ported. EventChannel `net.potafree.shinsoku/division_regions`. The observer is a hidden subview of the
  FlutterViewController's view and reads `reservedRegions(kind: .division)` (active, finite, non-empty, at most 8)
  in `updateConstraints`. It is guarded by `@available(iOS 27.1, *)` **and** `#if compiler(>=6.4)`, so the
  default Xcode 26.0.1 still compiles (and reports no regions). Shinsoku has no UIScene, so the observer
  attaches to the registered controller's view, on `onListen` and on `applicationDidBecomeActive`.
  For the UIScene move in U2 (PR #3), the bridge is self-contained: `DivisionRegionStream.register(with:
  FlutterViewController)` (one call, from wherever channels get registered) plus `attach()` from
  `sceneDidBecomeActive`. Rebasing means moving those two lines. I checked that
  it compiles with `DEVELOPER_DIR=…/Xcode-27.2.app flutter build ios --simulator --debug` (build succeeded; the
  Xcode-managed files the build touched were reverted).
- Dart (`lib/platform/division_regions.dart`): a `DivisionRegions` widget in `MaterialApp.builder`. It adds each
  active region to `MediaQuery.displayFeatures` as a hinge, so the shell, dialogs and sheets (through
  `DisplayFeatureSubScreen`) all read one API, and host renders can fake a fold the same way. The widget tree
  always has the same shape, so a fold appearing does not rebuild the app; the test found an early version that
  did. Any platform other than iOS, or a channel error, means no regions.
- Tests (`test/platform/division_regions_test.dart`): malformed entries, NaN/∞/negative values, cap of 8,
  empty/non-list input, stream → display features, error → cleared.

## 2. Adaptive shell (`lib/app/shell_scaffold.dart`)
- `ShellScaffold.splitFor(size, displayFeatures)` decides the layout from the constraints only:
  - **Compact** if either side is < 600: iPhone (portrait and landscape), Duo outer (466×678, and 678×466
    landscape = compact×compact), inner display in Split View (475 wide). This is today's iPhone layout, with the
    bottom tab bar.
  - **Regular** if both sides are ≥ 600 (= the regular×regular size class of the inner display). Two panes are
    split at a reported fold that crosses the whole window, or at the centre if there is none. The gap is
    `max(fold width, 24 pt)`, centred on the fold. Only a hairline is drawn there; it has no semantics and no
    hit target, and a test checks this. A fold that would leave a pane narrower than 280 pt falls back to compact.
  - **Axis:** taken from the fold (taller than wide → side by side; wider than tall → stacked); with no fold,
    from the window aspect. This is the `ArrangementView(.split)` rule.
- **Panes:** Record (status, transcript, profile, record button) is always visible in one pane. The other pane
  shows Drafts / Desktop / Settings.
  - Side by side: Record on the left, the switchable pane on the right (tools on the trailing side, where the
    Duo's own vertical bar is).
  - Stacked (inner portrait / tabletop): the switchable pane on top, Record at the bottom. This deviates from a
    literal "left = Record": the skill's tabletop rule ("content up, controls down") and DESIGN §3 (primary
    action in the bottom third) put the record button in the lower half. **Open decision** for the coordinator.
- **Navigation choice: a top switcher in the second pane (`SkSegmented`, labels only), not a NavigationRail.**
  Record never needs navigation (it is always on screen), so only three destinations remain, and all of them
  live in the second pane. A rail would take ~84 pt from the Record half (each half should stay
  outer-display-sized, per the "don't stretch" rule) and would sit next to the system's own 84 pt trailing bar
  in landscape. A switcher at the top of the pane keeps the control next to the content it changes. This is
  the companion-pane / list-detail pattern. I dropped the icons because "Settings" truncated in the 380 pt
  landscape pane.
- **Safe insets per pane:** each pane keeps the insets of the window edges it touches and drops the others
  (`MediaQuery.removePadding` + `SafeArea`). The trailing 84 pt only reaches the right pane in landscape;
  top 84 / bottom 95 go to the top / bottom pane in portrait. Tests check the pane rects.
- **State across switches:** the four pages sit under `GlobalKey`s and move between the compact `IndexedStack`
  and the panes without being rebuilt. A test checks that the Desktop and Settings `State` objects are
  identical before and after.
- `SkTitledByChrome` (component layer): an `SkPage` with only a title drops its header inside the second pane,
  because the switcher already names the page. Desktop keeps its header, since it has a subtitle.
- The old vertical side bar at ≥ 760 width is gone; the regular layout replaces it.
- `test/widget_test.dart` now pins an iPhone-sized window: Flutter's default 800×600 test window is now
  (correctly) a two-pane size. No assertions changed.

## 3. Posture-safe capture
- Capture state, the recorder, the stream session, status and transcript already lived in `_MobileShellState`,
  above `ShellScaffold`. Nothing had to move. The class doc now states this.
- **D1** (posture never changes capture) and **D2** (a regular → compact switch mid-capture shows Record) are in
  `docs/design/state_invariants.md`.
- D2 is implemented as `ShellScaffold.holdRecord` (= capture not idle). On a regular → compact switch the shell
  shows Record at once and reports `onTabSelected(0)` after the frame. The seeded model test found the case this
  covers (seed 7): leaving Record on the phone mid-recording, then unfolding and folding again, showed Drafts
  with no Stop in reach. It is kept as a named regression case.
- Test seam: `MobileShell.debugCapture` (`@visibleForTesting DebugCapture { start(); stop() → transcript }`)
  replaces the recorder/provider pipeline in widget tests. Production code is unchanged when it is null.
- `test/app/posture_test.dart`:
  - starts a fake recording and resizes 402 → 951 → book fold → tabletop → 402: the recording stays listening,
    the recorder is never stopped, and the Record button stays visible;
  - stops the recording and resizes again: the transcript survives;
  - stateful pages keep their State;
  - the D2 case;
  - the seed-7 regression;
  - a model test, seeds 1/7/42 × 40 events, with D1/D2 checked after every event.

## 4. Host renders
- New devices `duo-inner-landscape-fold` (hinge line at x = 475.5) and `duo-inner-portrait-fold` (y = 475.5),
  for record-idle, record-listening, drafts-list and settings. Total: 124 images, all passed.
- Runs: `build/ui-review/ios-ui-01/round-01/u4-before/` (at `82b218b`, the old shell) and
  `build/ui-review/ios-ui-01/round-01/u4-after/index.html` (at `c013685`).

## Pending tier B (the renders cannot prove these)
- Real division-region values: the width when book-folded, whether the observer's `updateConstraints` fires on
  every fold change, coordinates in a non-scene app, and whether the region reports as inactive when flat.
- A live fold or unfold during a real recording (audio session, Bailian streaming) and the one-frame D2 tab sync.
- Under-display camera occlusion on the inner display (`reservedRegions(kind: .occlusion)` is not bridged; the
  host renders have no camera region).
- Split View halves, Dynamic Island on the side, the real 84/95 pt bars.
- Dialogs and sheets landing in one half (they use `DisplayFeatureSubScreen`, which only acts when a region is
  active). The full-screen draft editor still spans both panes on the inner display.

## Open decisions / design conflicts
| Item | DESIGN.md / task | Implemented | Why |
|---|---|---|---|
| Stacked order | "left = record" | Record at the bottom when stacked | tabletop "controls down", §3 bottom third |
| Second-pane navigation | rail or switcher | top switcher, labels only | 3 destinations, keeps each half phone-sized |
| Draft editor on inner display | §6 nothing crosses the hinge | full-screen route (unchanged) | follow-up: open it in the second pane |

## Verification (source `c013685`)
- `cd mobile && flutter analyze`: no issues found.
- `bash tool/test_diff.sh`: no new failures (0 known).
- `python3 tool/review_lint.py`: R01, R02 and R03 pass.
- `tool/host_review.sh ios-ui-01/round-01/u4-after`: 124 images, all passed.
