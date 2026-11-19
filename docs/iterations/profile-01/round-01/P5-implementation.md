# profile-01 P5 — model test for the active profile (PR1–PR4)

Branch `profile-01-p5-model`. Model: Opus.

## What
- `mobile/test/model/harness.dart`: Dart port of `tool/model_check.py` (seeded sequences, every invariant
  after every event, chunk-then-single shrinking, failure printed as a Dart case for `regressions_test.dart`).
- `mobile/test/model/profile_world.dart`:
  - Events: AutomationSet, ManualPick (keyboard when up, else the app), KeyboardAppear(fieldKind),
    KeyboardDisappear, RecordStart (keyboard when up, else the app), RecordStop, ProfileDelete,
    ProfileRename, ProfileAdd (the app then picks it, as MobileShell does), AppRelaunch (new store + sync from
    the mirrored group), FullAccess(on|off), ClockSkew(app|intent|keyboard, ±2000 ms). Real time in ms.
  - `RefModel`: independent precedence by real (sequence) order; never reads writers' clocks or calls
    resolveActive.
  - `ProfileSystem`: real `ActiveProfileStore` + `resolveActive` + `profileForRecordStart` over a fake App
    Group; App Intent and keyboard are stand-ins following the P1 contract (that is also the contract P2/P3
    must implement: see below).
  - Invariants PR1 (record = what the keyboard showed; captured profile unchanged until stop), PR2 (stored
    selection = newest explicit event; keyboard display = model incl. field rules), PR3 (stored id and the
    group list match the app; keyboard shows an existing id with its current name), PR4 (no Full Access →
    last known profile, read-only reason, picks don't write).
- `profile_model_test.dart`: 7 fixed seeds × 200 events (< 1 s; ~6 s with compile). `SHINSOKU_MODEL_SEEDS=3000`
  passed (34 s). Mutation checks: four broken systems (re-resolve during recording, no field rules, no PR3
  repair, forgotten last profile) are each caught by the right rule.
- `regressions_test.dart`: 6 named cases + 2 unit tests for `profileForRecordStart`.

## Bugs found and fixed (product code)
1. **PR1, keyboard → app handoff.** Record in the keyboard opened `shinsoku://dictation` and the app
   re-resolved the group, without the keyboard's field rule or (no Full Access) its stale profile. Shrunk:
   `FullAccess(false) → AutomationSet(review) → KeyboardAppear → RecordStart` recorded Review while the keyboard
   showed Dictation. Fix: `profileForRecordStart` in `active_profile.dart`; `MobileShell` reads
   `?profile=<id>` from the deep link (falls back to the selection if that profile was deleted).
2. **PR2, clock skew.** The field-rule check compared `selection.at` (writer's clock) with
   `keyboardAppearedAt` (keyboard's clock). With the keyboard 1.8 s behind, an automation 1.1 s *before* the
   keyboard appeared looked newer and suppressed the search-field rule. Fix: optional
   `selectionAtKeyboardAppear` on `resolveActive` — "newer than the keyboard" = "differs from the selection
   the keyboard read when it appeared". Timestamps stay as the fallback when it's not given (P1 tests
   unchanged).

## Notes for P2 / P3
- P3 keyboard: on appear store `appearedAt` and the decoded `activeProfile.v1`; resolve with both; re-resolve
  when the group changes; cache the last shown profile (id + name) for read-only mode; open
  `shinsoku://dictation?profile=<shown id>`.
- P2 intent: only set ids listed in `profiles.v1`.

## Open decisions
- The skew fix matters only if writers' clocks disagree (on one device they share a clock, except for clock
  changes mid-session). Kept because the brief puts ±2 s skew in scope; drop by reverting the
  `selectionAtKeyboardAppear` branch if unwanted.
- P1's open decision (automation fired before the keyboard appeared loses to a field rule) is unchanged; the
  model encodes the current rule.

## Verification (source state 3f05dd2 + docs)
- `flutter analyze`: no issues. `tool/test_diff.sh`: no new failures (0 known). `review_lint.py`: R01–R04 ok.
- Not run: simulator/device (not needed: tier A).
