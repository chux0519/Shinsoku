# P3 — keyboard: show and switch the active profile, field-kind detection

Implementer brief. Read AGENTS.md, DESIGN.md (§2, §5 SkKey, §6 keyboard), `docs/iterations/profile-01/plan.md`,
`docs/design/state_invariants.md` PR1–PR4, P1's `mobile/lib/services/active_profile.dart` and
`mobile/ios/Runner/ProfileGroup.swift` (App Group keys `profiles.v1`, `activeProfile.v1`, JSON shape, sanitizer).
Branch `profile-01-p3-keyboard`. Files: `mobile/ios/ShinsokuKeyboard/**` only (+ adding files to the keyboard
target in the pbxproj). P2 is editing `mobile/ios/Runner/**` and `KeyboardSceneTests` — don't touch those.
No simulators, no nested agents, no merging.

1. Shared code: the keyboard needs the same read/write/sanitize helper as `ProfileGroup.swift`. Add that file
   to the keyboard target as well (target membership, not a copy). If it pulls in Runner-only symbols, factor a
   tiny `ProfileGroupCore.swift` both targets compile, and tell the coordinator (P2 would then rebase).
2. Status row: show the active profile name (from the resolver: manual/automation/fieldRule/default, same
   precedence as Dart — port `resolveActive` faithfully incl. `selectionAtKeyboardAppear`; capture the
   selection and time in viewWillAppear). Tap the name → cycle to the next profile; long-press → a compact
   list (UIMenu) of profiles. A pick writes `{profileId, source: manual, at}` (Full Access required; without
   it, show the name read-only with a lock glyph — PR4).
3. Field-kind detection from `textDocumentProxy` (keyboardType, textContentType, returnKeyType): map to kinds
   `search`, `url`, `email`, `message`, `other`. Rules are read from the App Group key `fieldRules.v1`
   (`{kind: profileId}`); P4 writes them from Settings. No rules → no effect.
4. Record key: open `shinsoku://dictation?profile=<id>` with the profile the keyboard shows (PR1, merged in P5).
5. DESIGN: status row stays one line; profile name is a secondary-text button, ≥ 44 pt hit area, truncates;
   no new colours.

Verify: build the keyboard target + Runner (`cd mobile && flutter build ios --simulator --debug --no-pub`,
Xcode 27.2 default), restore Flutter-regenerated tracked files before commit. Write the tier-B checklist for
the coordinator in `P3-implementation.md` (what to tap, what the status row must show). Commit per unit, push,
PR, STATE.md section, reply with PR URL. Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`;
gh via `env -u https_proxy -u http_proxy -u all_proxy gh`.
