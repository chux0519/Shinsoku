# Agent notes for Shinsoku

Shinsoku is a voice input tool: speak, get clean text where you type. The product direction is **Flutter
everywhere** (user decision 2026-11-18): the iOS app (`mobile/`, Flutter + a Swift keyboard extension) is the
active line of work; Android and a Flutter desktop app follow.

Practices: pfstack (potafree stack), the same stack and principles as Shinphony. Read this file first; details
live in the linked docs. Platform history and older engineering notes are in [AGENT.md](AGENT.md); current
priorities are in [Roadmap.md](Roadmap.md).

## Code layout and the Qt freeze
- `mobile/` — Flutter app (`lib/`), iOS host (`ios/Runner`), keyboard extension (`ios/ShinsokuKeyboard`, Swift).
- `src/`, `tests/`, `CMakeLists.txt`, `vcpkg.json`, `packaging/` — the Qt/C++ desktop app. **Frozen
  (2026-11-18):** no new features, only fixes the user asks for. It stays until a Flutter desktop app reaches
  parity (Nearby server, history, MCP, CLI); its removal is its own iteration, confirmed by the user.
- New shared logic goes into Dart, not C++.

## Roles
- **Coordinator** (main session): talks with the user, writes plans and acceptance criteria, reviews every diff
  and screenshot, merges, releases. Owns shared resources: the dedicated simulators, physical devices, App
  Store Connect / TestFlight.
- **Implementers** (workers in hc): one task = one branch = one worktree = one writer. They code, run tier A,
  write implementation notes. They never launch other agents, touch shared resources, merge or release.
- Launch: `tool/spawn_worker.sh <name> <worktree> [sonnet]` (it runs `proxy_on; nvm use --lts;` first; without
  them the API returns 403). Check the worker with `hc read <t>` before `hc send`. Model by difficulty:
  mechanical work → sonnet; design, concurrency, protocol, security, native/keyboard extension → the default
  (Opus). State the choice in the plan.
- Hot shared files (`mobile/lib/main.dart`, the theme/component layer, `ios/Runner.xcodeproj`) have one writer
  at a time.
- Machine load: at most 2 workers and 1 simulator; heavy commands run with `nice -n 10`.

## Never lose work
- Every change goes through a branch and a PR; the coordinator merges and pushes main right away.
- Implementers: each small verifiable unit ends in check → commit → push. Nothing older than a few minutes
  lives only on this machine. Remote: `git@github.com:chux0519/Shinsoku.git` (SSH).
- Every report and every pause writes `docs/iterations/<id>/round-NN/STATE.md` (done, in progress, next,
  open decisions, how to verify).

## Plan first, bounded rounds
- Plan + acceptance criteria → user confirms → implement. Scope changes need a new confirmation.
- At most 3 implement → accept → review rounds per iteration; then stop and ask the user.
- An agent saying "done" is not evidence. Record the exact source state that was tested.

## Evidence tiers
- **A (default):** host-rendered screenshots (Flutter golden/widget renders) + `flutter analyze` + lint +
  test diff.
- **B:** one device / one theme / relevant scenes, only when A cannot prove it (keyboard extension, timing,
  microphone, gestures, iPhone Duo hinge/posture). Coordinator only. Timing issues: record once, cut frames at
  PHASE marks.
- **C:** full matrix (iPhone, iPhone Duo folded/unfolded, light/dark) once before a store submission.
- Simulators are shared with other projects in turns (disk is tight: never create new ones, user decision
  2026-11-18). Use only these, by UDID, never `booted`; boot one at a time and shut it down when done:
  `iPhone 17` iOS 27.2 `9080FE77-1FF9-49A1-B165-55DCA4ECED64`, `iPhone Duo` iOS 27.1
  `2F378AB1-D2CC-44E6-9E0F-5AE02FBAFFFC`. Before booting, check no other project's simulator is running
  (`xcrun simctl list devices booted`). Dev builds use their own bundle id, never `net.potafree.shinsoku` on a
  device that has the TestFlight build.
- Evidence goes under `build/ui-review/<iteration-id>/round-NN/<device>/` (not in git; keep the latest 2
  iterations).

## Design
- [DESIGN.md](DESIGN.md) is the single source of truth; only the coordinator edits it.
- Every screenshot gets a review (Impeccable / HIG, plus the iPhone Duo skills for foldable layouts); obvious
  defects are fixed in the same round; advice that conflicts with DESIGN.md goes to the user as a "design
  conflicts" table.

## Rules, invariants, numbers
- New pitfall → a rule in [docs/review_rules.md](docs/review_rules.md), and in `tool/review_lint.py` if it can
  be checked automatically. Every review runs `python3 tool/review_lint.py`.
- Timing / state bugs (recording, keyboard ↔ app handoff, Nearby pairing) → a numbered rule in
  [docs/design/state_invariants.md](docs/design/state_invariants.md) first, then a model-based test
  (`tool/model_check.py` pattern), then a named regression case.
- Only new failures count (`tool/test_diff.sh`, runs `cd mobile && flutter test`). A wall-clock benchmark that
  fails in the full run is rerun alone before it counts.

## Authorizations
- Standing (no need to ask): push branches, open PRs, merge PRs to main — **only when the change can be rolled
  back** (a plain revert restores the previous state; no data migration, deletion, or external side effect).
- Always ask: TestFlight uploads, store submissions and releases, creating simulators (never: disk), deleting the Qt code,
  anything public or hard to undo.
- An authorization never extends to a different context. If the tool refuses an action, ask; don't work around.

## Hard rules
- Never print tokens, passwords, API keys or review credentials; read them inside scripts only.
- Fixtures use `example-*` hosts only; no real host or user names in the repo or public exports.
- `rm -rf "${D:?}"` form only; look before deleting or overwriting.
- Don't change global toolchains or shared SDKs; ask the user to apply patches.
- Temporary LAN previews serve a copied folder only and are stopped after use; generated HTML has
  `<meta charset="utf-8">`.
- Build numbers go through `tool/next_build.py`, never a blind `sed`.
- Replies to the user: short, action items first, in the user's language.
