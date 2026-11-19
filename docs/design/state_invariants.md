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

- **D3 Stacked + keyboard: Record gets the window.** In a stacked split (tabletop, or portrait when flat), while
  a field in Record has focus and the software keyboard is up, the switchable pane steps aside (kept offstage,
  its state intact) and Record fills the window, so its text, status and bottom row (Copy · Record · Done) stay
  above the keyboard; when the keyboard goes down or focus leaves Record, the split returns. A field in the
  switchable pane never collapses it (live-01 decision 2026-11-19). Tests: `mobile/test/model/record_model_test.dart`,
  `mobile/test/app/live_wiring_test.dart` ("D3: …").

## L. Live transcript and the Record area (live-01)
Events: `new_recording(post)` (Record tap), `keyboard_record(post)` (`shinsoku://dictation`), `partial(words)`,
`final(words)` (provider), `drop` (connection lost or provider error, while listening or after Stop), `stop`,
`process` (provider result; a post-processing profile takes two: raw text, then the processed text), `edit(text)`,
`compose(text)` (IME marked text), `done`, `open_draft_elsewhere(text)` (Drafts edits the Record draft),
`keyboard_up` / `keyboard_down` (iPhone Duo, stacked). The shell (`mobile/lib/app/mobile_shell.dart`) creates
one `RecordingPipeline` per recording and mirrors its `LiveTranscript` into the Record area. Seeded model test:
`mobile/test/model/record_model_test.dart` (seeds 1 / 7 / 42 / 99 / 2026; `SHINSOKU_MODEL_SEEDS=<n>`), real
MobileShell on the Duo inner display with a scripted pipeline (`test/model/scripted_pipeline.dart`); named cases
in `mobile/test/model/record_regressions_test.dart`; provider replay for L1/L2 in
`mobile/test/services/live_transcript_replay_test.dart` (T1).
- **L1 Committed only grows.** During listening (and finishing), committed text only grows: each value extends
  the previous one, nothing in it changes or disappears; pending text (the provider's interim words, drawn in
  text-tertiary) may change. The Record area shows exactly committed + pending.
- **L2 Nothing heard is lost or doubled.** On stop, the final text equals committed + the provider's final
  segments (no word lost, none duplicated); a post-processing profile replaces it once with the processed text.
  If the connection drops or the provider fails (while listening or after Stop), the recording stops and
  committed + pending become this recording's draft, shown editable in the area; the status line says
  "Recording stopped" and offers "Record again".
- **L3 One recording, one draft.** A recording's text never lands in a different draft, and editing never
  creates a second one: Done, Copy, a new recording over unsaved edits, and Drafts editing the Record draft all
  update the same entry in place. Record and Drafts show one source: after Drafts edits the Record draft, the
  Record area shows that text. Done after an edit also republishes it (keyboard's latest + clipboard).
- **L4 No composition crosses a record start.** Before a recording starts (Record tap, keyboard, Shortcuts),
  unsaved Record edits are saved with any IME composition committed first; the new recording never starts over
  marked text.

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
- **PR2 Strict precedence: manual > automation > field rule > default** (user decision 2026-11-19, replaces
  the "made after the keyboard appeared" rule). Between a manual pick and an automation set, the newest write
  is the selection (last writer wins in `activeProfile.v1`; timestamps aren't compared). A field rule applies
  only while no explicit selection is in effect: the stored selection is missing, has source `default`, or
  points at a deleted profile (PR3). It never overrides a manual or automation selection, whatever the
  timestamps, clock skew or when the keyboard appeared. An automation stays in effect across apps; to return
  to the default profile after an app, the user adds a "When <app> is closed → Set Shinsoku Profile:
  <default>" automation (P4 guide). That write has source `automation`, so field rules stay off until a
  selection with source `default` is written (open: a reset intent, see P3-implementation.md). Regressions: "PR2: an automation before appear beats a field rule",
  "PR2: a field rule applies again once the picked profile is deleted".
- **PR3 No dangling selection.** Deleting or renaming a profile never leaves the active selection pointing at a
  missing id: the resolver falls back to the default (first) profile and the app rewrites the stored selection
  to `default`, so the keyboard shows it.
- **PR4 Read-only without Full Access.** Without Full Access the keyboard still shows the last known profile
  read-only and says why it can't switch.

## Process
- Seeds are fixed in CI. A failing seed prints its shrunk sequence and is kept as a named regression case.
- Three layers: pure model test → real UI driven with fakes (clock, network, payments) → device scenario
  script with PHASE marks for recording.
