# R3 — implementation notes (App Store screenshots, 6.9", 10 locales)

Branch `release-01-r3-screenshots`. Tier A done here; the keyboard frames (tier B) are for the coordinator.
Nothing was sent to App Store Connect (dry run only).

## Pipeline
1. `tool/store_shots.sh [locales] [themes]` → `mobile/test/host_review/store_test.dart` (opt-in,
   `SHINSOKU_STORE_SHOTS=1`): real screens, 440×956 pt at 3× = **1320×2868**, clean status bar drawn on top
   (9:41, full bars, full battery), Pro owned. One flutter process per locale (UI font loaded once).
   Output `build/store/raw/<locale>/NN-<scene>-<theme>.png` + `.json` (cut paragraphs listed).
   Scenes: record-live (mid-sentence, pending words dimmed), record-done (cleaned text + "Dictation · default"),
   drafts (5 drafts incl. a translation and the custom profile), profiles (round 2: Settings › Profiles on its
   own page under a "Profiles" title — `SettingsProfilesSection`, extracted from Settings unchanged — so the
   screen starts at the heading: 4 built-ins in the locale + custom "Polite email"), field-rules (Email → custom profile, picker open), desktop (paired + connected to
   `example-mac`, 192.0.2.10).
   Fixtures: `store_fixtures.dart`, natural text per locale, no names/hosts/keys.
2. `build/venv-store/bin/python tool/store_frames.py [--look light|dark] [--locales …] [--check]`: Pillow from
   a venv under `build/` (`python3 -m venv build/venv-store && build/venv-store/bin/pip install pillow`).
   Flat brand canvas (light: accent #1F6470 + white caption; dark: canvas #101314), caption from the
   `captions` block in `docs/store/metadata/<locale>.yaml`, "Shinsoku Pro" tag on profiles/field-rules/desktop,
   the screen in a rounded device-free frame. Output `build/store/screenshots/<locale>/NN-<scene>.png`
   (RGB, no alpha) + `index.html` (utf-8). Fonts: SF Pro / PingFang SC·TC / Hiragino Sans W6 / Apple SD
   Gothic Neo Bold (macOS).
3. `python3 tool/store_screenshots.py [--apply] [--locales …]`: dry run by default; `--apply` replaces each
   locale's `APP_IPHONE_67` set (reserve → PUT parts → commit with md5 → order → wait for processing).

## Captions
- 7 per locale in upload order: record-live, keyboard, record-done, drafts, profiles, field-rules, desktop.
  `store_metadata.py check` validates the block (order, one line, ≤48 chars); `push` does not send it;
  `review-zh.md` has a captions table for the user.
- Wrapping: ≤2 lines, balanced, 96→80 px. Korean breaks at spaces only; **Chinese/Japanese 2-line captions
  must mark the break with `|`** (character breaks split words, e.g. 电/脑) — `--check` fails otherwise.
  Pseudo-length check: English captions +40 % must still fit. Result: all fit at 96 px.

## Keyboard frame (tier B, coordinator) — round 2: Notes, zh-Hans + zh-Hant only
`KeyboardSceneTests/StoreSceneTests.swift` (in the test target; `--build-only` passes):
```
SCENE_TEST=KeyboardSceneTests/StoreSceneTests SCENE_STATUS_BAR=clean \
  bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh <iPhone 17 UDID> build/store/keyboard
```
Optional `TEST_RUNNER_STORE_LOCALES=zh-Hans`. Per locale: seeds "title\nbody" (fixture text) as latest (Runner
launched with `-AppleLanguages`), opens **Notes** in that language (dismisses first-run sheets, New Note), Shinsoku
keyboard → Insert; PHASE `store-<locale>-ready` / `-inserted`; then deletes the note (best effort, SCENE line
`note-deleted`). No Safari, no `data:` URL. The shared simulator's language is never changed, so the keyboard
keys show the system language (zh-Hans); the zh-Hant frame has Simplified keyboard labels next to a Traditional
note. `SCENE_STATUS_BAR=clean` overrides the status bar to 9:41 and clears it on exit. Then rerun
`store_frames.py`: it picks `build/store/keyboard/light/PHASE-*-store-<locale>-inserted.png` (or
`build/store/keyboard/<locale>.png`) as 02-keyboard for zh-Hans/zh-Hant (`KEYBOARD_LOCALES`); the other locales
ship 6 screenshots. Not run on a simulator by me: Notes labels (compose, onboarding, delete) are matched in
en/zh-Hans/zh-Hant with a toolbar fallback; a failed step attaches `FAIL-<step>` with the element tree.

## Round 2 (coordinator review)
1. 04-profiles starts at the Profiles heading (own page, see above); checked in all 10 locales.
2. The translation profile's list subtitle was the English prompt (real app behaviour). Fixed in the app:
   `profileListDescription()` shows the new ARB string `profileTranslationDescription` (10 languages + pseudo,
   glossary note) for the built-in translation profiles while their instruction is unchanged; the instruction
   (sent to the model) stays English; an edited one shows as written. Test:
   `test/services/profile_list_description_test.dart` (10 locales, edited prompt, legacy ZH -> EN seed).
   Every locale's 04 now shows the localized line.
3. Keyboard frame: Notes instead of the Safari page; zh-Hans and zh-Hant only.

## Open points for the coordinator
- zh-Hant keyboard frame: keys in Simplified Chinese (system language); keep or drop zh-Hant's frame.
- ASC en-US also has old `APP_IPHONE_65` and `APP_IPAD_PRO_129` sets; the script leaves other display types
  alone (the iPad set may need deleting by hand since 1.0 is iPhone-only).
- Fixture texts are duplicated in `StoreSceneTests.swift` (Swift cannot read the Dart file); keep in sync.

## Code changes outside tooling
- `NearbyMicrophoneView`: `@visibleForTesting previewConnected` (host renders only) for the paired scene.
- `host_fonts.dart`: font loading moved out of `host_review_test.dart` (shared; host review unchanged,
  smoke-run en + ja).

## Verified (round 2)
`flutter analyze` clean; `tool/test_diff.sh` no new failures; `python3 tool/review_lint.py` all ok;
`store_metadata.py check` ok; `store_frames.py --check` ok; 60 screenshots rendered + framed and reviewed on
the contact sheet (all ten 04 rechecked); profile_list_description_test passes; `tool/ios_keyboard_scene.sh --build-only` TEST BUILD SUCCEEDED (generated files restored);
`store_screenshots.py` dry run: 10 locales, new APP_IPHONE_67 sets, 6 files each, nothing sent.
