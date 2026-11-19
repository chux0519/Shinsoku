# I4 — ready-made App Shortcuts per profile

Branch `i18n-01-i4-shortcuts`, worktree `/Volumes/ZT/repos/Shinsoku-wt/i4-shortcuts`, base `main` @ e539779
(I1 + I2 merged). Model: Opus (native, App Intents). Read AGENTS.md, `docs/iterations/i18n-01/plan.md` (I4 row)
and `I2-implementation.md` first. I3 runs in parallel on Dart services; stay out of `mobile/lib/services/`.

## Goal
In the Shortcuts app and Spotlight, each of the user's profiles appears as a ready-made action ("Switch
Shinsoku to Chat"), with no setup, in the user's language once I5 fills the catalogs.

## Work
1. `ios/Runner/ProfileIntents.swift`: a parameterized App Shortcut over `ProfileEntity`
   (phrases like `"Switch \(.applicationName) to \(\.$profile)"`, `"Use \(\.$profile) in \(.applicationName)"`),
   keep the existing Set/Get shortcuts. `suggestedEntities()` returns the saved profiles.
2. Call `ShinsokuShortcuts.updateAppShortcutParameters()` whenever the profile list changes (the app's profile
   mirror into the App Group; find where `profiles.v1` is written natively) and on launch.
3. Strings: phrases into `Runner/en.lproj/AppShortcuts.strings` (keep `${applicationName}`; check how a
   parameter is written in the .strings key — verify with the compiler's extracted keys, rule M11), short
   titles / descriptions into `Runner/Localizable.xcstrings`. `tool/check_xcstrings.py` and R06 must pass.
4. Use in apps page (`mobile/lib/features/settings/use_in_apps_view.dart`): one line telling the user the
   per-profile shortcuts already exist in the Shortcuts app (ARB string, English only). Keep it small.
5. Tier B is the coordinator's: add a scene note (not a run) of what to check — Shortcuts app shows one action
   per profile; renaming a profile updates it.

## Out of scope
Dart services, region defaults (I3), translations (I5), pricing.

## Done when
`flutter build ios --simulator --debug --no-pub` (under `perl -e 'alarm shift; exec @ARGV' 900`),
`tool/ios_keyboard_scene.sh --build-only`, `python3 tool/review_lint.py`, `check_xcstrings.py --stringsdata …`
pass; restore Flutter-regenerated tracked files before committing; `I4-implementation.md` + STATE.md section;
PR open. Reply with the PR URL.
