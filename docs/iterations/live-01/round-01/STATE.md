# STATE — live-01 T2 (Record screen: the transcript is the text field)
- Done: SkTranscriptArea + controller, Record redesign (Copy · Record · Done), Drafts editor page (old framed
  editor removed), SkStrings table, temp LiveTranscript copy, minimal shell wiring, tests, host scenes.
  Details: `T2-implementation.md`.
- In progress: none. Next: coordinator review of renders; T3 wires T1's real LiveTranscript (delete
  `features/record/live_transcript.dart`).
- Open decisions: Duo stacked + keyboard (shell rule), Drafts↔Record text sync, done-status wording, draft
  editor discard path (see notes §Open).
- Verify: `cd mobile && flutter analyze`; `tool/test_diff.sh`; `python3 tool/review_lint.py`;
  `tool/host_review.sh live-01/round-01/t2`.
