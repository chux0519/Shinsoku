# OhMyTypeless

Windows-first rewrite of Potatype with `Qt6`, structured so Linux and macOS can be added later without another UI rewrite.

## Current status

This is the new codebase. It starts from:

- `Qt6 Widgets` for the application shell
- `QSystemTrayIcon` for tray integration
- `QClipboard` for clipboard integration
- a custom frameless Qt HUD window
- a Windows global hotkey backend using `RegisterHotKey`

The long-term structure is:

- `src/core`: app state and orchestration
- `src/platform`: platform services and platform-specific backends
- `src/ui`: Qt windows and widgets

## Build

Install dependencies with `vcpkg`, then configure with the Qt toolchain from your local vcpkg clone:

```powershell
cmake -S . -B build -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build build
```

## Run

```powershell
.\build\ohmytypeless.exe
```

## Scope of the first bootstrap

This bootstrap intentionally focuses on the shell and platform boundaries first:

- application window
- settings window
- history window
- tray icon and menu
- HUD overlay
- Windows global hotkey registration
- persisted config file
- sqlite-backed history
- real microphone capture via `miniaudio`
- optional `.wav` recording persistence

The ASR / refine / Gemini pipeline is not connected yet. The current Windows app can already:

- register and persist the global hotkey
- enumerate input devices
- start and stop real microphone recording
- write capture events into local history
- optionally save raw recordings as `.wav`

## Planned migration from Potatype

1. Move pipeline, history, recording, and config logic into `src/core`.
2. Reintroduce audio capture with a cross-platform backend.
3. Keep platform-specific implementations behind service interfaces.
4. Add Linux and macOS hotkey/HUD backends incrementally.
