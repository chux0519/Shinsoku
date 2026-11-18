# STATE: U1 (round-01)
- Done: services, features, app shell split; main.dart is 56 lines; analyze/test_diff/lint clean.
- In progress: none. Next: coordinator review and merge; U3 can build `lib/ui/` on this layout.
- Open decisions: none.
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`.

# STATE: U3 (round-01)
- Done: tokens + theme, component layer, tier-A host renders, Record / Drafts + editor / Settings (+ keyboard
  setup, profile sheet) / Nearby / shell migrated, R03, audit. Details: U3-implementation.md, U3-audit.md.
- In progress: none. Next: coordinator review of PR #5 and the renders; then U4 (Duo two-pane) builds on
  `ShellScaffold` / `SkTabBar` / `skPageInsets`.
- Open decisions: the "design conflicts" table in U3-audit.md (frame vs raised for sections, drafts row lines,
  extra components for §5).
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`,
  `tool/host_review.sh ios-ui-01/round-01/u3-after` → `build/ui-review/ios-ui-01/round-01/u3-after/index.html`.

# STATE: U4 (round-01)
- Done: division-region bridge, adaptive two-pane shell, posture-safe capture (D1, D2 + model test), fold host
  renders. Details: U4-implementation.md. PR #6.
- In progress: none. Next: coordinator review + tier B on the iPhone Duo simulator (fold/unfold mid-recording,
  real region values, occlusion) — see "Pending tier B".
- Open decisions: stacked order (Record at the bottom), switcher vs rail, draft editor spanning panes.
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`,
  `tool/host_review.sh ios-ui-01/round-01/u4-after` → `build/ui-review/ios-ui-01/round-01/u4-after/index.html`.

## U2 (keyboard extension) — UIScene migration done, rebased on main (with U4), awaiting coordinator rerun
- Done: keyboard redesign (theme, key, layout, delete repeat, return type); App Group handoff (user decision
  2026-11-18) with `LatestTextStore`, entitlements on both targets, Debug seed/reset launch arguments;
  tier-B scene harness `KeyboardSceneTests` + `tool/ios_keyboard_scene.sh` (Xcode 27.2 via `with-xcode.sh`,
  English launch args + zh labels, FAIL-<step>.png/.txt, Runner install, entitlement + pluginkit checks,
  keyboard/app logs); UIScene adoption (iOS 27 SDK launch crash), channels in `registerChannels(_:)`,
  U4's division regions wired through `DivisionRegionHook`.
- Verified: `--build-only` with Xcode 27.2 and 26.0.1: TEST BUILD SUCCEEDED, no warnings in touched files;
  App Group present on app + appex. Not run on a simulator by the implementer.
- Next: coordinator reruns `bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh
  9080FE77-1FF9-49A1-B165-55DCA4ECED64 build/ui-review/ios-ui-01/round-02/iphone-17/keyboard`; check deep
  links (cold + warm) and Duo division regions after the scene migration.
- Open: before TestFlight, register `group.net.potafree.shinsoku` for both App IDs and regenerate profiles
  (ask the user first). Final keyboard heights after screenshots.
- Details: `U2-implementation.md`.

