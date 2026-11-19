# P3 — keyboard: active profile in the status row, field-kind rules

Branch `profile-01-p3-keyboard`, rebased onto main after P2 (#15) merged. The keyboard shares
`Runner/ProfileGroup.swift` by target membership (Foundation-only; it is the one shared helper for both
targets, no copy, no `ProfileGroupCore.swift` split).

## Round 2 (coordinator review, user decision 2026-11-19): strict precedence
manual > automation > field rule > default. A field rule applies only while no explicit selection is in
effect (selection missing, source `default`, or pointing at a deleted profile); never over manual or
automation, whatever the timestamps. Changed in this branch:
- Dart `resolveActive`: dropped `keyboardAppearedAt` / `selectionAtKeyboardAppear`; unit tests rewritten
  (old "explicit after appear wins" / "same instant" / "older explicit loses to rule" → "rule never overrides
  manual/automation at any time", plus "rule without selection" and "rule after the picked profile was
  deleted").
- Swift port matches; the keyboard no longer captures anything at appear. PR1 unchanged (Record passes the
  shown id).
- P5 model: `RefModel.keyboardShows` = rule only when `explicitId == null`; `KeyboardStandIn` no longer
  captures. Regressions that encoded the old rule: **"PR2: clock skew does not reorder automation and
  keyboard"** (expected the rule to beat an earlier automation) → renamed "PR2: an automation before appear
  beats a field rule", same sequence, now expects the automation; **"PR1: keyboard Record tap with a field
  rule"** (preceded by an automation, which now wins) → automation removed so the rule applies. New:
  "PR2: a field rule applies again once the picked profile is deleted", and a harness mutant
  (`_OldTimingKeyboard`, the old rule) that the model must reject with PR2. `ProfileSystem` takes an optional
  `makeKeyboard`.
- `docs/design/state_invariants.md` PR2 rewritten with the date.

**Open (for the user):** "When <app> is closed → Set Shinsoku Profile: <default>" writes source
`automation`, so after it field rules stay off (an automation is in effect). If field rules should come back
after the app closes, P2 needs a way to write source `default` — e.g. a "Reset Shinsoku Profile" intent, or
Set treating the default profile as a reset. Not done here (P2 files).

## What changed (all in `mobile/ios/ShinsokuKeyboard/` + 5 pbxproj lines for the keyboard target)
- `KeyboardProfileResolver.swift` (Foundation only): faithful port of Dart `resolveActive` (strict precedence,
  round 2); else stored selection if the id exists; else first profile (PR3). Unparseable `at` = no selection (as Dart's
  `fromJson`). Timestamps parse Dart's microsecond and Swift's millisecond forms. Also `fieldRules.v1`
  parser, `next(after:)` cycling, `dictationURL(profileId:)`, and `LastShownProfile` (extension's own
  `UserDefaults.standard`, readable without Full Access — PR4).
- `KeyboardProfileButton.swift`: plain `UIButton` (secondary text 13 pt, `textSecondary`, truncating tail,
  one line), 28 pt drawn + 8 pt hit outset top/bottom = 44 pt; width ≥ 44, ≤ 45 % of the status row. Trailing
  `chevron.up.chevron.down` when switchable, leading `lock.fill` when read-only. `FieldKind.detect` from the
  proxy, first match: email (keyboard or content type) → URL keyboard → search (`.webSearch` keyboard, e.g.
  Safari's address bar, or Search/Google/Yahoo return key) → URL content type → message (Send return key) →
  other.
- `KeyboardViewController.swift`: `viewWillAppear` and `hostDidBecomeActive` resolve. `textDidChange` re-resolves when the field kind changes. Tap →
  next profile, long-press → `UIMenu` (checkmark on current); both write `{profileId, source: manual, at}` via
  `ProfileGroup.writeSelection`. VoiceOver: label "Profile", value = name, custom actions "Use <name>".
  Without Full Access: last shown name + lock; tap shows status "Turn on Full Access to switch profiles"
  (warning, lock icon); no menu. Record opens `shinsoku://dictation?profile=<shown id>` (PR1); no profile
  known → plain `shinsoku://dictation`. Log category `profile` (ids, kind, source only; never names).
- No new colours; no new App Group keys written by the keyboard except `activeProfile.v1`.

## Decisions (accepted 2026-11-19)
1. (Superseded by strict precedence; the keyboard no longer captures at appear.)
2. `.webSearch` (Safari address bar) maps to `search`, not `url`.
3. Profile button hidden when no profile is known (app never published a list; or no Full Access and never
   shown before).

## Tier A evidence
- `mobile/ios/ShinsokuKeyboard/ResolverChecks/run.sh` → "resolver checks: all passed" (round 2; compiles
  the resolver + `Runner/ProfileGroup.swift` on the Mac; not part of any target).
- `xcrun --sdk iphonesimulator swiftc -typecheck` of the keyboard sources: no warnings.
- `cd mobile && flutter build ios --simulator --debug --no-pub` (Xcode 27.2): ✓; regenerated tracked files
  restored. `python3 tool/review_lint.py`: ok.
- Round 2: `flutter analyze` no issues; `flutter test test/model test/services/active_profile_test.dart` 34
  passed; `SHINSOKU_MODEL_SEEDS=3000` model test passed; `tool/test_diff.sh` no new failures.

## Tier-B checklist (coordinator, iPhone 17 `9080FE77-…`)
Setup: app with ≥ 3 profiles (e.g. Default, Chat, Review); Shinsoku keyboard added. Log stream:
`xcrun simctl spawn <udid> log stream --predicate 'subsystem == "net.potafree.shinsoku.keyboard" AND category == "profile"'`.
1. **Full Access on**, Notes: status row = `[mic] Ready … <ActiveName> ⌃⌄ [globe]`, one line. Name matches the
   app's Record screen.
2. Tap the name → next profile in list order (wraps). Log `profile (manualPick): … source=manual`. App's Record
   shows the same profile after switching to it.
3. Long-press the name → menu titled "Profile" with all profiles, checkmark on current; pick one → shown. (If the
   menu can't draw inside the keyboard's 216 pt window, record it: fallback is a cycle-only control.)
4. Long name (rename a profile to 40+ chars in the app): truncates with "…", status text truncates first,
   globe still visible, row stays one line.
5. Record → app opens and records with the shown profile (P5 regression "PR1: keyboard Record tap records what
   the keyboard shows"); URL in the app log has `?profile=<id>`.
6. Shortcuts "Set Shinsoku Profile: Review" (P2), then open Notes → keyboard shows Review; then Safari address
   bar with a search rule → still Review (strict precedence).
7. Field rule: write `fieldRules.v1` = `{"search":"<ChatId>"}` into the group (until P4's Settings UI lands:
   `xcrun simctl spawn <udid> defaults write group.net.potafree.shinsoku fieldRules.v1 '{"search":"<id>"}'` may
   not reach the app-group container — use P4's UI if merged). Safari address bar → keyboard shows Chat, log
   `kind=search source=fieldRule` — only while the selection's source is `default` (fresh install or after
   the selected profile was deleted). Tap name → manual pick beats the rule from then on.
8. **Full Access off** (Settings › Keyboards › Shinsoku): last shown name with a lock glyph, no chevron;
   tap → status "Turn on Full Access to switch profiles" (warning colour); long-press → no menu; Record still
   passes the shown id.
9. Light + dark, VoiceOver: "Profile, Chat, button", custom actions "Use …".

Not tested by me: anything on a simulator (implementers don't touch shared simulators).

## Scene (tier B harness, branch `profile-01-p3-scene`)
Run (coordinator, iPhone 17, under Xcode 27.2, simulator already booted):
`SCENE_TEST=KeyboardSceneTests/ProfileKeyboardSceneTests bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash
tool/ios_keyboard_scene.sh 9080FE77-1FF9-49A1-B165-55DCA4ECED64 build/ui-review/profile-01/round-01/iphone-17`

- `KeyboardSceneTests/SceneSupport.swift`: `SceneTestCase` base class. The Settings / Safari-field / Shortcuts /
  Runner / FAIL-PHASE helpers of `KeyboardSceneTests` and `ProfileIntentSceneTests` moved there unchanged; both
  scenes now subclass it (FAIL trees now always include SpringBoard; `tap` scrolls Settings or Shortcuts,
  whichever is in front). 8 pbxproj lines add the two new files to the test target.
- `ProfileKeyboardSceneTests` (steps = task brief 1–8): seed → textarea shows Dictation → tap → Chat → tap →
  Review → long-press menu lists Dictation/Chat/Review/ZH -> EN, pick Chat → keyboard Record → app's Record
  has Chat selected (PR1) → reseed → address bar (`.webSearch` = search) shows Review (rule) → Shortcuts
  "Set Profile: Chat" → address bar shows Chat (PR2) → Full Access off → textarea shows "Chat, read only",
  tap → "Turn on Full Access to switch profiles", long-press opens no menu (PR4) → Full Access on → system
  keyboard restored.
- Keyboard control is matched as button label `Profile`, value = name (`"<name>, read only"` without Full
  Access). App side: segment label `Chat` with `selected == YES`.
- Soft (reported at the end, scene continues): the long-press menu not drawing (falls back to cycling to
  Chat) and a menu opening without Full Access. Everything else stops the scene with `FAIL-<step>`.
- Seed (Runner DEBUG launch args, `AppDelegate.applySceneProfileArguments`): `-ShinsokuSceneResetSelection
  YES` removes `activeProfile.v1` (Dart's launch sync then writes the default selection);
  `-ShinsokuSceneFieldRules '{"search":"review"}'` writes `fieldRules.v1` directly (P4's `setFieldRules`
  channel not merged; known kinds only, `{}` clears). The scene leaves `fieldRules.v1 = {search: review}` and
  the selection at automation/Chat behind.
  Superseded (scene-rules): `-ShinsokuSceneFieldRules` is gone; the scene sets the rule in Settings ›
  Profiles › Field rules and resets it to None at the end. See `scene-rules-implementation.md`.
- Assumes the built-in profile list (Dictation, Chat, Review, ZH -> EN); an edited list fails at the first
  name check.
- Verified: `tool/ios_keyboard_scene.sh --build-only` under Xcode 27.2 → TEST BUILD SUCCEEDED, no warnings in
  AppDelegate / KeyboardSceneTests; `python3 tool/review_lint.py` ok. Not run on a simulator.
