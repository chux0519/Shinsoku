# Shinsoku Mobile

The mobile app is now a Flutter project that targets Android and iOS from one
codebase.

## Current Shape

- `lib/`: Flutter application code
- `android/`: generated Flutter Android runner
- `ios/`: generated Flutter iOS runner
- `test/`: widget tests for the mobile shell

The previous Android Kotlin implementation, iOS SwiftUI implementation, and
shared native mobile core have been removed. Platform-specific code should stay
limited to Flutter runner integration unless a feature genuinely requires a
native plugin or platform channel.

## What Works Now

- Material 3 mobile shell
- responsive bottom navigation / navigation rail
- record, drafts, and settings surfaces
- profile selection for dictation, chat, and review workflows
- simulated capture-to-draft flow
- basic toggles for microphone, keyboard insertion, and cloud processing state

The speech backend and real platform insertion flows are still placeholders.

## Development

```bash
cd mobile
flutter pub get
flutter test
flutter run -d "iPhone 16 Pro"
```

Use `flutter devices` to list available simulators and devices.

## App Icons

Mobile app icons are generated from the shared Shinsoku square-bolt SVG at
`resources/icons/square-bolt.svg`, matching the desktop app and the previous iOS
icon set.

```bash
mobile/scripts/generate_app_icons.sh
```

## Real Soniox Smoke Test

The app has an opt-in simulator smoke-test mode for real Soniox transcription.
It is disabled unless `SHINSOKU_SMOKE_TEST=soniox` is passed as a Dart define.

```bash
cd mobile
set -a
source ../.env
set +a

flutter build ios --simulator --no-pub \
  --dart-define=SHINSOKU_SMOKE_TEST=soniox \
  --dart-define=SONIOX_API_KEY="$SONIOX_API_KEY"

xcrun simctl install <SIMULATOR_UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <SIMULATOR_UDID> com.shinsoku.shinsokuMobile
```

By default the test streams the Mozilla DeepSpeech `LDC93S1.wav` smoke-test
recording from GitHub to Soniox and marks the run as passed when realtime
transcription tokens are received.

## Real Bailian Smoke Test

The app also has an opt-in simulator smoke-test mode for Bailian. It exercises
OpenAI-compatible Chat Completions, Chat Completions streaming, Responses,
Qwen-ASR audio URL recognition, and Fun-ASR realtime WebSocket recognition.

```bash
cd mobile
set -a
source ../.env
set +a

flutter build ios --simulator --no-pub \
  --dart-define=SHINSOKU_SMOKE_TEST=bailian \
  --dart-define=SHINSOKU_SMOKE_AUDIO_URL=asset://assets/smoke-ldc93s1.wav \
  --dart-define=BAILIAN_API_BASE="$BAILIAN_API_BASE" \
  --dart-define=BAILIAN_API_KEY="$BAILIAN_API_KEY" \
  --dart-define=BAILIAN_OPENAI_MODEL="$BAILIAN_OPENAI_MODEL"

xcrun simctl install <SIMULATOR_UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <SIMULATOR_UDID> com.shinsoku.shinsokuMobile
```

Defaults are `qwen3-asr-flash` for Qwen-ASR, `fun-asr-realtime` for realtime
ASR, and the DashScope Beijing WebSocket endpoint. The bundled
`assets/smoke-ldc93s1.wav` avoids simulator network timeouts when testing
realtime ASR.
