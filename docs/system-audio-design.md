# System Audio / Meeting Transcription Design

This note tracks the first implementation pass for system-audio capture and
meeting transcription workflows.

## Goals

- support transcribing system output audio, not just microphone input
- keep microphone dictation behavior intact
- treat system-audio capture as an input-source choice, not as an ASR backend
- prepare the codebase for future microphone + system mix capture

## MVP Scope

Windows only for the first pass.

Use WASAPI loopback through `miniaudio`:

- `microphone`
- `system`

Do not implement mixed capture yet.
Do not implement per-output-device selection yet.
Use the default playback device for the first loopback MVP.

## Product Shape

Add `Audio Input Source` in settings:

- `Microphone`
- `System Audio (Loopback)`

Meeting workflows are expected to:

- prefer history over auto-paste
- work well with streaming ASR
- later pair with profiles such as `Meeting Transcription`
- avoid selection-command flows, which are tied to foreground text editing rather than loopback capture

## Config Shape

Under `audio`:

- `capture_mode = microphone | system`

Remain global for now:

- input device id
- recordings directory
- retention / rotation

Longer term:

- optional playback device selection for loopback mode
- optional mixed input mode

## Runtime Direction

Refactor `AudioRecorder` toward input-source selection, but keep the shared
workflow code platform-neutral.

Product-facing intent should be expressed in a small abstraction such as:

- `microphone`
- `system`
- later optional `mix`

Platform-specific mapping should remain backend-specific:

- microphone capture => `ma_device_type_capture`
- system loopback => `ma_device_type_loopback`

Do not let WASAPI-specific assumptions leak into controller or profile logic.
The Windows MVP can use loopback internally, but the long-term direction should
leave room for:

- macOS virtual / aggregate device capture
- Linux PipeWire monitor streams
- PulseAudio monitor devices where applicable

For the first pass:

- microphone mode keeps existing input-device enumeration
- system mode uses the default playback device

## Platform Notes

- Windows: WASAPI loopback is the initial target
- macOS: requires a different strategy, likely virtual devices or system APIs
- Linux:
  - PipeWire monitor streams are the most promising direction
  - PulseAudio monitor devices may also be viable depending on distro

## File Plan

### `src/core/app_config.*`

Add `audio.capture_mode`.

### `src/core/audio_recorder.*`

Add input-source selection and a Windows loopback startup path, while keeping
the top-level API generic enough for future macOS / Linux implementations.

### `src/ui/settings_window.*`

Expose `Audio Input Source`.

### `src/core/app_controller.*`

Apply capture mode when starting recording and keep settings UI synchronized.

## Acceptance Criteria

- Windows can record system output audio with the default playback device.
- Existing microphone dictation still works unchanged.
- The settings page clearly distinguishes microphone and system-audio capture.
