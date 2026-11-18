# U3 — DESIGN.md component layer, tier-A host renders, migrate every screen

You are an implementer (read AGENTS.md, then DESIGN.md in full — it is the spec). Branch
`ios-ui-01-u3-components`, this worktree only. Files: `mobile/lib/**`, `mobile/test/**`, `tool/host_review.sh`
(new). Do not touch `mobile/ios/**` (keyboard is U2, Duo native bridge is U4). No simulators, no nested agents,
no merging. `main.dart` was just split (U1): screens live in `mobile/lib/features/**`, shell in `lib/app/`.

## Units (each: `cd mobile && flutter analyze` clean + `bash tool/test_diff.sh` + `python3 tool/review_lint.py`
→ commit → push `origin ios-ui-01-u3-components`; open the PR after unit 1, mark it draft until done)

1. **Tokens + theme** `lib/ui/tokens.dart`, `lib/ui/theme.dart`: DESIGN.md §2 colours (dark + light, exact
   hex), §3 type scale/spacing/radii. A `ThemeData` built from tokens (no `ColorScheme.fromSeed`). Theme
   follows the system.
2. **Components** `lib/ui/`: SkButton (primary/secondary/text), SkIconButton, SkRecordButton, SkCard,
   SkSection + SkListRow, SkSegmented, SkSheet, SkTextArea, SkStatusLine, SkBadge (DESIGN §5). 44 pt targets,
   selection = fill not outline, Reduce Motion respected, Semantics labels.
3. **Host render harness (tier A)** modelled on Shinphony's `tool/host_review.sh`
   (`/Volumes/ZT/repos/Shinphony/tool/host_review.sh`, read-only reference): a flutter test under
   `mobile/test/host_review/` gated by an env var, rendering each scene × theme (dark, light) × device to PNG
   under `build/ui-review/<run>/`, plus an `index.html` contact sheet (`<meta charset="utf-8">`). Devices
   (logical pt, use real system font if available): iphone 402×874 (safe top 62, bottom 34); duo-outer 466×678
   (safe trailing 84); duo-inner portrait 669×951 (safe top 84, bottom 95) and landscape 951×669 (safe
   trailing 84). Scenes: record-idle, record-listening, record-result, drafts-empty, drafts-list,
   draft-editor, settings, nearby, keyboard-setup (if a setup guide screen exists; else skip and note), plus
   one Dynamic Type 2.0× text-scale variant of record and settings on iphone. Use fakes, no network.
4. **Migrate screens** to the component layer, one commit per screen: Record, Drafts + editor, Settings,
   Nearby, common widgets (AppHeader/StatusChip/EmptyState/InfoPanel → components). Follow DESIGN §7 per
   screen (one primary action, status line with the fix for errors, empty state one line). Remove raw
   `Color(0x…)` outside `lib/ui/`. Keep behaviour and existing widget tests passing (update finders only if
   text legitimately changed; say which).
   Layout: single column; do NOT build the Duo two-pane layout (that is U4) — but make every screen
   constraint-driven (LayoutBuilder/MediaQuery.sizeOf, independent left/right safe insets, no
   `width - padding.left * 2`).
5. **Audit**: `docs/iterations/ios-ui-01/round-01/U3-audit.md` — table screen × DESIGN section × finding ×
   fixed/how, from your own review of the renders (before vs after). List anything you think conflicts with
   DESIGN.md as a "design conflicts" table instead of changing DESIGN.md (coordinator owns it).

Add review rule R03 to `tool/review_lint.py` + `docs/review_rules.md`: no `Color(0x` or `ColorScheme.fromSeed`
in `mobile/lib/` outside `mobile/lib/ui/`.

Done: `U3-implementation.md` (components, harness usage, render command, exact commit) + `STATE.md`, push,
PR ready for review, reply with PR URL and the render output path. Model: you are Opus — take design care.
Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`. gh needs proxy variables unset
(`env -u https_proxy -u http_proxy -u all_proxy gh …`); git push over SSH works.
