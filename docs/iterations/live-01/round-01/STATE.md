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

# STATE — live-01 T1 (streaming partials)
- Done: `LiveTranscript` + `service.live`; live sessions for Bailian realtime and Soniox (PCM), batch phases,
  post-processing phases; 17 replay tests (L1/L2, out-of-order, repeats, drop, provider errors). Details:
  `T1-implementation.md`.
- In progress: none. Next: coordinator review; T3 wires `startLiveSession` / `beginBatchListening` into the
  shell (creates the service at record start) and recovers text from `live.value` on `failed`.
- Open decisions: none (interface kept exactly; additions listed in T1-implementation.md).
- Verify: `cd mobile && flutter test test/services/live_transcript_replay_test.dart`; `tool/test_diff.sh`;
  `python3 tool/review_lint.py`.
