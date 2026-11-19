# I2 — native strings: keyboard extension, App Intents, Info.plist (English base + localisation plumbing)

Implementer brief. Read AGENTS.md, `docs/iterations/i18n-01/plan.md`. Branch `i18n-01-i2-native`. Files:
`mobile/ios/ShinsokuKeyboard/**`, `mobile/ios/Runner/**` (Swift + string catalogs + Info.plist),
`mobile/ios/Runner.xcodeproj` (known regions, catalog membership), `mobile/ios/KeyboardSceneTests/**` (only
to keep tests passing). I1 works on `mobile/lib/**` in parallel — don't touch it. No simulators, no nested
agents, no merging. No `flutter pub get` without a time limit (M09).

1. String Catalogs (`.xcstrings`, Xcode 27.2): `Localizable.xcstrings` in the keyboard target (every user-facing
   string: status texts, key titles, VoiceOver labels/hints, Full Access hint, profile menu title, lock
   explanation, return key titles that we set ourselves); `AppShortcuts.xcstrings` + `Localizable.xcstrings` in
   Runner for App Intents (titles, descriptions, parameter titles, dialogs, errors, App Shortcut phrases and
   short titles); `InfoPlist.xcstrings` for permission texts (microphone etc.) and display name if needed.
   English values only now; I5 adds the other 9 locales.
2. Add the 10 known regions to the project (en, ja, zh-Hant, ko, de, es, zh-Hans, fr, pt-BR, it) so I5 only
   fills catalogs. `CFBundleDevelopmentRegion` en; `CFBundleAllowMixedLocalizations` as appropriate.
3. Use `String(localized:)` / `LocalizedStringResource` correctly for App Intents (phrases must keep
   `\(.applicationName)`; parameterized phrases later in I4).
4. Scene tests keep matching English labels (they launch apps with English args) — they must still build;
   don't change behaviour.
5. A pseudo-locale check: build with `-AppleLanguages (en-XA)` style accented English is optional; at minimum
   a script `tool/check_xcstrings.py` that fails if a catalog key lacks an English value or a Swift literal
   user-facing string is not localized (R06; rule M11).

Verify: build keyboard + Runner (`cd mobile && perl -e 'alarm shift; exec @ARGV' 900 flutter build ios --simulator
--debug --no-pub`), `tool/ios_keyboard_scene.sh --build-only`, `python3 tool/review_lint.py`, the new checker;
restore Flutter-regenerated tracked files before commit. Commit per unit, push, PR, `I2-implementation.md` +
STATE.md section, reply with PR URL. Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh
via `env -u https_proxy -u http_proxy -u all_proxy gh`.
