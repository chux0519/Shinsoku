# P2 — App Intents: "Set Shinsoku Profile" / "Get Shinsoku Profile"

Implementer brief. Read AGENTS.md, `docs/iterations/profile-01/plan.md`, `docs/design/state_invariants.md`
(PR1–PR4) and P1's `mobile/lib/services/active_profile.dart` + `ProfileGroupChannel` in
`mobile/ios/Runner/AppDelegate.swift` (App Group keys `profiles.v1`, `activeProfile.v1`). Branch
`profile-01-p2-intents`. Files: `mobile/ios/Runner/**` (new Swift files OK, add them to the Runner target in
the pbxproj), Info.plist if needed. No Dart changes except reading a new source if strictly required. No
simulators, no nested agents, no merging.

Build (iOS 16+, `@available` guarded; app min stays iOS 15):
1. `ProfileEntity: AppEntity` (id, name) with an `EntityQuery` reading `profiles.v1` from the App Group
   (suggestedEntities = all; entities(for:) by id).
2. `SetShinsokuProfileIntent: AppIntent` — parameter `profile: ProfileEntity`; writes `activeProfile.v1` =
   `{profileId, source: "automation", at: ISO8601 now}` using the same sanitizer as `ProfileGroupChannel`
   (share one Swift helper, don't duplicate the JSON shape); `openAppWhenRun = false`; returns a dialog
   "Shinsoku profile: <name>". Must run without opening the app (works from a personal automation with Run
   Immediately).
3. `GetShinsokuProfileIntent` — returns the current active ProfileEntity (resolve missing id → first profile,
   like PR3) as an output value.
4. `ShinsokuShortcuts: AppShortcutsProvider` with phrases, e.g. "Set \(.applicationName) profile" — keep
   phrases short; English only for now.
5. Make sure the App Intents metadata is generated for the Runner target (Xcode 27.2 default toolchain);
   confirm `Metadata.appintents` exists in the built app.
6. Write the result notes for the coordinator's tier-B check: how to run the intent from the Shortcuts app in
   the simulator via XCUITest (you may extend `mobile/ios/KeyboardSceneTests` with a separate test
   `testProfileIntentScene` that opens Shortcuts, adds/runs the Set Shinsoku Profile action, then shows the
   keyboard status — the keyboard part arrives in P3, so assert the App Group value via a Runner launch that
   reads it, or leave a TODO the coordinator will finish after P3).

Verify: `cd mobile && flutter build ios --simulator --debug --no-pub`; restore Flutter-regenerated tracked files
before committing. Commit per unit, push, PR, `P2-implementation.md` + STATE.md section, reply with PR URL.
Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u
http_proxy -u all_proxy gh`.
