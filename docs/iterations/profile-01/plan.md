# Iteration profile-01 — a different profile for each app (iOS)

Status: **awaiting user confirmation** (2026-11-19). Base: `main` @ e17734e (TestFlight 0.1.0 (19)).

## Goal
When the user dictates in Slack, Shinsoku uses "Chat"; in Mail, "Review"; in a translation app, "ZH → EN" —
without picking it each time.

## The iOS constraint
A third-party keyboard cannot learn which app hosts it (no public API; private ways fail App Review). So we do
not detect the app. We use three sources, highest priority first:

1. **Manual choice in the keyboard** — tap the profile name in the keyboard status row to switch. It applies
   until the next automation event (2) or until the user picks again.
2. **Shortcuts automation (the "per-app" mechanism)** — Shinsoku ships an App Intent **"Set Shinsoku
   Profile"** (plus "Get Shinsoku Profile"). The user creates a personal automation in Shortcuts: *When
   Slack is opened → Set Shinsoku Profile: Chat* (Run Immediately, no notification). This is the
   system-supported way to react to the foreground app.
3. **Field-type rule (optional)** — the keyboard sees the field's keyboard type / content type / return key
   (search, URL, email, message…). Settings can map a field kind to a profile; used when nothing in 1–2 is
   newer.
4. **Default profile.**

The active profile lives in the App Group (`group.net.potafree.shinsoku`), so the app, the keyboard and the
App Intent agree. Recording in the app reads it at start.

## Work units
| # | Unit | Files | Model | Tier |
|---|---|---|---|---|
| P0 | **Release blocker (user decision 2026-11-19): no API keys in the app binary.** Remove `BAILIAN_API_KEY` / `SONIOX_API_KEY` from `build_testflight.sh` dart-defines and from the `String.fromEnvironment` defaults in `provider_settings.dart` / `smoke_test.dart` (smoke tests read keys from the test environment only). The app already shows "Provider settings required" with an Open Settings fix when no key is saved. Add lint R04 (no `*_API_KEY` dart-define or `fromEnvironment` key in `mobile/lib` / release scripts) and review rule M06. Note for TestFlight users: keys must be entered once in Settings | `mobile/scripts/`, `mobile/lib/services/`, `tool/review_lint.py` | sonnet | A |
| P1 | Shared profile store: profile list (no secrets) + active selection `{profileId, source, at}` mirrored to the App Group via the existing channel registration point; Dart stays the owner; keys stay in the keychain. Migration from the current secure-storage list | `mobile/lib/services/`, `mobile/ios/Runner/` | Opus | A |
| P2 | App Intents (iOS 16+, guarded; app min stays iOS 15): `SetProfileIntent`, `GetProfileIntent`, `ProfileEntity` query reading the App Group; `AppShortcutsProvider` phrases | `mobile/ios/Runner/` (Swift) | Opus | A + B |
| P3 | Keyboard: profile name in the status row, tap to cycle / long-press list; field-kind detection; reads/writes the active selection | `mobile/ios/ShinsokuKeyboard/` | Opus | B |
| P4 | Flutter UI: Settings › Profiles › "Use in apps" guide (steps to create the Shortcuts automation, one "Open Shortcuts" action), field-kind rules, Record shows which profile is active and why ("Set by Shortcuts · Slack" is not knowable — show "Set by automation") | `mobile/lib/features/` | sonnet | A |
| P5 | Invariants + model test: precedence and freshness rules (PR1–PR4 below) with seeded random event sequences (automation set, manual pick, field change, app record start, app relaunch) | `docs/design/state_invariants.md`, `mobile/test/` | Opus | A |

Order: P0 ‖ P1 → (P2 ‖ P5) → (P3 ‖ P4). At most two workers at a time.

### Invariants (draft)
- **PR1** Recording uses exactly the profile that the keyboard shows at the moment Record is tapped.
- **PR2** A newer event wins: automation set and manual pick are ordered by timestamp; a field rule never
  overrides a manual pick or an automation set made after the keyboard appeared.
- **PR3** Deleting or renaming a profile never leaves the active selection pointing at a missing id (falls
  back to default, keyboard shows it).
- **PR4** Without Full Access the keyboard still shows the last known profile read-only and says why it can't
  switch.

## Acceptance criteria
- Tier A: analyze, lint, test diff clean; P5 model test with fixed seeds in CI; renders for the new Settings
  screens (iphone + duo, dark/light).
- Tier B (iPhone 17): run "Set Shinsoku Profile: Chat" from the Shortcuts app (XCUITest drives Shortcuts) →
  keyboard shows Chat → Record deep link starts with Chat; manual switch in the keyboard → app uses it; field
  rule applies in a Safari search field. Evidence under `build/ui-review/profile-01/round-01/`.
- Pending C (device): the Shortcuts *App opened* automation trigger itself (not reliably available in the
  simulator).

## Out of scope
Desktop (Qt is frozen; it already has foreground-app rules), Android, new profile fields, syncing profiles
across devices.

## Needs from the user
- Confirm the approach (Shortcuts automation as the per-app mechanism + manual + optional field rules).
- Confirm the precedence (manual > automation > field rule > default, newest event wins between manual and
  automation).
