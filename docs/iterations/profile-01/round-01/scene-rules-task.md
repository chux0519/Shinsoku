# Fix: ProfileKeyboardSceneTests vs P4 field-rule mirroring (integration on main)

Implementer brief. Read AGENTS.md. Branch `profile-01-scene-rules`. Files: `mobile/ios/KeyboardSceneTests/**`,
`mobile/ios/Runner/AppDelegate.swift` (DEBUG scene args only), `tool/ios_keyboard_scene.sh`, docs. No product
behaviour changes. No simulators (coordinator runs), no nested agents, no merging.

On main @ 922abed the coordinator ran all three scenes on iPhone 17: KeyboardSceneTests PASS, ProfileIntentSceneTests
PASS, ProfileKeyboardSceneTests FAIL at `address-bar-rule: keyboard should show 'Review', shows 'Dictation'`
(ProfileKeyboardSceneTests.swift:213). It passed on its own branch before P4 (#19) merged. Likely cause: P4 makes
Dart the owner of field rules and mirrors them (empty) to `fieldRules.v1` on launch, overwriting the DEBUG seed
`-ShinsokuSceneFieldRules`. Confirm from code.

Fix by driving the real UI instead of seeding: in the scene, open Runner › Settings › Profiles › Field rules,
set Search → Review (and reset it at the end), go back; remove the `-ShinsokuSceneFieldRules` DEBUG arg (keep
`-ShinsokuSceneResetSelection` only if still needed and not overwritten by the same mechanism — check). Add a
PHASE screenshot of the Field rules page. Evidence of the run: `build/ui-review/profile-01/round-01/
main-ProfileKeyboardSceneTests/` (FAIL png/txt) in the main checkout `/Volumes/ZT/repos/Shinsoku` — read-only.

Build-check (`tool/ios_keyboard_scene.sh --build-only`), commit, push, PR, reply with PR URL.
Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy
-u all_proxy gh`.
