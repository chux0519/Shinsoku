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

- not started

## Active Priorities

1. Validate Linux system audio on more real desktop/device combinations.
2. Continue classifying Wayland selection failures by app behavior instead of
   treating them as one generic bug.
3. Keep Wayland Alt-key conflicts in the UX/documentation bucket, not as a
   low-level input-grab project.

## Next Suggested Task

If work continues immediately, do this next:

1. Validate the Windows key-recording flow on real hardware, especially
   left/right modifier distinction and uncommon keyboard layouts.
2. Validate Linux system audio on more real desktop/device combinations.
3. Continue reducing Wayland selection ambiguity by classifying app behavior
   instead of treating failures as one generic path.

## Guardrails

- Do not introduce new platform-specific behavior directly into `src/core/`.
- Do not fork separate product flows for Windows vs Wayland unless the
  abstraction truly cannot support both.
- Do not chase "consume Alt globally on Wayland" through device grabs.
- Do not create new long-lived planning docs unless they replace something in
  `AGENT.md` or `Roadmap.md`.
