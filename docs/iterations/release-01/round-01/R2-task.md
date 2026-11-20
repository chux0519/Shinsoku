# R2 — App Store metadata in 10 languages + push script

Branch `release-01-r2-metadata`, worktree `/Volumes/ZT/repos/Shinsoku-wt/r2-meta`. Model: Opus. Tier A.
Read AGENTS.md, `docs/iterations/release-01/plan.md` (incl. "Keys"), `docs/iterations/pricing-01/plan.md`
(Free vs Pro), `docs/i18n/glossary.md`, `docs/privacy-app/research-20261119.md` (competitors, positioning),
and the app's real features (`mobile/lib`, `DESIGN.md`). Never claim a feature the app does not have.

## Work
1. `docs/store/metadata/<locale>.yaml` for en-US, zh-Hans, zh-Hant, ja, ko, de-DE, fr-FR, es-ES, pt-BR, it:
   `name` (keep "Shinsoku"; ≤30), `subtitle` (≤30), `promotional_text` (≤170), `description` (≤4000, plain text,
   short paragraphs + a few "•" lists), `keywords` (≤100 bytes incl. commas, no spaces after commas, no words
   already in name/subtitle, no competitor names/trademarks), `whats_new` (1.0: first release). Locale-native
   copy (not literal translation); keywords researched per language (what people search for: voice typing,
   dictation, speech to text, voice keyboard, transcription, AI rewrite …). Positioning: fast, accurate voice
   input everywhere you type; bring your own key (Soniox / Bailian / OpenAI-compatible) — you pay the provider
   directly, no subscription; AI clean-up with profiles; keyboard with live preview; drafts; iPhone Duo; Pro
   one-time unlock (custom profiles, per-app switching, Desktop). Say clearly that an API key from a provider
   is required. Simplified Chinese neutral (not mainland-specific; the app is not offered in mainland China).
2. App-level fields in `docs/store/app.yaml`: primary category Productivity, secondary Utilities, copyright
   "2026 Potafree LLC", privacy URL `https://potafree.net/shinsoku/privacy/`, support URL
   `https://potafree.net/shinsoku/support/`, marketing URL `https://potafree.net/products/shinsoku` (check the
   page path in /Volumes/ZT/repos/potafree.net/src/pages), age-rating answers (all "none"; unrestricted web
   access: no), content rights: no third-party content.
3. `tool/store_metadata.py`: `check` (limits, keyword bytes/duplicates, required fields, every locale present,
   no key-like strings) and `push` (dry-run by default; `--apply` PATCHes appInfoLocalizations +
   appStoreVersionLocalizations for the app's version in PREPARE_FOR_SUBMISSION via `tool/asc.py`'s `call`;
   creates missing localizations). **You run only `check` and `push` dry-run** (a GET-only diff against ASC is
   fine, ASC API key is read inside asc.py); the coordinator runs `--apply`.
4. `docs/store/review-zh.md`: table for the user (field → English → zh-Hans → zh-Hant).

## Done when
`python3 tool/store_metadata.py check` passes, dry-run diff printed in the PR description,
`python3 tool/review_lint.py` ok, commit per unit, push, `R2-implementation.md` + STATE.md, PR open. Reply with
the PR URL.
