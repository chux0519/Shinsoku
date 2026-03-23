# Selection Follow-ups

This note tracks the known issues after landing the first working
`SelectionService` and selection-command MVP.

## Confirmed Issues

### 1. Cross-platform auto-detection is still Windows-shaped

Current `AppController` behavior always probes `selection_->capture_selection()`
before deciding whether to run plain dictation or selection-command mode.

That is acceptable for the current Windows MVP, but it is not a correct
cross-platform default yet:

- the Qt stub always reports failure
- ordinary dictation on non-Windows would still produce fallback-style selection
  debug/state behavior
- `selection_detection.capture_backend` is currently written as the Windows
  backend name in the dictation fallback metadata path

Follow-up:

- add a capability-style check for automatic selection detection
- only run selection auto-detection when the platform backend explicitly
  supports it
- stop hardcoding the Windows backend name in generic metadata paths

### 2. Windows clipboard restore still only restores plain text

The current Windows selection backend now uses native clipboard APIs for
reliability, but the snapshot/restore path only preserves `CF_UNICODETEXT`.

That means selection-command use can degrade or overwrite richer clipboard
content such as:

- images
- file lists
- HTML / rich text
- multi-format clipboard payloads

Follow-up:

- implement a richer native clipboard snapshot/restore path
- preserve the formats that matter most for user workflows instead of only
  plain text

## Current Status

What works now:

- selection capture on Windows
- UIA-first, clipboard-fallback selection detection
- LLM-powered selection-command transforms
- replacing the selected text in tested Windows editor flows

What still needs cleanup:

- capability-driven cross-platform gating
- richer clipboard restoration on Windows
