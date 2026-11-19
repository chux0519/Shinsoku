# P0 implementation — no API keys in the app binary

- `build_testflight.sh`: `BAILIAN_API_KEY` / `SONIOX_API_KEY` removed from the dart-define list; loop aborts if any `*_API_KEY` name appears.
- `provider_settings.dart`: key defaults are `''`; no key `fromEnvironment`.
- `smoke_test.dart` / `mobile_shell.dart`: smoke runs read keys from the saved provider settings (Settings), not compile-time constants.
- R04 added to `tool/review_lint.py` and `docs/review_rules.md` (+ M06 manual: `strings` check of the IPA before submission). Verified R04 fails on a planted `fromEnvironment('FOO_API_KEY')`.
- Test: `mobile/test/services/provider_settings_defaults_test.dart` (defaults empty, not configured). The existing `record_view_test` covers the "Provider settings required" fix link.
- Checks: `flutter analyze` clean, `tool/test_diff.sh` no new failures, `review_lint.py` R01–R04 ok.
- Not done: the `strings` check of a real IPA (no build made here). Smoke-run on simulator not run (no simulators for implementers).
