# R3 — App Store screenshots, 6.9" iPhone, 10 languages

Branch `release-01-r3-screenshots`, worktree `/Volumes/ZT/repos/Shinsoku-wt/r3-shots`. Model: Opus. Tier A;
the coordinator runs the simulator (tier B) for keyboard frames. Read AGENTS.md, DESIGN.md,
`docs/iterations/release-01/plan.md` ("Keys"), `docs/store/metadata/*.yaml` (wording), `tool/host_review.sh`
and `mobile/test/host_review/`.

## Work
1. **Store scenes** (host-rendered, real Flutter screens with store fixtures, each locale's own language):
   (1) Record with live text mid-sentence, (2) Record done with the cleaned text + profile, (3) Drafts list,
   (4) Profiles (built-ins + one custom, Pro), (5) Field rules (Pro, owned), (6) Desktop paired (owned).
   Fixture text is natural, in the locale's language, believable content (no lorem, no real names/hosts:
   `example-*`); key fields only empty or masked (•••); status bar clean (9:41, full battery) if the harness
   draws one.
2. **Keyboard frame** (7): the Shinsoku keyboard over a chat/notes app — provide an XCUITest scene method
   (`KeyboardSceneTests/StoreSceneTests.swift`, build-only for you) that sets the app language via
   `-AppleLanguages (<lang>) -AppleLocale <locale>` launch arguments for the host app and a neutral page in
   Safari/Notes, and screenshots PHASE frames; the coordinator runs it on iPhone 17 (1206×2622).
3. **Framing** (`tool/store_frames.py`, Pillow if available else document the dependency; no global installs —
   use a venv under `build/`): 1320×2868 canvas, the brand background (DESIGN.md colours), a caption (≤ 2 short
   lines, from a `captions` block you add to each `docs/store/metadata/<locale>.yaml`; check fits, no clipping,
   CJK fonts available on macOS), the screen scaled into a rounded device-free frame. Output
   `build/store/screenshots/<locale>/NN-<scene>.png`.
4. **Upload** (`tool/store_screenshots.py`): dry-run by default, lists what it would replace in the
   APP_IPHONE_67 display type (6.9" accepts 1320×2868) for each locale via `tool/asc.py`; `--apply` deletes the
   old set's screenshots and uploads in order (reserve → upload parts → commit with md5, like the IAP
   screenshot). **You run only the dry run.**
5. Contact sheet `build/store/screenshots/index.html` (`<meta charset="utf-8">`).

## Done when
All 6 host scenes × 10 locales rendered and framed, no clipped text (pseudo-length check for captions), the
contact sheet reviewed by you, `flutter analyze`, `tool/test_diff.sh`, `python3 tool/review_lint.py`,
`tool/ios_keyboard_scene.sh --build-only` pass; restore regenerated files; commit per unit, push;
`R3-implementation.md` + STATE.md; PR open. Reply with the PR URL.
