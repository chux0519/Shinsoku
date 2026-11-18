# U1 — split mobile/lib/main.dart (no behaviour change)

You are an implementer (read AGENTS.md first: roles, hard rules). Branch `ios-ui-01-u1-split`, this worktree only.
Do not launch other agents, do not boot simulators, do not merge.

Goal: `mobile/lib/main.dart` (4091 lines) becomes < 200 lines (app entry + `ShinsokuMobileApp`). Move code,
don't rewrite it. Target layout (adjust if a seam is clearly better; explain in implementation.md):
- `lib/app/` — app widget, `MobileShell` + state, deep link / keyboard bridges.
- `lib/services/` — transcription (`RealTranscriptionService`, Bailian/Soniox live sessions, WAV), smoke-test
  runners, provider settings + stores, voice profiles, drafts model/store.
- `lib/features/record/`, `features/drafts/` (DraftsView, DraftEditorScreen, DraftCard), `features/settings/`
  (SettingsView, ConfigTextField, save button, SmokeTestPanel), `features/common/` (AppHeader, ShinsokuMark,
  InfoPanel, StatusChip, EmptyState).
- `lib/nearby/` stays.
Private `_` classes used across files become public only where needed; keep names otherwise.

Units (each: `cd mobile && flutter analyze` no new issues + `bash tool/test_diff.sh` no new failures +
`python3 tool/review_lint.py` → commit → push `origin ios-ui-01-u1-split`):
1. services, 2. features, 3. app shell + slim main.dart.
Do not revert unrelated churn from `flutter test` in pubspec.lock / analysis_options.yaml — just don't commit it.

Done: write `docs/iterations/ios-ui-01/round-01/U1-implementation.md` (final layout, any API visibility
changes, analyze/test output, exact commit) and `STATE.md`, push, open a PR to main (`gh pr create`), and reply
with the PR URL. Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
