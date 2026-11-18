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

## Process
- Seeds are fixed in CI. A failing seed prints its shrunk sequence and is kept as a named regression case.
- Three layers: pure model test → real UI driven with fakes (clock, network, payments) → device scenario
  script with PHASE marks for recording.
