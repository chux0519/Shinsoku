# Feature Roadmap

This document tracks the next feature wave after the Qt shell alignment work.
It is intentionally file-oriented so implementation can proceed incrementally
without losing architectural boundaries.

## Goals

1. Add configurable HTTP proxy support with both `http` and `socks5`.
2. Add a "selection command" interaction mode:
   - capture selected text from the current app
   - transcribe a spoken command
   - send both to an LLM text transform backend
   - replace the selected text with the result
3. Prepare for more ASR backends, including streaming / websocket backends.
4. Add profile / preset support for reusable recurring workflows.
5. Add system-audio / loopback capture for meeting transcription workflows.
6. Add an offline fallback / forced-local mode with `sherpa-onnx`.
7. Redesign settings information architecture so provider-specific configuration
   can expand without turning the settings window into one long page.

## Guiding Rules

1. Keep `core` platform-agnostic.
2. Keep platform-specific selection / paste / focus behavior under `src/platform`.
3. Avoid adding more provider-specific branches directly into `AppController`.
4. Prefer capability-driven backend interfaces over "OpenAI-compatible" assumptions.
5. Land each phase with the current app still usable.

## Delivery Order

1. Network and proxy foundation
2. Backend abstraction pass 1
3. Selection service abstraction
4. Selection command MVP
5. Settings information architecture redesign
6. Streaming backend support
7. Profiles / presets
8. System audio / meeting transcription
9. Offline `sherpa-onnx` mode
10. Online/offline fallback policy refinement
11. Cross-platform capability audit and rollout planning

## Status

- Phase 1: completed
- Phase 2: completed
- Phase 3: completed
- Phase 4: in progress
- Phase 5: in progress
- Phase 6: in progress
- Phase 7: in progress
- Phase 8: in progress
- Phase 9: pending
- Phase 10: pending
- Phase 11: pending

---

## Phase 1: Network And Proxy Foundation

### Outcome

All HTTP-based backends read network transport settings from one place. Proxy
support is available in settings and config, and applies consistently to ASR,
refine, and future online backends.

### Files To Change

#### `src/core/app_config.hpp`

Add:

- `enum`-like proxy type as string or dedicated config fields
- `NetworkProxyConfig`
  - `enabled`
  - `type` = `http` | `socks5`
  - `host`
  - `port`
  - optional `username`
  - optional `password`
- `NetworkConfig`
  - `proxy`
- add `network` to `AppConfig`

#### `src/core/app_config.cpp`

Add config parsing and writing for:

- `[network.proxy]`
  - `enabled`
  - `type`
  - `host`
  - `port`
  - `username`
  - `password`

Keep path normalization behavior intact.

#### `src/ui/settings_window.hpp`

Add getters/setters for:

- proxy enabled
- proxy type
- proxy host
- proxy port
- proxy username
- proxy password

#### `src/ui/settings_window.cpp`

Add a `Network` section containing:

- enable checkbox
- type combo box
- host line edit
- port spin box
- username line edit
- password line edit

This can stay in the current long settings page for now. Later tab splitting can
move it without changing config shape.

#### `src/core/curl_support.hpp`

Add a small transport/options struct:

- `CurlTransportOptions`
  - proxy enabled
  - proxy URL or fields
  - optional auth

#### `src/core/curl_support.cpp`

Centralize libcurl proxy setup here:

- map config to curl proxy settings
- support both HTTP proxy and SOCKS5 proxy
- keep the rest of the clients ignorant of proxy details

#### `src/core/asr_client.cpp`

Stop reaching directly into config for transport assumptions.
Use transport options from a shared builder/helper.

#### `src/core/text_refiner.cpp`

Same as ASR client.

#### New file: `src/core/network_config.hpp`

Optional extraction target if `app_config.hpp` starts getting too large.
If this is introduced, keep it config-only and not Qt-dependent.

### Acceptance Criteria

- Proxy config can be edited in settings and persisted to config.
- Existing OpenAI-compatible ASR and refine requests use proxy settings.
- No platform-specific code leaks into `core`.

### Progress Notes

- `AppConfig` now includes proxy settings under `network.proxy`.
- Settings UI now exposes proxy enable/type/host/port/username/password.
- `curl_support` now owns shared transport options and proxy application.
- Existing ASR and refine requests now use shared transport options.

---

## Phase 2: Backend Abstraction Pass 1

### Outcome

Current batch ASR and refine behavior remains unchanged, but `AppController`
stops being tightly coupled to one concrete online backend style.

### Files To Add

#### `src/core/backend/asr_backend.hpp`

Define:

- `AsrBackend`
  - `name()`
  - `supports_streaming()`
  - `transcribe(...)`

#### `src/core/backend/text_transform_backend.hpp`

Define:

- `TextTransformRequest`
  - `input_text`
  - `instruction`
  - optional `context`
- `TextTransformBackend`
  - `name()`
  - `transform(...)`

#### `src/core/backend/backend_factory.hpp`

Create current backend instances from config.

### Files To Change

#### `src/core/asr_client.hpp`
#### `src/core/asr_client.cpp`

Either:

- adapt `AsrClient` to implement `AsrBackend`, or
- keep it as an internal concrete class used by a new adapter

#### `src/core/text_refiner.hpp`
#### `src/core/text_refiner.cpp`

Either:

- adapt as a concrete `TextTransformBackend`, or
- keep as implementation detail behind an adapter

#### `src/core/app_controller.cpp`

Reduce direct construction of provider clients inside transcription jobs.
Use backend interfaces or a backend factory.

### Acceptance Criteria

- Existing dictation flow still works.
- `AppController` no longer encodes provider assumptions directly.
- New backend types can be introduced without expanding the controller again.

### Progress Notes

- Added `AsrBackend` and `TextTransformBackend` interfaces.
- Added a first `backend_factory`.
- `AsrClient` now implements `AsrBackend`.
- `TextRefiner` now implements `TextTransformBackend`.
- `AppController` now uses backend factory output in the transcription job path.

---

## Phase 3: Selection Service Abstraction

### Outcome

Selection capture and replacement become explicit platform services instead of
being embedded into app logic.

### Files To Add

#### `src/platform/selection_service.hpp`

Define:

- `SelectionCaptureResult`
  - `success`
  - `selected_text`
  - optional debug info
- `SelectionService`
  - `capture_selection()`
  - `replace_selection(const QString&)`
  - optional `last_debug_info()`

#### `src/platform/qt/qt_selection_service.hpp`
#### `src/platform/qt/qt_selection_service.cpp`

Fallback / stub implementation for non-Windows builds.

#### `src/platform/windows/windows_selection_service.hpp`
#### `src/platform/windows/windows_selection_service.cpp`

Windows MVP implementation:

- preserve clipboard
- simulate copy on selection
- read selected text
- replace selection via paste path
- restore clipboard

### Files To Change

#### `CMakeLists.txt`

Add new platform files, with Windows sources guarded by `WIN32`.

#### `src/main.cpp`

Compose the correct `SelectionService` implementation.

### Acceptance Criteria

- `core` does not know how selection is captured.
- Windows has a usable MVP.
- Non-Windows builds still compile via a safe stub.

### Progress Notes

- Added `SelectionService` as a dedicated platform boundary.
- Added a Windows MVP that captures and replaces selection via clipboard
  preservation plus simulated copy/paste shortcuts.
- Added a Qt stub backend so non-Windows builds can keep compiling cleanly.
- Wired selection service construction through `main.cpp` and into
  `AppController` without changing the existing dictation workflow yet.

---

## Phase 4: Selection Command MVP

### Outcome

A new interaction mode supports:

1. user selects text in another app
2. user triggers command mode
3. app records spoken instruction
4. app transcribes instruction
5. app sends `selected_text + instruction` to an LLM text transform backend
6. app replaces the selected text

### New Concepts

#### `src/core/task_types.hpp`

Define:

- `CaptureMode`
  - `dictation`
  - `selection_command`
- `TextTask`
  - `mode`
  - `selected_text`
  - `spoken_instruction`
  - `result_text`

### Files To Change

#### `src/core/app_state.hpp`

Potentially add a distinct mode/state marker for selection command workflows.

#### `src/core/app_controller.hpp`
#### `src/core/app_controller.cpp`

Add:

- selection command trigger path
- selection capture before or after recording, depending on UX choice
- instruction transcription flow
- transform request assembly
- replace-selection output path

Do not overload existing plain dictation path with many inline branches.
Prefer a small helper flow.

#### `src/ui/main_window.hpp`
#### `src/ui/main_window.cpp`

Optional early UI affordance:

- add a button for testing selection command mode
- or a visible status/hint for the mode

#### `src/platform/global_hotkey.hpp`

Later extension point if a separate hotkey should trigger command mode.
Do not change yet unless required for MVP.

### Prompt / Backend Behavior

For MVP, reuse the refine-style backend path with a dedicated instruction prompt
template. Do not build a general agent system yet.

### Acceptance Criteria

- Works on Windows with selected text in common editors.
- Failure modes are visible:
  - no selection found
  - command transcription failed
  - transform failed
  - replace failed

---

## Phase 5: Settings Information Architecture Redesign

### Outcome

The settings UI stops growing as one long scrollable form and becomes a
navigation-based settings shell that can host both common settings and
provider-specific pages cleanly.

### Design Direction

Use a settings container with:

- left-side navigation (`QListWidget` or equivalent)
- right-side `QStackedWidget` pages
- card-style sections inside each page

Initial page split:

- `General`
- `Audio`
- `ASR`
- `Transform`
- `Network`
- `Providers`
- `Advanced`

### Config Shape Direction

Gradually align config to these conceptual groups:

- `general`
- `audio`
- `asr`
  - `batch`
  - `streaming`
- `transform`
- `network`
- `providers`
  - `openai_compatible`
  - `soniox`
  - `bailian`
  - `sherpa_onnx`
- `advanced`

Provider-specific settings should live under `providers.<name>` instead of
being flattened into generic sections.

### Files To Change

#### `src/ui/settings_window.hpp`
#### `src/ui/settings_window.cpp`

Refactor the current monolithic layout into:

- navigation list
- stacked pages
- per-page section builders

Keep current fields functional while moving them into the new grouping.

#### `src/core/app_config.hpp`
#### `src/core/app_config.cpp`

Prepare for future config reshaping where needed, but avoid a breaking config
migration unless it is required for correctness. It is acceptable to keep the
existing storage shape temporarily while the UI grouping changes first.

#### `src/core/app_controller.cpp`

Keep settings synchronization logic working while fields move between pages.

#### New file: `docs/settings-redesign.md`

Track:

- page structure
- field-to-page mapping
- legacy config names vs future config grouping
- which settings stay generic vs which move under provider-specific config

### Acceptance Criteria

- Settings are split into navigation-based pages instead of one long form.
- Existing settings remain editable and persisted correctly.
- There is a clear home for provider-specific configuration before streaming and
  offline providers are added.

### Progress Notes

- Added `docs/settings-redesign.md` to track page grouping and field mapping.
- `SettingsWindow` now uses a navigation-based shell with dedicated pages for
  General, Audio, ASR, Transform, Network, Providers, and Advanced.
- Existing settings getters and setters were kept stable so controller sync and
  config persistence did not need to change in the first pass.

---

## Phase 6: Streaming Backend Support

### Outcome

The architecture can host real-time / websocket / incremental ASR providers
without reworking the dictation stack again.

### Files To Add

#### `src/core/backend/streaming_asr_backend.hpp`

Define:

- `StreamingAsrCallbacks`
  - `on_partial_text`
  - `on_final_text`
  - `on_error`
- `StreamingAsrSession`
  - `start`
  - `push_audio`
  - `finish`
  - `cancel`
- `StreamingAsrBackend`
  - `create_session(...)`

#### `src/core/backend/streaming_asr_backend.cpp`

May be unnecessary if interface-only.

### Files To Change

#### `src/core/app_controller.cpp`

Separate:

- batch recording/transcribe flow
- streaming live transcription flow

Do not let the current batch path absorb websocket semantics.

#### `src/core/audio_recorder.*`

May need chunk delivery hooks for live streaming.

#### `src/platform/hud_presenter.hpp`

Optional later extension:

- support partial transcription text in HUD

### Acceptance Criteria

- Existing batch path still works.
- One streaming backend can be added without changing the public dictation UX too much.

### Progress Notes

- Added a first `streaming_asr_backend.hpp` interface with session, callbacks,
  capabilities, and audio format types.
- Extended `backend_factory` and `AppController` to reserve a streaming backend
  slot without changing the current batch dictation path yet.
- Added first-pass streaming settings fields and Soniox provider placeholders so
  realtime backend configuration can be persisted before the websocket client
  itself is implemented.
- Integrated `ixwebsocket` into the build, added websocket transport options
  derived from the shared proxy config, and introduced a first Soniox backend
  skeleton so provider-specific websocket work can land without expanding
  `AppController`.
- Added a proxy-capable websocket socket layer with HTTP CONNECT and SOCKS5
  tunneling support for `wss` sessions, and wired the first Soniox streaming
  session to use it.
- `AppController` now routes plain dictation through the streaming backend when
  streaming is enabled, while selection-command mode continues to use the batch
  path.
- Added `scripts/soniox_smoke_test.py` for protocol verification; the current
  test key reaches Soniox successfully but returns `402 Organization balance
  exhausted`, so product-level streaming still needs a funded key for live
  transcription validation.

---

## Phase 7: Profiles / Presets

### Outcome

Users can save and switch between reusable workflows without editing prompts
and output behavior every time.

Examples:

- default dictation
- selection rewrite
- speak Chinese, output polished English
- meeting cleanup / summarize

### Design Direction

Profiles should sit above provider configuration. They are workflow presets,
not transport or provider definitions.

A profile may bind:

- capture mode preference
- transform enabled/disabled
- transform prompt template
- preferred output behavior
- preferred ASR backend / streaming provider

### Files To Change

#### `src/core/app_config.hpp`
#### `src/core/app_config.cpp`

Add a profile list / active profile concept, or split profile config out if
`AppConfig` becomes too large.

#### `src/ui/settings_window.*`

Add a dedicated profile management page or section:

- list profiles
- create / rename / delete
- set active profile

#### `src/core/app_controller.*`

Apply the active profile to capture / transform / output behavior without
polluting provider-specific code paths.

#### New file: `docs/profiles-design.md`

Track:

- profile schema
- global vs per-profile settings
- migration plan from the current single refine prompt setup

### Acceptance Criteria

- User can switch profiles without manually editing prompts every time.
- One profile can express "speak Chinese, output polished English" as a stable
  workflow.
- Profiles coexist cleanly with provider-specific settings.

---

## Phase 8: System Audio / Meeting Transcription

### Outcome

The app can capture system output audio, not just microphone input, enabling
meeting transcription and media transcription workflows.

### Design Direction

Treat this as an input-source feature rather than an ASR-backend feature.

Introduce an audio capture source such as:

- `microphone`
- `system`
- later optional `mix`

Start with Windows loopback capture via WASAPI.

### Files To Change

#### `src/core/app_config.hpp`
#### `src/core/app_config.cpp`

Add capture source configuration under audio.

#### `src/core/audio_recorder.*`

Refactor toward an input-source abstraction so microphone capture and loopback
capture do not remain hard-coded into one path.

#### `src/ui/settings_window.*`

Expose input source selection in the Audio page.

#### `src/core/app_controller.*`

Ensure meeting-transcription workflows do not assume paste-to-focused-window as
the primary output path.

#### New file: `docs/system-audio-design.md`

Track:

- loopback MVP scope
- platform differences
- output expectations for meeting transcription

### Acceptance Criteria

- Windows can transcribe system audio via loopback capture.
- Existing microphone dictation still works.
- Settings clearly distinguish microphone vs system capture.

---

## Phase 9: Offline `sherpa-onnx`

### Outcome

The app can run fully local ASR on CPU when configured to do so.

### Files To Add

#### `src/core/backend/offline_asr_backend.hpp`

Define offline backend interface specialization if needed.

#### `src/core/backend/sherpa_onnx_asr_backend.hpp`
#### `src/core/backend/sherpa_onnx_asr_backend.cpp`

Concrete backend for local inference.

#### `src/core/offline_config.hpp`

If `AppConfig` becomes too large, split offline model settings here.

### Files To Change

#### `src/core/app_config.hpp`
#### `src/core/app_config.cpp`

Add offline config:

- `mode` = `disabled | fallback | forced`
- `provider` = `sherpa_onnx`
- `model_path`
- optional decoding/runtime settings

#### `src/ui/settings_window.*`

Add offline section:

- mode
- model path
- optional choose button

### Acceptance Criteria

- Forced offline mode works without network.
- Model path errors are surfaced clearly.
- Offline backend plugs into the same backend selection layer as online ASR.

---

## Phase 10: Fallback Policy Refinement

### Outcome

Online/offline switching becomes predictable and debuggable.

### Files To Change

#### `src/core/app_controller.cpp`
#### `src/core/backend/backend_factory.*`

Define when fallback is allowed.

Examples:

- allowed fallback:
  - no network
  - connection refused
  - DNS failure
  - timeout
- no fallback:
  - invalid credentials
  - bad request
  - unsupported model config

### Acceptance Criteria

- Users can tell whether the app ran online or offline.
- Failure policy is deterministic and debuggable.

---

## Phase 11: Cross-Platform Capability Audit And Rollout Plan

### Outcome

The project has an explicit rollout plan for macOS and Linux support instead of
accumulating ad-hoc Windows-first behavior.

### Scope

Document and prioritize platform gaps for:

- global hotkey semantics
- system audio capture
- selection capture / replace
- focused-window paste
- HUD / tray behavior
- streaming provider transport support

### Deliverables

#### New file: `docs/platform-capability-matrix.md`

Document:

- supported capabilities by platform
- degraded / unsupported capabilities
- rollout order for macOS and Linux

### Acceptance Criteria

- There is a concrete capability matrix for Windows / macOS / Linux.
- Future cross-platform work can proceed incrementally without re-deciding
  boundaries each time.

---

## Suggested Milestones

### Milestone A

- Phase 1
- Phase 2

This gives a stable base for all future backends.

### Milestone B

- Phase 3
- Phase 4

This ships the first major new user-facing interaction.

### Milestone C

- Phase 5
- Phase 6
- Phase 7
- Phase 8
- Phase 9
- Phase 10
- Phase 11

This expands provider coverage and resilience.

---

## Current Recommendation

Current recommended order:

1. profiles / presets
2. system audio / meeting transcription
3. offline `sherpa-onnx`
4. online/offline fallback policy
5. cross-platform capability audit

This order gives the product a stronger workflow layer first, then adds the
next major input source, and only after that lands the local backend and the
policy that decides when to use it.
