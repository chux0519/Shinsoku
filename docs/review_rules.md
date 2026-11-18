# Review rules

Pitfalls we have hit. `R*` rules are checked by `tool/review_lint.py` (run one with
`python3 tool/review_lint.py R01`); `M*` rules are checked by reading.

| Id | Rule | Why (the incident) |
|---|---|---|
| R01 | No real host or user names in tests and fixtures; use `example-*`. | A public export leaked a machine name. |
| R02 | `rm -rf` only as `rm -rf "${VAR:?}"`. | An empty variable must never delete `/`. |
| R03 | No `Color(0x` or `ColorScheme.fromSeed` in `mobile/lib/` outside `mobile/lib/ui/`; colours come from DESIGN.md tokens (`SkColors`). | The pre-DESIGN app seeded Material from one hex and scattered literals (ios-ui-01 U3). |
| M01 | Timing claims need a recording cut at stable frames, not one screenshot after the action. | A transient state was reported as a persistent failure. |
| M02 | Build-number bumps go through `tool/next_build.py`, never a blind `sed`. | A sed rewrote a hex id that contained the number. |
| M03 | Qt/C++ code under `src/`, `tests/`, `packaging/` is frozen: no new features; new shared logic goes in Dart. | User decision 2026-11-18: everything moves to Flutter. |
| M04 | New Flutter UI uses the `mobile/lib/ui/` component layer and DESIGN.md tokens, not raw Material widgets or literal colours. | DESIGN.md §5/§8. |
| M05 | iPhone Duo: no text or control across the hinge; posture change never stops an active recording. | DESIGN.md §6. |
