# P2 — implementation notes (App Intents)

Branch `profile-01-p2-intents`. Commits: `53eb1c5` (intents + shared store), `42b86f2` (scene test, script
selector, intent log), then these notes.

## What was built
- `mobile/ios/Runner/ProfileGroup.swift` — the one owner of the App Group keys (`profiles.v1`,
  `activeProfile.v1`), the JSON shape and the sanitizer. `ProfileGroupChannel` (AppDelegate.swift) now calls
  it instead of its own copy; `AppDelegate.appGroup` aliases `ProfileGroup.appGroup`. Adds `readProfiles`,
  `readSelection`, `resolveActive` (stored id if it still exists, else first profile → `source: "default"`,
  PR3) and `writeSelection(profileId:source:)` (writes `{profileId, source, at}`, `at` in Dart's
  `toIso8601String()` format: UTC, milliseconds, `Z`; passes through the same sanitizer).
- `mobile/ios/Runner/ProfileIntents.swift` (all `@available(iOS 16.0, *)`; app minimum stays iOS 15):
  - `ProfileEntity` (`id`, `name`) + `ProfileEntityQuery` (`suggestedEntities` = all, `entities(for:)` by id).
  - `SetShinsokuProfileIntent` — `profile` parameter, `openAppWhenRun = false`. Re-checks the id against the
    current list (a deleted profile is refused with a message, never written — PR3; a renamed one is written
    and the dialog shows the current name). Writes `source: "automation"`, returns dialog
    "Shinsoku profile: <name>". Logs `intent setActive: source=automation` (subsystem
    `net.potafree.shinsoku.app`, category `profiles`, no names).
  - `GetShinsokuProfileIntent` — returns `ProfileEntity` as the output value + the same dialog; no profiles
    published yet → error "Open Shinsoku once so your profiles are available."
  - `ShinsokuShortcuts` — "Set \(.applicationName) profile", "Switch \(.applicationName) profile",
    "Get \(.applicationName) profile"; short titles "Set Profile" / "Get Profile". English only.
- Both files are in the Runner target (pbxproj: 4 lines each).

## Metadata
`flutter build ios --simulator --debug --no-pub` (default Xcode 27.2) → `Runner.app/Metadata.appintents/`
contains `extract.actionsdata` with actions `GetShinsokuProfileIntent`, `SetShinsokuProfileIntent` and entity
`ProfileEntity`. No build setting change was needed.

## Notes for review
- The intent runs in the app's process in the background (no UI). `didFinishLaunching` still runs, so the
  implicit Flutter engine may start; it does nothing visible. The running app picks the new selection up on
  resume / before recording (P1's `refresh()`).
- The field-rule vs automation question from P1 (open decision 1) is unchanged here: the intent only writes
  `source: "automation"` with the current time.

## Tier B (coordinator) — `ProfileIntentSceneTests.testProfileIntentScene`
New file `mobile/ios/KeyboardSceneTests/ProfileIntentSceneTests.swift` in the existing UI-test target.
`tool/ios_keyboard_scene.sh` gained `SCENE_TEST` (default `KeyboardSceneTests/KeyboardSceneTests`, so the
keyboard scene runs exactly as before). Run on the booted iPhone 17 under Xcode 27.2:

```
SCENE_TEST=KeyboardSceneTests/ProfileIntentSceneTests \
  tool/ios_keyboard_scene.sh 9080FE77-1FF9-49A1-B165-55DCA4ECED64 build/ui-review/profile-01/round-01/iphone-p2
```

Scene: launch Shinsoku (publishes `profiles.v1`) → Shortcuts › Shortcuts tab › the Shinsoku App Shortcuts
section (fallback: library search "Shinsoku") → "Set Profile" → pick Review → dialog "Shinsoku profile:
Review" → "Get Profile" → same dialog; repeat with Chat → launch Shinsoku cold → a label containing "Chat"
exists. No shortcut is created, so it's idempotent. The read-back is done by the Get intent in the app's own
process (the ad-hoc test runner cannot read the App Group).

**Not run** (no simulator for implementers): only `build-for-testing` succeeded. Expect to adjust selectors on
the first run — Shortcuts' App Shortcuts layout (section/tile labels, where the dialog snippet lives:
Shortcuts vs SpringBoard) is the guess. FAIL-<step>.txt carries the element tree for that. The last check
("Chat" on the Record screen) depends on how P1's shell labels the active profile.
TODO(P3): extend with the keyboard status row showing Chat.

Pending C (device): the Shortcuts *App is opened* automation with Run Immediately.

## Verification run
- `cd mobile && flutter build ios --simulator --debug --no-pub` → built; Metadata.appintents present.
- `tool/ios_keyboard_scene.sh --build-only` → `** TEST BUILD SUCCEEDED **`, no warnings in the new files.
- `python3 tool/review_lint.py` → all ok.
- Flutter-regenerated tracked files (AppFrameworkInfo.plist, Podfile.lock, pbxproj SPM rewrite, scheme,
  pubspec.lock) restored before each commit. No Dart changes, so analyze / test diff are unaffected.

## Round 1 tier-B fixes (coordinator run on iPhone 17, `build/ui-review/profile-01/round-01/iphone17-intent/`)
Shortcuts did receive the English launch arguments (tiles read "Set Profile" / "Get Profile").
- dark, `FAIL set-review-picker-Review`: the tap hit the tile container (`Other`, label "Set Profile"), which
  does not react; now taps the icon `Button` inside it. The picker/dialog lookup only waited on one app; it now
  polls Shortcuts, SpringBoard and Siri (`com.apple.siri`) together.
- light, "Neither element nor any descendant has keyboard focus": the Shinsoku section was not there yet (first
  launch after install, App Shortcuts still indexing), so the search fallback ran and typed without focus. Now
  waits 10 s for the section first; the search taps until the keyboard is up (3 tries) and checks it
  (`FAIL-<step>-search-focus`) before typing.
- FAIL attachments: besides the foreground app's tree, `FAIL-<step>-springboard.txt` (system snippets).
