# T2 — Record screen: the transcript is the text field

Implementer brief. Read AGENTS.md, DESIGN.md (all; §3 transcript type 17/1.45, §4 motion, §5, §7), and
`docs/iterations/live-01/plan.md` (behaviour, actions, L3/L4). Branch `live-01-t2-ui`. Files:
`mobile/lib/ui/**`, `mobile/lib/features/record/**`, `mobile/lib/features/drafts/**`, tests, host-review
scenes. Don't edit `mobile/lib/services/**` (T1) or `mobile/lib/app/**` (T3 wires things later) beyond the
minimum to compile; use a fake `ValueListenable<LiveTranscript>` per T1's interface:
```dart
enum LivePhase { idle, connecting, listening, finishing, processing, done, failed }
class LiveTranscript { final String committed; final String pending; final LivePhase phase; final String? error; }
```
(Put a temporary copy under `mobile/test/` or a feature-local fake; T3 switches to T1's real file.)
No simulators, no nested agents, no merging.

1. `SkTranscriptArea` (mobile/lib/ui/): borderless, fills the space between the status line and the profile
   selector; transcript type; committed in text colour, pending in text-tertiary; read-only while listening/
   finishing/processing (processing dims the raw text); editable when done/idle; keyboard-safe (scrolls caret
   into view, the bottom controls stay reachable, no overflow with the software keyboard up); placeholder
   "Tap the microphone and start speaking." when empty; selection/copy/paste work; Semantics.
2. Record screen: status line + reason line unchanged; the text area; profile segmented control; a bottom row
   with Copy (left icon button), Record/Stop (centre, unchanged), Done (right; saves the edit into the same
   draft and dismisses the keyboard). Clear in the text area's context menu. Copy also publishes the text as
   the latest for the keyboard (call the existing publish path through a callback, don't import services).
3. Drafts: tapping a draft opens it in the same editor layout (top bar: back, Copy, Save); remove the old
   framed editor page and its two big buttons. Swipe-to-delete with Undo stays.
4. Host renders: record idle, listening with live text (fake committed + pending), processing, done/editable,
   editing with keyboard inset (simulate viewInsets), drafts → editor; iphone + duo-inner (+fold) dark/light,
   `tool/host_review.sh live-01/round-01/t2`. Widget tests for read-only vs editable states, Done saving into
   the same draft (L3), Copy callback.
5. Strings: put every new user-facing string in one place (`mobile/lib/ui/strings.dart` or the existing
   pattern) — i18n-01 will translate later.

Verify: analyze, test_diff, lint (R03!), renders. Commit per unit, push, PR, `T2-implementation.md` + STATE.md
section, reply with PR URL and the render path. Model: Opus — design care. Trailer `Co-Authored-By: Claude
<noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy -u all_proxy gh`.
