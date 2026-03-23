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
4. Add an offline fallback / forced-local mode with `sherpa-onnx`.

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
5. Streaming backend support
6. Offline `sherpa-onnx` mode
7. Online/offline fallback policy refinement

## Status

- Phase 1: completed
- Phase 2: completed
- Phase 3: completed
- Phase 4: in progress
- Phase 5: pending
- Phase 6: pending
- Phase 7: pending

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

## Phase 5: Streaming Backend Support

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

---

## Phase 6: Offline `sherpa-onnx`

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

## Phase 7: Fallback Policy Refinement

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

This expands provider coverage and resilience.

---

## Current Recommendation

Start with Milestone A:

1. proxy config in `AppConfig`
2. settings UI for proxy
3. transport options in `curl_support`
4. backend interface extraction pass 1

That is the lowest-risk path and prevents the next three features from growing
directly into `AppController`.
