# Iteration live-01 — live transcript preview + the transcript is the text field

Status: **awaiting user confirmation** (2026-11-19). Base: `main` @ 47076c9 (TestFlight 0.1.0 (20)).

## Goal
1. While recording, the words appear as they are recognised (streaming providers: Bailian realtime, Soniox).
2. Record screen redesign (user choice 2026-11-19, "文字就是输入框"): the middle of the Record screen is one
   borderless text area. During recording it fills live (unconfirmed words lighter); after stop it is directly
   editable. No separate full-screen editor with a framed box and two big buttons.

Out of scope: localisation, keyboard extension changes, new providers, desktop.
Next iteration (user decision 2026-11-19): **i18n-01 — multi-language, multi-region support** for the app,
the keyboard extension, the Shortcuts actions (App Intents strings) and the setup guides; done together with
the user. New UI text in live-01 goes through one string table so i18n-01 can translate it without hunting.

## Behaviour
- **Live text**: `committed` (final words/sentences) in text colour, `pending` (provider's interim words) in
  text-tertiary. Batch providers (Qwen-ASR batch, OpenAI-compatible) show no live text — the area shows
  "Listening…" and the result appears after stop.
- **After stop**: if the profile post-processes (Chat, Review, ZH → EN…), the area shows the raw text dimmed
  with "Processing…" in the status line, then swaps to the processed text. The swap is the only time text is
  replaced wholesale.
- **Editing**: after stop the area is editable in place; edits update the same draft (no duplicate draft) and
  what the keyboard's Insert uses (App Group latest) when the user taps Use/Copy. Starting a new recording
  with unsaved edits keeps them in the draft (nothing is lost).
- **Actions** beside the record button: Copy (left), Record/Stop (centre, unchanged), Done/Save (right). Clear
  lives in the text area's context menu. Drafts list: tapping a draft opens it in the same borderless editor
  (top bar holds Copy/Save) — the old framed editor page goes away.
- iPhone Duo: the Record pane holds the text area; layout rules unchanged.

## Invariants (to add as L1–L4)
- **L1** During listening, committed text only grows (never shrinks or changes); pending text may change.
- **L2** On stop, the final text equals committed + the provider's final segments (no word lost, none
  duplicated); for post-processing profiles the processed text replaces it once.
- **L3** A recording's text never lands in a different draft; editing never creates a second draft.
- **L4** Recording cannot start while the text area has focus and unsaved IME composition (or it commits
  the composition first).

## Work units
| # | Unit | Files | Model | Tier |
|---|---|---|---|---|
| T1 | Streaming partials: `LiveTranscript {committed, pending, phase}` as a `ValueListenable` from the transcription service for Bailian realtime (sentence updates / sentence_end) and Soniox (final vs non-final tokens); batch providers emit phase only. Replay tests from recorded provider message fixtures (`example-*` data only, no keys) covering L1/L2 | `mobile/lib/services/`, `mobile/test/services/` | Opus | A |
| T2 | Record screen redesign + in-place editing + Drafts open in the same editor; component `SkTranscriptArea` (borderless, live styling, editable state) in `mobile/lib/ui/`; codes against T1's interface with a fake | `mobile/lib/features/record/`, `features/drafts/`, `mobile/lib/ui/`, tests | Opus | A |
| T3 | Wire T2 to T1, L1–L4 in `docs/design/state_invariants.md`, model test (seeded: partial/final/stop/process/edit/new-recording events) | `mobile/lib/app/`, `mobile/test/model/` | Opus | A |

Order: T1 ‖ T2 → T3. DESIGN.md §7 Record/Drafts entries updated by the coordinator after the renders.

## Acceptance
- Tier A: analyze, lint, test diff; replay tests; renders of Record idle / listening with live text (fake) /
  processing / editable result / editing with keyboard up, iPhone + Duo, dark/light; Drafts → editor.
- Tier B (iPhone 17): existing three scenes still pass; Record → stop → edit in place → keyboard Insert uses
  the edited text (fake provider path via a DEBUG launch arg feeding the fixture stream — no real keys in the
  simulator).
- Pending C (device): real streaming latency and live text with real keys (the user tests on TestFlight).
