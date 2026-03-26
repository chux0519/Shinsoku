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

### Current platform summary

#### Windows

- strongest platform overall
- hotkeys, selection, HUD, and streaming workflows are in good shape
- system audio MVP exists
- Settings and Profiles UI is already ready for shared key-recording flow
- missing: record-next-key implementation in the Windows hotkey backend

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

- not started

## Active Priorities

1. Implement Windows hotkey key capture on top of the shared `GlobalHotkey`
   abstraction.
2. Validate Linux system audio on more real desktop/device combinations.
3. Continue classifying Wayland selection failures by app behavior instead of
   treating them as one generic bug.
4. Keep Wayland Alt-key conflicts in the UX/documentation bucket, not as a
   low-level input-grab project.

## Next Suggested Task

If work continues immediately, do this next:

1. Implement `supports_key_capture()` and `capture_next_key(...)` in
   `src/platform/windows/windows_global_hotkey.*`.
2. Reuse the existing Settings and `AppController` flow without adding a
   Windows-only UI path.
3. Return canonical hotkey names from the Windows backend so config/UI stay
   cross-platform.
4. Verify the recorded key updates existing hold-key and hands-free-chord
   settings correctly on Windows.

## Guardrails

- Do not introduce new platform-specific behavior directly into `src/core/`.
- Do not fork separate product flows for Windows vs Wayland unless the
  abstraction truly cannot support both.
- Do not chase "consume Alt globally on Wayland" through device grabs.
- Do not create new long-lived planning docs unless they replace something in
  `AGENT.md` or `Roadmap.md`.
