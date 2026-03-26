# Platform Capability Matrix

This note tracks the current and planned platform support boundaries for
Windows, macOS, and Linux.

It is intentionally practical:

- what is already implemented today
- what is product-level intent vs platform backend detail
- what each platform is likely to use as its concrete implementation path
- what must remain capability-gated instead of assumed

## Goals

- make platform differences explicit
- avoid accidental Windows-only logic in core workflows
- prioritize rollout by capability instead of by large platform rewrites

## Status Legend

- `full`: implemented and expected to work
- `partial`: implemented with caveats or reduced reliability
- `planned`: not implemented yet, but intended
- `unsupported`: not a planned default capability for that platform path

## Capability Matrix

| Capability | Windows | macOS | Linux X11 | Linux Wayland | Notes |
| --- | --- | --- | --- | --- | --- |
| Global hold-to-record hotkey | full | planned | planned | partial | Wayland MVP can use `libevdev` device reads with user input-device permissions; not a universal compositor API |
| Hands-free chord behavior | full | planned | planned | partial | Depends on the same global input path as the hold hotkey |
| Selection capture | partial | planned | planned | partial | Windows uses UIA plus clipboard fallback; Wayland can use clipboard-preserve plus synthetic `Ctrl+C` fallback when key injection works |
| Selection replace | partial | planned | planned | partial | Wayland path is expected to be clipboard-preserve plus synthetic paste, not semantic focused-text editing |
| Auto paste to focused window | partial | planned | partial | partial | Wayland can often use `wl-copy` plus `wtype`, but compositor support and focus semantics still vary |
| Tray integration | partial | planned | partial | partial | Desktop environment differences matter |
| HUD overlay | full | planned | planned | planned | Pure Qt path is portable; visual polish should remain backend-agnostic |
| Batch HTTP ASR | full | full | full | full | Provider/backend dependent, not platform dependent |
| Streaming websocket ASR | full | planned | planned | planned | Transport layer is mostly portable once TLS/proxy paths are verified |
| Profiles / presets | full | full | full | full | Product-layer feature, should remain platform-agnostic |
| Meeting transcript window (v1) | full | full | full | full | Pure Qt window; source/capture capabilities differ by platform |
| System audio capture | partial | planned | planned | planned | Windows loopback MVP exists via miniaudio backend; other platforms need native paths |
| Offline sherpa-onnx ASR | planned | planned | planned | planned | Mostly backend/library integration once audio path exists |

## Current Implementation Snapshot

Current Windows implementation already includes:

- Qt shell with shared QSS theme and HUD overlay
- low-level global hotkey backend
- clipboard integration and focused-window paste path
- selection capture / replace service
- streaming ASR providers:
  - Soniox
  - Bailian
- profile / preset support
- system audio capture MVP
- meeting transcription window v1

Current project-level abstractions that should be reused on other platforms:

- `GlobalHotkey`
- `ClipboardService`
- `SelectionService`
- `AudioCaptureService`
- `HudPresenter`
- backend interfaces under `src/core/backend/`

Current Windows-heavy areas still needing careful rollout treatment:

- `src/platform/windows/windows_global_hotkey.*`
- `src/platform/windows/windows_clipboard_service.*`
- `src/platform/windows/windows_selection_service.*`
- `src/platform/miniaudio_audio_capture_service.*` for system loopback specifics

## Windows Notes

Current strengths:

- mature hotkey behavior
- working clipboard integration
- streaming providers already validated
- HUD and shell are stable
- system audio capture MVP is present
- meeting transcript window v1 is usable

Current caveats:

- selection capture still depends on editor behavior
- focused paste is inherently app-dependent
- system audio capture is still MVP-only and should not leak WASAPI assumptions
- some workflows still rely on Windows-native affordances that must become capability-gated elsewhere

Likely long-term implementation path:

- hotkeys: current low-level keyboard hook backend
- selection: UIA where available, clipboard fallback where acceptable
- paste: current clipboard/focus restore backend
- system audio: current loopback path behind `AudioCaptureService`

## macOS Notes

Expected requirements:

- accessibility permission for global input / focused text workflows
- separate system-audio capture path
- careful testing for overlay, tray, and clipboard behaviors
- likely different user expectations for tray/menu bar behavior
- likely more native-looking system audio routing constraints

Likely implementation path:

- hotkeys:
  - Quartz event tap or other accessibility-backed global input path
- selection capture / replace:
  - accessibility APIs for focused text where possible
  - clipboard fallback only for explicitly supported flows
- focused paste:
  - accessibility + event synthesis path
- system audio:
  - CoreAudio-based capture path or virtual device strategy
- tray:
  - status item / Qt bridge path

Expected product policy:

- treat accessibility-dependent features as optional capabilities
- explicitly surface unsupported/permission-denied states in UI

Immediate recommendation:

- do not start implementation until capability-specific abstractions are ready

## Linux Notes

Split Linux thinking into:

- X11
- Wayland

Reason:

- global input and focused-window automation assumptions differ drastically
- system audio and selection behavior vary with compositor / desktop stack
- X11 and Wayland should not share one fake "Linux" backend contract

### Linux X11

Likely implementation path:

- hotkeys:
  - X11 grab / Qt/XCB-backed path
- selection capture / replace:
  - clipboard/X11 selection integration
- paste:
  - synthetic key events where acceptable
- system audio:
  - Pulse monitor source or PipeWire monitor-backed implementation

Risk:

- behavior is possible, but desktop environment variance is real

### Linux Wayland

Likely implementation path:

- hotkeys:
  - `libevdev`-backed global input monitor, similar to the approach used in
    the local `potatype` reference project
  - requires readable `/dev/input/event*` devices, so this is a capability with
    setup requirements rather than a compositor-guaranteed API
- selection capture:
  - clipboard-preserve plus synthetic `Ctrl+C` fallback, similar in spirit to
    the Windows clipboard fallback and the approach used by
    `get-selected-text`
- selection replace / focused paste:
  - clipboard-preserve plus synthetic paste such as `Ctrl+V`
  - helper tools like `wl-copy` and `wtype` are a reasonable MVP path
- system audio:
  - PipeWire/portal-specific capture path

Risk:

- many Windows-style automation assumptions are still not valid
- helper-tool and compositor support can vary
- these workflows should stay capability-gated even when implemented

Immediate product policy:

- treat Wayland selection capture, selection replace, and focused paste as
  `partial`, not `full`
- do not describe the Wayland path as semantic focused-text access
- keep `core` unaware of whether the backend uses UIA, clipboard fallback,
  `wtype`, or any future portal/compositor path

Immediate recommendation:

- do not treat Linux as one behavior bucket

## Rollout Recommendation

1. keep product intent in `core` and push new OS specifics behind platform services
2. finish documenting capability assumptions before starting large non-Windows work
3. implement macOS and Linux incrementally by capability instead of "big platform ports"
4. prefer bringing up:
   - HUD / shell
   - hotkeys
   - batch ASR
   - streaming ASR
   - then clipboard-driven selection / paste
   - then system audio
5. treat selection command and auto paste as capability-gated, not guaranteed

## Current Recommendation For The Next Machine

If development moves to a macOS or Linux machine next, do this first:

1. read this document
2. read `docs/platform-rollout-plan.md`
3. inspect the platform abstractions already in use:
   - `src/platform/global_hotkey.hpp`
   - `src/platform/clipboard_service.hpp`
   - `src/platform/selection_service.hpp`
   - `src/platform/audio_capture_service.hpp`
   - `src/platform/hud_presenter.hpp`
4. do not start by editing `AppController` for platform-specific behavior
5. implement one capability at a time and document degraded behavior

## Review Checklist For New Features

When adding a feature, ask:

1. does `core` now know anything Windows-specific?
2. is the capability optional or assumed?
3. what is the degraded behavior on unsupported platforms?
4. should this be capability-gated in settings or UI?
5. can this backend be swapped without changing workflow logic?
