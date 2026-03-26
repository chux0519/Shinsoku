# AGENT.md

This file is the repository-level handoff note for coding agents.

It should stay short, current, and useful for day-to-day collaboration.

## Purpose

Use this file for:

- repository-wide engineering rules
- platform boundaries and implementation direction
- the current capability snapshot that affects feature work

Do not use this file as a changelog.
Active execution status and next steps belong in `Roadmap.md`.

## Working Rules

- Keep product intent in `src/core/`.
- Keep OS-specific behavior behind platform abstractions in `src/platform/`.
- Do not let Windows-only, Wayland-only, or backend-specific assumptions leak
  into shared workflow code.
- Prefer extending existing abstractions over adding one-off branches in
  `AppController`.
- Keep profile behavior driven by `input -> transform -> output` fields rather
  than reviving legacy type/enable flags.
- Keep UI styling centralized in `resources/themes/` and `src/ui/app_theme.cpp`.
- Avoid ad-hoc stylesheet strings in individual widgets unless the exception is
  temporary and clearly justified.

## Core Platform Abstractions

These are the main extension points for cross-platform work:

- `GlobalHotkey`
- `ClipboardService`
- `SelectionService`
- `AudioCaptureService`
- `HudPresenter`

Related shared backend boundaries live under `src/core/backend/`.

## Hotkey Model

Hotkey config now uses canonical internal key names instead of Linux-only
`KEY_*` names.

Examples:

- `right_alt`
- `space`
- `right_ctrl`
- `menu`
- `left_meta`

Rules:

- New UI/config work should use canonical names, not backend-native names.
- Backend-native mappings should stay inside platform backends.
- Old `KEY_*` config values must remain load-compatible.

Relevant files:

- `src/platform/hotkey_names.hpp`
- `src/platform/hotkey_names.cpp`
- `src/platform/global_hotkey.hpp`

## Platform Direction

### Windows

Current strength:

- strongest overall platform today
- stable hotkey backend
- stable clipboard and selection service
- stable HUD and shell
- streaming ASR path already validated
- system audio MVP exists

Current gap:

- hotkey key recording is not implemented yet

Expected direction:

- keep current low-level hotkey backend
- add key capture through `GlobalHotkey::capture_next_key(...)`
- map captured Windows events into canonical hotkey names
- reuse the existing Settings and `AppController` recording flow instead of
  adding a Windows-only UI path

### Linux Wayland

Current direction:

- global hotkeys use passive `libevdev` monitoring
- key recording in Settings is implemented through the same input path
- selection capture prefers `wl-paste --primary`
- selection replace and auto-paste use `wl-copy` plus `wtype`
- system audio MVP uses PulseAudio compatibility APIs:
  - `libpulse` for default sink / monitor discovery
  - `libpulse-simple` for sample capture
- HUD uses the Wayland layer-shell presenter

Constraints:

- passive `libevdev` listening can detect keys, but it cannot safely consume
  keys globally
- do not reintroduce device-grab approaches such as `libevdev_grab`
- Wayland selection and paste flows are app-dependent and should remain
  capability-gated

### Linux X11

Not implemented yet.

If work starts here, treat it as a separate backend from Wayland.

### macOS

Not implemented yet.

Expected future direction:

- global input via accessibility/event tap style APIs
- focused text workflows via accessibility-backed paths where possible
- system audio via a separate native strategy

## Current Capability Snapshot

### Working well enough today

- Windows main workflow
- Windows selection workflow
- Windows system audio MVP
- shared Settings IA has been simplified around `General / Providers /
  Transform / Network / Profiles / Advanced`
- shared Profiles now represent workflow presets through input, transform, and
  output fields
- Wayland HUD overlay
- Wayland multi-monitor HUD targeting
- Wayland key recording in Settings
- Wayland selection capture in real browser/editor targets
- Linux system audio MVP on mainstream PulseAudio-compatible desktops

### Intentionally partial or app-dependent

- Wayland selection replace / auto-paste
- Wayland Alt-based hotkeys
- focused-window paste behavior across arbitrary apps

### Still pending

- Windows hotkey key recording
- macOS backend work
- Linux X11 backend work
- broader Linux system-audio runtime validation

## Documentation Policy

Keep collaboration docs minimal:

- `AGENT.md` for stable repo rules and platform guidance
- `Roadmap.md` for current status, next steps, and active priorities

If information does not help another agent make a better implementation
decision soon, do not add a new doc for it.
