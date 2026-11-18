# STATE: U1 (round-01)
- Done: services, features, app shell split; main.dart is 56 lines; analyze/test_diff/lint clean.
- In progress: none. Next: coordinator review and merge; U3 can build `lib/ui/` on this layout.
- Open decisions: none.
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`.

# STATE: U3 (round-01)
- Done: tokens + theme, component layer, tier-A host renders, Record / Drafts + editor / Settings (+ keyboard
  setup, profile sheet) / Nearby / shell migrated, R03, audit. Details: U3-implementation.md, U3-audit.md.
- In progress: none. Next: coordinator review of PR #5 and the renders; then U4 (Duo two-pane) builds on
  `ShellScaffold` / `SkTabBar` / `skPageInsets`.
- Open decisions: the "design conflicts" table in U3-audit.md (frame vs raised for sections, drafts row lines,
  extra components for §5).
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`,
  `tool/host_review.sh ios-ui-01/round-01/u3-after` → `build/ui-review/ios-ui-01/round-01/u3-after/index.html`.

# STATE: U4 (round-01)
- Done: division-region bridge, adaptive two-pane shell, posture-safe capture (D1, D2 + model test), fold host
  renders. Details: U4-implementation.md. PR #6.
- In progress: none. Next: coordinator review + tier B on the iPhone Duo simulator (fold/unfold mid-recording,
  real region values, occlusion) — see "Pending tier B".
- Open decisions: stacked order (Record at the bottom), switcher vs rail, draft editor spanning panes.
- Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`,
  `tool/host_review.sh ios-ui-01/round-01/u4-after` → `build/ui-review/ios-ui-01/round-01/u4-after/index.html`.
