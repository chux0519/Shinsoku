# R1 — iPhone only, version 1.0.0, privacy manifests and usage strings

Branch `release-01-r1-app`, worktree `/Volumes/ZT/repos/Shinsoku-wt/r1-app`. Model: Opus. Tier A + build.
Read AGENTS.md and `docs/iterations/release-01/plan.md` (especially "Keys").

## Work
1. **iPhone only:** `TARGETED_DEVICE_FAMILY = 1` for Runner and ShinsokuKeyboard (all configurations); remove
   iPad-only Info.plist keys (`UISupportedInterfaceOrientations~ipad`, iPad launch/icon entries) if present.
   Keep the iPhone orientations as they are (iPhone Duo).
2. **Version 1.0.0:** `mobile/pubspec.yaml` `version: 1.0.0+22` (the coordinator bumps the build at upload);
   the keyboard extension must follow the same `CFBundleShortVersionString`/`CFBundleVersion` (check how it
   does today; Apple rejects a mismatch).
3. **Privacy manifests:** `PrivacyInfo.xcprivacy` for Runner and ShinsokuKeyboard (in the right target's
   resources): `NSPrivacyTracking` false, no tracking domains, `NSPrivacyCollectedDataTypes` empty (the
   developer collects nothing; audio/text go from the device directly to the provider the user chose with the
   user's own key), and the required-reason APIs actually used (grep: UserDefaults incl. App Group →
   `CA92.1`/`1C8F.1`; file timestamps; system boot time; disk space). Check Flutter plugins' pods already ship
   their own manifests; list them in the notes.
4. **Usage strings:** review every `NS*UsageDescription` (microphone, local network, Bonjour services, speech if
   any) in English + the InfoPlist catalog (10 languages): accurate, says why, mentions the chosen provider for
   the microphone. No unused permission keys. `ITSAppUsesNonExemptEncryption` = NO stays.
5. **Key check (plan "Keys"):** grep the repo for any committed key-like value (`sk-`, long hex/base64 next to
   `api_key`/`apiKey`); confirm R04 and the M06 IPA check in `mobile/scripts/build_testflight.sh` cover the
   1.0 path. Never print `.env` values; compare inside a script only.

## Done when
`flutter analyze`, `tool/test_diff.sh`, `python3 tool/review_lint.py`, `flutter build ios --simulator --debug
--no-pub` (under `perl -e 'alarm shift; exec @ARGV' 900`), `tool/ios_keyboard_scene.sh --build-only` pass, and
an unsigned release config check: `flutter build ios --release --config-only --no-pub` then `plutil -lint` on
both Info.plists. Restore Flutter-regenerated tracked files before committing; commit per unit and push;
`R1-implementation.md` + `docs/iterations/release-01/round-01/STATE.md`; PR open. Reply with the PR URL.
