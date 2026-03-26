# Wayland Follow-up Notes

This document captures the current Linux/Wayland state after the recent capability bring-up work, so a follow-up agent or contributor can continue from a known baseline.

## Current Open Issues

### 1. Recording HUD first-frame rendering is broken

Status:

- `Transcribing`, `Thinking`, notice, and error HUD states render normally.
- `Recording` / `Listening` on the Wayland layer-shell HUD path still render incorrectly on first show.

Observed behavior:

- The HUD appears as a white or empty rectangular box.
- Rounded corners and the expected waveform-style content do not render correctly.
- This appears specific to the waveform-mode path, not the general HUD path.

Likely focus area:

- `src/platform/wayland/wayland_layer_shell_hud_presenter.cpp`
- Compare the `Recording` / `Listening` path against the Windows / Qt HUD behavior in:
  - `src/platform/qt/qt_hud_presenter.cpp`

Notes:

- A previous attempt to replace QSS panel styling with custom-painted panel rendering regressed other HUD states and was reverted.
- Any fix should be narrowly scoped to the waveform-mode path.

Current engineering read:

- This looks like a Wayland layer-surface first-show / first-commit issue in the waveform path, not a general HUD failure.
- The problem likely comes from geometry, child visibility, or first-frame synchronization differences between the Wayland presenter and the stable Qt HUD path.
- This should be treated as a fixable rendering bug, not as evidence that the layer-shell HUD approach is wrong.

Recommended approach:

- Keep the existing QSS-backed panel structure.
- Align the Wayland persistent HUD states more closely with `src/platform/qt/qt_hud_presenter.cpp`, especially around stable sizing and indicator visibility.
- Prefer fixes that stabilize first-frame layout or recreate the Wayland surface only when the initial surface state is clearly invalid.

Do not do this:

- Do not replace the whole HUD panel with a custom-painted implementation.
- Do not mix a broad visual redesign into this fix.
- Do not change non-waveform HUD states unless the same root cause clearly affects them.

### 2. Selection command does not reliably capture selected text on Wayland

Status:

- Current implementation exists, but is not reliable in real applications.

Observed behavior:

- Selection command fails to detect selected text in real targets.
- Clipboard fallback currently does not produce dependable results.

Current implementation approach:

- Save clipboard
- Write placeholder text
- Simulate `Ctrl+C`
- Read clipboard back
- Restore clipboard

Relevant files:

- `src/platform/wayland/wayland_selection_service.cpp`
- `src/platform/wayland/wayland_clipboard_service.cpp`

Notes:

- This is still the main known functional gap for Wayland selection workflows.
- Needs more investigation against real apps like browsers / editors.

Current engineering read:

- The current clipboard probe approach is inherently fragile on Wayland.
- The failure is not just timing noise; it comes from platform constraints around synthetic copy, clipboard ownership, and app-specific behavior.
- This should not be treated as a near-term parity bug with an obvious one-line fix.

Recommended decision point:

- Either keep this backend explicitly `partial` and message it as best-effort, or redesign the capture path around stronger Linux/Wayland-specific mechanisms.
- Do not keep tuning sleep durations and expect the current `clipboard -> Ctrl+C -> clipboard` probe to become broadly reliable.

Next investigation targets:

- Test against real targets such as Chromium-based browsers, Firefox, VSCode, and GTK text editors.
- Check whether `wl-paste`, primary-selection behavior, or compositor-specific paths provide a better signal than the current placeholder probe.
- Separate "synthetic copy was delivered" from "clipboard content changed" in debug output so failures are easier to classify.

### 3. Alt-based hold key remains high-conflict on Linux/Wayland

Status:

- Default config remains `KEY_RIGHTALT` by request.
- Linux/Wayland warning hints were added, but the underlying conflict is not fully solvable with the current listener model.

Observed behavior:

- Apps like VSCode and browsers may still react to `Alt` while recording is triggered.
- Menu focus / application shortcut behavior can leak through.

Important constraint:

- `libevdev` listening is safe for detection.
- Global keyboard grabbing was attempted and caused severe system-wide input breakage; that approach must not be used.

Relevant files:

- `src/platform/wayland/wayland_global_hotkey.cpp`
- `src/ui/settings_window.cpp`

Notes:

- A previous `libevdev_grab` attempt was removed after causing a major bug.
- Any future solution should avoid destructive device-level grabs.

Current engineering read:

- This is an architectural limitation of passive `/dev/input` monitoring, not a small implementation defect.
- The current best path is better warnings, safer defaults, and clearer capability messaging.

Recommended approach:

- Keep the backend as listener-only.
- Prefer `Ctrl`-based defaults or stronger Linux-specific warnings if the default key is revisited later.
- Treat any future "consume the key globally" idea as suspect unless it avoids device grabs entirely.

### 4. Alt+Space still interferes with app UI in some cases

Status:

- Partially mitigated, not fully fixed.

Observed behavior:

- In-app controls may still react when `Alt + Space` is used.
- Profile dropdown interaction remains imperfect.

Relevant files:

- `src/ui/main_window.cpp`

Notes:

- This is a UX issue, not currently a system-stability issue.
- Lower priority than the waveform HUD and selection capture issues.

Current engineering read:

- This is related to the same Alt propagation problem, but limited to in-app behavior.
- It should be handled as a local UI mitigation task, not as a platform backend blocker.

### 5. Linux system audio needs more runtime validation

Status:

- A Linux MVP backend now exists.
- It compiles and is wired into Linux startup.
- It still needs more real-world validation.

Implementation status:

- Backend path should now prefer the PulseAudio compatibility layer.
- Microphone capture continues to delegate to miniaudio.

Relevant files:

- `src/platform/linux/linux_pulseaudio_audio_capture_service.hpp`
- `src/platform/linux/linux_pulseaudio_audio_capture_service.cpp`
- `src/main.cpp`
- `CMakeLists.txt`

Notes:

- Default-output capture is enough for the first Linux MVP.
- It should be tested specifically with `system audio + meeting profile` flows.

Current engineering read:

- For now, the safest route is to lean on the desktop's PulseAudio compatibility surface, which usually maps to `pipewire-pulse` on mainstream distros.
- The main remaining risk is runtime behavior across real desktop setups, not basic code structure.

Validation priorities:

- Verify default-output capture on a normal Linux desktop with `pipewire-pulse` or PulseAudio available.
- Test `system audio + meeting profile` end-to-end, including start, streaming updates, and stop.
- Confirm failure behavior when the compatibility server is unavailable or when the default output changes during app lifetime.

## Things That Are Working

- Wayland global hotkey monitoring works in principle.
- Wayland layer-shell HUD can show as a real overlay.
- HUD follows the host window's screen better than the earlier single-screen behavior.
- HUD bottom margin now affects placement.
- `Paste to focused window` no longer resets immediately on apply.
- Profiles now have usable disabled-profile semantics.
- Linux system audio backend now exists as an MVP.
- The project currently builds successfully with:

```bash
cmake --build build-vcpkg -j8
```

## Recommended Next Priorities

1. Fix `Recording` / `Listening` HUD first-frame rendering on Wayland.
2. Decide whether Wayland selection capture should remain best-effort or move to a redesigned backend, then implement that decision.
3. Validate and harden `system audio + meeting` flows on Linux.
4. Revisit Alt-related hotkey conflicts only after the above are stable.
