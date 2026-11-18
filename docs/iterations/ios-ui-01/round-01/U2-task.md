# U2 — keyboard extension redesign

You are an implementer (read AGENTS.md and DESIGN.md §2–§6 first). Branch `ios-ui-01-u2-keyboard`, this
worktree only. Files: `mobile/ios/ShinsokuKeyboard/**` (and its Info.plist / the keyboard target in
`ios/Runner.xcodeproj` only if a new Swift file must be added). Do not touch `mobile/lib/`. Do not boot or use
simulators (the coordinator does tier B), do not launch agents, do not merge.

Current: `KeyboardViewController.swift` — title row, two teal buttons, three secondary buttons, two-line hint,
hard-coded colours, Delete doesn't repeat.

Build, top to bottom, at a height that matches the system keyboard (≈ 216–260 pt depending on device):
1. Status row (28 pt): SF Symbol + one short line ("Ready", "Latest text ready", "Turn on Full Access to
   insert"); globe key on the right only when `needsInputModeSwitchKey` is true.
2. Main row: **Insert latest** (left; shows the first words of the latest text, truncated; disabled look when
   nothing available), **Record** (centre, largest, accent fill, mic, ≥ 56 pt high, light haptic; keeps the
   current `shinsoku://dictation` open path), **Delete** (right; repeats while held: 0.4 s delay then ~0.08 s,
   accelerating to word deletes after ~1.5 s is optional).
3. Edit row: Space (wide), Return (title from `textDocumentProxy.returnKeyType`: return/go/search/send/done…).
- No title row, no permanent hint paragraph; the Full Access hint only appears when `hasFullAccess` is false.
- Latest text source: clipboard (as today) when Full Access is on; keep it simple, no new App Group code.
- Colours from DESIGN.md §2 tokens in a small `KeyboardTheme.swift`, light/dark by `traitCollection`;
  radii control 10; touch targets ≥ 44; pressed state = fill change; VoiceOver labels on every key.
- Status text: no animation loops.

Verification you can do (tier A for native): `cd mobile && flutter build ios --simulator --no-pub --debug`
or `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator
CODE_SIGNING_ALLOWED=NO build` with `nice -n 10`; it must build with no new warnings in the extension.
Optionally a SwiftUI/UIKit preview isn't needed. Each unit (theme, layout, delete-repeat/return type) → build →
commit → push `origin ios-ui-01-u2-keyboard`.

Done: `docs/iterations/ios-ui-01/round-01/U2-implementation.md` (layout, sizes, what to check on the
simulator, exact commit) and `STATE.md`, push, open a PR to main, reply with the PR URL.
Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
