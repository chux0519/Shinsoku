# P3 scene — tier-B harness for the keyboard profile switch

Implementer brief. Read AGENTS.md, `docs/iterations/profile-01/plan.md`, PR1–PR4 in
`docs/design/state_invariants.md` (PR2 strict precedence, 2026-11-19), `docs/iterations/profile-01/round-01/
P3-implementation.md` (tier-B checklist), and the existing harness `mobile/ios/KeyboardSceneTests/` +
`tool/ios_keyboard_scene.sh` (helpers: English launch args, en/zh labels, FAIL-* attachments,
ensureSystemKeyboard/restoreSystemKeyboard, Runner seed/reset launch args). Branch `profile-01-p3-scene`.
Files: `mobile/ios/KeyboardSceneTests/**`, `tool/ios_keyboard_scene.sh`, and DEBUG-only launch args in
`mobile/ios/Runner/` if needed to seed profiles/selection/field rules. P4 edits `mobile/lib/**` and adds a
`setFieldRules` channel method in parallel — don't edit those. No simulators (coordinator runs it), no nested
agents, no merging.

New test `KeyboardSceneTests/ProfileKeyboardSceneTests` (PHASE screenshots each step):
1. Seed via Runner DEBUG launch args: profiles published, selection reset to default, field rules
   `{search: <Review id>}` (write `fieldRules.v1` directly in DEBUG if P4's channel isn't merged yet).
2. Safari data: textarea (message/other kind) with the Shinsoku keyboard: status row shows the default
   profile name.
3. Tap the profile name → next profile, source manual; long-press → menu lists all profiles; pick Chat.
4. Record → `shinsoku://dictation?profile=<Chat id>` → Runner Record shows Chat (PR1) (handle mic alert / the
   "Provider settings required" state as in the deep-link phases).
5. Reset selection to default; focus Safari's address bar (search kind) → keyboard shows Review (field rule).
6. Run "Set Shinsoku Profile: Chat" via Shortcuts (reuse ProfileIntentSceneTests helpers) → back to the
   address bar → keyboard shows Chat, not Review (PR2 strict precedence).
7. Full Access off → name shown read-only with the lock; tap explains why (PR4). Restore Full Access on.
8. Restore the system keyboard at the end.

Build-check only (`tool/ios_keyboard_scene.sh --build-only`), commit, push, PR, short notes in
`P3-implementation.md` (scene section) + STATE.md, reply with PR URL and the exact SCENE_TEST command.
Model: Opus. Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u
http_proxy -u all_proxy gh`.
