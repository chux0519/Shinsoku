# I5 — translations (9 languages) + glossary

Branch `i18n-01-i5-translations`, worktree `/Volumes/ZT/repos/Shinsoku-wt/i5-translations`, base `main` @ be545f7
(I1–I4 merged). Model: Opus (translation quality, CJK). Read AGENTS.md, `docs/iterations/i18n-01/plan.md`, and
`I1/I2/I3/I4-implementation.md` (each has "For I5" notes) first.

Languages: ja, zh-Hant, ko, de, es, zh-Hans, fr, pt-BR, it (English exists).

## Work
1. **Glossary first**: `docs/i18n/glossary.md` — one table: English term → each language (Shinsoku stays
   untranslated; profile, field rule, draft, insert, record, post-processing, keyboard, Full Access (use Apple's
   own wording in each language for iOS settings names: "Allow Full Access", "Keyboards", Settings paths),
   Shortcuts / App Shortcuts (Apple's name per language), provider names untranslated). Tone: short, plain,
   friendly, like Apple's own UI; zh-Hant uses Taiwan wording by default (HK falls back to it); zh-Hans is for
   Singapore/Malaysia/overseas readers, mainland-neutral wording.
2. **Flutter**: `mobile/lib/l10n/app_<tag>.arb` for each language (ARB tags: `ja`, `zh_Hant`, `ko`, `de`, `es`,
   `zh_Hans` (plus a plain `zh` fallback = zh_Hans if gen-l10n needs it), `fr`, `pt_BR` (plus `pt` = pt_BR),
   `it`); every key, ICU plurals correct per language; placeholders kept. Remove the "until then it falls back"
   comment in `l10n.dart` if it no longer holds. Check the default profile names/prompts (I3) and the I4
   Use-in-apps line (its quoted phrase must match the translated App Shortcut phrase).
3. **Native**: fill all 9 languages in `ShinsokuKeyboard/Localizable.xcstrings`, `Runner/Localizable.xcstrings`,
   `Runner/InfoPlist.xcstrings` (state `translated`); add `Runner/<lang>.lproj/AppShortcuts.strings` for each
   language and register each in the `AppShortcuts.strings` variant group (I2 notes §1; xcodeproj gem). Phrases
   keep `${applicationName}` / `${profile}`; Siri phrase rules: natural for the language, short.
4. **Scene tests** (`mobile/ios/KeyboardSceneTests/`): the shared simulators run in Chinese, so the keyboard
   will now show zh-Hans. Add zh-Hans (and keep English) labels to the match lists (`SceneTestCase.L` or
   equivalent) wherever a keyboard / Shortcuts string is matched. Build-only check; the coordinator runs tier B.
5. **Checks**: `tool/check_xcstrings.py` — extend it (or a new R-rule) so every catalog key has a value in all
   10 languages and placeholders (%@, %lld, ${…}) match the English ones; same for ARB (placeholders and
   plural forms match). Add to `review_lint.py`.
6. **Renders**: `tool/host_review.sh i18n-01/round-01/i5-<tag> '' '' '' <tag>` (or whatever the I1 locale dimension
   takes) for ja and de at least — confirm no overflow; list any string that had to be shortened.
7. **Review package for the user**: `docs/i18n/review-zh.md` — a two-column table (English → zh-Hans → zh-Hant)
   of every user-visible string, grouped by screen, so the user can review Chinese in one place.

## Done when
`flutter analyze`, `tool/test_diff.sh`, `python3 tool/review_lint.py`, `flutter build ios --simulator --debug
--no-pub` (under `perl -e 'alarm shift; exec @ARGV' 900`), `tool/ios_keyboard_scene.sh --build-only` pass; restore
Flutter-regenerated tracked files before committing; commit per language group and push as you go;
`I5-implementation.md` + STATE.md; PR open. Reply with the PR URL.
