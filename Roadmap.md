# Roadmap.md

This file tracks current execution status, active priorities, and the next
useful work items.

Update it when major work lands or priorities change.

## Current State

### Recently completed

- Wayland HUD surface targeting and multi-monitor placement were fixed.
- Linux system audio MVP was stabilized around PulseAudio-compatible APIs.
- Linux TLS certificate loading for streaming transcription was fixed.
- Wayland selection capture now prefers primary selection and has clearer debug
  classification.
- Wayland selection replace now reuses configured paste keys.
- Hotkey config was normalized to canonical internal key names.
- Wayland Settings gained a record-key flow for hold key and hands-free chord.
- Settings navigation was reorganized into `General / Providers / Transform /
  Network / Profiles / Advanced`.
- Profiles were simplified into `input / transform / output` presets with
  per-profile input source and input device.
- Legacy profile type and enabled-state fields were removed.
- System-audio workflows now use the `Live Caption` naming and window model.
- Tray behavior now matches desktop expectations: left click opens the main
  window and the context menu exposes history, settings, and quit.
- Windows hotkey backend now supports record-next-key in Settings through the
  shared `GlobalHotkey` capture flow.

### Current platform summary

#### Windows

- strongest platform overall
- hotkeys, selection, HUD, and streaming workflows are in good shape
- system audio MVP exists
- shared key recording now works in Settings for hold key and hands-free chord

#### Linux Wayland

- hotkeys work through passive `libevdev`
- record-next-key works
- HUD overlay works and follows the correct screen
- selection command is usable but still app-dependent
- Linux system audio MVP works on tested PulseAudio-compatible desktops
- main known limitation: Alt-based hold keys still conflict with some apps

#### Linux X11

- not started

#### macOS

- dedicated macOS backends now exist for:
  - global hotkeys
  - key recording in Settings
  - focused-app auto paste
  - accessibility-backed selection capture
  - selection replacement through focused-app paste
  - system audio capture through a native ScreenCaptureKit path
- native non-activating HUD is in place and no longer steals foreground focus
- arm64 `.app` / `.dmg` packaging target exists for release builds
- macOS and Linux now default to light tray icons to better match dark menu bars
- app launches and builds with the native macOS backend set
- main remaining work is real-hardware validation, permission UX polishing, and
  app-specific behavior classification
- known limitation: VS Code / Electron editor selection command is unreliable
  with Alt-based hold keys because the app can consume the modifier and the
  Monaco editor does not consistently expose selection text through macOS
  Accessibility APIs.

## Active Priorities

1. Validate the macOS backend on real hardware and real apps:
   - Input Monitoring permission flow for global hotkeys
   - Accessibility permission flow for selection workflows
   - Screen Recording / ScreenCaptureKit behavior for system audio
   - packaged `.app` / `.dmg` behavior on a clean machine
   - selection capture coverage across browsers, editors, terminals, and chat apps
2. Tighten macOS capability messaging and app-specific debug output where the
   native backend is still app-dependent.
3. Validate Linux system audio on more real desktop/device combinations.
4. Continue classifying Wayland selection failures by app behavior instead of
   treating them as one generic bug.
5. Keep Wayland Alt-key conflicts in the UX/documentation bucket, not as a
   low-level input-grab project.
6. Continue the Flutter mobile rewrite while keeping desktop Qt and platform
   services out of the mobile UI layer.

## Mobile Direction

### Product framing

- do not treat mobile as a direct Qt port
- do treat mobile as a new product surface built around speech input
- use Flutter for the shared Android/iOS product shell
- treat platform keyboard or insertion features as native integration projects
  layered behind the Flutter shell

### Recommended implementation split

1. Flutter app:
   - record, drafts, and settings surfaces
   - profile and provider configuration UI
   - mobile history and local persistence
   - shared Android/iOS navigation and state model
2. Platform integration:
   - microphone permission and audio capture plugins
   - Android insertion / IME integration if the product returns to keyboard input
   - iOS keyboard extension only if the Flutter app flow is not enough
3. Shared logic:
   - backend/provider config that is serialization-friendly
   - transform/refine prompts that do not depend on Qt or desktop services
   - persistence models that are not tied to desktop file paths

### What should be reused

- `src/core/backend/`
- transport/auth/provider config logic
- text transform/refinement logic
- serialization-ready parts of app/profile config
- persistence models that are not tied to Qt widgets or desktop file paths

### What should not be reused directly

- Qt desktop UI in `src/ui/`
- tray, HUD, global hotkeys, desktop selection services
- Wayland / Windows / macOS platform backends under `src/platform/`
- desktop-first `AppController` orchestration if it assumes recorder triggers,
  windowing, or clipboard flows that do not exist on mobile

### Implementation order

1. Harden the Flutter shell:
   - finish real state management and persistence
   - replace simulated capture with platform microphone capture
   - add provider setup and backend execution
2. Add transcript workflows:
   - streaming or batch ASR integration
   - transform/profile application
   - draft editing and history
3. Decide platform insertion:
   - Android IME or share-sheet style insertion
   - iOS app-first insertion workflow or keyboard extension
   - keep either path behind explicit platform integration boundaries

### Technology recommendation

- Mobile product shell: Flutter
- Android runner: generated Flutter runner plus platform channels/plugins as
  needed
- iOS runner: generated Flutter runner plus platform channels/plugins as needed

### Guardrails for mobile work

- do not start by porting the Qt desktop UI
- do not bind shared product logic tightly to Flutter widgets
- do not let mobile product constraints leak back into desktop abstractions
  unless the abstraction genuinely improves both sides
- do not promise desktop feature parity on mobile in the first phase
- do not reintroduce the deleted Kotlin/SwiftUI mobile implementations without
  an explicit product decision

## Next Suggested Task

If work continues immediately, do this next:

1. Validate macOS hold-to-talk and hands-free recording with both modifier keys
   and non-modifier keys.
2. Validate macOS selection capture in Safari, Chrome, Cursor, terminals, and a
   native Cocoa text field. Treat VS Code / Electron editor support as a known
   limitation until there is a dedicated integration strategy.
3. Validate macOS auto paste and selection replacement in both standard
   `Cmd+V` targets and `Cmd+Shift+V` targets.
4. Validate macOS system-audio capture on real devices and confirm whether the
   current ScreenCaptureKit implementation behaves reliably enough for the
   `Live Caption` profile.
5. When mobile work starts, begin with a codebase extraction pass:
   - inventory which `src/core` types are still Qt-bound
   - identify which backend/config/history modules can move into a shared
     mobile-safe core without bringing desktop platform code with them

## Guardrails

- Do not introduce new platform-specific behavior directly into `src/core/`.
- Do not fork separate product flows for Windows vs Wayland unless the
  abstraction truly cannot support both.
- Do not add a macOS-only Settings path for hotkey recording when the shared
  `GlobalHotkey::capture_next_key()` flow can support it.
- Do not block the macOS port on system-audio work; finish dictation workflows
  first.
- Do not chase "consume Alt globally on Wayland" through device grabs.
- Do not create new long-lived planning docs unless they replace something in
  `AGENT.md` or `Roadmap.md`.
- Do not start mobile implementation by trying to share the Qt desktop UI.
