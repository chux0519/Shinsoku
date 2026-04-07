## Mobile

Mobile platform code lives under this directory so the desktop app and mobile
projects can evolve independently without crowding the repository root.

- `android/`: Android IME app and mobile shell code
- `ios/`: iOS app and keyboard-extension shell code

The long-term goal is to reuse shared speech/config/backend core logic from the
desktop codebase while keeping mobile UI and platform integration native.
