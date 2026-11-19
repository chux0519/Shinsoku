# i18n-01 round 01 — STATE

## I2 — native strings (branch `i18n-01-i2-native`)
- **Done:** keyboard strings localized (46 keys), App Intents catalog (14 keys), AppShortcuts.strings (3
  phrases), InfoPlist.xcstrings (2 permission texts), 10 known regions, CFBundleLocalizations,
  `tool/check_xcstrings.py` + lint R06 / rule M11. English only. Notes: `I2-implementation.md`.
- **In progress:** nothing; awaiting coordinator review.
- **Next:** I5 fills the 9 other languages (catalog JSON + `<lang>.lproj/AppShortcuts.strings` in the variant
  group); scene match lists need zh-Hans entries (implementation notes §2).
- **Open decisions:** keyboard `PrimaryLanguage` (en-US vs mul / per region) — I3/I5.
- **How to verify:** `cd mobile && perl -e 'alarm shift; exec @ARGV' 900 flutter build ios --simulator --debug
  --no-pub`; `tool/ios_keyboard_scene.sh --build-only`; `python3 tool/review_lint.py`;
  `python3 tool/check_xcstrings.py --stringsdata ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/Runner.build/Debug-iphonesimulator`.
  Restore Flutter-regenerated tracked files (`AppFrameworkInfo.plist`, `Podfile.lock`, `Runner.xcscheme`) after a build.
