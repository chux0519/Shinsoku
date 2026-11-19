# I1 — implementation notes

Branch `i18n-01-i1-framework`, base `main` @ 146800e. Source state tested: the PR head (see PR).

## What changed
- **Framework:** `flutter_localizations` + `intl ^0.20.2`, `generate: true`, `mobile/l10n.yaml`
  (template `app_en.arb`, output committed under `mobile/lib/l10n/gen/`). `MaterialApp` has the delegates and
  `appSupportedLocales`. `context.l10n` (`lib/l10n/l10n.dart`). `plannedLocaleTags` lists the 10 target locales;
  only `en` has content (the others fall back to English until I5).
- **ARB:** 208 messages, semantic keys (`recordStatusListening`), every one with a `description`, placeholders
  typed, ICU plurals where counts appear (`nearbyDesktopsFound`, `nearbyStreamingGaps`). Dates: Drafts date
  groups use `DateFormat.yMMMMd(locale)`; times still come from `MaterialLocalizations` (it honours the 24-hour
  setting).
- **Extraction:** every string in `features/`, `ui/`, `nearby/`, `app/shell_scaffold.dart` and the product part of
  `app/mobile_shell.dart` is in the ARB. `ui/strings.dart` (`SkStrings`) is deleted. Brand/provider names
  (Shinsoku, Bailian, Soniox, Qwen-ASR) stay literal. `ShellScaffold.tabs` became `tabsFor(l10n)`; `FieldKind.label`
  became `fieldKindLabel(l10n, kind)`; `activeProfileReason` takes `l10n`.
- **Built-in profiles:** `VoiceProfileStore.load()` creates them from the ARB (`localizedDefaultProfiles`) on first
  launch and **saves them right away**, so the names are user data from then on. `defaultVoiceProfiles` (English)
  stays as the seed for tests and the list shown before storage loads. `systemAppLocalizations()` resolves the
  system locale without a `BuildContext`.
- **Error wording (no raw exception text):** `describeFailure(l10n, error)` (`lib/l10n/failure_text.dart`) maps
  timeouts, network errors, missing/invalid key, quota, lost connection, empty result, recorder and microphone
  problems to friendly sentences; the raw error goes to `debugPrint` only. Used by Record failures, snack bars
  (settings save, post-processing, clipboard). Nearby: `NearbyProtocolException` now always has a `code`;
  `NearbyClientStatus` carries `code`/`arg` (`logText` is English for logs); `nearby_text.dart` maps code → ARB.
  Desktop-supplied messages are no longer shown. `NearbyInputException` (manual entry) has a code.
- **Pseudo-locale:** `tool/pseudo_arb.py` generates `app_en_XA.arb` (accents, ~40% longer, `[ … ]`, placeholders
  and ICU syntax untouched). `appSupportedLocales` excludes it, so the app never offers it.
- **Lint R05** (`tool/review_lint.py`) + **rule M10** (`docs/review_rules.md`). Developer-only code is exempt
  between `// i18n-ignore-start` / `// i18n-ignore-end` (the two smoke-test runners in `mobile_shell.dart`); a
  single line can carry `i18n-ignore`.
- **Host review:** `tool/host_review.sh <run> [scenes] [themes] [devices] [locale]`; `pseudo` (or a locale tag)
  writes to `<run>-<locale>`. Every scene already failed on a Flutter overflow exception; under `pseudo` it also
  fails when a localized paragraph hits its line limit (skipped at 200 % text). Scenes build their statuses from
  the locale's strings, so pseudo renders show no English except user data (sample transcripts, profile names).
  Also added `--no-pub` to the script's `flutter test` (rule M09).
- **Tests:** `test/l10n/l10n_test.dart` (ARB descriptions, key/placeholder parity for every `app_*.arb`, pseudo
  longer and bracketed, `describeFailure`, Nearby codes and plurals, localized default profiles, Drafts date
  group). The existing tests got `localizationsDelegates`; assertions look up text through
  `test/support/l10n.dart` (`en`).

## Component changes the pseudo run forced (all in `mobile/lib/ui/`)
- `SkListRow`: a trailing value gets the larger share of the row (title flex 2 : value flex 3) and may use two
  lines ("Desktop automatic" was cut in the narrow Duo pane).
- `SkSegmented` (equal-width): horizontal padding 14 → 10, labels wrap to two lines before they ellipsize
  (the pane switcher cut "Desktop"/"Settings" in the Duo landscape panes). Scrollable lists are unchanged.
Neither changes the English renders noticeably (checked `nearby`, `drafts-list` on the Duo).

## Verification (all on the PR head)
- `flutter analyze`: no issues. `flutter test`: 170 passed (1 skipped, the opt-in host review).
- `python3 tool/review_lint.py`: R01–R05 ok.
- `tool/host_review.sh i18n-01/round-01/i1` (en, 192 images) and `… i1 '' '' '' pseudo` (192 images, no overflow,
  no clipped text).
- `flutter build ios --simulator --debug --no-pub` built; Flutter-regenerated tracked files restored.

## Decisions I made (flag if wrong)
1. Default profiles are persisted on first launch (otherwise "ARB at creation time only" has no creation time).
2. `SmokeTestStatus.label/detail` are strings built when the status is created (not live-updating on a locale
   change mid-session). A running app rarely changes language; a restart refreshes them.
3. Error classification is by exception type and message keywords (provider messages are English and not ours).
   Unknown failures show "Something went wrong. Try again."
4. The `Shinsoku` page header on Record stays a literal (brand).
5. Nearby `nearbyErrorMicDenied` says "Allow it in Settings" without a button (the Desktop page has none today).

## Not done / out of scope
- **RTL-safe layout check** (in the plan's I1 row, not in the task brief): not done. The code uses
  `EdgeInsetsDirectional`/`AlignmentDirectional` in places but I did not audit or render an RTL locale. None of
  the 10 target languages is RTL.
- Native strings (keyboard, App Intents, Info.plist) are I2; native profile names are still published from the
  stored profile names.
- Translations: only English + pseudo.
