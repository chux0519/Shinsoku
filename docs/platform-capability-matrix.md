# Platform Capability Matrix

This note tracks the current and planned platform support boundaries for
Windows, macOS, and Linux.

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
| Global hold-to-record hotkey | full | planned | planned | partial | Wayland likely needs portal-based degradation |
| Hands-free chord behavior | full | planned | planned | partial | Depends on global input support |
| Selection capture | partial | planned | planned | planned | Windows uses UIA plus clipboard fallback |
| Selection replace | partial | planned | planned | planned | Clipboard and focused-input semantics differ by platform |
| Auto paste to focused window | partial | planned | partial | unsupported/partial | Wayland should be treated conservatively |
| Tray integration | partial | planned | partial | partial | Desktop environment differences matter |
| HUD overlay | full | planned | planned | planned | Pure Qt path is portable |
| Batch HTTP ASR | full | full | full | full | Provider/backend dependent, not platform dependent |
| Streaming websocket ASR | full | planned | planned | planned | Transport layer is mostly portable |
| System audio capture | planned | planned | planned | planned | Platform-specific audio APIs required |
| Offline sherpa-onnx ASR | planned | planned | planned | planned | Mostly backend/library integration once audio path exists |

## Windows Notes

Current strengths:

- mature hotkey behavior
- working clipboard integration
- streaming providers already validated
- HUD and shell are stable

Current caveats:

- selection capture still depends on editor behavior
- focused paste is inherently app-dependent
- system audio capture not implemented yet

## macOS Notes

Expected requirements:

- accessibility permission for global input / focused text workflows
- separate system-audio capture path
- careful testing for overlay, tray, and clipboard behaviors

Immediate recommendation:

- do not start implementation until capability-specific abstractions are ready

## Linux Notes

Split Linux thinking into:

- X11
- Wayland

Reason:

- global input and focused-window automation assumptions differ drastically
- system audio and selection behavior vary with compositor / desktop stack

Immediate recommendation:

- do not treat Linux as one behavior bucket

## Rollout Recommendation

1. finish workflow-level features in platform-agnostic form
2. land system audio abstraction
3. land offline ASR backend
4. audit Windows-only assumptions after those abstractions exist
5. implement macOS and Linux incrementally by capability:
   - hotkey
   - selection
   - paste
   - tray
   - system audio

## Review Checklist For New Features

When adding a feature, ask:

1. does `core` now know anything Windows-specific?
2. is the capability optional or assumed?
3. what is the degraded behavior on unsupported platforms?
4. should this be capability-gated in settings or UI?
