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
