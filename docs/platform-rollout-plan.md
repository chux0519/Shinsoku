# Platform Rollout Plan

This document is the handoff-oriented companion to
`docs/platform-capability-matrix.md`.

It is meant to answer:

- what the project already has today
- what a macOS or Linux implementation should start from
- which files and abstractions matter first
- what should be deferred or capability-gated

## Current Product State

The project currently has these user-visible workflows:

- plain dictation
- hands-free dictation
- selection command / selected-text rewrite
- streaming dictation with multiple providers
- profiles / presets
- system audio capture MVP
- meeting transcription window v1

The current implementation is strongest on Windows.

## Current Architecture Snapshot

### Product/Core layer

Keep these as the source of product intent:

- `src/core/app_controller.*`
- `src/core/app_config.*`
- backend interfaces under `src/core/backend/`
- workflow docs:
  - `docs/profiles-design.md`
  - `docs/settings-redesign.md`
  - `docs/system-audio-design.md`

These files should continue to express:

- what the workflow is
- what output is expected
- which capability is requested

They should not grow more OS-specific branches.

### Platform boundaries already in place

These are the main extension points for other platforms:

- `src/platform/global_hotkey.hpp`
- `src/platform/clipboard_service.hpp`
- `src/platform/selection_service.hpp`
- `src/platform/audio_capture_service.hpp`
- `src/platform/hud_presenter.hpp`

### Current Windows implementations

- `src/platform/windows/windows_global_hotkey.*`
- `src/platform/windows/windows_clipboard_service.*`
- `src/platform/windows/windows_selection_service.*`
- `src/platform/miniaudio_audio_capture_service.*`

These are not portable themselves, but they define what a non-Windows backend
must be able to satisfy.

## Recommended Rollout Order

### Step 1: Shell bring-up

Target:

- app launches
- settings opens
- history opens
- HUD can render

Files to understand first:

- `src/main.cpp`
- `src/ui/app_theme.cpp`
- `src/ui/main_window.*`
- `src/platform/qt/qt_hud_presenter.*`

Why first:

- it gives a usable shell for later backend work
- it avoids debugging platform services without a visible app

### Step 2: Hotkey backend

Target:

- hold-to-record
- hands-free chord if supported

Files to use as reference:

- `src/platform/global_hotkey.hpp`
- `src/platform/windows/windows_global_hotkey.*`

macOS likely path:

- accessibility/event tap-backed implementation

Linux likely path:

- X11-specific backend where needed
- Wayland backend can start from an `evdev`-style monitor similar to the local
  `potatype` project, with explicit setup requirements and capability gating

### Step 3: Batch ASR only

Target:

- microphone capture
- record -> transcribe -> copy/history

Files to understand:

- `src/platform/audio_capture_service.hpp`
- `src/platform/miniaudio_audio_capture_service.*`
- `src/core/backend/asr_backend.hpp`
- `src/core/backend/backend_factory.*`

Why before selection/paste:

- it proves audio + backend + basic workflow on the new platform

### Step 4: Streaming ASR

Target:

- Soniox / Bailian style realtime dictation

Files to understand:

- `src/core/backend/streaming_asr_backend.hpp`
- `src/core/backend/streaming/`
- `src/core/backend/streaming/ix_proxy_socket.cpp`

Notes:

- streaming transport is mostly portable
- verify TLS / proxy / event loop behavior on the target OS

### Step 5: Selection and focused paste

Target:

- selected-text rewrite where the platform really supports it

Files to understand:

- `src/platform/selection_service.hpp`
- `src/platform/clipboard_service.hpp`
- Windows implementations under `src/platform/windows/`

Policy:

- do not force semantic parity if the platform does not allow it cleanly
- capability-gate it instead
- on Wayland, an MVP clipboard-preserve plus synthetic `Ctrl+C` / paste flow is
  acceptable as a platform backend, as long as `core` only sees capability
  contracts

### Step 6: System audio

Target:

- system / loopback capture
- meeting transcription v1

Files to understand:

- `src/platform/audio_capture_service.hpp`
- `src/platform/miniaudio_audio_capture_service.*`
- `docs/system-audio-design.md`
- `src/ui/meeting_transcription_window.*`

Policy:

- microphone and system audio should remain two capture modes
- platform backend decides how to realize `system`

## Platform-Specific Guidance

### macOS

Start with:

1. shell
2. hotkeys
3. batch microphone capture
4. streaming

Defer until later:

- selection command
- focused paste automation
- system audio

Expected blockers:

- accessibility permission
- event tap reliability
- system audio routing strategy

### Linux

Treat X11 and Wayland separately.

For Wayland specifically, recommended order is:

1. shell / HUD
2. hotkeys via a dedicated platform backend
3. batch microphone capture
4. streaming
5. clipboard-driven selection capture / replace fallback
6. system audio

Wayland-specific implementation notes:

- global hotkeys can start from `libevdev` device monitoring, similar to
  `potatype`
- auto paste can start from helper-tool orchestration such as `wl-copy` plus
  `wtype`
- selection capture can start from clipboard-preserve plus synthetic copy,
  similar in spirit to the `get-selected-text` fallback approach
- these are still degraded capabilities and should remain surfaced as such in UI

Expected blockers:

- compositor differences
- helper binary availability
- input-device permissions for `evdev`
- system audio source discovery

## What To Tell The Next AI First

If you start development on another machine, the next AI should read these in
this order:

1. `AGENT.md`
2. `docs/feature-roadmap.md`
3. `docs/platform-capability-matrix.md`
4. `docs/platform-rollout-plan.md`
5. `docs/system-audio-design.md`
6. `docs/profiles-design.md`

Then it should inspect these code interfaces before proposing a platform
implementation:

1. `src/platform/global_hotkey.hpp`
2. `src/platform/clipboard_service.hpp`
3. `src/platform/selection_service.hpp`
4. `src/platform/audio_capture_service.hpp`
5. `src/platform/hud_presenter.hpp`
6. `src/core/app_controller.hpp`

## Rules For The Next Platform Implementation

1. Do not add platform-specific APIs directly into `src/core/`.
2. Prefer one capability at a time over a big all-platform port.
3. Ship degraded behavior explicitly instead of pretending parity exists.
4. Keep settings and UI capability-aware.
5. Update these docs whenever a platform assumption changes.
6. For Wayland, prefer backend-local helper orchestration over teaching `core`
   about `wl-copy`, `wtype`, `libevdev`, portals, or compositor names.
