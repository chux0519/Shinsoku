# Wayland Follow-up Notes

This document captures the current Linux/Wayland state after the recent capability bring-up work, so a follow-up agent or contributor can continue from a known baseline.

## Current Open Issues

### 1. Alt-based hold key remains high-conflict on Linux/Wayland

Status:

- Default config remains `right_alt` by request.
- Linux/Wayland warning hints and key-recording support now exist, but the
  underlying conflict is not fully solvable with the current listener model.

Observed behavior:

- Apps like VSCode and browsers may still react to `Alt` while recording is
  triggered.
- Menu focus / application shortcut behavior can leak through.
- Some laptop-specific keys may report as `left_meta`, `menu`, or other
  hardware-dependent codes when recorded.

Important constraint:

- `libevdev` listening is safe for detection and one-shot key capture.
- Global keyboard grabbing was attempted and caused severe system-wide input
  breakage; that approach must not be used.

Relevant files:

- `src/platform/wayland/wayland_global_hotkey.cpp`
- `src/platform/hotkey_names.hpp`
- `src/platform/hotkey_names.cpp`
- `src/ui/settings_window.cpp`
- `src/core/app_controller.cpp`

Notes:

- Hotkey config now stores canonical names like `right_alt`, `space`, and
  `menu` instead of backend-specific `KEY_*` names.
- Settings can now record the next key on Wayland and temporarily suspend
  existing hotkeys during capture.
- If a keyboard exposes a vendor key as the same evdev code as `left_meta`,
  the application cannot distinguish them.

Current engineering read:

- This is an architectural limitation of passive `/dev/input` monitoring, not a
  small implementation defect.
- The current best path is better warnings, safer alternatives, and clearer
  recording/configuration UX.

Recommended approach:

- Keep the backend as listener-only.
- Keep the new record-key UX and canonical hotkey abstraction.
- Treat `Alt` as a high-conflict option rather than a default-safe key.
- If defaults are revisited later, prefer a key with better hardware
  availability and lower menu/editor conflict.

### 2. Selection command remains partial on Wayland

Status:

- Core capture and replace now work in some real applications, but the workflow
  remains app-dependent.

Observed behavior:

- Selected text capture now works in tested browser/editor targets when primary
  selection is available.
- Replace now works in browser inputs that accept `wl-copy` plus synthetic
  paste.
- Some apps such as VSCode may still fail if the chosen hold key steals focus
  before paste is sent.

Current implementation approach:

- Try `wl-paste --primary` first
- Fall back to clipboard-preserve plus synthetic `Ctrl+C`
- Replace via `wl-copy` plus configured paste keys, then restore clipboard

Relevant files:

- `src/platform/wayland/wayland_selection_service.cpp`
- `src/platform/wayland/wayland_clipboard_service.cpp`

Notes:

- Real-world behavior has improved enough that this is no longer a total
  blocker, but it still is not platform-parity with Windows focused-text
  editing.
- Debug info now distinguishes primary-selection success from clipboard
  fallback behavior.

Current engineering read:

- The stronger path is primary selection plus explicit clipboard helper tools,
  not more tuning of the old clipboard-probe-only approach.
- The remaining failures are mostly focus / injection compatibility issues, not
  "capture is always broken" failures.

Recommended decision point:

- Keep this backend explicitly `partial` and message it as app-dependent.
- Do not keep tuning sleep durations and expect full semantic parity with
  Windows.

Next investigation targets:

- Test against more targets such as Chromium-based browsers, Firefox, VSCode,
  and GTK text editors.
- Check whether `shift+insert` or other configured paste keys improve specific
  editor compatibility.
- Keep distinguishing focus/key-conflict failures from actual capture failures
  in debug output.

### 3. Windows hotkey recording is still pending

Status:

- The shared hotkey recording abstraction now exists.
- Only the Wayland backend currently implements "record the next key."

Observed behavior:

- Windows still relies on selecting from the predefined hotkey list.
- Settings/workflow already support a backend-provided record-next-key path, so
  Windows can plug into it later without product-layer redesign.

Relevant files:

- `src/platform/global_hotkey.hpp`
- `src/platform/windows/windows_global_hotkey.cpp`
- `src/platform/hotkey_names.hpp`
- `src/platform/hotkey_names.cpp`
- `src/ui/settings_window.cpp`

Current engineering read:

- The interface shape is now good enough for Windows to implement later.
- The main remaining Windows work is backend event capture and canonical-name
  mapping, not product/UI design.

Recommended approach:

- Leave the current abstraction in place.
- When Windows work resumes, implement `supports_key_capture()` and
  `capture_next_key(...)` in the Windows backend instead of adding a separate UI
  path.

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

### 5. Linux system audio still needs broader runtime validation

Status:

- A Linux MVP backend now exists.
- It compiles, is wired into Linux startup, and has passed initial end-to-end
  validation.
- It still needs broader real-world validation across more desktops and device
  changes.

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
- HUD follows the host window's screen correctly across multi-monitor placement.
- HUD bottom margin now affects placement.
- Wayland `Recording` / `Listening` HUD first-frame rendering has been fixed.
- `Paste to focused window` no longer resets immediately on apply.
- Profiles now have usable disabled-profile semantics.
- Hotkey config now uses canonical internal key names with backward-compatible
  migration from old `KEY_*` values.
- Settings can record the next hold key or hands-free chord on Wayland.
- Wayland selection capture now prefers primary selection and can succeed in
  real browser/editor targets.
- Wayland selection replace now reuses configured paste keys.
- Linux system audio backend now exists as an MVP.
- The project currently builds successfully with:

```bash
cmake --build build-vcpkg -j8
```

## Recommended Next Priorities

1. Document and later implement Windows hotkey key-capture on top of the new shared abstraction.
2. Validate and harden `system audio + meeting` flows on Linux across more desktop/device scenarios.
3. Continue classifying Wayland selection failures by app/focus/paste-key behavior instead of treating them as one generic bug.
4. Revisit Alt-related hotkey conflicts only as UX policy and messaging, not as a device-grab project.
