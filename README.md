# Shinsoku

Cross-platform speech input for everyday work.

Shinsoku is a desktop app for people who want voice input to feel practical, fast, and usable across both Windows and Linux. It is built for real daily workflows: dictation, live caption from system audio, and speech-driven text transformation.

This project is open by design. It is not meant to be a locked-down product with one blessed workflow. It is meant to be remixed, adapted, forked, and pushed in different directions by the community.

## Why this exists

Most voice typing tools are optimized for a single platform, a single language flow, or a single use case. In practice that usually means:

- Windows and Linux do not get the same experience
- system audio captioning is missing or treated as an afterthought
- multilingual users still have to manually rewrite the result
- coding and browser-heavy workflows feel awkward

Shinsoku tries to close that gap with one app and one workflow model.

## Why choose Shinsoku

- Cross-platform where it matters today. Windows and Linux Wayland are both real targets, not one primary platform plus one neglected port.
- Built for real desktop workflows. Global hotkeys, tray control, history, profiles, clipboard, auto-paste, and HUD feedback are part of the product.
- More than dictation. You can capture microphone audio, monitor system loopback audio for live captions, or speak in one language and output in another.
- Profile-based workflow switching. Different tasks can use different input sources, streaming providers, prompts, and output behavior.
- Open and hackable. The project is intentionally structured so contributors, maintainers, and coding agents can understand it quickly and reshape it without asking for permission.

## Core use cases

### 1. Daily dictation on Windows and Linux

Use a hold key or hands-free trigger to speak naturally into any app. The result can be copied, pasted automatically, or both.

This is the default workflow for:

- chat and email
- note taking
- documents
- browser-based forms
- general desktop input

### 2. Live caption from system audio

Shinsoku can listen to loopback/system audio and show a lightweight live caption window.

This is useful for:

- meetings
- videos and livestreams
- online classes
- recorded lectures
- spoken content you want to follow in real time

### 3. Speak Chinese, write English

A built-in profile can take spoken Chinese and output natural English directly. Instead of stopping at raw transcription, the app can run a transform stage to produce ready-to-use text.

This is useful for:

- bilingual communication
- writing emails in English
- drafting messages quickly
- thinking in Chinese while producing English output

### 4. Vibe coding and browser-heavy work

For browser-based development, prompt-heavy workflows, and vibe coding sessions, voice input is often blocked by context switching and poor paste behavior. Shinsoku is structured around low-friction desktop input, so it is easier to speak, insert, revise, and continue working without breaking flow.

## Current feature set

- Global hotkey driven recording workflow
- Hold-to-talk and hands-free style triggers
- Microphone capture
- Linux system audio capture via PulseAudio-compatible APIs
- Live Caption window for system-audio workflows
- Clipboard copy and paste-to-focused-window output
- Profile system with per-profile input / transform / output settings
- History and local persistence
- Optional recording retention
- Streaming transcription provider support
- Text refinement / transform stage
- Wayland HUD overlay support

## Platform support

| Platform | Status | Notes |
| --- | --- | --- |
| Windows | Good | Strongest overall platform today. Hotkeys, selection, HUD, streaming workflows, and system-audio MVP are in place. |
| Linux Wayland | Good, improving | Hotkeys, HUD, selection, and system-audio MVP are working. Some app-specific selection behavior and Alt-key UX limitations still exist. |
| Linux X11 | Community-owned | Not a maintainer target right now. If the community wants X11 support, the codebase is open to that work. |
| macOS arm64 | Good, improving | Native hotkeys, native non-activating HUD, accessibility-backed selection workflows, focused-app paste, and ScreenCaptureKit system audio are in place. The main remaining work is real-app validation, permission UX polish, and packaging validation on more machines. |

## Product shape

Shinsoku is not just a speech-to-text wrapper. The app is organized around a desktop productivity loop:

1. Trigger capture with a global shortcut
2. Choose the right profile for the task
3. Transcribe or stream speech
4. Optionally refine or transform the text
5. Send the result to clipboard, paste target, or live caption window

That workflow is what makes it useful in daily work.

## Providers and pipeline

The app currently supports configurable transcription and streaming backends, plus a separate transform stage for post-processing. Example defaults in the codebase include:

- OpenAI-compatible transcription
- Soniox streaming transcription
- Bailian streaming transcription
- a transform stage for cleanup or bilingual rewriting

This lets the project support very different workflows without splitting into separate tools.

## Open collaboration

Shinsoku is also an experiment in open-ended building.

This project was largely built through vibe coding and agent collaboration. The goal is not to hide that. The goal is to make that collaboration legible and useful.

If you want to work on the project, the intended handoff is simple:

1. Read `Roadmap.md` for current status and priorities
2. Read `AGENT.md` for repo rules, platform boundaries, and implementation direction
3. Change the project in the direction you think it should go

That applies whether you are a human contributor, a maintainer using coding agents, or someone experimenting with your own fork.

## Philosophy

Shinsoku should feel:

- open to forks and reinterpretation
- inclusive of different workflows, languages, and desktop habits
- free to evolve in public
- practical before polished

If you want a rigid product roadmap with one official way to use the app, this repository is probably not that. If you want a good base for building better cross-platform voice workflows, that is exactly the point.

## Build

Install dependencies with `vcpkg`, then configure with your Qt-enabled toolchain.

```powershell
cmake -S . -B build -G "Ninja Multi-Config" `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build build --config Debug --target shinsoku
cmake --build build --config Release --target shinsoku
```

This keeps both `Debug` and `Release` outputs under the same `build/` directory. If you switch from a previous single-config `Ninja` build tree, delete `build/` first or use a new build directory.

### Faster Qt setup options

Installing Qt through `vcpkg` can take a long time because many `vcpkg` ports are built from source. That tradeoff is often acceptable for CI or fully reproducible environments, but it is not the fastest way to get a development machine ready.

If you want a faster local setup, install a prebuilt Qt with the official Qt Online Installer, then point CMake at that installation while still using `vcpkg` for the rest of the dependencies.

#### Option 1: Use a prebuilt Qt installation

After installing Qt, pass either `CMAKE_PREFIX_PATH` or `Qt6_DIR` when configuring.

If you keep `vcpkg` manifest mode enabled, `vcpkg` will still try to install the Qt dependencies declared in `vcpkg.json`. If you want Qt to come only from your preinstalled local copy while still using `vcpkg` for the other libraries, disable manifest mode for this build and install the non-Qt dependencies manually first.

Windows example:

```powershell
vcpkg install curl ixwebsocket mbedtls miniaudio nlohmann-json sqlite3 --triplet x64-windows

cmake -S . -B build -G "Ninja Multi-Config" `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake `
  -DVCPKG_MANIFEST_MODE=OFF `
  -DCMAKE_PREFIX_PATH=C:\Qt\6.10.2\msvc2022_64
```

Linux example:

```bash
vcpkg install curl ixwebsocket mbedtls miniaudio nlohmann-json sqlite3 --triplet x64-linux

cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_MANIFEST_MODE=OFF \
  -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.2/gcc_64
```

That keeps the default project behavior unchanged while still allowing an opt-in local setup that avoids building Qt through `vcpkg`.

Windows example:

```powershell
cmake -S . -B build -G "Ninja Multi-Config" `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake `
  -DCMAKE_PREFIX_PATH=C:\Qt\6.10.2\msvc2022_64
```

Linux example:

```bash
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.2/gcc_64
```

If you prefer to point directly at the package config directory instead of the Qt prefix, use `Qt6_DIR`:

Windows example:

```powershell
cmake -S . -B build -G "Ninja Multi-Config" `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake `
  -DQt6_DIR=C:\Qt\6.10.2\msvc2022_64\lib\cmake\Qt6
```

Linux example:

```bash
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DQt6_DIR=$HOME/Qt/6.10.2/gcc_64/lib/cmake/Qt6
```

This is usually the best choice if you want to avoid waiting for a local Qt build.

#### Option 2: Stay on `vcpkg`, but lean on binary caching

`vcpkg` already uses a local binary cache by default, so once a given package and ABI have been built on the same machine, later installs and rebuilds are much faster.

Default cache locations:

- Windows: `%LOCALAPPDATA%\vcpkg\archives`
- Linux: `$XDG_CACHE_HOME/vcpkg/archives` or `$HOME/.cache/vcpkg/archives`

You can also move the cache to a larger or shared location:

Windows example:

```powershell
$env:VCPKG_DEFAULT_BINARY_CACHE="D:\vcpkg-binary-cache"
```

Linux example:

```bash
export VCPKG_DEFAULT_BINARY_CACHE="$HOME/.cache/vcpkg-binary-cache"
```

Or explicitly configure a filesystem cache source:

Windows example:

```powershell
$env:VCPKG_BINARY_SOURCES="clear;files,D:\vcpkg-binary-cache,readwrite"
```

Linux example:

```bash
export VCPKG_BINARY_SOURCES="clear;files,$HOME/.cache/vcpkg-binary-cache,readwrite"
```

That does not eliminate the first Qt build, but it avoids paying the same cost repeatedly across rebuilds, fresh build trees, and CI machines that share the same cache.

#### Current packaging note

The current packaging targets assume Qt comes from the `vcpkg_installed/` tree inside the build directory. Building the app with a prebuilt external Qt works, but the packaging targets may need adjustment if Qt is no longer provided by `vcpkg`.

## Linux requirements

On Linux, the project is currently aimed at Wayland desktops.

### Build-time dependencies

- `Qt6`
- `libevdev`
- `libpulse`
- `libpulse-simple`
- `autoconf`
- `autoconf-archive`
- `automake`
- `gperf`
- `libtool`
- XCB / X11 development packages used by Qt on Linux
  - for example on Ubuntu or Debian:
  - `libxcb1-dev libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev libegl1-mesa-dev`
- Qt Wayland client support
- the Wayland `wlr-layer-shell` protocol headers generated from the in-repo XML

### Runtime dependencies

- `wl-copy` and `wl-paste`
  - used for clipboard and selection workflows on Wayland
- `wtype`
  - used for paste simulation and selection replacement on Wayland
- a PulseAudio-compatible audio stack
  - used for Linux system loopback capture
- a Wayland compositor with `wlr-layer-shell` support
  - used for the native overlay HUD path

### Notes

- Wayland global hotkeys and key capture currently read `/dev/input/event*` through `libevdev`.
- On systems where those devices are not readable by normal users, add your user to the `input` group or grant equivalent access with a `udev` rule, then log out and back in.
- If `wl-copy`, `wl-paste`, or `wtype` are missing, some Wayland selection and auto-paste workflows will not work.
- If `wlr-layer-shell` is unavailable, the Wayland-specific HUD path cannot be used.
- Linux system-audio capture depends on PulseAudio-compatible monitor sources being available on the desktop.
- Linux X11 is not an active maintainer target.
- Some `vcpkg` ports on Linux also expect autotools utilities from the system package manager. On Ubuntu or Debian, install `autoconf autoconf-archive automake gperf libtool` before configuring the project.
- `vcpkg`'s Linux `qtbase` build also expects the platform X11/XCB/EGL development packages to be installed from the system package manager.

## Run

```powershell
.\build\Debug\shinsoku.exe
```

For a release build on Windows, run `.\build\Release\shinsoku.exe`.

On Linux, run the generated binary from the matching configuration directory in your build tree.

On macOS during development, run `./build/Debug/shinsoku` or `./build/Release/shinsoku`.

## Windows packaging

For a local Windows portable package, configure once with `Ninja Multi-Config`, then build the release packaging target:

```powershell
cmake -S . -B build -G "Ninja Multi-Config" `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build build --config Release --target package_windows_portable
```

The resulting zip is written to `build/packages/` and is intended to be uploaded directly as a portable release artifact.

## macOS packaging

For a local macOS arm64 app bundle and DMG, configure once with `Ninja Multi-Config`, then build the release packaging target:

```bash
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Release --target package_macos_dmg
```

The resulting DMG is written to `build/packages/` and includes a directly usable `Shinsoku.app`.

## Linux packaging

GitHub Releases publish Linux builds as `x86_64` AppImages. The CI workflow builds the Linux binary, then packages it with `linuxdeploy` and the Qt plugin.

On Ubuntu or Debian, the release packaging path also expects:

```bash
sudo apt install autoconf autoconf-archive automake gperf libtool \
  libxcb1-dev libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev \
  libxkbcommon-dev libxkbcommon-x11-dev libegl1-mesa-dev
```

Project-level release automation notes live in `RELEASE.md`.

## Repository structure

- `src/core`: app state, configuration, providers, persistence, and orchestration
- `src/platform`: platform services and platform-specific backends
- `src/ui`: Qt desktop windows and widgets
- `resources`: icons and themes

## Current limitations

- Windows hotkey key-capture flow is still incomplete
- Linux system-audio support needs more validation across real desktop setups
- Linux X11 is not a maintainer target right now
- macOS still needs broader validation across apps, permissions, and devices
- Public packaging and onboarding still need refinement for open-source release

## Demo ideas

The most useful demos for this project are workflow demos, not benchmark demos:

- Daily dictation into a chat app, note app, and browser form
- Live Caption on top of a meeting or video
- Speak Chinese and get clean English output
- Voice-driven vibe coding input inside a browser editor
- Quick switching between profiles for different tasks
- A contributor demo showing how someone can hand the repo to an agent with `Roadmap.md` and `AGENT.md`

## Contributing

Issues, pull requests, forks, and experiments are welcome, especially around:

- Windows and Linux workflow differences
- Linux X11 support from the community
- macOS validation, permission UX polish, and app-specific behavior fixes
- system-audio capture behavior on real devices
- multilingual dictation and transformation prompts
- desktop integration, packaging, and onboarding
