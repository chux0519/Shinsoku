# Shinsoku

Shinsoku is a cross-platform voice input product for desktop and mobile.

Today the repository contains:

- a Qt desktop app for Windows, macOS, and Linux
- a Flutter mobile app for Android and iOS under [mobile](/Volumes/ZT/repos/Shinsoku/mobile)

## Product shape

Shinsoku is built around one workflow:

1. Capture speech
2. Transcribe with the right backend
3. Optionally refine or transform the text
4. Insert it into the active surface
5. Keep enough history and settings to make the workflow repeatable

The project is opinionated about that loop, but not about one single provider or one single platform shell.

## Current status

### Desktop

- Qt-based app with profile-driven voice input workflows
- Windows, macOS, and Linux support
- streaming transcription backends
- transform / post-processing pipeline
- history, local persistence, clipboard/paste flows, HUD surfaces

Code lives under [src](/Volumes/ZT/repos/Shinsoku/src).

Known limitation: desktop selection-command support is app-dependent. On macOS,
native text fields and terminal text selection are expected to work better than
Electron/Monaco editors such as VS Code, which may intercept modifier keys or
not expose selected editor text reliably through Accessibility APIs. Prefer a
non-conflicting hold key when testing editor integrations.

### Mobile

- Flutter shell for Android and iOS
- record, drafts, and settings surfaces
- profile-driven mobile workflow placeholders
- simulated capture-to-draft flow
- generated Android and iOS Flutter runners

Code lives under [mobile](/Volumes/ZT/repos/Shinsoku/mobile).

## Repository layout

- [src](/Volumes/ZT/repos/Shinsoku/src): desktop app
- [resources](/Volumes/ZT/repos/Shinsoku/resources): shared brand/theme assets
- [packaging](/Volumes/ZT/repos/Shinsoku/packaging): desktop packaging scripts
- [mobile](/Volumes/ZT/repos/Shinsoku/mobile): Flutter mobile app and generated platform runners

## Build

### Desktop

Use CMake with `vcpkg`:

```bash
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Debug --target shinsoku
cmake --build build --config Release --target shinsoku
```

See [RELEASE.md](/Volumes/ZT/repos/Shinsoku/RELEASE.md) for packaging and release details.

### Mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run
```

Mobile details live in [mobile/README.md](/Volumes/ZT/repos/Shinsoku/mobile/README.md).

## Design direction

The product direction is simple:

- Qt desktop UI and Flutter mobile UI
- shared prompt/profile/pipeline logic where it is worth reusing
- shared brand language across desktop, Android, and iOS
- black/white system-following themes instead of heavily branded chrome

## Collaboration

If you are continuing work in this repo, read:

- [Roadmap.md](/Volumes/ZT/repos/Shinsoku/Roadmap.md)
- [AGENT.md](/Volumes/ZT/repos/Shinsoku/AGENT.md)
