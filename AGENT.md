# AGENT.md

This file records repository-level implementation conventions for coding agents.

## UI styling

- Keep application styling centralized in shared theme resources under
  `resources/themes/`.
- Keep `src/ui/app_theme.cpp` limited to theme loading and token substitution.
- Do not add ad-hoc stylesheet strings to individual `*.cpp` or `*.hpp` files
  unless there is a temporary, clearly documented exception.
- Prefer exposing stable widget `objectName`s from UI code and styling those
  names from the shared QSS instead of embedding local visual rules next to the
  widget construction code.

## Platform boundaries

- Keep platform-specific behavior behind platform or capability abstractions;
  do not let Windows-only APIs or assumptions spread into `src/core/`.
- When adding new OS-dependent features such as global input, clipboard /
  selection, system-audio capture, tray integration, or focused-window paste,
  prefer an interface that can support Windows, macOS, and Linux backends later.
- For input and capture features, model product-level intent in `core`
  and keep concrete backend details such as WASAPI loopback, X11/Wayland,
  macOS accessibility, or Windows foreground-window handling out of shared
  workflow code.
