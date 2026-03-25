# Profiles / Presets Design

This note tracks the first implementation pass for reusable workflow profiles.

## Goals

- let users switch between recurring workflows without editing prompts each time
- keep provider-specific configuration separate from workflow presets
- preserve current single-profile behavior during migration
- support future meeting, translation, and rewrite workflows cleanly

## Product Shape

A profile is a workflow preset, not a provider definition.

Examples:

- `Default Dictation`
- `Chinese To English Conversation`
- `Selection Rewrite`
- `Meeting Cleanup`

Each profile should be able to express:

- which capture mode it prefers
- whether transform is enabled
- which transform prompt or template to use
- which output behavior is preferred
- which ASR path is preferred

## Proposed Profile Schema

Short-term shape:

- `id`
- `name`
- `kind`
  - `dictation`
  - `selection_command`
  - `meeting`
- `enabled`
- `capture`
  - `prefer_streaming`
  - `preferred_streaming_provider`
  - `language_hint`
- `transform`
  - `enabled`
  - `prompt_mode`
    - `inherit_global`
    - `custom`
  - `custom_prompt`
- `output`
  - `copy_to_clipboard`
  - `paste_to_focused_window`
  - `paste_keys`
- `notes`

Longer term:

- allow provider overrides under a profile only where clearly needed
- do not duplicate full provider config blobs into every profile

## Global Vs Per-Profile

Remain global for now:

- network / proxy
- provider credentials
- audio device
- recordings directory
- observability
- HUD layout

Candidate per-profile overrides:

- transform prompt
- streaming enabled / disabled
- preferred streaming provider
- output mode
- selection-command vs dictation bias

## UI Direction

Use a dedicated `Profiles` page in settings.

First pass UI:

- left-side list of profiles
- buttons:
  - `New`
  - `Duplicate`
  - `Delete`
- right-side editor for selected profile:
  - name
  - workflow type
  - streaming preference
  - transform enabled
  - prompt source
  - output behavior

Main window:

- add a current-profile picker
- keep the default experience usable even if only one profile exists

## Config Migration

Current app behavior is effectively one implicit global profile.

Migration plan:

1. introduce a default profile synthesized from current global settings
2. keep existing config keys working
3. write profiles alongside existing config
4. only migrate more fields into profiles after the first UI pass is stable

## File Plan

### `src/core/app_config.hpp`
### `src/core/app_config.cpp`

Add:

- `ProfileConfig`
- `ProfilesConfig`
- active profile id
- list of profiles

### `src/core/app_controller.*`

Add:

- active profile resolution
- helper that merges global config with active profile behavior

### `src/ui/settings_window.*`

Add:

- profile management UI
- getters / setters for profile editing

### `src/ui/main_window.*`

Add:

- active profile picker
- optional display of current workflow name

## Acceptance Criteria

- user can switch profiles without editing prompts manually
- one profile can express “speak Chinese, output polished English”
- profile switching does not require changing provider credentials
- existing users still get sane behavior via a default migrated profile
