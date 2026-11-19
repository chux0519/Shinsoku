# T1 — implementation notes (streaming partials)

Branch `live-01-t1-stream`. Files: `mobile/lib/services/live_transcript.dart` (new),
`mobile/lib/services/transcription_service.dart`, `mobile/test/services/live_transcript_replay_test.dart`,
`mobile/test/services/replay_live_socket.dart`, `mobile/test/fixtures/streaming/*.json`.

## Interface (as in the brief, plus helpers)
- `enum LivePhase { idle, connecting, listening, finishing, processing, done, failed }` — unchanged.
- `LiveTranscript {committed, pending, phase, error}` — value type (`==`, `copyWith`, `text` = committed +
  pending, `LiveTranscript.idle`).
- `RealTranscriptionService.live` → `ValueListenable<LiveTranscript>`. One service instance per recording
  (T3 creates it at record start, not at stop as the shell does today). `dispose()` frees the notifier.
- New on the service (T3 uses these):
  - `streamsLive` — Soniox, or Bailian in realtime mode.
  - `startLiveSession()` → `LiveAsrSession` (Bailian realtime or Soniox PCM stream); feed `addPcm`, then
    `finishLiveSession(session:, profile:)`. `finishBailianRealtimeSession` stays as an alias so the current
    shell keeps working unchanged.
  - `beginBatchListening()` — batch providers: phase `listening`, empty text; `transcribe()` then goes
    `finishing → (processing →) done`.
  - `reset()` → `idle`.
- Constructor injection for tests: `connect: LiveSocketConnector`, `httpClient:`.

## Semantics
- Bailian: a sentence is final on `sentence_end: true`; without that field, a non-null `end_time`. Finals
  commit in `sentence_id` order only while every lower known id is final, so committed never changes in the
  middle (L1). Committed sentences are never rewritten (repeats and late rewrites ignored). A final sentence
  arriving with an id below committed text is appended (nothing lost). Sentences joined with `''` (as before).
- Soniox: `is_final` tokens append to committed; each message's non-final tokens replace pending; `<fin>` /
  `<end>` dropped; a final token starting before the last committed final's `end_ms` is a repeat and skipped.
  Live streaming config: `audio_format: pcm_s16le`, 16 kHz, mono. The post-stop upload path uses the same
  session with `audio_format: wav`.
- Stop result (L2) = committed + whatever is still pending at the provider's finish, trimmed.
- Post-processing: `processing` with committed = raw text, then `done` with committed = processed text (one
  wholesale replacement). `done.committed` has no commit suffix; `result.text` still has it.
- Batch upload after stop: provider words may flow in, but the phase stays `finishing` until `done`.
- Failure (task-failed, provider error, socket error/close before the result, finish timeout, empty
  transcript, post-process HTTP error): phase `failed` with `error`; committed and pending kept. The session
  stops sending audio and `finish()` throws.

## Behaviour change for T3 to note
- Soniox used to return partial text as a success on an `error_message`; now the session fails and throws.
  The text is in `service.live.value` (committed + pending) — T3 should save it to the draft rather than
  dropping it ("nothing is lost").
- Bailian: a socket closing before `task-finished` used to return what it had as success; now it is `failed`
  (same recovery via `live.value`).

## Tests
Replay fixtures (hand-written in the providers' shapes, `example` content, no keys): Bailian basic,
out-of-order + repeated + rewrite + end_time-only, unended at finish, dropped, task-failed; Soniox basic,
repeated messages, dropped, error. Each normal fixture asserts L1 over the whole history and L2 (exact final
text); per-message snapshot tests pin committed/pending; plus post-processing, commit suffix, batch phases,
Soniox WAV upload, missing credentials. Mutation check: removing the Soniox repeat guard fails
`soniox_repeated`.

## Verified (source = branch head at push)
`flutter analyze` clean; `tool/test_diff.sh` no new failures; `python3 tool/review_lint.py` ok.
