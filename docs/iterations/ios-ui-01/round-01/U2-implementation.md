# U2 — keyboard extension redesign: implementation notes

Branch `ios-ui-01-u2-keyboard`. Round 1: `89cc9d5` (theme + key), `4851f74` (layout). Round 2 (privacy fix):
see STATE.md for the tested commit.

## Files
- `mobile/ios/ShinsokuKeyboard/KeyboardTheme.swift` (new) — DESIGN.md §2 colour tokens as dynamic `UIColor`s
  (light/dark from `traitCollection`), pressed fills (raised + text 8 %, accent blended 18 % towards canvas),
  radius 10, spacing, fonts (13 status, 15 keys, 15/600 Record, 12 caption).
- `mobile/ios/ShinsokuKeyboard/KeyboardKey.swift` (new) — `KeyboardKey: UIControl` (mirrors `SkKey`): icon +
  title + optional one-line detail, styles `raised` / `accent`, pressed state = fill change, `isDimmed`
  (looks disabled but still takes taps), `hitOutset` for small visible keys, `.keyboardKey` trait.
- `mobile/ios/ShinsokuKeyboard/KeyboardViewController.swift` — rewritten layout + `KeyRepeater`.
- `mobile/ios/Runner.xcodeproj/project.pbxproj` — only the two new files added to the keyboard target
  (IDs `8A6D121A…121D`).

## Layout (top to bottom)
Height constraint on the input view: 216 pt portrait (226 when width ≥ 400), 176 in landscape (compact
vertical size class). Margins 8 pt sides/bottom (safe-area aware), 4 pt top, 8 pt between rows/keys.
Background `frame`, keys `raised`, Record `accent`.

| Row | Height | Content |
|---|---|---|
| Status | 28 | SF Symbol + one line in text-secondary (warning colour for Full Access / open failure, success after insert). Globe (44 wide, hit area 44 high) on the right only when `needsInputModeSwitchKey`. |
| Main | rest (≈ 112 portrait, ≈ 72 landscape; ≥ 56 required) | **Insert** ("Insert" when the Shinsoku marker is on the pasteboard, "Paste" otherwise; never shows clipboard content; dimmed only without Full Access) · **Record** (42 % width, accent fill, mic 22 pt, "Record", light haptic on touch-down, opens `shinsoku://dictation` via SwiftUI `openURL` then `extensionContext.open` like before) · **Delete** (Insert is 1.4× Delete's width). |
| Edit | 48 (≥ 40) | Space (70 %) · Return (30 %, title from `returnKeyType`: return/go/search/join/next/route/send/done/call/continue). |

Status texts: "Ready", "Latest text ready", "Turn on Full Access to insert" (only when `hasFullAccess` is
false), "Nothing to paste — tap Record", "Inserted", "Opening Shinsoku…", "Open Shinsoku from the Home Screen".
No animation. Action-driven status changes are posted as VoiceOver announcements; appear-time ones are not.

Delete: one delete on touch-down, repeats after 0.4 s every 0.08 s, switches to word deletes (trailing
whitespace + previous word) after 1.5 s; stops on touch up/outside/cancel and on `viewWillDisappear`.

Latest text (round 2, privacy fix): App Groups are **not** configured (both `Runner.entitlements` and
`ShinsokuKeyboard.entitlements` are empty), so the app hands text over through the pasteboard with a marker:
`AppDelegate.publishLatestText` writes one item `{public.utf8-plain-text: text, "net.potafree.shinsoku.latest":
empty Data}` with `.localOnly` and a 10-minute expiration. On appear the keyboard only calls
`UIPasteboard.general.contains(pasteboardTypes: ["net.potafree.shinsoku.latest"])` (metadata, no content read,
Full Access only): marker present → status "Latest text ready", key "Insert"; absent → status "Ready", key
"Paste". The string is read **only inside the Insert/Paste tap**. No preview is shown and nothing from the
clipboard goes into accessibility values. Success haptic on insert.

VoiceOver labels: "Insert latest text" (value "Shinsoku text", or "Needs Full Access") / "Paste",
"Record" (hint "Opens Shinsoku to record"), "Delete", "Space", Return (label follows the key title),
"Next keyboard".

## Verification done (tier A for native)
- `xcodebuild -project mobile/ios/Runner.xcodeproj -target ShinsokuKeyboard -configuration Debug -sdk
  iphonesimulator CODE_SIGNING_ALLOWED=NO build` (with `nice -n 10`): **BUILD SUCCEEDED, 0 warnings** in the
  extension (baseline on `main` had 2 deprecation warnings, `contentEdgeInsets` / `imageEdgeInsets`, now gone).
- Round 2: keyboard target as above (0 warnings) and `flutter build ios --simulator --debug` (Runner incl.
  the `AppDelegate` change): built. The files that build regenerates (SwiftPM migration in pbxproj/scheme,
  Podfile.lock, pubspec.lock, AppFrameworkInfo.plist, analysis_options.yaml) were reverted, not committed. `python3 tool/review_lint.py` ok. No Dart changes, so no `flutter analyze`/test diff.

## What to check on the simulator (tier B, coordinator)
1. Notes field, light + dark, Full Access on and off: status row text, globe visibility, no clipping at 216 pt.
2. **No paste banner on keyboard appear** (with Full Access on, after copying text in another app and after
   publishing from Shinsoku).
3. Record in Shinsoku → back in Notes: status "Latest text ready", key "Insert", no text shown; tap inserts,
   status "Inserted". Copy text elsewhere (no marker): status "Ready", key "Paste"; tap pastes it.
   Marker expires after 10 minutes (text too).
3b. Full Access off: Insert dimmed, status "Turn on Full Access to insert" in warning colour.
4. Hold Delete: single delete, repeat after ~0.4 s, word deletes after ~1.5 s, stops on release.
5. Return title in Safari address bar ("go"), Messages ("send" only where the host sets it), search fields.
6. Record opens Shinsoku (`shinsoku://dictation`), light haptic on device.
7. Landscape (176 pt) and iPhone Duo folded/unfolded widths: rows keep ≥ 56 / ≥ 40 pt.
8. VoiceOver: every key has a label; Insert reads the preview text.

## Open points
- Heights 216/226/176 are estimates of the system keyboard; adjust after the tier B screenshots.
- Side effect of the round 2 handoff: published text leaves the clipboard after 10 minutes and no longer goes
  to Universal Clipboard (`.localOnly`). If users rely on pasting it elsewhere later, App Groups would be the
  cleaner handoff (needs entitlements + provisioning; coordinator/user decision).
