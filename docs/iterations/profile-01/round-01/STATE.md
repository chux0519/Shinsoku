# STATE — profile-01 P5 (model test)
- Done: harness, model test PR1–PR4, two bugs fixed (keyboard record handoff carries the shown profile;
  field-rule check is clock-skew free). Details: `P5-implementation.md`.
- In progress: none. Next: coordinator review; P3 must use `?profile=` and `selectionAtKeyboardAppear`.
- Open decisions: keep or drop the skew fix (see P5-implementation.md).
- Verify: `cd mobile && flutter analyze && flutter test test/model`; `SHINSOKU_MODEL_SEEDS=3000 flutter test
  test/model/profile_model_test.dart`; `bash tool/test_diff.sh`; `python3 tool/review_lint.py`.

---

# profile-01 round-01 — STATE (P1 worker)

## Done
- P1 shared profile store: model + pure resolver + App Group channel + shell wiring + migration + PR1–PR4
  invariants. PR on branch `profile-01-p1-store`. Details: `P1-implementation.md`.

## In progress
- Nothing. P1 approved in review; rebased onto main after P0 (#13).

## Next
- P2 (App Intents) and P5 (model test drives `resolveActive` / `ActiveProfileStore` with a fake bridge).

## Open decisions (for the coordinator / user)
1. **Automation vs field rule.** Per the plan, a field rule applies when no explicit event is newer than the
   keyboard appearing. A Shortcuts "When Slack is opened → Chat" automation fires *before* the keyboard
   appears, so a configured field rule (e.g. "message field → X") would override it in Slack. Implemented
   literally; if automation should beat field rules regardless of time, it's a one-line change in
   `resolveActive`.
2. **Default profile** = first profile in the list (there is no explicit "default" setting yet).

## How to verify
- `cd mobile && flutter analyze && flutter test test/services/active_profile_test.dart test/app/active_profile_shell_test.dart`
- `tool/test_diff.sh`, `python3 tool/review_lint.py`
- `tool/host_review.sh profile-01/round-01/p1` (unchanged vs main: 124/124 byte-identical)
- `cd mobile && flutter build ios --simulator --debug --no-pub`, then restore regenerated tracked files.

---

# STATE — profile-01 P0 (merged, #13)
- Done: all five items of P0-task.md (see P0-implementation.md).
- In progress: none. Next: coordinator review, merge; next TestFlight build needs keys entered once in Settings.
- Open decisions: none.
- Verify: `cd mobile && flutter analyze`; `bash tool/test_diff.sh`; `python3 tool/review_lint.py`.

---

# STATE — profile-01 P2 (App Intents, branch `profile-01-p2-intents`)
- Done: `ProfileGroup.swift` (shared App Group store + sanitizer, used by `ProfileGroupChannel`),
  `ProfileIntents.swift` (ProfileEntity + query, Set/Get Shinsoku Profile, AppShortcutsProvider), Metadata.appintents
  confirmed; tier-B scene `ProfileIntentSceneTests` + `SCENE_TEST` selector in `tool/ios_keyboard_scene.sh`.
  Details: `P2-implementation.md`.
- In progress: none.
- Next: coordinator runs the tier-B scene on iPhone 17 (never run yet; selectors for the Shortcuts app are a
  best guess); P3 adds the keyboard check (TODO in the scene).
- Open decisions: none new (P1's automation-vs-field-rule question still stands).
- Verify: `cd mobile && flutter build ios --simulator --debug --no-pub` (then restore regenerated tracked
  files; check `build/ios/iphonesimulator/Runner.app/Metadata.appintents`); `tool/ios_keyboard_scene.sh
  --build-only`; `python3 tool/review_lint.py`.
