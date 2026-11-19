# profile-01 round 01 — acceptance (coordinator)

Tested source: main @ c5000d2 (P0 #13, P1 #14, P5 #16, P2 #15, P3 #17, P3 scene #18, P4 #19, scene fix #20).

## Tier A
- `flutter analyze` clean; `tool/test_diff.sh` no new failures (baseline 0); `review_lint` R01–R04 ok.
- P5 model test: 7 fixed seeds in the default run (< 1 s); 3000 seeds pass. Found and fixed two real bugs
  (keyboard Record used a different profile than shown — PR1; clock skew reordered automation vs keyboard —
  PR2, later superseded by the strict precedence).
- Host renders for Use in apps, Field rules, Record reason line (iphone + duo-inner, dark/light).

## Tier B — iPhone 17, iOS 27.2, Xcode 27.2 (shared sim 9080FE77), all on main, light + dark: PASS
- `SCENE_TEST=KeyboardSceneTests/KeyboardSceneTests` — keyboard insert/App Group/deep links (regression).
- `SCENE_TEST=KeyboardSceneTests/ProfileIntentSceneTests` — Shortcuts "Set/Get Shinsoku Profile" (Review,
  Chat) without opening the app; app then records with Chat.
- `SCENE_TEST=KeyboardSceneTests/ProfileKeyboardSceneTests` — keyboard shows default; tap cycles; long-press
  menu; Record → app uses the shown profile (PR1); field rule Search → Review set through
  `shinsoku://settings/field-rules`; Safari address bar shows Review; after "Set Shinsoku Profile: Chat" the
  address bar shows Chat (PR2 strict); Full Access off → read-only with lock (PR4).

## Decisions recorded
- 2026-11-19 user: strict precedence manual > automation > field rule > default; a field rule applies only
  when the selection source is default (PR2 rewritten). Manual vs automation: newest wins.
- 2026-11-19 user: no API keys in the binary (P0, lint R04, rule M06).
- New product deep links: `shinsoku://settings/field-rules`, `shinsoku://settings/use-in-apps`.
- New review rule M07: scenes don't scroll Flutter pages (stale accessibility frames); use deep links.

## Pending C (device)
- The Shortcuts *App opened / App closed* automation triggers themselves.
- Entering provider keys after P0 on a TestFlight build; M06 `strings` check of the IPA before submission.
