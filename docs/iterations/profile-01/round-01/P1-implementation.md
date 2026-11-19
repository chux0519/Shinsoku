# P1 implementation notes — shared profile store

Branch `profile-01-p1-store`. Commits: 0408a3c (model + resolver + invariants), 1ca808b (native channel),
3a5218e (shell wiring), plus this notes commit.

## What was there
- Profile list: `flutter_secure_storage` key `voice_profiles.v1` (`VoiceProfileStore`), unchanged.
- Selection: only an in-memory `_selectedProfileIndex` in `MobileShell` (reset to 0 on every launch, never
  persisted). Recording read `_activeProfile` at **stop**, so a pick during processing could change it.

## What changed
- `mobile/lib/services/active_profile.dart` (new):
  - `ProfileSource` (wire names `manual`, `automation`, `fieldRule`, `default`), `ProfileSelection`
    `{profileId, source, at}` (ISO-8601 UTC), JSON encode/decode (invalid → null).
  - Pure `resolveActive(selection, profiles, {fieldRuleMatch, keyboardAppearedAt})` → `ResolvedProfile`
    (profile + source). Rules: field rule applies only if the selection is not an explicit (manual /
    automation) event at or after `keyboardAppearedAt`; without `keyboardAppearedAt` a field rule never beats an
    explicit selection; missing id → default = first profile in the list (PR3).
  - `ProfileGroupBridge` (interface) + `MethodChannelProfileGroupBridge` on `net.potafree.shinsoku/profiles`.
  - `ActiveProfileStore`: `sync(profiles)` (publish ids/names; keep the group's selection; write `default`
    only if none or if it points at a missing id — idempotent migration + PR3 repair), `refresh()` (re-read the
    group), `selectManually(id)`. All channel calls are best-effort (MissingPlugin/PlatformException → keep the
    in-memory selection).
- `mobile/ios/Runner/AppDelegate.swift`: `ProfileGroupChannel.register(messenger:)` called from
  `registerChannels`. Methods `publishProfiles` / `setActive` / `readActive`; suite `group.net.potafree.shinsoku`,
  keys `profiles.v1`, `activeProfile.v1` (JSON strings). Native re-serializes only `id`,`name` and
  `profileId`,`source`,`at` (and validates `source`), so prompt text or keys can't land in the group even if
  Dart sent them. Logs carry byte counts only. Kept in AppDelegate.swift to avoid a pbxproj edit.
- `mobile/lib/app/mobile_shell.dart`: active profile = `resolveActive(store.selection, profiles)`; Record
  selector → `selectManually`; new profile → manual pick of it; launch → `sync` (migration); save/delete →
  `sync` (PR3); app resume → `refresh`; `_startRecording` refreshes and resolves once, stores
  `_recordingProfile`, and stop/transcribe uses it (PR1). Keyboard deep-link recording goes through the same
  path.
- `docs/design/state_invariants.md`: group **PR** with PR1–PR4 and the event alphabet for P5.

## Tests
- `mobile/test/services/active_profile_test.dart` (20): each precedence rule, JSON, store migration
  idempotence, PR3 repair, refresh picks up automation, no-plugin fallback, no prompt text in the list.
- `mobile/test/app/active_profile_shell_test.dart` (4): launch migration, Record selector writes `manual`,
  keyboard-written selection shows on launch and after resume, PR3 repair on launch.

## Verification (source state 3a5218e + this commit, docs only)
- `flutter analyze`: no issues. `tool/test_diff.sh`: no new failures (0 known). `review_lint.py`: R01–R03 ok.
- `tool/host_review.sh profile-01/round-01/p1`: 124 images, byte-identical to a baseline rendered with main's
  `mobile_shell.dart` (`p1-base`): 0 differ.
- `flutter build ios --simulator --debug --no-pub` (Xcode 27.2): built. Regenerated tracked files restored.
- Not run: simulator/device (tier B is the coordinator's; P2/P3 will exercise the group from native).

## Notes for later units
- P2/P3 writers: write `activeProfile.v1` as a JSON string with the same fields; `at` ISO-8601 with `Z`.
  The newest write is the selection (PR2 ordering = write order); the app only rewrites it on a manual pick,
  on migration, or when the id is missing.
- P3 keyboard: compute with the same rules as `resolveActive` (field rule vs `keyboardAppearedAt`).
