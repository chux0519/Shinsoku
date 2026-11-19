# T2 — implementation notes (Record screen: the transcript is the text field)

Branch `live-01-t2-ui`, tested at `0501059` (+ this notes commit). Model: Opus.

## What changed
- **`SkTranscriptArea` + `SkTranscriptController`** (`mobile/lib/ui/sk_transcript_area.dart`): borderless
  TextField, transcript type 17/1.45. The controller paints committed words in text and the pending tail in
  text-tertiary (`showLive`), plain text otherwise (`showText`), `commitComposing()` for L4. Read-only while
  live (selection/Copy still work), `dimmed` = text-secondary while processing, `followEnd` keeps the last
  line in view, Clear added to the context menu when editable and non-empty, `Semantics(label: Transcript)`.
  It reports a fixed intrinsic height (`minHeight`) so a content-sized page gives it at least that and the
  area scrolls its own text (no page-long text pushing the controls off screen).
- **Strings** (`mobile/lib/ui/strings.dart`, `SkStrings`): every new user-facing string; i18n-01 translates.
- **Record** (`features/record/record_view.dart`, now stateful): status + reason line unchanged; the area;
  profile selector; bottom row Copy (icon, left) · Record/Stop · Done (text, right). Copy/Done only appear
  when they apply (fade, keep their space so the record button stays centred, no taps/VoiceOver when hidden).
  While the field has focus the page title and profile selector step aside so text + bottom row fit above the
  keyboard; short panes (< 560 pt, Duo tabletop) also drop the title.
  New inputs: `transcript: ValueListenable<LiveTranscript>?`, `onSaveText`, `onCopyText`. Without a live
  transcript (or while it is idle) the area follows `captureState` + `smokeTestStatus.transcript`, so batch
  providers and smoke runs keep working. Phase handling: connecting/listening/finishing → live text,
  read-only; processing → raw text dimmed, status "Processing…"; done → result loaded once (a new result
  reloads, rebuilds don't clobber edits); failed → keeps heard words editable; idle → leaves text.
  Unsaved edits are saved before the area is reused by a new recording — on a Record tap (synchronously,
  before `onCapturePressed`) and when a recording starts elsewhere (keyboard/Shortcuts: post-frame).
- **Drafts** (`features/drafts/draft_editor_page.dart`): tapping a draft opens `DraftEditorPage`: top bar back
  · Copy · Save, "time · profile" caption, the same area. Back and swipe-back also keep edits; emptied text
  never empties a draft (Save/Copy disabled). `DraftEditorScreen`/`DraftEditResult` (framed box, two big
  buttons) removed. Swipe-to-delete + Undo unchanged.
- **`features/record/live_transcript.dart`**: TEMPORARY copy of T1's `LivePhase`/`LiveTranscript`; T3 deletes it
  and repoints imports (RecordView, scenes, tests).
- **Shell (minimum, `app/mobile_shell.dart`)**: `_recordDraft` (the draft the Record text belongs to);
  `_saveRecordText` replaces it in place (or creates one if none/deleted); `_copyRecordText` = save + the
  existing `_publishTextWithFeedback`; Drafts editor callbacks replace the same slot (tracking the new
  immutable entry, and `_recordDraft` if it is that one). A finished recording **stays on Record** (was:
  switch to Drafts) since the result is edited in place. The DebugCapture path now makes its draft like a
  real recording (tests).

## Tests (tier A)
- `test/features/record_transcript_test.dart`: read-only vs editable through listening/processing/done,
  pending style = text-tertiary, committed grows; Done saves once (L3); Record tap over unsaved edits saves
  before capture (L3/L4); a recording started elsewhere still saves edits; Copy callback; Clear in the menu.
- `test/app/record_draft_test.dart` (real MobileShell + DebugCapture): Done/Copy edit the recording's own
  draft, Copy publishes, second take gets its own draft; Drafts → editor → Save updates the same draft and
  Record keeps editing that draft.
- `widget_test.dart` editor flow updated; `posture_test.dart` finds the transcript inside RecordView (Drafts
  now lists the debug take too).
- A test caught a real bug: focus hid the title → the Column's children shifted → the TextField's element
  was rebuilt and the IME link lost. Fixed by keying the transcript slot.

## Evidence
- `flutter analyze`: no issues. `tool/test_diff.sh`: no new failures (0 known). `python3 tool/review_lint.py`:
  all ok (R03 ok).
- Renders: `tool/host_review.sh live-01/round-01/t2` → 176 images, all scenes pass (no overflow) →
  `build/ui-review/live-01/round-01/t2/index.html`. New scenes: `record-listening-live`,
  `record-processing-live`, `record-editing` (simulated keyboard: 336 pt on iPhone, 40 % of height
  elsewhere, drawn as a flat "software keyboard (simulated)" block), `draft-editor` (new page);
  `record-listening` = batch provider ("Listening…"). Fold variants added for listening-live, result, editing.

## Open / for the coordinator
1. **Duo stacked (portrait/tabletop) + keyboard**: the keyboard covers nearly all of the bottom Record pane;
   `duo-inner-portrait(-fold)/record-editing` shows only the text, status and bottom row scrolled away. Needs
   a shell rule (`app/shell_scaffold.dart`, outside T2's files): e.g. while the keyboard is up in a stacked
   split, give Record the whole window (or collapse the switchable pane). Design decision → DESIGN §6.
2. After editing a draft in Drafts that is also the Record screen's draft, the Record area still shows the
   old text until the next recording (the draft itself is right; a later Done on Record would overwrite the
   Drafts edit). T3 can pass the current draft text down when wiring.
3. The done status still says "Copied. Paste it anywhere…" because the shell still auto-publishes each
   result; with an explicit Copy that line could change — product call.
4. Back from the draft editor saves edits (no discard path besides Clear/undo). Flag if a Cancel is wanted.
