# Shinsoku

Shinsoku is a cross-platform voice input product for desktop and mobile.

Today the repository contains:

- a Qt desktop app for Windows, macOS, and Linux
- a native Android IME and mobile shell under [mobile/android](/Volumes/ZT/repos/Shinsoku/mobile/android)
- an iOS scaffold under [mobile/ios](/Volumes/ZT/repos/Shinsoku/mobile/ios)
- shared native/mobile core work that is moving repeated logic out of per-platform UI code

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

### Android

- native IME
- native launcher/settings shell
- streaming and batch recognition backends
- provider-assisted post-processing
- on-device history
- early shared-core reuse under [mobile/nativecore](/Volumes/ZT/repos/Shinsoku/mobile/nativecore)

Code lives under [mobile/android](/Volumes/ZT/repos/Shinsoku/mobile/android).

### iOS

- SwiftUI app shell scaffold
- keyboard extension scaffold
- shared model layer prepared for future native/core reuse

Code lives under [mobile/ios](/Volumes/ZT/repos/Shinsoku/mobile/ios).

## Repository layout

- [src](/Volumes/ZT/repos/Shinsoku/src): desktop app
- [resources](/Volumes/ZT/repos/Shinsoku/resources): shared brand/theme assets
- [packaging](/Volumes/ZT/repos/Shinsoku/packaging): desktop packaging scripts
- [mobile/android](/Volumes/ZT/repos/Shinsoku/mobile/android): Android app + IME
- [mobile/ios](/Volumes/ZT/repos/Shinsoku/mobile/ios): iOS app + keyboard extension scaffold
- [mobile/nativecore](/Volumes/ZT/repos/Shinsoku/mobile/nativecore): shared native logic for mobile
- [website](/Volumes/ZT/repos/Shinsoku/website): static product site

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

### Android

```bash
cd mobile/android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Android details live in [mobile/android/README.md](/Volumes/ZT/repos/Shinsoku/mobile/android/README.md).

### iOS

The iOS project is scaffolded under [mobile/ios](/Volumes/ZT/repos/Shinsoku/mobile/ios) and is intended to be generated from `project.yml` with XcodeGen.

See [mobile/ios/README.md](/Volumes/ZT/repos/Shinsoku/mobile/ios/README.md).

## Design direction

The product direction is simple:

- native platform UI
- shared prompt/profile/pipeline logic where it is worth reusing
- shared brand language across desktop, Android, iOS, and web
- black/white system-following themes instead of heavily branded chrome

## Collaboration

If you are continuing work in this repo, read:

- [Roadmap.md](/Volumes/ZT/repos/Shinsoku/Roadmap.md)
- [AGENT.md](/Volumes/ZT/repos/Shinsoku/AGENT.md)

## Website

A static landing page lives under [website](/Volumes/ZT/repos/Shinsoku/website).

Open [website/index.html](/Volumes/ZT/repos/Shinsoku/website/index.html) locally in a browser, or deploy that directory as a static site.
