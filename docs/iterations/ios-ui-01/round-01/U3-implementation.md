# U3 implementation: DESIGN.md component layer, host renders, screen migration

Branch `ios-ui-01-u3-components`, PR #5. Tested source: `5b99840` (last code commit; later commits are docs only).

## Commits
| Unit | Commit | What |
|---|---|---|
| 1 | `9ed5ade` | `lib/ui/tokens.dart`, `lib/ui/theme.dart`, contrast test, R03 lint + rule |
| 2 | `9db660c` | Component layer + component tests |
| 3 | `53e05f7` | Host render harness, `tool/host_review.sh`, `ShellScaffold` extracted (no visual change) |
| 4 | `bdb2e11` | Settings (+ profile editor sheet, keyboard setup screen) |
| 4 | `1eae8fa` | Record |
| 4 | `08fecdb` | Drafts + draft editor (+ undo delete in the shell) |
| 4 | `bb6de91` | Nearby (Desktop Mic) |
| 4 | `5b99840` | Shell chrome + removal of `features/common/widgets.dart` |
| 5 | (docs) | `U3-audit.md`, this file, STATE |

## Tokens and theme (`mobile/lib/ui/`)
- `SkColors` (ThemeExtension, `SkColors.of(context)`): DESIGN §2 dark + light, exact hex; `onAccent`, `pressed`
  (text 8 %), `tone(SkTone)`. `SkType` (§3 scale + `mono` = Menlo), `SkSpace` (+ `margin(width)` 16/20),
  `SkShape` (radii, hairline, 44 target), `SkMotion` (150/200/250 ms, `of(context)` → zero under Reduce Motion).
- `buildSkTheme(brightness)`: explicit `ColorScheme` from tokens, text theme merged so the platform family (SF Pro)
  stays, no splash, snack bar/dialog/sheet/tooltip themes from tokens. `main.dart`: `themeMode: system`.
- `import 'package:shinsoku_mobile/ui/ui.dart'` exports everything.

## Components
`SkButton` (primary / `.secondary` / `.text`, `busy`, `destructive`, `expand`), `SkIconButton` (tooltip = VoiceOver
label), `SkRecordButton` (idle / listening / processing / unavailable, light haptic on start/stop, optional `level`
ring), `SkCard`, `SkSection` + `SkSectionLabel` + `SkSectionBody`, `SkListRow` (+ `.toggle`, `selected` = fill +
check, custom semantics actions), `SkSwitch`, `SkSegmented` (equal or `scrollable`), `SkSheet` + `showSkSheet` +
`showSkConfirm`, `SkTextArea` (+ `.field`), `SkStatusLine` (tone icon, detail, fix action, live region), `SkBadge`,
layout: `SkPage`, `SkPageHeader`, `SkTopBar`, `SkEmptyLine`, `SkTabBar`, `skPageInsets()`; base: `SkPressable`
(pressed = fill, ≥ 44, semantics), `SkFill`, `SkActivityIndicator` (still arc under Reduce Motion).
Layout is constraint-driven: `skPageInsets(context, constraints.maxWidth)` = margin + each side's own safe inset,
centred at 600 pt on wide windows.

## Host render harness (tier A)
```
tool/host_review.sh <run> [scene,…] [theme,…] [device,…]
tool/host_review.sh ios-ui-01/round-01/u3-after                       # everything (108 images, ~10 s)
tool/host_review.sh ios-ui-01/round-01/u3-after record-idle "" iphone  # one scene, both themes, one device
```
Output `build/ui-review/<run>/<device>/<scene>-<theme>.png` (+ `.json` with size, safe area, text scale) and
`build/ui-review/<run>/index.html` (`<meta charset="utf-8">`). A full run clears old PNGs first.
- Test: `mobile/test/host_review/host_review_test.dart` (skipped unless `SHINSOKU_HOST_REVIEW=1`), scenes in
  `scenes.dart` (real screens, fake data, plugin channels answered with null, no network).
- Devices: `iphone` 402×874 (top 62, bottom 34), `iphone-text200` (same, 2.0× text: record-idle, settings),
  `duo-outer` 466×678 (right 84), `duo-inner-portrait` 669×951 (top 84, bottom 95), `duo-inner-landscape` 951×669
  (right 84). Themes `dark`, `light`. Host SF Pro (`SFNS.ttf`) and SF Mono for Menlo; iOS target platform; real
  shadows; Reduce Motion on so frames are still; any layout exception fails the scene.
- Scenes: record-idle, record-listening, record-processing, record-result, record-error, drafts-empty, drafts-list,
  draft-editor, settings, profile-editor, keyboard-setup, nearby, nearby-pair.
- Latest runs: `build/ui-review/ios-ui-01/round-01/u3-before/` (at `53e05f7`, 76 images) and `.../u3-after/` (at
  `5b99840`, 108 images, all passed).

## Behaviour changes (all deliberate, listed for review)
- Denied microphone / missing provider key no longer switch to tab 2 (that is Desktop since Nearby was added; the
  intent was Settings). The error stays on Record with its fix (`SmokeTestStatus.fix`). Label
  'Microphone permission required' → 'Microphone access is off'.
- Profiles are managed in Settings › Profiles (sheet editor, delete with confirmation); Record only selects, and not
  while recording.
- Settings shows only the selected provider's fields; one Save button (was two). "Keyboard setup" opens the new
  in-app guide instead of iOS Settings directly; the guide's button opens iOS Settings.
- Drafts: swipe to delete with Undo (was a delete button without undo); tap the row to edit.
- Success status hides the timing debug detail unless `SHINSOKU_SMOKE_TEST` is set (still logged via debugPrint).
- Nearby: once connected, the Connect button becomes Disconnect.
- Hidden tabs run with `TickerMode` off.

## Tests
- New: `test/ui/tokens_test.dart` (contrast, theme from tokens), `test/ui/components_test.dart` (44 pt, labels,
  selection semantics, Reduce Motion, toggle rows), `test/features/record_view_test.dart` (inline fixes, empty
  state, profile lock while listening).
- Changed finders in `test/widget_test.dart` (UI changed, texts did not): draft row is tapped instead of the
  removed "Edit draft" button; saved text found with `find.text` instead of `SelectableText`; the draft test checks
  the TODAY group, swipe-to-delete and Undo instead of a delete icon.

## Verification (source `5b99840`)
- `cd mobile && flutter analyze`: No issues found.
- `bash tool/test_diff.sh`: no new failures (0 known).
- `python3 tool/review_lint.py`: R01, R02, R03 ok.
- `tool/host_review.sh ios-ui-01/round-01/u3-after`: 108 images, all scenes passed (no overflow at 2.0×).
- Not committed: `mobile/pubspec.lock` churn from `flutter test` (kept as on main).
