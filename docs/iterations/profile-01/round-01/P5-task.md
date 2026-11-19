# P5 — model-based test for profile selection (PR1–PR4)

Implementer brief. Read AGENTS.md, `docs/design/state_invariants.md` (PR1–PR4), `tool/model_check.py` (the
pfstack pattern: small reference model, seeded random event sequences, check every rule after every event,
shrink failures, save named regressions) and P1's `mobile/lib/services/active_profile.dart`. Branch
`profile-01-p5-model`. Files: `mobile/test/model/**` (Dart port of the pattern), docs. Do not change product
code unless the test finds a real bug — then fix it minimally, add a named regression, and describe it.
No simulators, no nested agents, no merging.

Events: automationSet(profileId, t), manualPick(profileId, t), keyboardAppear(fieldKind, t),
keyboardDisappear(t), recordStart(t), recordStop(t), profileDelete(id), profileRename(id), profileAdd,
appRelaunch (reload from the mirrored store), fullAccess(on|off), clock skew within ±2 s between writers.
Reference model: an independent, obviously-correct statement of the precedence (don't call resolveActive from
the model). After each event check: PR1 (profile captured at recordStart is the one the keyboard showed, and
doesn't change until recordStop), PR2, PR3, PR4. Fixed seeds in the default `flutter test` run (fast, < 5 s);
a longer run behind an env var. Failing sequences shrink and are printed as a Dart test case to paste into
`mobile/test/model/regressions_test.dart`.

Verify: analyze, test_diff, lint. Commit per unit, push, PR, `P5-implementation.md` + STATE.md section, reply
with PR URL. Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u
https_proxy -u http_proxy -u all_proxy gh`.
