# Iteration i18n-01 — multiple languages and regions

Status: **confirmed by the user 2026-11-19**. Market research: `docs/market/research-20261119.md`. Base: `main` @ 61d4233 (TestFlight 0.1.0 (21)).

## User decisions so far (2026-11-19)
- Languages (all in this iteration): en, ja, zh-Hant, ko, de, es, zh-Hans, fr, pt-BR, it.
- Screenshot review: **sample, don't review every locale** — full review for en + one CJK (ja) + one long
  European (de); for the others, a pseudo-locale run plus spot checks of the densest screens (Settings, Use in
  apps, keyboard). Automated overflow checks run for every locale.
- China mainland storefront: **never** (user decision). zh-Hans targets Singapore/Malaysia/overseas Chinese.
- Regions differ by: default provider, default profiles, ASR language hint (not only UI text).
- Translation: model-translated with one glossary; the user reviews Chinese; other languages spot-checked
  before store submission.
- Website Shortcuts guide: separate iteration after i18n-01. App-provided ready-made Shortcuts per profile go
  into i18n-01 (their titles need translating anyway).
- Pricing: **out of scope here, still undecided.** Leaning: a low-price paid version first; later maybe Free + Pro
  (free users bring their own key or use Apple's on-device speech engine; Pro unlocks advanced features).
  i18n-01 must not hard-code anything that blocks either model.

## Scope
| # | Unit | Notes |
|---|---|---|
| I1 | Flutter localisation framework: `flutter_localizations` + ARB (`gen-l10n`), move every user-facing string (incl. live-01's string table, error wording — no raw "Bad state: …"), plural/number/date formatting, RTL-safe layout check | lint rule: no literal user-facing strings outside ARB |
| I2 | Native strings: keyboard extension (`Localizable.xcstrings`), App Intents titles/descriptions/dialogs/phrases (`AppShortcuts.xcstrings`), Info.plist permission texts (`InfoPlist.xcstrings`) | Shortcuts action names searchable in each language |
| I3 | Region profile: locale/region → default provider (Fun-ASR for zh-Hant/zh-Hans regions incl. Cantonese; Soniox elsewhere), default profiles (e.g. 中→英, 日→英, 한→영, X→EN), ASR language hints per provider; first-launch only, never overrides user settings | invariant: user settings always win; Fun-ASR realtime language coverage per snapshot must be verified before defaulting non-Chinese locales to it |
| I4 | Ready-made App Shortcuts per profile ("Switch Shinsoku to Chat") | localized phrases |
| I5 | Translations + glossary (model), Chinese review by the user, pseudo-locale and longest-language renders (de/ja) | tier A renders per locale |

## Acceptance
- Every locale renders every screen with no overflow (automated check); pseudo-locale catches unextracted
  strings; visual review is sampled per the decision above (en, ja, de in full; others spot-checked).
- Tier B: keyboard + Shortcuts in zh-Hans and ja on the simulator (system language switch per run).
- The user signs off the Chinese wording.
