# STATE — live-01 T1 (streaming partials)
- Done: `LiveTranscript` + `service.live`; live sessions for Bailian realtime and Soniox (PCM), batch phases,
  post-processing phases; 17 replay tests (L1/L2, out-of-order, repeats, drop, provider errors). Details:
  `T1-implementation.md`.
- In progress: none. Next: coordinator review; T3 wires `startLiveSession` / `beginBatchListening` into the
  shell (creates the service at record start) and recovers text from `live.value` on `failed`.
- Open decisions: none (interface kept exactly; additions listed in T1-implementation.md).
- Verify: `cd mobile && flutter test test/services/live_transcript_replay_test.dart`; `tool/test_diff.sh`;
  `python3 tool/review_lint.py`.
