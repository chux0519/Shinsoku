# P0 — no API keys in the app binary (release blocker)

Implementer brief. Read AGENTS.md first. Branch `profile-01-p0-keys`, this worktree only. No simulators, no
nested agents, no merging, never print key values (don't cat `.env`; names only).

1. `mobile/scripts/build_testflight.sh`: the dart-define loop must not pass `BAILIAN_API_KEY` or
   `SONIOX_API_KEY` (keep non-secret ones: API base, model names, realtime URL/model). Add a guard that aborts
   if any `*_API_KEY` would be passed.
2. `mobile/lib/services/provider_settings.dart`: defaults for `bailianApiKey` / `sonioxApiKey` become empty;
   no `String.fromEnvironment` for any key. Non-secret defaults may stay.
3. `mobile/lib/services/smoke_test.dart`: keys must not be compiled into the app. If the smoke runner is only
   used by integration tests, move key reading to the test side (e.g. `integration_test/` reads
   `--dart-define` only in test builds, or the runner takes keys as constructor parameters supplied by the
   test). The release app must contain no key-shaped compile-time constant.
4. Lint R04 in `tool/review_lint.py` + `docs/review_rules.md` (M06 manual: "no API keys in app binaries;
   users enter keys in Settings; check the IPA with `strings` before submission"): R04 fails on
   `fromEnvironment\(['"][A-Z_]*API_KEY` under `mobile/lib/` and on `*_API_KEY` in the dart-define list of
   `mobile/scripts/*.sh`.
5. Verify: `cd mobile && flutter analyze`, `bash tool/test_diff.sh`, `python3 tool/review_lint.py`; widget
   tests that relied on env keys must use fakes. Confirm the "Provider settings required" path still shows when
   no key is saved (existing widget test or add one).

Commit per unit, push, PR, write `P0-implementation.md` + `STATE.md`, reply with the PR URL. Model: sonnet.
Trailer `Co-Authored-By: Claude <noreply@anthropic.com>`; gh via `env -u https_proxy -u http_proxy -u all_proxy gh`.
