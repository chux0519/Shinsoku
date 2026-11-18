# U4 — iPhone Duo: adaptive shell, division-region bridge, posture-safe recording

You are an implementer (read AGENTS.md, DESIGN.md §6, then `/Volumes/ZT/repos/iphone-duo-skills/skills/
iphone-duo-flutter/SKILL.md`, `iphone-duo-dual-pane-patterns/SKILL.md`, `reference/device-facts.md` —
read-only). Branch `ios-ui-01-u4-duo`, this worktree. No simulators (coordinator runs tier B), no nested agents,
no merging. U3 just landed: components in `mobile/lib/ui/`, shell in `lib/app/` (`ShellScaffold`, `SkTabBar`,
`skPageInsets`), tier-A renders via `tool/host_review.sh` (devices iphone, duo-outer, duo-inner-portrait,
duo-inner-landscape).

## Units (each: analyze + `tool/test_diff.sh` + `review_lint` + `tool/host_review.sh` → commit → push; open
the PR after unit 1 as draft)
1. **Division-region bridge**, ported from Shinphony (read-only reference):
   `/Volumes/ZT/repos/Shinphony/lib/src/division_regions.dart` and the `DivisionRegionObserver` /
   `DivisionRegionStream` in `/Volumes/ZT/repos/Shinphony/ios/Runner/AppDelegate.swift`. Channel name
   `net.potafree.shinsoku/division_regions`; new file `mobile/lib/platform/division_regions.dart`; native code
   in `mobile/ios/Runner/` (keep `@available(iOS 27.1, *)` guards; degrade to "no regions" everywhere else).
   Unit tests with `testEvents` (malformed input, cap, empty).
2. **Adaptive shell**: branch on constraints, not device. Compact (< 600 wide, incl. Duo outer and folded):
   today's iPhone layout. Regular (≥ 600, Duo inner): two panes split at the division region when present
   (else at the centre): left = Record (status, transcript, record button); right = Drafts list, with Settings
   / Desktop reachable via a NavigationRail-style side control or the right pane's own top switcher — choose
   per the dual-pane-patterns skill and explain. Nothing interactive or text-bearing inside the division
   region. Independent left/right/top/bottom safe insets (84 pt trailing bar on landscape inner; 84/95 top/
   bottom portrait inner).
3. **Posture-safe state**: recording/listening state and the current transcript live above the layout switch
   (not in a pane widget that is rebuilt), so compact ↔ regular switches mid-recording never stop or reset it.
   Add a widget test that starts a fake recording, resizes 402→951 wide and back, and asserts the capture state
   and transcript survive. Add invariant D1 to `docs/design/state_invariants.md` ("posture/size change never
   changes capture state").
4. Host renders: add a `duo-inner-*` variant with a fake division region (centre, 0 width hinge line is fine)
   for record-idle, record-listening, drafts-list, settings. Note anything the renders cannot prove as
   "pending B" (real hinge region values, live fold during recording, under-display camera).

Done: `U4-implementation.md`, `STATE.md`, PR ready, reply with PR URL and render path.
Commit trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy -u
all_proxy gh …`.
