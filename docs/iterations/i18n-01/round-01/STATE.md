# i18n-01 round 01 — STATE

## I1 — Flutter localisation framework (implementer, 2026-11-19)
- Done: gen-l10n + `app_en.arb` (208 messages), all UI strings extracted, friendly error mapping (no raw
  exception text), pseudo-locale (`tool/pseudo_arb.py`), lint R05 + rule M10, host review `locale` dimension
  with clipped-text check, l10n tests. Details: `I1-implementation.md`.
- In progress: none. Next: coordinator review of the diff and the en/pseudo renders; then I2 (native strings),
  I3 (region defaults) in parallel.
- Open decisions: see `I1-implementation.md` §Decisions (default profiles persisted on first launch; RTL check
  not done).
- Verify: `cd mobile && flutter analyze && flutter test`; `python3 tool/review_lint.py`;
  `tool/host_review.sh i18n-01/round-01/i1` and `tool/host_review.sh i18n-01/round-01/i1 '' '' '' pseudo`.

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

## I3 — region defaults (branch `i18n-01-i3-region`)
- **Done:** `regionDefaultsFor` (Fun-ASR for Chinese incl. Cantonese, Soniox elsewhere; per-provider language
  hints; translation profile from the device language), hints sent to Soniox / Fun-ASR, first-launch-only
  applier with `region_defaults.v1` marker, invariants R1–R3 + unit/model tests, Settings save keeps hints.
  Provider findings with sources: `I3-implementation.md`.
- **In progress:** nothing; awaiting coordinator review.
- **Next:** I5 translates the 16 new profile messages; I4/I5 decide keyboard `PrimaryLanguage` (recommend `mul`).
- **Open decisions:** Bailian endpoint for non-mainland users (intl), hints visible in Settings, pre-I1 installs
  without settings count as fresh — `I3-implementation.md` §Open decisions.
- **How to verify:** `cd mobile && flutter analyze && flutter test test/services/region_defaults_test.dart
  test/model/region_model_test.dart test/features/settings_save_test.dart`; `SHINSOKU_MODEL_SEEDS=1000` for a long
  model run; `tool/test_diff.sh`; `python3 tool/review_lint.py`;
  `tool/host_review.sh i18n-01/round-01/i3 record-idle,record-result,record-listening-live,settings [… pseudo]`.

## I4 — ready-made App Shortcuts per profile (branch `i18n-01-i4-shortcuts`)
- **Done:** parameterized phrases "Switch Shinsoku to ${profile}" / "Use ${profile} in Shinsoku" on the Set
  shortcut (first, so Shortcuts shows one tile per profile); `updateAppShortcutParameters()` on launch and when
  the published profile list changes; phrases in `en.lproj/AppShortcuts.strings` (key form verified against
  the compiler-extracted stringsdata); one ARB line on Use in apps. Notes: `I4-implementation.md`.
- **In progress:** nothing; awaiting coordinator review.
- **Next:** coordinator tier B (scene note in `I4-implementation.md`); I5 translates the two phrases and
  `useInAppsReadyMade`.
- **Open decisions:** none.
- **How to verify:** same commands as I2 above, plus `tool/host_review.sh i18n-01/round-01/i4 use-in-apps`
  (and `... '' '' pseudo`).
