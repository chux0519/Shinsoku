# RC003 Remote Input Roadmap

## Purpose

Add Xiaomi Bluetooth Remote 2 Pro / RC003 as an optional Shinsoku input device.
The remote is not a product dependency: users must remain free to use a normal
microphone, a nearby phone, or future third-party devices with any supported ASR
and text-transform provider.

The implementation must be independent. Public protocol behavior may inform
interoperability, but GPL source from `HD838A/remote-mic-app` must not be copied
unless Shinsoku makes an explicit compatible licensing decision. Its logo, icon,
name, and other proprietary assets are out of scope.

References:

- <https://github.com/HD838A/remote-mic-app>
- <https://github.com/HD838A/remote-mic-app/blob/main/TECHNICAL.md>

## Target Experience

1. Pair RC003 once in Shinsoku Settings.
2. Assign its voice button and other buttons to Profiles or actions.
3. Hold the voice button and speak without opening the main window.
4. Stream decoded audio through the active Profile's ASR and transform stages.
5. Release the button to finalize and insert text into the captured target app.
6. See device, signal, battery, audio, ASR, and insertion diagnostics locally.

The direct Shinsoku path is:

```text
RC003 BLE ATVV -> ADPCM decoder -> PCM16 16 kHz mono
                 -> streaming ASR -> Profile transform -> clipboard/insertion
```

Do not require a virtual sound device for the production path. A virtual device
is useful only for the initial hardware and audio-quality proof.

## Architecture

### Shared protocol core

Implement a Qt-free C++ library with these responsibilities:

- ATVV UUID and capability model
- connection/session generation state machine
- control packet parsing and microphone open/close lifecycle
- audio-frame accumulation across BLE notifications
- high-nibble-first IMA/DVI ADPCM decoding
- fixed PCM16 16 kHz mono output
- deterministic test fixtures captured from hardware owned by the project
- stale packet, duplicate stop, reconnect, truncation, and malformed-frame tests

The core publishes push events rather than pretending to be a miniaudio device:

```cpp
on_ready(DeviceInfo)
on_voice_start(AudioFormat{16000, 1, Pcm16})
on_audio(std::span<const std::int16_t>)
on_voice_stop()
on_button(RemoteButtonEvent)
on_error(RemoteError)
```

### Platform BLE adapters

- macOS: CoreBluetooth in Objective-C++, behind a shared C++ interface.
- Windows: C++/WinRT with `Windows.Devices.Bluetooth.GenericAttributeProfile`.
- Linux: BlueZ D-Bus only after macOS and Windows behavior is stable.
- iOS: exploratory containing-app adapter only; do not promise keyboard-extension
  background reliability.

All callbacks carry a monotonically increasing connection/session generation.
Late callbacks from a previous connection or recording are discarded.

### Shinsoku integration

Extend Profile input sources without coupling the controller to RC003:

```text
microphone | system | remote_device | nearby_mobile
```

Introduce a push-audio source boundary shared by remote devices and nearby
mobile clients. The controller converts PCM to the formats needed by VAD,
recording retention, streaming ASR, and batch fallback. Voice-stop must drain the
tail before ASR finalization.

Button actions should use stable action IDs:

- start/stop voice input
- select next/previous/specific Profile
- copy last transcript
- undo insertion
- newline, backspace, or submit
- run a future Workflow

## Delivery Phases

### Shared foundation completed before hardware arrival

The hardware-independent input path is already in place:

- `PushAudioSource` / `PushAudioSink` provide a Qt-free PCM16 push boundary.
- Nearby Mobile exercises the same start, samples, stop, source identity, and
  requested-Profile lifecycle that RC003 will use.
- `AppController` routes remote PCM through the normal ASR, transform,
  insertion, and source-aware history pipeline.
- The desktop has local-network discovery, pinned WSS, revocable trust, and
  diagnostics; the Flutter iPhone client has passed simulator E2E with real
  protocol pairing, PCM transfer, and returning-client authentication.
- Device Adapter v1 now has a conformance checker plus an explicitly enabled
  desktop process runtime. The runtime displays manifest/permission state,
  discovers and connects a device, bridges strict PCM16 into `PushAudioSink`,
  and supports specific/next/previous Profile button actions.

This deliberately validates the shared product flow without guessing at the
RC003 BLE protocol or importing GPL implementation code.

### Phase 0: when hardware arrives

- verify the printed model is RC003
- record macOS version, firmware, BLE vendor/product IDs, and advertised UUIDs
- run the reference app with its virtual microphone as Shinsoku input
- validate voice quality, range, press/release behavior, and reconnect behavior
- capture project-owned packet/audio fixtures without importing reference code
- document any behavior that differs from the public technical notes

Exit: the physical device and decoded voice path are understood well enough to
write deterministic tests.

### Phase 1: decoder and macOS MVP

- implement the shared protocol/decoder core test-first
- implement CoreBluetooth discovery, pairing, reconnect, and capabilities
- expose connection and decoded-audio diagnostics
- feed remote PCM directly into streaming ASR
- map the voice button to the active Profile

Exit: hold, speak, release, transcribe, transform, and paste works repeatedly on
macOS without a virtual audio driver.

### Phase 2: product hardening

- add device selection, forget-device, battery, firmware/model, and health UI
- add audio packet, decode, tail-drain, ASR, and insertion timing diagnostics
- add pre-roll and destination-readiness buffering
- add configurable physical-button actions and per-app Profile behavior
- test sleep/wake, Bluetooth toggles, out-of-range recovery, and app shutdown

Exit: failures are visible and recoverable without logs or terminal commands.

### Phase 3: Windows

- reuse the protocol/decoder tests unchanged
- implement WinRT GATT discovery, subscribe, read/write, and reconnect
- validate HID/GATT coexistence and Windows power management
- run the same end-to-end acceptance suite used on macOS

Exit: macOS and Windows have equivalent voice-button behavior and diagnostics.

### Phase 4: open device interface

- stabilize a versioned input-device capability and event contract
- publish a minimal sample adapter and conformance tests
- document security, device identity, audio ownership, and lifecycle rules
- allow community adapters without granting arbitrary in-process access by
  default; prefer a local IPC boundary for untrusted plugins

Exit: an ESP32 or another remote can integrate without changing AppController.

## Arrival-Day Checklist

1. Photograph the box/device labels and record the exact model and firmware.
2. Capture Bluetooth advertisements and GATT services before installing or
   trusting any third-party driver.
3. Exercise every physical button and record press, hold, repeat, and release
   events separately.
4. Capture at least three owned voice samples and the corresponding BLE packet
   traces for deterministic tests.
5. Verify nibble order, reset packets, sample rate, tail behavior, and whether
   the device can expose HID and microphone capabilities concurrently.
6. Measure first-audio latency, release-to-final latency, reconnect time, range,
   and battery reporting.
7. Run the reference app only as a black-box comparison and record observable
   differences; do not copy its source, assets, identifiers, or branding.

## iOS Boundary

The containing app can experiment with CoreBluetooth, App Group handoff, and
foreground transcription. The keyboard extension cannot own the full BLE,
audio, network ASR, and post-processing lifecycle reliably. iOS RC003 support is
therefore not an initial release requirement. Nearby iPhone microphone support
for the desktop should be completed first because it has a clearer lifecycle and
works with hardware the user already owns.

## Acceptance Checklist

- no reference-project source or assets in the implementation
- no virtual audio dependency in the direct path
- first audio is not clipped; final audio is drained before ASR completion
- stale BLE callbacks cannot affect a newer session
- reconnect works after sleep, range loss, and Bluetooth restart
- device loss never blocks microphone-based Profiles
- all audio and transcript retention follows Shinsoku privacy settings
- diagnostics explain connection, packet, decode, ASR, transform, and insertion
  failures separately
- macOS and Windows protocol behavior is covered by the same fixture tests
