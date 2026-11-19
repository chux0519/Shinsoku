# P3 — keyboard: active profile in the status row, field-kind rules

Branch `profile-01-p3-keyboard`, **stacked on P2** (`profile-01-p2-intents` @ 290d1a1, PR #15): the keyboard
shares P2's `Runner/ProfileGroup.swift` by target membership (it's Foundation-only, no Runner symbols, so no
`ProfileGroupCore.swift` split was needed). Merge #15 first; then this PR's diff is P3 only (rebase if P2 changes).

## What changed (all in `mobile/ios/ShinsokuKeyboard/` + 5 pbxproj lines for the keyboard target)
- `KeyboardProfileResolver.swift` (Foundation only): faithful port of Dart `resolveActive` — field rule only
  when the stored selection isn't an explicit (manual/automation) event that differs from
  `selectionAtKeyboardAppear` (no clock comparison when the capture exists; `at >= appearedAt` otherwise);
  else stored selection if the id exists; else first profile (PR3). Unparseable `at` = no selection (as Dart's
  `fromJson`). Timestamps parse Dart's microsecond and Swift's millisecond forms. Also `fieldRules.v1`
  parser, `next(after:)` cycling, `dictationURL(profileId:)`, and `LastShownProfile` (extension's own
  `UserDefaults.standard`, readable without Full Access — PR4).
- `KeyboardProfileButton.swift`: plain `UIButton` (secondary text 13 pt, `textSecondary`, truncating tail,
  one line), 28 pt drawn + 8 pt hit outset top/bottom = 44 pt; width ≥ 44, ≤ 45 % of the status row. Trailing
  `chevron.up.chevron.down` when switchable, leading `lock.fill` when read-only. `FieldKind.detect` from the
  proxy, first match: email (keyboard or content type) → URL keyboard → search (`.webSearch` keyboard, e.g.
  Safari's address bar, or Search/Google/Yahoo return key) → URL content type → message (Send return key) →
  other.
- `KeyboardViewController.swift`: `viewWillAppear` and `hostDidBecomeActive` capture `keyboardAppearedAt` +
  `selectionAtKeyboardAppear`, then resolve. `textDidChange` re-resolves when the field kind changes. Tap →
  next profile, long-press → `UIMenu` (checkmark on current); both write `{profileId, source: manual, at}` via
  `ProfileGroup.writeSelection`. VoiceOver: label "Profile", value = name, custom actions "Use <name>".
  Without Full Access: last shown name + lock; tap shows status "Turn on Full Access to switch profiles"
  (warning, lock icon); no menu. Record opens `shinsoku://dictation?profile=<shown id>` (PR1); no profile
  known → plain `shinsoku://dictation`. Log category `profile` (ids, kind, source only; never names).
- No new colours; no new App Group keys written by the keyboard except `activeProfile.v1`.

## Decisions to review
1. `hostDidBecomeActive` counts as a new keyboard appearance (re-captures). So an automation that ran while
   the host app was opening is "before" the keyboard and a matching field rule wins over it — same as P1
   open decision 1 (literal plan precedence).
2. `.webSearch` (Safari address bar) maps to `search`, not `url`.
3. Profile button hidden when no profile is known (app never published a list; or no Full Access and never
   shown before).

## Tier A evidence
- `mobile/ios/ShinsokuKeyboard/ResolverChecks/run.sh` → "resolver checks: all passed" (29 checks; compiles
  the resolver + `Runner/ProfileGroup.swift` on the Mac; not part of any target).
- `xcrun --sdk iphonesimulator swiftc -typecheck` of the keyboard sources: no warnings.
- `cd mobile && flutter build ios --simulator --debug --no-pub` (Xcode 27.2): ✓; regenerated tracked files
  restored. `python3 tool/review_lint.py`: ok. No Dart changes.

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
6. Shortcuts "Set Shinsoku Profile: Review" (P2), then open Notes → keyboard shows Review.
7. Field rule: write `fieldRules.v1` = `{"search":"<ChatId>"}` into the group (until P4's Settings UI lands:
   `xcrun simctl spawn <udid> defaults write group.net.potafree.shinsoku fieldRules.v1 '{"search":"<id>"}'` may
   not reach the app-group container — use P4's UI if merged). Safari address bar → keyboard shows Chat, log
   `kind=search source=fieldRule`. Tap name → manual pick beats the rule for that session.
8. **Full Access off** (Settings › Keyboards › Shinsoku): last shown name with a lock glyph, no chevron;
   tap → status "Turn on Full Access to switch profiles" (warning colour); long-press → no menu; Record still
   passes the shown id.
9. Light + dark, VoiceOver: "Profile, Chat, button", custom actions "Use …".

Not tested by me: anything on a simulator (implementers don't touch shared simulators).
