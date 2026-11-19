# Iteration release-01 — Shinsoku 1.0 on the App Store

Status: **draft, waiting for the user's confirmation.** Base: `main` after pricing-01 (TestFlight 22, sandbox
purchase passed). Goal: version 1.0.0 submitted for review with the Shinsoku Pro IAP.

## Decisions (user, 2026-11-19)
- **iPhone only** for 1.0 (`TARGETED_DEVICE_FAMILY = 1`); iPad later as its own iteration.
- **Version 1.0.0** (pubspec and the App Store version; build numbers continue from 23).
- **Privacy policy / support:** the user's own site, `https://potafree.net/shinsoku/privacy/` and
  `https://potafree.net/shinsoku/support/`, in the `potafree.net` repo next to the Shinphony / POTASMS pages.
- **Review key:** a dedicated low-quota Soniox key, created by the user, in `.env` as `REVIEW_SONIOX_API_KEY`.
- **Never leak the user's key (user, 2026-11-19):** see "Keys" below.

## Keys (hard rules for this iteration)
- No API key in the app binary: R04 (no `*_API_KEY` dart-define) and M06 (the TestFlight script refuses to
  upload when any `*_API_KEY` value from the environment or `.env` is found inside the IPA). The 1.0 archive
  goes through the same script.
- The review key goes only into App Review notes (visible to Apple only), sent by a script that reads `.env`;
  it is never printed, logged, committed, put in screenshots, the description, or the website.
- Never the user's personal Bailian/Soniox keys: only `REVIEW_SONIOX_API_KEY`. After approval the user revokes
  it (or keeps it at a low quota).
- Screenshots: key fields show the empty or masked state only; fixture data uses `example-*` hosts.
- Before submission: grep the repo, the IPA and the generated metadata for each `*_API_KEY` value (script,
  values never printed).

## Work units
| # | Unit | Where | Model | Tier |
|---|---|---|---|---|
| R1 | iPhone-only (`TARGETED_DEVICE_FAMILY = 1`, app + keyboard), version 1.0.0, check `Info.plist` usage strings and `PrivacyInfo.xcprivacy` (required-reason APIs) for app + keyboard | `mobile/ios` | Opus | A + build |
| R2 | Store metadata in 10 languages: name, subtitle, description, keywords, promotional text, what's new; category Productivity (secondary Utilities); age rating; copyright "Potafree LLC"; glossary-consistent | `docs/store/` (YAML) + `tool/asc_metadata.py` | Opus | A |
| R3 | Screenshots 6.9" (1320×2868), 10 languages: Record with live text, keyboard in a chat app, profiles, field rules (Pro), Desktop; host renders framed with a caption line, plus keyboard frames from the simulator scene | `tool/`, `mobile/test/host_review` | Opus | A (+ B for the keyboard) |
| R4 | Website: `potafree.net/shinsoku/privacy` and `/support` (10 languages), from the Shinphony pages; deploy needs the user's OK | `potafree.net` repo | Sonnet | A |
| R5 | Coordinator: privacy label via ASC (data not collected by the developer; audio and text go directly to the provider the user chose, with the user's own key), review notes with the review key (script), IAP attached to the version, price $4.99, availability without CHN, manual release after approval; archive 1.0.0 (23) with the M06 check | ASC | — | C |

Order: R1 + R4 in parallel; R2 then R3 (captions use the metadata wording); R5 last.

## Acceptance
- Tier A: analyze, lint, test diff; metadata YAML passes length limits (name 30, subtitle 30, keywords 100,
  promo 170) in every language; screenshots 1320×2868, no clipped text, no key visible.
- Tier B: keyboard screenshots on iPhone 17 (en, zh-Hans, ja).
- Tier C (before submit): full matrix once (iPhone light/dark, iPhone Duo folded/unfolded) per AGENTS.md;
  TestFlight 1.0.0 (23) installed by the user; key leak check passes.
- **Asks the user before:** the website deploy, the TestFlight upload, the submission for review, and the
  release after approval.

## User actions
1. Create the review Soniox key (low quota) and add `REVIEW_SONIOX_API_KEY=` to `.env`.
2. Review the Chinese metadata and the website text (tables like `docs/i18n/review-zh.md`).
