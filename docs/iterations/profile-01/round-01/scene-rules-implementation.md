# profile-01 scene-rules — implementation notes

## Cause (from code)
`MobileShell._loadVoiceProfiles` runs on every launch: `FieldRulesStore.pruneTo` loads Dart's rules (secure
storage, empty on the scene simulator) and `mirror` writes them to `fieldRules.v1` through `setFieldRules`.
That runs after `didFinishLaunching`, so it overwrote the DEBUG seed `-ShinsokuSceneFieldRules` and the keyboard
saw no rule in the address bar → `Dictation` instead of `Review`. It passed before P4 (#19) because nothing
wrote `fieldRules.v1` from Dart then.

`-ShinsokuSceneResetSelection` is unaffected: it removes `activeProfile.v1`, and Dart's `sync` only fills a
missing (or stale) selection with the default. Still needed (step 5 must undo the manual Chat pick), kept.

## Change
- `ProfileKeyboardSceneTests`: step 1 sets the rule in the app: Settings tab › Profiles › Field rules ›
  Search → Review (sheet), checks the row shows `Review`, `PHASE-xx-field-rules-seed` (the Field rules page),
  Back. A teardown block (runs after success and after a failure) relaunches the app and sets Search → None
  (`PHASE-xx-field-rules-reset`). Picking an already-set value skips the sheet.
- `AppDelegate` (DEBUG only): `-ShinsokuSceneFieldRules` and its parser removed.
- Element matching (Flutter rows merge their texts with `\n`): tab = button label BEGINSWITH `Settings`;
  entry = button BEGINSWITH `Field rules` (scrolls with swipe-up); Search row = button `Search` or
  BEGINSWITH `Search\n` (not the entry's subtitle "Search, web address, …"); option = button `<name>` or
  BEGINSWITH `<name>\n`; Back = button `Back` (the top bar's tooltip). Not checked on a simulator by me
  (coordinator runs); a mismatch fails at `field-rules-seed-*` with the runner's element tree.

## Verified
- `bash`-free: `DEVELOPER_DIR=…/Xcode-27.2.app/… tool/ios_keyboard_scene.sh --build-only` → exit 0.
- `python3 tool/review_lint.py` → ok.
- Run: `bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 env SCENE_TEST=KeyboardSceneTests/ProfileKeyboardSceneTests
  bash tool/ios_keyboard_scene.sh <UDID> <out-dir>`.

## Round 2 — coordinator run of f2e2338 failed at `field-rules-seed-entry`
- Evidence (`build/ui-review/profile-01/round-01/fix-ProfileKeyboard/light/FAIL-field-rules-seed-entry.*`): the
  screenshot shows the Settings page scrolled to the end with Field rules on screen, but the element tree from
  the same moment is out of date (Save Settings at y=356 vs ~121 pt in the image) and Field rules is
  `{{0,0},{0,0}}`. The labels match what the scene looks for (`Field rules\nSearch, web address, email,
  message`, tab button `Settings`). So the scroll worked; the check ran during 8 fast flings, before Flutter's
  accessibility tree caught up.
- Fix: `scrollRunner` drags slowly and holds before release (no fling), then polls up to 2 s for a non-zero
  frame + hittable before the next drag. New `waitHittable` guards the Search row (after the push) and the
  sheet option (after the sheet animation).
- Verified: `--build-only` (Xcode 27.2) exit 0; `review_lint.py` ok. Not simulator-run.

## Round 3 — a1c08c1 still failed at `field-rules-seed-entry`; deep link instead of scrolling
- Product: `shinsoku://settings/field-rules` and `shinsoku://settings/use-in-apps`, handled in
  `MobileShell._handleDeepLink` (same `DeepLinkBridge` path as `dictation`). They wait for the launch profile
  load, select the Settings tab and push the page (the same widgets the Settings rows push). Unknown
  `settings/<page>` and bare `settings` are ignored. The host can deliver a link up to 3 times (openURL, its
  0.4 s retry, consumeInitialURL), so a link for the page already open is ignored; a different linked page
  replaces it. The push is not awaited, so the host's `openURL` call returns right away.
- Test: `mobile/test/app/settings_deep_link_test.dart`: both pages (Field rules: Search row + its sheet lists
  Review; duplicate delivery pushes once; Back lands on Settings), unknown pages ignored.
- Scene: `setSearchRule` opens the link with `openDeepLink` (accepts the open-in confirmation if shown), then
  Search row → sheet → profile, as before. `scrollRunner` removed.
- Rule M07 in `docs/review_rules.md` (don't scroll Flutter pages in scene tests).
- Verified: `flutter analyze` clean; `tool/test_diff.sh` no new failures; `review_lint.py` ok;
  `--build-only` (Xcode 27.2) exit 0. Not simulator-run.
