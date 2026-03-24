# Settings Redesign

This note tracks the information architecture for the settings window as the
project grows beyond one batch ASR provider.

## Goals

- stop using one long scroll-heavy settings form
- separate common workflow settings from provider-specific configuration
- keep current config persistence stable while the UI structure changes
- create a clean home for future streaming and offline providers

## Navigation Structure

### General

- hold key
- hands-free chord
- copy to clipboard
- paste to focused window
- paste keys
- HUD enabled
- HUD bottom margin

### Audio

- input device
- save recordings
- recordings directory
- audio rotation mode
- max files
- VAD enabled
- VAD threshold
- VAD minimum speech duration

### ASR

- workflow-level ASR mode and backend selection
- shared ASR behavior that is not provider-specific

Later additions:

- streaming enablement
- streaming provider choice
- common ASR defaults shared across providers

Current first pass:

- streaming enabled
- streaming provider selection
- streaming language hint

### Transform

- refine enabled
- refine system prompt

This page is also the future home for selection-command transform settings so
that command workflows do not remain buried under the historical "refine"
label.

### Network

- proxy enabled
- proxy type
- proxy host
- proxy port
- proxy username
- proxy password

### Providers

Reserved for provider-specific pages or cards:

- OpenAI-compatible batch ASR endpoint settings
- OpenAI-compatible text transform endpoint settings
- Soniox
- Alibaba Bailian
- sherpa-onnx

Current first pass:

- `OpenAI-compatible batch ASR`
- `OpenAI-compatible text transform`
- `Soniox streaming`

### Advanced

- history metadata recording
- timing recording
- future experimental toggles

## Config Direction

Short term:

- keep current config keys stable
- only move fields in the UI

Longer term:

- group common settings as `general`, `audio`, `asr`, `transform`, `network`,
  `advanced`
- move provider-specific settings under `providers.<name>`

## Migration Rules

1. UI reshaping should not require an immediate config migration.
2. Existing getters and setters on `SettingsWindow` should stay stable until the
   controller synchronization layer is explicitly refactored.
3. New provider-specific configuration should prefer new config groups instead
   of extending unrelated legacy sections.
