# STATE — i18n-01 round 01

## I1 — Flutter localisation framework (implementer, 2026-11-19)
- Done: gen-l10n + `app_en.arb` (208 messages), all UI strings extracted, friendly error mapping (no raw
  exception text), pseudo-locale (`tool/pseudo_arb.py`), lint R05 + rule M10, host review `locale` dimension
  with clipped-text check, l10n tests. Details: `I1-implementation.md`.
- In progress: none. Next: coordinator review of the diff and the en/pseudo renders; then I2 (native strings),
  I3 (region defaults) in parallel.
- Open decisions: see `I1-implementation.md` §Decisions (default profiles persisted on first launch; RTL check
  not done).
- Verify: `cd mobile && flutter analyze && flutter test`; `python3 tool/review_lint.py`;
  `tool/host_review.sh i18n-01/round-01/i1` and `tool/host_review.sh i18n-01/round-01/i1 '' '' '' pseudo`.
