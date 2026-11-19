# T3 — wire live transcript to the Record screen; invariants L1–L4; model test

Implementer brief. Read AGENTS.md, DESIGN.md, `docs/iterations/live-01/plan.md`, and both notes:
`round-01/T1-implementation.md` (LiveTranscript API: startLiveSession/finishLiveSession/beginBatchListening/
streamsLive/reset; **on provider error/drop the session fails — recover the committed text from `live.value`,
never lose it**) and `round-01/T2-implementation.md` (SkTranscriptArea, Record/Drafts editors, fakes, §Open).
Branch `live-01-t3-wire`. Files: `mobile/lib/app/**`, `mobile/lib/features/**` (wiring only), `mobile/test/**`,
`docs/design/state_invariants.md`. No simulators, no nested agents, no merging.

1. Replace T2's fake with T1's real `ValueListenable<LiveTranscript>`; delete the temporary fake types.
2. Failure path: if the stream fails/drops, keep committed + pending as the draft text (phase failed, status
   line explains and offers retry); nothing typed or recognised is lost (L2/L3).
3. Coordinator decisions on T2 §Open (2026-11-19):
   a. iPhone Duo stacked split + software keyboard up → collapse the switchable pane; Record gets the whole
      window until the keyboard goes down (shell rule in `app/shell_scaffold.dart`; host render of
      duo-inner-portrait(-fold)/record-editing must show text + bottom row).
   b. Editing a draft in Drafts that is also Record's current draft updates the Record area (single source).
   c. Keep auto-copy/publish of each new result. Done after an edit saves into the same draft AND republishes
      the edited text as the keyboard's latest (App Group) and clipboard; status line "Saved. Insert it from
      the keyboard." (string table).
   d. Back from the draft editor saves (no Cancel).
4. Invariants L1–L4 from the plan into `docs/design/state_invariants.md`; a seeded model test in
   `mobile/test/model/` (events: partial, final, drop, stop, process, edit, done, open-draft-elsewhere,
   new-recording, keyboard-up/down on Duo) checking L1–L4 after every event; shrink + named regressions.
5. A DEBUG-only launch arg `-ShinsokuSceneLiveFixture <name>` that makes the next recording replay a T1
   fixture instead of the microphone/provider (so the coordinator can run tier B on the simulator without keys);
   must be impossible in release builds (`kDebugMode` + native DEBUG guard).

Verify: analyze, test_diff, lint, renders (`tool/host_review.sh live-01/round-01/t3`), `flutter build ios
--simulator --debug --no-pub` (restore Flutter-regenerated tracked files). Commit per unit, push, PR,
`T3-implementation.md` + STATE.md, reply with PR URL. Model: Opus. Trailer `Co-Authored-By: Claude
<noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy -u all_proxy gh`.
