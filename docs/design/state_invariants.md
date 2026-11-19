# State invariants

Timing bugs (pushes vs snapshots vs taps vs the clock, retries, trials, notifications) are checked by
model-based tests: a small reference model plus seeded random event sequences, every invariant asserted
after every event. A new timing bug gets a new rule id here first, then a test.

## Event alphabet
`<event>(<args>)`, … — e.g. `launch`, `resume`, `clock(+Δ)`, `clock_back(Δ)`, `network_fail`,
`purchase_ok`, `reinstall`.

## <Group letter>. <Area>
- **X1 <Short name>.** <One sentence that a test can check after any event.>
- **X2 …**

## D. iPhone Duo posture (capture vs layout)
Events: `resize(window)` (iPhone, Duo outer, inner landscape / portrait, with or without a fold region),
`pick(page)` (tab bar or pane switcher), `toggle` (record button). Tests: `mobile/test/app/posture_test.dart`
(seeded model test, seeds 1 / 7 / 42, plus named cases).
- **D1 Posture never changes capture.** A size, posture or fold change never changes capture state, never
  stops the recorder, and never clears the current transcript; only `toggle` does. Stateful pages (Desktop,
  Settings) keep their State across compact ↔ regular switches.
- **D2 Folding mid-capture lands on Record.** A regular → compact switch while capture is not idle shows
  Record (with Stop), whichever page was picked before. Regression: seed 7, "tab away on the phone, unfold,
  fold".

## PR. Active profile (profile-01)
Events: `automation_set(id, at)` (App Intent), `manual_pick(id, at)` (keyboard or app Record selector),
`field_change(kind)` (keyboard), `keyboard_appear(at)`, `app_record_start`, `app_relaunch`, `profile_delete(id)`,
`profile_rename(id)`. The selection `{profileId, source: manual|automation|fieldRule|default, at}` lives in the
App Group (`group.net.potafree.shinsoku`, key `activeProfile.v1`; list of ids and names in `profiles.v1`). Pure
resolver: `resolveActive` in `mobile/lib/services/active_profile.dart` (unit tests:
`mobile/test/services/active_profile_test.dart`). Seeded model test: `mobile/test/model/profile_model_test.dart`
(seeds 1 / 7 / 42 / 99 / 123 / 2026 / 31337; `SHINSOKU_MODEL_SEEDS=<n>` runs seeds 0..n-1), events also
`keyboard_disappear`, `record_stop`, `profile_add`, `full_access(on|off)`, `clock_skew(writer, ±2 s)`; named
cases in `mobile/test/model/regressions_test.dart`.
- **PR1 Record uses what the keyboard shows.** Recording uses exactly the profile that the keyboard shows at the
  moment Record is tapped; the app resolves the selection once at record start and keeps that profile until
  the transcript is done. A keyboard tap passes the shown profile (`shinsoku://dictation?profile=<id>`,
  `profileForRecordStart`); the app can't see field rules or a read-only keyboard's stale profile. Only a
  shown profile that was deleted meanwhile falls back to the selection (PR3 wins). Regression: "PR1: keyboard
  Record tap records what the keyboard shows".
- **PR2 Newer event wins.** Automation set and manual pick are ordered by timestamp (the newest write is the
  selection); a field rule never overrides a manual pick or an automation set made at or after the moment the
  keyboard appeared. Without a keyboard session a field rule never overrides an explicit selection. "Newer"
  is real order, not writers' clocks: the keyboard compares the stored selection with the one it read when
  it appeared (`selectionAtKeyboardAppear`), so ±2 s of skew between the app, the App Intent and the keyboard
  can't reorder events. Regression: "PR2: clock skew does not reorder automation and keyboard".
- **PR3 No dangling selection.** Deleting or renaming a profile never leaves the active selection pointing at a
  missing id: the resolver falls back to the default (first) profile and the app rewrites the stored selection
  to `default`, so the keyboard shows it.
- **PR4 Read-only without Full Access.** Without Full Access the keyboard still shows the last known profile
  read-only and says why it can't switch.

## Process
- Seeds are fixed in CI. A failing seed prints its shrunk sequence and is kept as a named regression case.
- Three layers: pure model test → real UI driven with fakes (clock, network, payments) → device scenario
  script with PHASE marks for recording.
