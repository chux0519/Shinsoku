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
6. Prepare a mobile architecture split so Android and iOS work can reuse the
   speech pipeline without dragging desktop UI and desktop platform services
   into mobile code.

## Mobile Direction

### Product framing

- do not treat mobile as a direct Qt port
- do treat mobile as a new product surface built around speech input
- prioritize Android first, because Android IME support is the closest match to
  the desktop dictation workflow
- treat iOS as a second phase with a stricter product scope

### Recommended implementation split

1. Shared core:
   - provider/back-end abstractions
   - streaming transport and auth config
   - transform / refine pipeline
   - profile and settings data model
   - history / persistence schema where it is not desktop-UI-bound
2. Android shell:
   - Kotlin IME service
   - native microphone capture and input-connection commit flow
   - Android settings app for providers, profiles, permissions, and history
3. iOS shell:
   - Swift app first
   - keyboard extension second
   - keep the extension focused on voice-to-text insertion, not full desktop
     parity

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

1. Extract a mobile-safe shared core from the current desktop code:
   - remove Qt widget dependencies from reusable logic
   - reduce reliance on desktop platform service abstractions inside shared
     orchestration
   - define a cleaner boundary for audio input, backend execution, and text
     output
2. Build Android IME MVP:
   - hold / tap to dictate
   - stream speech
   - commit text into the active input field
   - basic provider/profile selection
3. Build Android companion settings app:
   - provider setup
   - profile editing
   - history
   - permission explanations
4. Build iOS companion app:
   - validate provider setup and mobile-safe shared core
   - validate microphone and streaming UX
5. Build iOS keyboard extension:
   - minimal insertion flow first
   - only add transform/profile complexity after the extension UX is stable

### Technology recommendation

- Android IME: Kotlin
- iOS app and keyboard extension: Swift
- Flutter is acceptable for a future companion settings app, but not preferred
  for the IME/keyboard shell itself

### Guardrails for mobile work

- do not start by porting the Qt desktop UI
- do not bind the shared core to Flutter, Kotlin, or Swift UI frameworks
- do not let mobile product constraints leak back into desktop abstractions
  unless the abstraction genuinely improves both sides
- do not promise desktop feature parity on mobile in the first phase
- do not start iOS keyboard work before Android IME and shared-core extraction
  have proven the architecture

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
