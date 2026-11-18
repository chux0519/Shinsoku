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

## Process
- Seeds are fixed in CI. A failing seed prints its shrunk sequence and is kept as a named regression case.
- Three layers: pure model test → real UI driven with fakes (clock, network, payments) → device scenario
  script with PHASE marks for recording.
