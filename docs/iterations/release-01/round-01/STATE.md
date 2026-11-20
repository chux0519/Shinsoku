# release-01 round-01 — STATE

## Done
- R1 (merged, PR #47): iPhone only, 1.0.0, privacy manifests, microphone string in 10 languages, M06 guard.
- R2 (branch `release-01-r2-metadata`): store metadata in 10 languages (`docs/store/`), `tool/store_metadata.py`
  (check / push dry-run / --apply / review-zh), lint R08. Details: `R2-implementation.md`.

## In progress
- R4 (website) — other worker.

## Next
- Coordinator review/merge of R2; `python3 tool/store_metadata.py push --apply` (coordinator) once the user has
  reviewed `docs/store/review-zh.md`. Then R3 (screenshots; captions from the metadata wording) → R5.

## Open decisions / user actions
- `REVIEW_SONIOX_API_KEY` is not in `.env` yet.
- Chinese review of the store text: `docs/store/review-zh.md`.
- Name: plain "Shinsoku" (current) or with a keyword ("Shinsoku: Voice Keyboard")?

## How to verify R2
`python3 tool/store_metadata.py check` → ok; `python3 tool/review_lint.py` → all ok;
`python3 tool/store_metadata.py push` → dry-run diff (24 changes at 849950f, nothing sent).
