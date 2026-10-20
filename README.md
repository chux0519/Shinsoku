# Shinsoku

Shinsoku is a cross-platform voice input product for desktop and mobile.

Today the repository contains:

- a Qt desktop app for Windows, macOS, and Linux
- a Flutter mobile app for Android and iOS under [mobile](/Volumes/ZT/repos/Shinsoku/mobile)

## Product shape

Shinsoku is built around one workflow:

1. Capture speech
2. Transcribe with the right backend
3. Optionally refine or transform the text
4. Insert it into the active surface
5. Keep enough history and settings to make the workflow repeatable

The project is opinionated about that loop, but not about one single provider or one single platform shell.

## Current status

### Desktop

- Qt-based app with profile-driven voice input workflows
- Windows, macOS, and Linux support
- streaming transcription backends
- transform / post-processing pipeline
- history, local persistence, clipboard/paste flows, HUD surfaces

Code lives under [src](/Volumes/ZT/repos/Shinsoku/src).

Known limitation: desktop selection-command support is app-dependent. On macOS,
native text fields and terminal text selection are expected to work better than
Electron/Monaco editors such as VS Code, which may intercept modifier keys or
not expose selected editor text reliably through Accessibility APIs. Prefer a
non-conflicting hold key when testing editor integrations.

### Mobile

- Flutter product shell for Android and iOS
- real microphone capture, editable drafts, Profiles, and provider settings
- Bailian batch/realtime and Soniox streaming transcription paths
- iOS keyboard extension handoff
- secure Nearby Desktop Mic client with local discovery and PCM streaming

Code lives under [mobile](/Volumes/ZT/repos/Shinsoku/mobile).

## Repository layout

- [src](/Volumes/ZT/repos/Shinsoku/src): desktop app
- [resources](/Volumes/ZT/repos/Shinsoku/resources): shared brand/theme assets
- [packaging](/Volumes/ZT/repos/Shinsoku/packaging): desktop packaging scripts
- [mobile](/Volumes/ZT/repos/Shinsoku/mobile): Flutter mobile app and generated platform runners

## Build

### Desktop

Use CMake with `vcpkg`:

```bash
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Debug --target shinsoku
cmake --build build --config Release --target shinsoku
```

See [RELEASE.md](/Volumes/ZT/repos/Shinsoku/RELEASE.md) for packaging and release details.

### Local history for agents

Build the read-only JSON CLI and local MCP server with the desktop targets:

```bash
cmake --build build --config Debug --target shinsoku-history shinsoku-history-mcp
./build/Debug/shinsoku-history list --since 2026-08-01 --limit 20 --pretty
./build/Debug/shinsoku-history list --app Mail --query project --pretty
./build/Debug/shinsoku-history get 42 --pretty
```

The default response omits diagnostic metadata and local recording paths. Use
`--include-meta` or `--include-audio-path` only for explicit debugging tasks.
The bundled `skills/read-shinsoku-history` skill gives agents the same guarded
query workflow without direct SQLite access.

For MCP hosts, register the packaged stdio server as a local command:

```json
{
  "mcpServers": {
    "shinsoku-history": {
      "command": "/Applications/Shinsoku.app/Contents/MacOS/shinsoku-history-mcp"
    }
  }
}
```

During development, use `build/Debug/shinsoku-history-mcp`. On Windows, point
the host to `shinsoku-history-mcp.exe` in the portable package. The server
supports legacy 2025 initialization and 2026-07-28 discovery, exposes only
search/get tools, opens SQLite read-only per call, and never returns raw
diagnostic metadata or recording paths. Pass `--database /path/history.sqlite3`
only when intentionally reading a non-default Shinsoku database.

### Nearby Desktop Mic

The desktop can accept a private local-network microphone stream from the
Flutter iPhone client. Enable it under `Settings > Network > Nearby
Microphone`, create a two-digit pairing code, then open the mobile app's
`Desktop` tab. The client discovers the desktop with Bonjour or accepts a
manual WSS endpoint plus certificate fingerprint.

Nearby is disabled by default. LAN transport is WSS-only, the client pins the
exact advertised certificate fingerprint, the desktop stores only a verifier
for the issued credential, and trusted devices can be revoked in Settings.
Protocol and simulator E2E details are in
[`docs/nearby-mobile-protocol.md`](docs/nearby-mobile-protocol.md).

### Open Device Adapters

Third-party hardware integrations can target the experimental Device Adapter
v1 JSONL contract without linking against Shinsoku or entering its process. A
packaged checker validates manifests, device/button events, strict PCM chunk
ordering, and bounded mono PCM16 audio traces:

```bash
cmake --build build --config Debug --target shinsoku-adapter-check
./build/Debug/shinsoku-adapter-check \
  --trace tests/fixtures/device_adapter_valid.jsonl \
  --require-audio --pretty
```

See [`docs/device-adapter-interface.md`](docs/device-adapter-interface.md) and
the standard-library Python example under `examples/device-adapters/`.
The desktop can run one explicitly selected executable from `Settings >
Advanced > Device Adapter`; it displays the adapter's declared permissions and
routes accepted PCM through the normal Profile pipeline. This child process is
not an OS sandbox, so only select an adapter you trust.

### Mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run
```

Mobile details live in [mobile/README.md](/Volumes/ZT/repos/Shinsoku/mobile/README.md).

## Design direction

The product direction is simple:

- Qt desktop UI and Flutter mobile UI
- shared prompt/profile/pipeline logic where it is worth reusing
- shared brand language across desktop, Android, and iOS
- black/white system-following themes instead of heavily branded chrome

## Collaboration

If you are continuing work in this repo, read:

- [Roadmap.md](/Volumes/ZT/repos/Shinsoku/Roadmap.md)
- [AGENT.md](/Volumes/ZT/repos/Shinsoku/AGENT.md)
