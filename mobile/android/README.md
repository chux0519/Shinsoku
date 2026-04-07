## Android

This directory contains the native Android implementation for Shinsoku's mobile
voice-input product surface.

### Current shape

- `app/`: Android IME shell, permission flow, settings UI, speech-recognizer integration
- `speechcore/`: shared mobile voice-input state machine and commit policy

### What already works

- debug builds via `./gradlew assembleDebug`
- an installable IME app shell
- a keyboard service that can:
  - start Android speech recognition from the mic button
  - show partial recognition text in the IME header
  - commit the final recognized text into the current editor
  - append a trailing space when configured
- a settings screen for:
  - microphone permission
  - auto-commit toggle
  - trailing-space toggle
  - optional language tag

### Local development

```bash
cd mobile/android
./gradlew assembleDebug
./gradlew :speechcore:test
```

The local Android SDK path is intentionally excluded from git via
`local.properties`.

### Near-term direction

- move more backend/config/profile logic into mobile-safe shared code
- replace Android's built-in recognizer with Shinsoku-managed speech backends
- add provider configuration and profile selection to the mobile shell
