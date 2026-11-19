# T1 — streaming partials (LiveTranscript)

Implementer brief. Read AGENTS.md and `docs/iterations/live-01/plan.md` (behaviour, L1/L2). Branch
`live-01-t1-stream`. Files: `mobile/lib/services/**`, `mobile/test/services/**`, `mobile/test/fixtures/**`.
T2 builds the UI in parallel against the interface below — keep it exactly (or tell the coordinator before
changing it). No simulators, no nested agents, no merging. Never print or commit API keys.

Interface (new file `mobile/lib/services/live_transcript.dart`):
```dart
enum LivePhase { idle, connecting, listening, finishing, processing, done, failed }
class LiveTranscript { final String committed; final String pending; final LivePhase phase; final String? error; ... }
// The transcription service exposes: ValueListenable<LiveTranscript> get live;
```
1. Bailian realtime (`transcription_service.dart` `_BailianRealtimeLiveSession`, sentence map by
   `sentence_id`): a sentence is committed when the provider marks it ended (check the payload field, e.g.
   `sentence_end` / end_time); the current unfinished sentence is `pending`. Ordered by id.
2. Soniox streaming: tokens with `is_final` → committed; non-final tokens → pending (replace each message).
3. Batch providers: phases only (listening → finishing → done) with empty committed/pending until the result.
4. Post-processing: after the raw final text, phase `processing`, then `done` with committed = processed text
   (the only wholesale replacement — L2).
5. Replay tests: recorded-shape provider message sequences as JSON fixtures under `mobile/test/fixtures/
   streaming/` (hand-written, realistic shapes, `example` content, no keys), a fake socket that replays them,
   asserting L1 (committed only grows during listening) and L2 (final = all final segments, no loss, no
   duplicates) for both providers, including out-of-order / repeated sentence updates and a dropped
   connection (phase failed, committed kept).

Verify: analyze, test_diff, lint. Commit per unit, push, PR, `T1-implementation.md` + STATE.md section, reply
with PR URL. Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u
https_proxy -u http_proxy -u all_proxy gh`.
