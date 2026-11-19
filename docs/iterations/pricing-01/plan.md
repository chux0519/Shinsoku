# Iteration pricing-01 — Shinsoku Pro (one-time unlock)

Status: **confirmed by the user 2026-11-19** (gates, price, IAP setup chosen in chat). Base: `main` after
i18n-01 I1–I4. Goal: the paywall is in, so the next version can go to the App Store.

## Decisions (user, 2026-11-19)
- Model: free download + **Shinsoku Pro**, a one-time non-consumable IAP, Family Sharing on, no trial.
- Price: **$6.99, launch $4.99** (set $4.99 first; raise later with a scheduled price change).
- **Always free:** speech recognition with the user's own key (Soniox / Bailian / OpenAI-compatible), the
  keyboard, live preview, drafts, the 4 built-in profiles with AI post-processing, manual profile switching.
- **Pro:** (1) custom profiles — creating profiles and editing any profile's prompt/settings; (2) per-app
  automatic switching — field rules and Shortcuts profile switching (Set Shinsoku Profile, the ready-made
  per-profile actions; Get stays free); (3) Desktop (Nearby).
- IAP `net.potafree.shinsoku.pro` is created by the coordinator through the App Store Connect API.
  User prerequisites: Paid Apps agreement, tax and banking active.

## Behaviour
- Locked features stay visible with a small "Pro" mark; tapping opens the Pro sheet (what Pro adds, the
  localized StoreKit price, Buy, Restore Purchases). Settings has a "Shinsoku Pro" row (status, buy, restore).
- Shortcuts Set Profile without Pro: the intent does nothing and answers with a dialog "Switching profiles from
  Shortcuts needs Shinsoku Pro" (opens nothing, never throws a raw error).
- Keyboard: field rules apply only with Pro; manual switching stays free.
- Losing Pro (refund, Family Sharing removed) never deletes data: custom profiles and field rules stay stored;
  custom profiles stay selectable but not editable; field rules and Shortcuts switching stop applying.

## Invariants (to add as E1–E4)
- **E1 A purchase is never lost:** Pro comes from StoreKit's verified transactions; offline or on a StoreKit
  error the last known state (App Group mirror) holds — errors never downgrade.
- **E2 Revocation removes Pro** at the next transaction update (refund, revoked Family Sharing).
- **E3 Downgrade never deletes or rewrites user data** (profiles, field rules, drafts).
- **E4 One source of truth:** the app, keyboard and App Intents read the same App Group mirror
  (`pro.v1`), written only by the app's StoreKit service.

## Work units
| # | Unit | Files | Model | Tier |
|---|---|---|---|---|
| S1 | Dart: `ProEntitlement` (ValueListenable, fake + channel impl), Pro sheet component, gates in profile editor, field rules, Use in apps, Nearby; Settings Pro row; ARB (English); renders | `mobile/lib/` | Opus | A |
| S2 | Native: StoreKit 2 service in Runner (products, purchase, restore = `AppStore.sync`, `Transaction.updates`, `currentEntitlements`), channel `net.potafree.shinsoku/store`, App Group mirror `pro.v1`, keyboard field-rule gate, Set Profile intent gate, `Shinsoku.storekit` config wired into the scheme for local tests | `mobile/ios/` | Opus | A + build |
| S3 | Wire S1↔S2, E1–E4 in `state_invariants.md` + model test, translations of the new strings (9 languages, glossary), scene: StoreKit test purchase → field rule applies; revoke → stops | `mobile/`, `KeyboardSceneTests/` | Opus | B |

Order: S1 now (I5 is still running, Dart only); S2 after I5 merges (both touch the Xcode project); S3 last.
Coordinator: create the IAP + localizations + review screenshot via the ASC API; TestFlight build with
sandbox purchase (asks the user before upload).

## Acceptance
- Tier A: analyze, lint, test diff; renders of the Pro sheet, locked rows and Settings Pro row (iPhone + Duo,
  light/dark, en + pseudo + ja + de); model test E1–E4 with seeds.
- Tier B (iPhone 17): StoreKit-config purchase → Pro row shows owned; field rule applies in the keyboard;
  Shortcuts Set Profile works; revoke in the StoreKit transaction manager → field rule stops, data intact.
- Pending C: real sandbox purchase on TestFlight (the user).

## After this iteration (release-01, separate plan)
App Store submission: screenshots per language, description/keywords, privacy label, EU Trader declaration
(user), review notes (BYO key: give reviewers a demo key via App Review notes, read from a script, never in
the repo), version 1.0.
