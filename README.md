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
| macOS | Planned, community help welcome | I want to support it, but it is not my main daily platform right now and I do not yet have a broad hardware setup for it. |

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
cmake -S . -B build -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build build
```

## Linux requirements

On Linux, the project is currently aimed at Wayland desktops.

### Build-time dependencies

- `Qt6`
- `libevdev`
- `libpulse`
- `libpulse-simple`
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

- If `wl-copy`, `wl-paste`, or `wtype` are missing, some Wayland selection and auto-paste workflows will not work.
- If `wlr-layer-shell` is unavailable, the Wayland-specific HUD path cannot be used.
- Linux system-audio capture depends on PulseAudio-compatible monitor sources being available on the desktop.
- Linux X11 is not an active maintainer target.

## Run

```powershell
.\build\shinsoku.exe
```

On Linux, run the generated binary from your build directory.

## Windows packaging

For a local Windows portable package, configure and build the project, then run:

```powershell
cmake -S . -B build-win-release -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-win-release --target package_windows_portable
```

The resulting zip is written to `build-win-release/packages/` and is intended to be uploaded directly as a portable release artifact.

## Repository structure

- `src/core`: app state, configuration, providers, persistence, and orchestration
- `src/platform`: platform services and platform-specific backends
- `src/ui`: Qt desktop windows and widgets
- `resources`: icons and themes

## Current limitations

- Windows hotkey key-capture flow is still incomplete
- Linux system-audio support needs more validation across real desktop setups
- Linux X11 is not a maintainer target right now
- macOS support is planned but still incomplete
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
- macOS bring-up and native backend work
- system-audio capture behavior on real devices
- multilingual dictation and transformation prompts
- desktop integration, packaging, and onboarding
