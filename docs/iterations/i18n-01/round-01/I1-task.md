# I1 — Flutter localisation framework + string extraction (English only in this unit)

Implementer brief. Read AGENTS.md, DESIGN.md, `docs/iterations/i18n-01/plan.md`. Branch
`i18n-01-i1-framework`. Files: `mobile/lib/**`, `mobile/l10n.yaml`, `mobile/lib/l10n/**`, `mobile/pubspec.yaml`
(add `flutter_localizations` + `intl`, `generate: true`), `mobile/test/**`, `tool/review_lint.py`,
`docs/review_rules.md`, host-review harness. Not `mobile/ios/**` (I2). No simulators, no nested agents, no
merging. **Never run `flutter pub get` without a time limit** (rule M09): `perl -e 'alarm shift; exec @ARGV' 600
flutter pub get`.

1. gen-l10n with `app_en.arb` as the template (descriptions + placeholders for every message; ICU plurals where
   counts appear; dates via `intl` DateFormat with the locale, e.g. Drafts' date groups). Keys are semantic
   (`recordStatusListening`), not English text.
2. Move every user-facing string in `mobile/lib/**` into the ARB: screens, components, status/reason lines,
   errors, snackbars, Semantics labels, the live-01 string table (`mobile/lib/ui/strings.dart` → delete or make
   it a thin accessor). Profile names that are user data stay as data; the built-in default profiles' names come
   from the ARB at creation time only.
3. Error wording: no raw exception text in the UI (e.g. "Bad state: Soniox connection closed…"). Map known
   failures to friendly messages (connection lost, key missing/invalid, quota, network, microphone) with the raw
   detail only in logs.
4. Supported locales list prepared for the 10 locales (en, ja, zh-Hant, ko, de, es, zh-Hans, fr, pt-BR, it) but
   only `app_en.arb` has content in this unit; add a **pseudo-locale** (e.g. `en-XA` style generated ARB with
   accented, ~40% longer strings) used only by tests/host renders, to catch unextracted strings and overflow.
5. Lint R05: no literal user-facing string in `Text(`/`SkButton(label:`/`SnackBar`/Semantics label etc. under
   `mobile/lib/features/**` and `mobile/lib/ui/**` (allowlist for punctuation/brand "Shinsoku"); rule M10 in
   review_rules.md.
6. Host review: a `locale` dimension in `tool/host_review.sh` (default en; `pseudo`), with an automated overflow
   check (fail on RenderFlex overflow / text clipped) for every scene.

Verify: analyze, test_diff (existing tests may need `localizationsDelegates` in test harness — update helpers,
not assertions' meaning), lint incl. R05, renders en + pseudo (`tool/host_review.sh i18n-01/round-01/i1`),
`flutter build ios --simulator --debug --no-pub` (restore Flutter-regenerated tracked files). Commit per unit,
push, PR, `I1-implementation.md` + STATE.md, reply with PR URL. Model: sonnet (mechanical extraction; ask the
coordinator if a wording decision is needed). Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via
`env -u https_proxy -u http_proxy -u all_proxy gh`.
