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
empty Data}` with `.localOnly` (the 10-minute expiration was dropped in `5fb4f55`). On appear the keyboard only calls
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
3b. Full Access off: Insert dimmed, status "Turn on Full Access to insert" in warning colour.
4. Hold Delete: single delete, repeat after ~0.4 s, word deletes after ~1.5 s, stops on release.
5. Return title in Safari address bar ("go"), Messages ("send" only where the host sets it), search fields.
6. Record opens Shinsoku (`shinsoku://dictation`), light haptic on device.
7. Landscape (176 pt) and iPhone Duo folded/unfolded widths: rows keep ≥ 56 / ≥ 40 pt.
8. VoiceOver: every key has a label; Insert reads the preview text.

## Open points
- Heights 216/226/176 are estimates of the system keyboard; adjust after the tier B screenshots.
- Side effect of the round 2 handoff: published text no longer goes
  to Universal Clipboard (`.localOnly`). If users rely on pasting it elsewhere later, App Groups would be the
  cleaner handoff (needs entitlements + provisioning; coordinator/user decision).

## Part 3 — tier-B scene harness (`e0090bb`)
Files: `mobile/ios/KeyboardSceneTests/KeyboardSceneTests.swift` (new XCUITest target `KeyboardSceneTests`, host
Runner, iOS 16.4+, IDs `8A6D1220…122D`, testable in `Runner.xcscheme`, not parallelizable) and
`tool/ios_keyboard_scene.sh`.

**Command (coordinator, simulator already booted, in a shell after `proxy_on; nvm use --lts`):**

    xcrun simctl list devices booted     # make sure no other project's simulator is up
    bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh \
      9080FE77-1FF9-49A1-B165-55DCA4ECED64 build/ui-review/ios-ui-01/round-02/iphone-17/keyboard

Xcode 27.2 is required for the iOS 27 simulators: the default Xcode 26.0.1 can't drive them (the test runner
hangs, DTServiceHub bless failure). `with-xcode.sh` selects it for that one command only.

Language: the shared simulators run in Chinese, and their language must not be changed. The scene launches
Settings and Safari with `-AppleLanguages (en) -AppleLocale en_US`, and still matches every system label in
English and Chinese (通用 / 键盘 / 键盘 / 添加新键盘… / 允许完全访问 / 允许, globe 下一个键盘). Our own key labels are
always English. Every wait goes through `require`/`check`: on failure it attaches `FAIL-<step>` (exported
as `FAIL-<step>.png` next to the PHASE shots) and logs `SCENE FAIL <step>` before failing.
Each failure also attaches the foreground app's element tree (`debugDescription`), exported as
`FAIL-<step>.txt`. Settings navigation (`navTap`) finds rows by label across all element types (iOS 27
Settings rows are not cells): either the exact label or "<label>, <value>", or a label prefix for Shinsoku /
Add New Keyboard / Allow Full Access. It skips matches inside the navigation bar, scrolls the row into view,
and if it's still not hittable, taps the centre of its frame.

The script never boots or shuts down a simulator. It runs `flutter build ios --simulator --debug --config-only`
and `xcodebuild build-for-testing` (ad-hoc signing, `nice -n 10`, DerivedData in
`build/ios-keyboard-scene/`). Then, for `light` and `dark` (`xcrun simctl ui <UDID> appearance`), it runs
`test-without-building -only-testing:KeyboardSceneTests`. It restores the original appearance and checks out
any tracked file under `mobile/` that Flutter regenerated (only files that were clean before the run).
Output per look: `<out>/<look>/PHASE-xx-<name>.png`, `<look>.xcresult`, `<look>.log`, `<look>-scene.txt`
(SCENE lines: phases + paste-banner result). Exit code 1 if either run failed (screenshots up to the failure
are still exported). Build check only: `tool/ios_keyboard_scene.sh --build-only` (generic simulator).

Phases: 01 keyboard-added → 02 full-access-off → 03 no-full-access → 04 edit-keys (Return, Space, Delete)
→ 05 delete-hold (2 s; asserts the field is empty) → 06 full-access-on → 07 latest-ready (marker item written
by the test, same shape as AppDelegate; asserts "Latest text ready" + Insert key) → 08 inserted (asserts the
field contains the text) → 09 paste (plain text, asserts the "Paste" key). Any "Allow Paste" / "pasted from"
UI gets an extra `PHASE-xx-paste-banner-<where>` shot and a SCENE log line. It is recorded, not a failure.

Idempotent: the keyboard is only added if missing; Full Access is set to the wanted value, accepting the
"Allow" alert. Settings is relaunched and walked back to its root first.

Text field: Safari, a `data:` page with one textarea, opened with `XCUIApplication.open(url)`; fallback:
typed into the address bar after switching to the system keyboard. Not an app field: the app's free text
fields need a recorded draft or edit persisted provider settings, and U3 moves them.

Unverified until the first run (fix in place if they break): Settings labels on iOS 27 ("General", "Keyboard",
"Keyboards", "Add New Keyboard…", "Allow Full Access"); the globe button's label ("Next keyboard"); Safari
accepting an externally opened `data:` URL.

Install and signing (fix 3): `xcodebuild test` did not install the host app on the simulator (only the
`.xctrunner`), so Shinsoku never showed up in Add New Keyboard. After `build-for-testing` the script checks
that `Runner.app/PlugIns/ShinsokuKeyboard.appex` exists, prints both signatures, runs
`xcrun simctl install <UDID> Runner.app`, then prints `simctl spawn <UDID> pluginkit -m -v -i
net.potafree.shinsoku.keyboard` and the installed `net.potafree.shinsoku*` apps. Simulator signing now
defaults to ad-hoc (`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
PROVISIONING_PROFILE_SPECIFIER=`) for the app, the extension and the test runner. Override it with
`SCENE_SIGN_ARGS`. KeyboardSceneTests already depends on Runner (`8A6D1229…`). If a
hardware keyboard is connected in Simulator.app, the software keyboard stays hidden. Run it headless or turn
that off.

## Part 3 finding — Insert returns no text with Full Access + marker (investigation)
Scene run (coordinator): marker visible ("Latest text ready"), but Insert → `UIPasteboard.general.string` empty
→ "Nothing to paste". Changes for the next run:
- `ClipboardReader` (in `KeyboardViewController.swift`) logs with `Logger(subsystem:
  "net.potafree.shinsoku.keyboard", category: "clipboard")` on every Insert tap: hasFullAccess, changeCount,
  hasStrings, types, numberOfItems, and what `string`, `value(forPasteboardType:)` (utf8 + plain),
  `data(forPasteboardType: utf8)` and `items` return. It logs only nil / type / length, **never content**
  (a password could be on the clipboard). It then takes the first non-empty of those sources.
- Writers (`AppDelegate.publishLatestText` and the scene test) add a `public.plain-text` representation next
  to `public.utf8-plain-text`.
- If types are visible but no content comes back, the keyboard shows "Clipboard locked — long-press the
  field, Paste" (warning colour), not "Nothing to paste".
- The script saves `<out>/<look>-keyboard.log` (`simctl spawn log show --last 5m`, that subsystem).

Hypothesis (most likely first):
1. **Paste privacy (iOS 16+).** Types and markers are metadata and readable without consent; content written
   by another app needs paste consent. A keyboard extension can't show the "Allow Paste" prompt, so the read
   is denied silently: no banner, `string == nil`. That matches what we saw exactly. If the log shows
   types=[…utf8…, marker] with every source nil, this is it. Then programmatic Insert from the clipboard can't
   work in the keyboard, and the "Paste" key can't either. The real handoff would be an **App Group** (shared
   container the app writes and the keyboard reads: entitlement on both targets + provisioning). That's a
   user/coordinator decision; until then the UI says "Clipboard locked…".
2. Type coercion: a Swift String under utf8 in `setItems` is not exposed through `.string`. The fallbacks and
   the extra plain-text representation would fix it; the log would show source 1–4 succeeding.
3. `.localOnly`: unlikely (it only affects Universal Clipboard); test by dropping it if 1 and 2 are ruled
   out.

Diagnosis (coordinator run, light): fullAccess=true, types=[public.plain-text, public.utf8-plain-text,
net.potafree.shinsoku.latest], numberOfItems=1, every read nil, items=[[:]]. The content is redacted: iOS 27
paste privacy. To rule out `.localOnly`, run
`SCENE_NO_LOCALONLY=1 bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh <UDID> <out>`.
Only the test writer drops `.localOnly`; AppDelegate is unchanged. The test prints `SCENE writer localOnly=…`.
App Group work waits for the user's decision.

## App Group handoff (user decision 2026-11-18)
The `.localOnly` experiment showed the content still redacted (`items=[[:]]`), which confirms paste privacy.
The keyboard can't read clipboard content, so the latest text now goes through an App Group.

- **Entitlements:** `com.apple.security.application-groups = [group.net.potafree.shinsoku]` in
  `Runner.entitlements` and `ShinsokuKeyboard.entitlements`.
- **App** (`AppDelegate.publishLatestText(_:)`, used by the `publishLatestText` channel): writes
  `latestText`, `latestId` (UUID), `latestAt` (Date) to `UserDefaults(suiteName: group)`. It also still puts
  the plain text on the clipboard (`.localOnly`) for the user's own pasting. The marker type is gone.
- **Keyboard** (`LatestTextStore`): reads the group (only with Full Access).
  - When `latestId != lastInsertedId`: status "Latest text ready", accessibility value "New Shinsoku text".
  - Insert inserts the text, stores `lastInsertedId` in the group, and shows "Inserted". When there's nothing
    new it re-inserts and shows "Inserted again".
  - No latest: status "Ready", key dimmed, tap → "Nothing yet — tap Record".
  - The text is never shown on screen or in accessibility values. The clipboard read path and its fallbacks
    are removed. One log line with booleans only (`groupAvailable`, `hasLatest`, `isNew`).
- **Scene hooks (Debug only):** Runner's Debug config now has `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`.
  - `-ShinsokuSceneResetLatest YES` clears the group keys.
  - `-ShinsokuSceneSeedLatest <text>` calls `publishLatestText`, the same code as the channel.
- **Scene steps 5–7:** Full Access on → reset → "Ready", Insert → "Nothing yet" → seed "Scene text 1" →
  "Latest text ready" → Insert → "Inserted", and the textarea contains "Scene text 1" → Insert again →
  "Inserted again". The plain-clipboard "Paste" phase is gone.
- **Script:** prints the App Group of the built *and* the installed app + appex and fails if it's missing.
  Simulator builds carry entitlements in the binary's `__TEXT,__entitlements` section
  (`Entitlements-Simulated.plist`), not in the code signature, so `codesign -d --entitlements -` shows an
  empty dict there. The script reads the section (marked "(simulated)") and falls back to the signature.

**Before TestFlight / device builds:** register the App Group `group.net.potafree.shinsoku` in the developer
portal, enable it for both App IDs (`net.potafree.shinsoku` and `net.potafree.shinsoku.keyboard`), and
regenerate the provisioning profiles. Automatic-signing device builds fail until that's done. The coordinator
asks the user before touching the portal.

### Seed diagnostics (after the run that failed at status-latest-ready)
- AppDelegate logs `Logger(subsystem: "net.potafree.shinsoku.app", category: "latest")`:
  - `scene args: count reset seedLength` (DEBUG; read from `ProcessInfo.processInfo.arguments` before the
    Flutter engine starts).
  - `scene reset: synchronize`.
  - `publish: suite keys length synchronize readBack` (always; never the text).
- Verified: the seed code is compiled into the Debug build (`Runner.app/Runner.debug.dylib` contains
  `ShinsokuSceneSeedLatest`).
- Test: after launching Runner it waits for a window plus 2 s and takes `PHASE-xx-runner-reset` /
  `runner-seed` screenshots, then goes back to Safari.
- Keyboard: re-reads the group on `viewWillAppear` and on `NSExtensionHostDidBecomeActive`, because the
  keyboard can stay on screen across the app switch. Each state log line says which trigger fired.
- Script: saves `<look>-app.log` next to `<look>-keyboard.log`.
