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
