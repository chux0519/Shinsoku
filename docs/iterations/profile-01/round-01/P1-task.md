# P1 — shared profile store in the App Group

Implementer brief. Read AGENTS.md, DESIGN.md, and `docs/iterations/profile-01/plan.md` (precedence and
PR1–PR4). Branch `profile-01-p1-store`, this worktree. No simulators, no nested agents, no merging.
P0 runs in parallel in `mobile/lib/services/provider_settings.dart` + scripts — don't touch those files.

Today: profiles live in flutter_secure_storage (`voice_profiles.v1`, `mobile/lib/services/voice_profiles.dart`);
find where the selected profile lives (Record view selector) and how recording reads it.

Build:
1. Dart `ActiveProfileStore` (pure model + persistence): profile list stays owned by Dart; the active
   selection is `{profileId, source: manual|automation|fieldRule|default, at: ISO8601}`. A pure resolver
   `resolveActive(selection, profiles, fieldRuleMatch?, keyboardAppearedAt?)` implementing the plan's
   precedence (manual vs automation: newest wins; field rule never overrides a manual/automation event made
   after the keyboard appeared; missing id → default — PR3). Unit tests for each rule.
2. Mirror to the App Group through a method channel registered at the existing single registration point in
   `mobile/ios/Runner/AppDelegate.swift` (`registerChannels`): Dart → native `publishProfiles(list without
   secrets: id, name)` and `setActive(selection)`; native → Dart `readActive()` (the keyboard and App Intents
   will write it later; read on app resume and before recording starts). App Group suite
   `group.net.potafree.shinsoku`, keys `profiles.v1` (JSON array) and `activeProfile.v1` (JSON object). No API
   keys or intents' prompt text in the group (prompt text stays in the keychain store).
3. Recording uses the resolved active profile at start (PR1). The Record selector writes a `manual` selection.
4. Migration: first launch copies the current list/selection to the group; idempotent.
5. Invariants: write PR1–PR4 into `docs/design/state_invariants.md` (from the plan); P5 adds the model test
   later — keep the resolver pure so it can be driven by it.

Verify: analyze, test diff, lint, host renders unchanged (`tool/host_review.sh profile-01/round-01/p1`);
native: `cd mobile && flutter build ios --simulator --debug --no-pub` (Xcode 27.2 is the default now); restore
Flutter's regenerated tracked files (pbxproj SPM rewrite, Podfile.lock, pubspec.lock, AppFrameworkInfo.plist,
scheme) before committing — commit only your changes.
Commit per unit, push, PR, `P1-implementation.md` + `STATE.md`, reply with the PR URL. Model: Opus.
Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy -u all_proxy gh`.
