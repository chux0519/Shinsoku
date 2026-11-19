# Review rules

Pitfalls we have hit. `R*` rules are checked by `tool/review_lint.py` (run one with
`python3 tool/review_lint.py R01`); `M*` rules are checked by reading.

| Id | Rule | Why (the incident) |
|---|---|---|
| R01 | No real host or user names in tests and fixtures; use `example-*`. | A public export leaked a machine name. |
| R02 | `rm -rf` only as `rm -rf "${VAR:?}"`. | An empty variable must never delete `/`. |
| R03 | No `Color(0x` or `ColorScheme.fromSeed` in `mobile/lib/` outside `mobile/lib/ui/`; colours come from DESIGN.md tokens (`SkColors`). | The pre-DESIGN app seeded Material from one hex and scattered literals (ios-ui-01 U3). |
| R04 | No API key compiled into the app: no `fromEnvironment('*_API_KEY')` under `mobile/lib/`, no `*_API_KEY` in the dart-define list of `mobile/scripts/*.sh`. | The TestFlight script baked the `.env` Bailian/Soniox keys into the IPA (profile-01 P0). |
| M01 | Timing claims need a recording cut at stable frames, not one screenshot after the action. | A transient state was reported as a persistent failure. |
| M02 | Build-number bumps go through `tool/next_build.py`, never a blind `sed`. | A sed rewrote a hex id that contained the number. |
| M03 | Qt/C++ code under `src/`, `tests/`, `packaging/` is frozen: no new features; new shared logic goes in Dart. | User decision 2026-11-18: everything moves to Flutter. |
| M04 | New Flutter UI uses the `mobile/lib/ui/` component layer and DESIGN.md tokens, not raw Material widgets or literal colours. | DESIGN.md §5/§8. |
| M05 | iPhone Duo: no text or control across the hinge; posture change never stops an active recording. | DESIGN.md §6. |
| M06 | No API keys in app binaries; users enter keys in Settings. Before a submission run `strings` over the IPA's Runner binary and Flutter `App.framework` and look for key prefixes. | Same incident as R04; the lint covers source, this covers the artifact. |
| M07 | Scene tests (XCUITest) don't scroll Flutter pages to reach a row: after a scroll Flutter's element tree can stay stale (old frames, zero-size rows). Reach the page by a `shinsoku://` deep link, or put the row on the first screen. | profile-01 scene-rules: Field rules was on screen but reported a zero frame after scrolling, in two runs. |
| M08 | Confirm a PR shows MERGED before removing its worktree/branch; resolve conflicts first. | 2026-11-19: PR #26 merge failed on a STATE.md conflict and the worktree was removed anyway (work survived only because it was pushed). |
| M09 | Scripts never run `flutter pub get` implicitly (`--no-pub`) and wrap flutter calls in a time limit. | 2026-11-19: a hung `pub get` in the scene script held the shared Flutter lock for 20 min and blocked another project. |
| R06 | Native (Swift) user-facing strings go through `String(localized:)` / `LocalizedStringResource` and a String Catalog with an English value; App Shortcut phrases keep `\(.applicationName)` and live in `<lang>.lproj/AppShortcuts.strings` (Runner targets iOS 15; `AppShortcuts.xcstrings` needs 17). Checked by `tool/check_xcstrings.py`. | i18n-01 I2: the keyboard and Shortcuts strings were bare English literals; I5 could not translate them. |
| M11 | After changing native strings, run `tool/check_xcstrings.py --stringsdata <DerivedData>/Build/Intermediates.noindex/Runner.build/Debug-iphonesimulator` once: the compiler's extracted keys are authoritative, the source scan only approximates them. Remove stale catalog keys so I5 does not translate dead text. | i18n-01 I2: the compiler's key for an interpolated string (`%@`) differs from the Swift literal; a hand-typed key silently falls back to English. |
