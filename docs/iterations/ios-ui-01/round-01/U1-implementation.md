# U1 implementation: split mobile/lib/main.dart

`main.dart` went from 4091 to 56 lines (`main()` + `ShinsokuMobileApp`). Code was moved, not rewritten.

## Layout (lib/)
- `app/`: `mobile_shell.dart` (MobileShell + state), `bridges.dart` (KeyboardBridge, DeepLinkBridge)
- `services/`: `capture_types` (CaptureState, CommitSuffix), `transcription_service` (RealTranscriptionService,
  Bailian live session, timing consts), `smoke_test` (config, Soniox/Bailian runners), `wav`, `provider_settings`
  (+store), `voice_profiles` (+store), `drafts` (DraftEntry; there is no draft store in the old code)
- `features/record/record_view.dart`; `features/drafts/drafts_view.dart` (DraftsView, DraftEditorScreen, DraftCard);
  `features/settings/settings_view.dart` (SettingsView, save button, ConfigTextField, SmokeTestPanel);
  `features/common/widgets.dart` (AppHeader, ShinsokuMark, InfoPanel, StatusChip, EmptyState)
- `nearby/` unchanged. Seam differences from the task: none besides the above file grouping.

## Visibility changes (private -> public, needed across files)
`BailianRealtimeLiveSession`, `bailianRealtime*` consts, `bailianAsrModeRealtime/Qwen`, `defaultVoiceProfiles`,
`WavPcm16`, `parseWavPcm16`, `parseWavPcm16Bytes`, `RealTranscriptionService.finishBailianRealtimeSession`,
`DraftEditResult`. Side effect: `BailianSmokeTestRunner._parseWavPcm16` was renamed too (now `parseWavPcm16`) by my
bulk rename; harmless.
Test change: `test/widget_test.dart` imports `services/drafts.dart` for `DraftEntry` (it used to come from main.dart).

## Verification (source = HEAD of this branch)
- `flutter analyze`: No issues found (same as before).
- `bash tool/test_diff.sh`: no new failures (0 known).
- `python3 tool/review_lint.py`: R01, R02 ok.
- Not committed: churn in `mobile/pubspec.lock`, `mobile/analysis_options.yaml`.
- Commits: U1.1 services 52ad82a, U1.2 features, U1.3 app shell (see `git log`).
