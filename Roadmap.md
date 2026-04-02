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

## Next Suggested Task

If work continues immediately, do this next:

1. Validate macOS hold-to-talk and hands-free recording with both modifier keys
   and non-modifier keys.
2. Validate macOS selection capture in Safari, Chrome, VS Code, Cursor, and a
   native Cocoa text field, then classify failures by app behavior.
3. Validate macOS auto paste and selection replacement in both standard
   `Cmd+V` targets and `Cmd+Shift+V` targets.
4. Validate macOS system-audio capture on real devices and confirm whether the
   current ScreenCaptureKit implementation behaves reliably enough for the
   `Live Caption` profile.

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
