# P4 — Settings: "Use in apps" guide, field-kind rules, active-profile reason

Implementer brief. Read AGENTS.md, DESIGN.md (component layer `mobile/lib/ui/`, §5–§7), `docs/iterations/
profile-01/plan.md`, `docs/design/state_invariants.md` (PR2 rewritten 2026-11-19: strict precedence manual >
automation > field rule > default; a field rule applies only when the selection source is default),
`mobile/lib/services/active_profile.dart`, `mobile/ios/Runner/ProfileGroup*.swift`. Branch `profile-01-p4-ui`.
Files: `mobile/lib/**`, `mobile/test/**`, and one native method in the profiles channel. Don't touch
`mobile/ios/ShinsokuKeyboard/**` or `mobile/ios/KeyboardSceneTests/**` (P3 scene work runs in parallel).
No simulators, no nested agents, no merging.

1. Settings › Profiles › **Use in apps** screen (component layer only): what it does in one line; numbered
   steps to create a Shortcuts personal automation "When <App> is opened → Set Shinsoku Profile: <profile>"
   (Run Immediately on), and a second "When <App> is closed → Set Shinsoku Profile: <default>"; one primary
   action "Open Shortcuts" (`shortcuts://` URL); a short note that the keyboard can also switch by tapping the
   profile name. Empty/edge copy: if iOS < 16, say the Shortcuts actions need iOS 16.
2. Settings › Profiles › **Field rules**: rows for Search, Web address, Email, Message → pick a profile or
   "None". Persist in Dart and mirror to the App Group key `fieldRules.v1` (`{kind: profileId}`, kinds
   `search|url|email|message`) via a new `setFieldRules` method on the existing profiles channel (sanitize in
   Swift like the others: only known kinds, non-empty ids). Deleting a profile removes rules that point to it.
3. Record: under the status line, show which profile is active and why — "Chat · set by you", "Chat · set by
   automation", "Dictation · default" (field-rule source shows only in the keyboard). Secondary text, no new
   colours.
4. Host renders for the new screens (iphone + duo-inner, dark/light) via `tool/host_review.sh
   profile-01/round-01/p4`; widget tests for rules persistence and the reason line.

Verify: analyze, test_diff, lint, renders, `flutter build ios --simulator --debug --no-pub`; restore
Flutter-regenerated tracked files before commit. Commit per unit, push, PR, `P4-implementation.md` + STATE.md
section, reply with PR URL. Model: sonnet. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via
`env -u https_proxy -u http_proxy -u all_proxy gh`.
