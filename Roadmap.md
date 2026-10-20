# Roadmap.md

This file tracks current execution status, active priorities, and the next
useful work items.

Update it when major work lands or priorities change.

## Current State

### Open input and local data program

Priorities combine user value, implementation effort, privacy risk, and
dependencies. Detailed RC003 work is tracked in `docs/rc003-roadmap.md`.

Implemented across the first slices: source-aware/date-grouped desktop history,
best-effort sensitive-target exclusion, foreground-app Profile rules, a
read-only JSON CLI, a dual-era stdio MCP server, a packaged Agent Skill, and a
secure Nearby Mobile desktop/iPhone MVP.

1. Source-aware history grouped by date and application.
   - value: very high; effort: low to medium
   - store a stable app ID and display name, never a window title by default
   - status: implemented with local-date groups and source/Profile labels
2. Read-only `shinsoku-history` CLI for agents and user automation.
   - value: very high; effort: low
   - JSON is the stable interface; diagnostic metadata and audio paths are opt-in
   - status: implemented and included in desktop packages
3. Sensitive-target history exclusion.
   - value: very high; effort: medium
   - detect secure/password fields first, then conservative token/search/address
     classifications where the OS exposes enough information
   - status: implemented as best-effort native target classification with audio cleanup
4. Foreground-app Profile rules.
   - value: high; effort: medium
   - build on the same stable app identity captured for history
   - status: implemented with exact-ID matching, conflict fallback, and recent-app Settings UI
5. Local read-only MCP server and packaged Agent Skill.
   - value: high; effort: medium
   - wrap the CLI/query layer instead of creating a second history API
   - status: implemented with 2025 initialize and 2026-07-28 discover compatibility
6. Nearby iPhone and web microphone for desktop.
   - value: high; effort: high
   - share the future push-audio boundary with RC003
   - status: desktop product runtime and Flutter iPhone client implemented;
     iOS simulator E2E covers pairing, PCM transfer, stop, and trusted reconnect
   - remaining: physical-iPhone interruption/lock/sleep/roaming validation,
     then a browser client after its HTTPS trust experience is acceptable
7. Bonjour discovery, short-code pairing, and revocable trust.
   - value: high; effort: high
   - required security foundation for nearby microphones
   - status: implemented with persistent TLS identity, certificate fingerprint
     advertisement, native macOS Bonjour, two-digit pairing, verifier-only
     storage, challenge-response, Settings controls, and live revocation
8. RC003 macOS and Windows support.
   - value: medium to high; effort: high and hardware-dependent
   - follow the independent implementation and acceptance plan
   - status: shared push-audio boundary and arrival plan complete; BLE protocol,
     decoder, and hardware validation intentionally wait for the owned device
9. Apple Watch remote microphone/control.
   - value: medium; effort: very high
   - depends on a stable nearby protocol and iPhone lifecycle
10. Versioned device adapter interface for ESP32 and community hardware.
    - value: strategic; effort: very high
    - status: experimental JSONL protocol, conformance checker, fixture, and
      standard-library Python example implemented; desktop Settings now launches
      one explicitly approved executable without a shell, displays declared
      permissions, strips credential-like environment values, and bridges PCM
      into the normal Profile pipeline
    - remaining: executable identity/sandbox hardening, multi-device selection,
      configurable button mapping, and contract hardening after RC003 becomes
      the second real implementation

### Recently completed

- Source-aware, date-grouped history and conservative sensitive-target
  exclusion landed across macOS and Windows context capture.
- Foreground-app Profile rules, the read-only history CLI/MCP server, and the
  packaged Agent Skill are implemented and covered by tests.
- Nearby Desktop Mic now has a pinned-WSS desktop runtime, Bonjour discovery,
  revocable pairing, a Flutter iPhone client, and iOS simulator E2E coverage.
- The experimental out-of-process device adapter v1 contract now has a packaged
  conformance checker, a language-neutral synthetic example, and a tested
  desktop process/PCM runtime.
- Wayland HUD surface targeting and multi-monitor placement were fixed.
- Linux system audio MVP was stabilized around PulseAudio-compatible APIs.
- Linux TLS certificate loading for streaming transcription was fixed.
- Wayland selection capture now prefers primary selection and has clearer debug
  classification.
- Wayland selection replace now reuses configured paste keys.
- Hotkey config was normalized to canonical internal key names.
- Wayland Settings gained a record-key flow for hold key and hands-free chord.
- Settings navigation was reorganized into `General / Providers / Transform /
  Network / Profiles / Advanced`.
- Profiles were simplified into `input / transform / output` presets with
  per-profile input source and input device.
- Legacy profile type and enabled-state fields were removed.
- System-audio workflows now use the `Live Caption` naming and window model.
- Tray behavior now matches desktop expectations: left click opens the main
  window and the context menu exposes history, settings, and quit.
- Windows hotkey backend now supports record-next-key in Settings through the
  shared `GlobalHotkey` capture flow.

### Current platform summary

#### Windows

- strongest platform overall
- hotkeys, selection, HUD, and streaming workflows are in good shape
- system audio MVP exists
- shared key recording now works in Settings for hold key and hands-free chord

#### Linux Wayland

- hotkeys work through passive `libevdev`
- record-next-key works
- HUD overlay works and follows the correct screen
- selection command is usable but still app-dependent
- Linux system audio MVP works on tested PulseAudio-compatible desktops
- main known limitation: Alt-based hold keys still conflict with some apps

#### Linux X11

- not started

#### macOS

- dedicated macOS backends now exist for:
  - global hotkeys
  - key recording in Settings
  - focused-app auto paste
  - accessibility-backed selection capture
  - selection replacement through focused-app paste
  - system audio capture through a native ScreenCaptureKit path
- native non-activating HUD is in place and no longer steals foreground focus
- arm64 `.app` / `.dmg` packaging target exists for release builds
- macOS and Linux now default to light tray icons to better match dark menu bars
- app launches and builds with the native macOS backend set
- main remaining work is real-hardware validation, permission UX polishing, and
  app-specific behavior classification
- known limitation: VS Code / Electron editor selection command is unreliable
  with Alt-based hold keys because the app can consume the modifier and the
  Monaco editor does not consistently expose selection text through macOS
  Accessibility APIs.

## Active Priorities

1. Validate Nearby Mobile on a physical iPhone and normal Wi-Fi:
   - first pairing and certificate-fingerprint confirmation
   - real microphone PCM quality and end-to-end transcription
   - call/audio interruption, screen lock, desktop sleep/wake, and Wi-Fi roaming
   - trust revocation and desktop TLS identity change recovery
2. Keep the local Agent interface stable:
   - preserve read-only SQLite access and default redaction
   - add query fields only through backward-compatible JSON/MCP contracts
   - do not expose API keys, audio paths, or raw diagnostic metadata by default
3. Start RC003 Phase 0 when the physical device arrives; do not infer packet
   behavior from the reference implementation before owned captures exist.
4. Validate the macOS backend on real hardware and real apps:
   - Input Monitoring permission flow for global hotkeys
   - Accessibility permission flow for selection workflows
   - Screen Recording / ScreenCaptureKit behavior for system audio
   - packaged `.app` / `.dmg` behavior on a clean machine
   - selection capture coverage across browsers, editors, terminals, and chat apps
5. Tighten macOS capability messaging and app-specific debug output where the
   native backend is still app-dependent.
6. Validate Linux system audio on more real desktop/device combinations.
7. Continue classifying Wayland selection failures by app behavior instead of
   treating them as one generic bug.
8. Keep Wayland Alt-key conflicts in the UX/documentation bucket, not as a
   low-level input-grab project.
9. Add browser and Watch clients only after the iPhone/desktop lifecycle is
   proven on physical devices.

## Mobile Direction

### Product framing

- do not treat mobile as a direct Qt port
- do treat mobile as a new product surface built around speech input
- use Flutter for the shared Android/iOS product shell
- treat platform keyboard or insertion features as native integration projects
  layered behind the Flutter shell

### Recommended implementation split

1. Flutter app:
   - record, drafts, and settings surfaces
   - profile and provider configuration UI
   - mobile history and local persistence
   - shared Android/iOS navigation and state model
2. Platform integration:
   - microphone permission and audio capture plugins
   - Android insertion / IME integration if the product returns to keyboard input
   - iOS keyboard extension only if the Flutter app flow is not enough
3. Shared logic:
   - backend/provider config that is serialization-friendly
   - transform/refine prompts that do not depend on Qt or desktop services
   - persistence models that are not tied to desktop file paths

### What should be reused

- `src/core/backend/`
- transport/auth/provider config logic
- text transform/refinement logic
- serialization-ready parts of app/profile config
- persistence models that are not tied to Qt widgets or desktop file paths

### What should not be reused directly

- Qt desktop UI in `src/ui/`
- tray, HUD, global hotkeys, desktop selection services
- Wayland / Windows / macOS platform backends under `src/platform/`
- desktop-first `AppController` orchestration if it assumes recorder triggers,
  windowing, or clipboard flows that do not exist on mobile

### Implementation order

1. Completed foundation:
   - native microphone capture and streaming/batch provider execution
   - editable drafts, Profiles, provider settings, and iOS keyboard extension
   - Nearby Desktop Mic with Bonjour/manual discovery, certificate pinning,
     secure credential storage, pairing, Profile request, and PCM streaming
2. Current hardening:
   - physical-device Nearby audio/interruption/lifecycle tests
   - clearer network and certificate-rotation recovery diagnostics
   - maintain simulator protocol and visual E2E tests
3. Later clients:
   - browser remote microphone after HTTPS onboarding is usable
   - Watch control through iPhone before investigating direct Watch audio

### Technology recommendation

- Mobile product shell: Flutter
- Android runner: generated Flutter runner plus platform channels/plugins as
  needed
- iOS runner: generated Flutter runner plus platform channels/plugins as needed

### Guardrails for mobile work

- do not start by porting the Qt desktop UI
- do not bind shared product logic tightly to Flutter widgets
- do not let mobile product constraints leak back into desktop abstractions
  unless the abstraction genuinely improves both sides
- do not promise desktop feature parity on mobile in the first phase
- do not reintroduce the deleted Kotlin/SwiftUI mobile implementations without
  an explicit product decision

## Next Suggested Task

If work continues immediately, do this next:

1. Run Nearby Mobile on a physical iPhone against the packaged macOS app and
   capture start-to-first-audio and stop-to-insertion timings.
2. Exercise interruption, lock-screen, sleep/wake, Wi-Fi loss, certificate
   rotation, and revocation recovery; turn failures into deterministic tests
   where possible.
3. When RC003 arrives, execute `docs/rc003-roadmap.md` Phase 0 and commit only
   project-owned packet/audio fixtures.
4. Use the experimental desktop adapter runtime for owned RC003 captures, then
   stabilize the public contract only after that second real implementation.

## Guardrails

- Do not introduce new platform-specific behavior directly into `src/core/`.
- Do not fork separate product flows for Windows vs Wayland unless the
  abstraction truly cannot support both.
- Do not add a macOS-only Settings path for hotkey recording when the shared
  `GlobalHotkey::capture_next_key()` flow can support it.
- Do not block the macOS port on system-audio work; finish dictation workflows
  first.
- Do not chase "consume Alt globally on Wayland" through device grabs.
- Do not create new long-lived planning docs unless they replace something in
  `AGENT.md` or `Roadmap.md`.
- Do not start mobile implementation by trying to share the Qt desktop UI.
- Do not copy GPL source or branded assets from the RC003 reference project
  without an explicit project-wide licensing decision.
