# P4 implementation notes — Settings guide, field rules, active-profile reason

Branch `profile-01-p4-ui`. Model: sonnet.

## What changed
- **Use in apps** (`features/settings/use_in_apps_view.dart`): one-line summary, "When the app is opened" (3 steps)
  and "When the app is closed" (2 steps) as numbered rows, a note that tapping the profile name in the keyboard also
  switches (it stays until an automation runs again), one primary action "Open Shortcuts". `iosMajorVersion < 16` shows a
  warning status line "The Shortcuts actions need iOS 16 or later." The version comes from a third native method,
  `systemMajorVersion` (round 2, coordinator decision), via `UseInAppsView.withSystemVersion`.
- **Field rules** (`features/settings/field_rules_view.dart`): rows Search / Web address / Email / Message, each opens
  a sheet with None + profiles. `services/field_rules.dart`: `FieldRules` (kind → profile id), `FieldRulesStore`
  (secure storage, mirrored to `fieldRules.v1` via `setFieldRules`). Deleting a profile prunes rules that point to it
  (`_saveVoiceProfiles`); launch also prunes and re-mirrors.
- **Record reason** (`services/profile_reason.dart`): "Chat · set by you", "Chat · set by automation",
  "Dictation · default" (field-rule source shows as default: only the keyboard sees the field). Secondary text under
  the status line; no new colours.
- **Native** (profiles channel, `AppDelegate.swift` + `ProfileGroup.swift`): `setFieldRules` (sanitizes: JSON object,
  only `search|url|email|message`, non-empty string ids) and `openShortcuts` (opens `shortcuts://`).

## Deviation from the brief
The brief says "one native method". I added `openShortcuts` (accepted in review; `systemMajorVersion` too), because the project has no `url_launcher`
and adding a dependency changes `pubspec.lock`. Say if you prefer the dependency.

## Verified
- `flutter analyze`: clean. `tool/test_diff.sh`: no new failures. `python3 tool/review_lint.py`: ok.
- New tests: `test/services/field_rules_test.dart` (persistence, mirror, prune on delete, sanitizing, picker UI,
  guide, reason wording and Record line).
- Renders: `build/ui-review/profile-01/round-01/p4/` (iphone + duo-inner-landscape, dark/light: use-in-apps,
  field-rules, record-idle, settings). Looked at iphone use-in-apps dark, field-rules light, record-idle dark.
- `flutter build ios --simulator --debug --no-pub`: built; Flutter-regenerated tracked files restored.
- Not run: simulator/device (not allowed). The `setFieldRules` / `openShortcuts` native paths are build-checked only.
