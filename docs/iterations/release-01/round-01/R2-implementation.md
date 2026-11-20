# R2 — implementation notes (App Store metadata)

Branch `release-01-r2-metadata`. Tier A only; nothing was written to App Store Connect.

## What is in
- `docs/store/metadata/<locale>.yaml` × 10 (en-US, zh-Hans, zh-Hant, ja, ko, de-DE, fr-FR, es-ES, pt-BR, it):
  name, subtitle, promotional_text, description, keywords, whats_new. Locale-native copy, glossary terms
  (模式/プロファイル/…; Apple names for Settings paths, Allow Full Access, Family Sharing, Shortcuts; Bailian
  untranslated; fr "Dicter" for Record).
- `docs/store/app.yaml`: Productivity / Utilities, "2026 Potafree LLC", privacy/support/marketing URLs,
  content rights (no third-party content), release type MANUAL, version 1.0.0, age-rating answers (all NONE /
  false; read from the live declaration's attribute list).
- `tool/store_metadata.py`: `check`, `push` (dry run; `--apply` writes), `review-zh`. Stdlib only — PyYAML is
  not installed and the global toolchain is not changed, so it parses the small YAML subset the files use.
- `docs/store/review-zh.md` (generated) for the user's Chinese review.
- Lint R08 runs the check; rule added to `docs/review_rules.md`.

## Claims checked against the code
- Providers: speech = Soniox or Bailian (`provider_settings.dart`); AI post-processing uses the Bailian key
  against an OpenAI-compatible base URL (`transcription_service.dart`), so the copy says clean-up/translation
  need Bailian or another OpenAI-compatible service. With only a Soniox key there is no clean-up.
- Keyboard: the Record key **opens the app** to record; Insert puts the latest text in (needs Full Access).
  There is no live preview inside the keyboard, so the copy puts "live text" in the app and describes the
  keyboard as "tap Record, speak, insert". The keyboard extension has no URLSession code → "sends nothing over
  the network".
- Keys in flutter_secure_storage (Keychain); no analytics/crash SDK in pubspec → "no ads, no analytics".
- Free vs Pro as in pricing-01 (custom profiles; field rules + Shortcuts Set Profile; Desktop). Desktop =
  "Shinsoku on your Mac or PC" (GitHub release has macOS, Windows, Linux builds).
- Languages: "Soniox recognizes dozens of languages" (no exact number claimed).

## check rules
Required fields; name == "Shinsoku"; name/subtitle ≤30, promo ≤170, description/whats_new ≤4000 chars;
keywords ≤100 **UTF-8 bytes** (stricter than Apple's character count, so CJK lists are short), no spaces at
commas, no empty/duplicate items, no item already in name/subtitle (Latin: word set; CJK: substring), no
trademark / other product / provider names; no HTML in the description; no key-like strings and none of the
`*_API_KEY` values from the environment, the worktree `.env` or the main checkout's `.env` (values never
printed). Negative test: `TEST_API_KEY="Potafree LLC" python3 tool/store_metadata.py check` fails on app.yaml.

## push
GETs the app by bundle id, the editable appInfo and appStoreVersion (PREPARE_FOR_SUBMISSION and the rejected
states), diffs and prints. `--apply` PATCHes changed fields, POSTs missing localizations, sets categories,
content rights, age rating, version string/copyright/release type. **What's New is not sent for the first
version** (ASC rejects it); it stays in the YAML for 1.1.

## Notes for the coordinator
- ASC still has the version as **0.1.0**; `push --apply` renames it to 1.0.0 (from app.yaml).
- Age rating: `datingAndRelationships`, `sharedLocation`, `socialMedia`, `socialMediaAgeRestricted` are new
  ASC attributes; I sent them as booleans. If `--apply` returns 409 on the age-rating PATCH, the error detail
  names the field and its expected type — fix app.yaml and rerun (the rest is independent).
- Name is plain "Shinsoku" in every locale (task: keep it). Adding a keyword to the name ("Shinsoku: Voice
  Keyboard") would rank better; that is the user's call.
