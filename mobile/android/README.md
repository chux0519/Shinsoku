## Android

This directory contains the native Android implementation for Shinsoku's mobile
voice-input product surface.

### Current shape

- `app/`: Android IME shell, permission flow, settings UI, speech-recognizer integration
- `speechcore/`: shared mobile voice-input state machine and commit policy

### What already works

- debug builds via `./gradlew assembleDebug`
- an installable IME app shell
- a launcher app that surfaces:
  - microphone permission state
  - keyboard enabled/selected state
  - the currently active profile and voice-input behavior summary
  - quick workflow switching for dictation / chat / review
  - a recent history preview
- a keyboard service that can:
  - start Android speech recognition from the mic button
  - show partial recognition text in the IME header
  - auto-commit the final recognized text into the current editor
  - hold recognized text in a pending state and expose `Insert` / `Clear`
    actions when review-before-insert is enabled
- an on-device history store for committed voice-input snippets
- a settings screen for:
  - microphone permission
  - keyboard enablement and picker shortcuts
  - auto-commit toggle
  - commit suffix selection: none / space / newline
  - workflow presets: dictation / chat / review-before-insert
  - optional language tag

### Local development

```bash
cd mobile/android
./gradlew assembleDebug
./gradlew :speechcore:test
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

The local Android SDK path is intentionally excluded from git via
`local.properties`.

### Near-term direction

- move more backend/config/profile logic into mobile-safe shared code
- replace Android's built-in recognizer with Shinsoku-managed speech backends
- add provider configuration to the mobile shell

### Recommended manual test flow

1. Install the debug APK.
2. Open the app and grant microphone permission.
3. Enable `Shinsoku Voice Input` in Android keyboard settings.
4. Use Settings to switch among:
   - `Dictation`: auto-commit + trailing space
   - `Chat`: auto-commit + newline
   - `Review`: pending transcript until `Insert`
5. Switch to the IME in any text field and verify each mode behaves as
   configured.
