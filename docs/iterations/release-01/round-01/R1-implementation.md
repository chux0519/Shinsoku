# R1 — implementation notes

Branch `release-01-r1-app`. Tested source: `db8ddb3` (all code; this commit adds notes only).

## What changed
1. **iPhone only.** `TARGETED_DEVICE_FAMILY = 1` in all six places it was `"1,2"` (project-level Debug/Release/
   Profile, which Runner and ShinsokuKeyboard inherit, and KeyboardSceneTests). Removed
   `UISupportedInterfaceOrientations~ipad` from `Runner/Info.plist`. iPhone orientations unchanged (portrait +
   both landscapes, for iPhone Duo). No iPad launch/icon keys in Info.plist; the AppIcon asset catalog still has
   iPad slots — actool drops them for family 1, left as is.
2. **Version 1.0.0.** `pubspec.yaml` `1.0.0+22`. The keyboard used hard-coded `MARKETING_VERSION = 0.1.0` /
   `CURRENT_PROJECT_VERSION = 21` (a mismatch with the app: 0.1.0 (22)). It now gets both from Flutter's
   `Generated.xcconfig` through `ios/ShinsokuKeyboard/Version.xcconfig` (base configuration of its three
   configs; `#include?` so the project still opens before Flutter generated the file). Runner Debug/Profile
   `CURRENT_PROJECT_VERSION` now `$(FLUTTER_BUILD_NUMBER)` like Release (was 21; Info.plist already used the
   Flutter variable, so this only matters for Xcode's display).
   Built bundle: app 1.0.0 (22), keyboard 1.0.0 (22), `UIDeviceFamily = [1]` for both.
3. **Privacy manifests** (`Runner/PrivacyInfo.xcprivacy`, `ShinsokuKeyboard/PrivacyInfo.xcprivacy`, in each
   target's Resources; present in the built bundles): tracking false, no domains, no collected data types.
   Required-reason APIs actually used in our Swift code (grep of Runner + ShinsokuKeyboard):
   - App: `UserDefaults(suiteName: group.net.potafree.shinsoku)` only → `1C8F.1`.
   - Keyboard: App Group suite → `1C8F.1`; `UserDefaults.standard` for `LastShownProfile` → `CA92.1`.
   - No file-timestamp, boot-time, disk-space or active-keyboard APIs in our Swift; the Dart code only does
     `File.existsSync/readAsBytes/delete` (no timestamps).
   Third-party manifests (already shipped, nothing to add):
   | Component | Manifest | Declares |
   |---|---|---|
   | Flutter.framework (engine) | yes | FileTimestamp `0A2A.1`, `C617.1`; SystemBootTime `35F9.1` |
   | flutter_secure_storage 9.2.4 | yes | nothing |
   | path_provider_foundation 2.5.1 | yes | nothing |
   | permission_handler_apple 9.4.10 | yes | UserDefaults `1C8F.1` |
   | record_ios 1.2.1 | yes | nothing |
   | integration_test | no | dev dependency, not in release builds |
4. **Usage strings.** Keys in Runner: microphone, local network, Bonjour `_shinsoku-mic._tcp` — all used
   (recording; Nearby desktop discovery). No speech-recognition or other unused keys; permission_handler is
   built with `PERMISSION_MICROPHONE=1` only. The keyboard has no usage keys (it cannot record; the app does).
   Microphone text now says where the audio goes:
   *"Shinsoku records your voice while you dictate and sends it to the speech provider you chose, or to your
   paired computer."* — 10 languages with glossary terms (speech provider, pair, Desktop). Korean local-network
   string moved to 해요체 like the rest of the app. Source is `tool/i18n/native.json` →
   `tool/i18n_native.py`; `docs/i18n/review-zh.md` regenerated (it also picked up a Shortcuts Pro row that was
   missing on main). `ITSAppUsesNonExemptEncryption = NO` unchanged.
5. **Keys.**
   - Repo scan: no `sk-…` strings, no long values next to `api_key`/`apiKey`/`secret`/`token`.
   - Script comparison (values never printed) of every `*_API_KEY` in the main checkout's `.env`
     (`BAILIAN_API_KEY`, `SONIOX_API_KEY`) against the working tree and the full `git log --all -p`: clean.
     `REVIEW_SONIOX_API_KEY` is **not in `.env` yet** (user action 1 in the plan).
   - R04 (lint) passes; the dart-define list in `build_testflight.sh` has no `*_API_KEY`.
   - M06 covers the 1.0 archive (same script), and will include `REVIEW_SONIOX_API_KEY` automatically
     (`*_API_KEY`, only `APPSTORE_*` excluded). **Gap fixed:** the script sources `../.env` relative to
     `mobile/`; from a worktree (no `.env`) it compared nothing and passed. It now refuses to upload when no key
     value was compared. `docs/review_rules.md` M06 text updated to describe the script.

## Checks (at db8ddb3)
- `flutter analyze`: no issues. `python3 tool/review_lint.py`: all ok. `tool/test_diff.sh`: no new failures.
- `flutter build ios --simulator --debug --no-pub`: built; bundle versions/family/manifests/zh-Hans
  InfoPlist.strings checked in the product.
- `tool/ios_keyboard_scene.sh --build-only`: built, both bundles carry the App Group.
- `flutter build ios --release --config-only --no-pub` then `plutil -lint` on both Info.plists: OK.
- Flutter-regenerated tracked files (`AppFrameworkInfo.plist`, `Podfile.lock`, `Runner.xcscheme`) restored
  after each build.

## For the coordinator
- Archive 1.0.0 from the main checkout (it has `.env`); the build number comes from pubspec (`+22` now).
- Tier B/C not run (worker).
