# I2 — native strings: implementation notes

Branch `i18n-01-i2-native`, base `main` @ 146800e. Tested source state: the PR head (see STATE.md).

## What changed
- **Keyboard** (`ShinsokuKeyboard/KeyboardViewController.swift`): all 9 status texts, key titles (Insert,
  Record, space), return key titles + VoiceOver labels (new `ReturnKeyTitle`, 10 types), every VoiceOver
  label/hint/value, the profile menu title, the profile custom action ("Use %@") and announcement
  ("Profile %@") use `String(localized:comment:)`. English text is unchanged, so scene tests match as before.
  46 keys in `ShinsokuKeyboard/Localizable.xcstrings`, each with a translator comment.
- **App Intents** (`Runner/ProfileIntents.swift` unchanged — its strings were already
  `LocalizedStringResource` literals): 14 keys in `Runner/Localizable.xcstrings` (titles, descriptions,
  parameter title, parameter summary `Set Shinsoku profile to ${profile}`, dialogs `Shinsoku profile: %@`,
  errors, short titles). `%@` (the profile's display representation = user's name) is `shouldTranslate: false`.
- **App Shortcut phrases**: `Runner/en.lproj/AppShortcuts.strings` (variant group). `AppShortcuts.xcstrings`
  fails the build: "only supported for iOS 17.0 and above" — Runner targets iOS 15. Phrases keep
  `${applicationName}`.
- **Info.plist**: `Runner/InfoPlist.xcstrings` (microphone, local network). `CFBundleAllowMixedLocalizations`
  = YES (system UI follows the user's language even before a locale is filled), `CFBundleLocalizations` lists
  the 10 languages (needed for the per-app Language setting with Flutter). `CFBundleDevelopmentRegion` stays
  `$(DEVELOPMENT_LANGUAGE)` = `en` (checked in the built Info.plist). Display name not localized (brand).
- **Project**: `knownRegions` = en, Base, ja, zh-Hant, ko, de, es, zh-Hans, fr, pt-BR, it;
  `SWIFT_EMIT_LOC_STRINGS = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` (project level). Edited with the
  `xcodeproj` gem; the diff only adds lines.
- **Checker** `tool/check_xcstrings.py` (lint R06, rule M11): English value for every key, source keys present
  in the catalogs, no bare literal to UI sinks, phrases keep `${applicationName}`, Info.plist permission texts
  match, stale keys warned; `--stringsdata <dir>` cross-checks the compiler-extracted keys.

## Verified
- `flutter build ios --simulator --debug --no-pub` ✓; built app has `en.lproj/{Localizable,InfoPlist,
  AppShortcuts}.strings` and `ShinsokuKeyboard.appex/en.lproj/Localizable.strings`.
- `tool/ios_keyboard_scene.sh --build-only` → TEST BUILD SUCCEEDED.
- `python3 tool/review_lint.py` all ok (R06 included); `check_xcstrings.py --stringsdata …` 0 problems.
- Negative test: an injected bare `accessibilityLabel = "Delete"`, an uncatalogued `String(localized:)` and a
  phrase without the app name each fail the checker (exit 1).
- Not run: tier B (simulator), pseudo-locale (optional; not done).

## For I5 / open points
1. **Adding a language to AppShortcuts**: create `Runner/<lang>.lproj/AppShortcuts.strings` *and* add it to the
   `AppShortcuts.strings` variant group in the pbxproj (e.g. `xcodeproj` gem: `vg.new_reference('<lang>.lproj/
   AppShortcuts.strings').name = '<lang>'`). The xcstrings catalogs only need the JSON filled.
2. **Scene tests vs. a translated keyboard**: the shared simulators run in Chinese. Once zh-Hans is filled, the
   keyboard (its own process; Safari's `-AppleLanguages (en)` does not reach it) will likely show Chinese, and
   scene matches like `statusText("Ready")`, `key("Insert latest text")`, `"Profile"` will fail. I5 should add
   the zh-Hans strings to the scenes' match lists (like `SceneTestCase.L`) — needs a tier-B run to confirm.
3. Keyboard `PrimaryLanguage` is `en-US` (the keyboard's input language in Settings). Whether it should be `mul`
   or vary by region is an I3/I5 decision; untouched here.
4. `AppDelegate` `FlutterError` messages ("Bad profile list." …) are developer-facing, not localized; the Dart
   side (I1) must map error codes to its own ARB strings, never show `message`.
5. Xcode IDE builds may rewrite catalog formatting/comments when syncing; that is expected, not a regression.
