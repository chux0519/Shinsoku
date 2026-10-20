# Input Device Adapter Direction

## Current Internal Contract

Nearby Mobile and future RC003 support share the Qt-free interface in
`src/core/input/push_audio_source.hpp`. An input adapter publishes:

- stable source identity, display name, and source kind
- an optional requested Profile ID
- a non-zero stream generation ID
- fixed audio format and PCM sample chunks
- explicit completed, cancelled, disconnected, or error termination

The consumer can reject stream start or audio synchronously when Shinsoku is
busy. Stale stream IDs must never affect a newer recording. Adapters do not call
ASR, post-processing, clipboard, history, or UI APIs directly.

## Experimental Public Boundary

Do not expose the current C++ virtual interface as a stable binary ABI. A public
adapter should run out of process and use a versioned local IPC protocol. This
keeps community adapters out of Shinsoku's address space and lets the protocol
exclude API keys, history data, and provider configuration by design. It does
not by itself restrict same-user filesystem permissions.

Protocol v1 is implemented as a validation, interoperability, and desktop
runtime boundary. It remains experimental until RC003 has exercised the full
hardware lifecycle, but external authors can implement, test, and explicitly
run adapters now.

An adapter process exposes only:

- adapter manifest and capabilities
- discover/connect/disconnect commands
- device status, battery, signal, and firmware events
- button events with stable action IDs
- the same push-audio start/chunk/stop lifecycle
- bounded diagnostics without transcript or provider credentials

Shinsoku launches only the single executable path explicitly selected under
`Settings > Advanced > Device Adapter`. It does not invoke a shell or scan for
plugins. The adapter identity and declared permissions are visible in Settings,
and disabling the adapter stops the process. Known API-key, token, secret, and
password environment variables are removed before launch and credentials are
never sent over the protocol.

A normal child process still has the user's OS privileges. It may be able to
read same-user files even when those files are absent from the protocol and
environment, so permission declarations are not a sandbox. Only run an adapter
you trust. Platform sandboxing, executable identity pinning, and restricted
launch policy remain future hardening work.

## Transport

Protocol v1 uses UTF-8 JSON Lines over standard input/output:

- Shinsoku writes host commands to adapter stdin.
- The adapter writes exactly one JSON event per stdout line.
- Human logs go to stderr; non-JSON stdout fails conformance.
- Each line is limited to 16 KiB.
- Unknown JSON fields are ignored, but unknown event types fail protocol v1.
- The first adapter event must be `adapter.hello` and the optional final event
  is `adapter.goodbye`.

Base64 PCM has modest overhead at mono 16 kHz and keeps the interface usable
from Python, Node, Rust, Go, and hardware gateway processes without a binary
ABI. Chunks are capped at 3,200 samples, so sustained payload is about 43 KB/s.

## Handshake And Commands

Shinsoku starts with:

```json
{"type":"host.hello","protocol_version":1,"host":{"name":"Shinsoku","version":"0.1.0"},"limits":{"maximum_line_bytes":16384,"maximum_chunk_samples":3200}}
```

The adapter responds with a manifest. Permissions are declarations shown to the
user, not credentials granted by the protocol.

```json
{"type":"adapter.hello","protocol_version":1,"adapter":{"id":"dev.example.rc003","name":"Example RC003 Adapter","version":"0.1.0","capabilities":["discover","connect","audio.pcm16","buttons","battery"],"permissions":["bluetooth"]}}
```

Host commands defined in v1 are:

```text
device.discover
device.connect       device_id
device.disconnect    device_id
adapter.shutdown
```

After `audio.start`, Shinsoku returns either `audio.accepted` or
`audio.rejected` with the same `stream_id`. A rejected adapter must stop sending
PCM for that stream and close it with `audio.stop`; Shinsoku can reject input
while another recording or transcription owns the shared audio pipeline.

Adapters report `device.found`, `discovery.finished`, `device.status`,
`button`, `audio.start`, `audio.chunk`, `audio.stop`, and `adapter.goodbye`.
Stable adapter and device IDs may contain ASCII letters, digits, `.`, `_`, and
`-`; display names may be Unicode but cannot contain line breaks.

## Audio Events

Only mono PCM16LE at 16 kHz is accepted in v1:

```json
{"type":"audio.start","stream_id":7,"device_id":"rc003-a1","profile_id":"default","format":{"encoding":"pcm16le","sample_rate_hz":16000,"channels":1}}
{"type":"audio.chunk","stream_id":7,"sequence":0,"pcm16le_base64":"AIAAAP9/"}
{"type":"audio.stop","stream_id":7,"reason":"completed","total_samples":3}
```

Stream IDs are non-zero. Sequences start at zero and are strictly contiguous;
local IPC loss or reordering is treated as an adapter failure rather than
silently degrading recognition. Stop reasons are `completed`, `cancelled`,
`disconnected`, or `error`.

## Stable Action IDs

Initial action IDs reserved for device buttons:

```text
voice.start
voice.stop
profile.next
profile.previous
profile.select:<profile-id>
transcript.copy-last
insertion.undo
key.backspace
key.newline
key.submit
workflow.run:<workflow-id>
```

An adapter reports physical events; the desktop owns action mapping and policy.
This prevents hardware-specific button names from leaking into Profiles or
workflows.

## Conformance

Build the checker and validate a captured adapter event trace:

```bash
cmake --build build --config Debug --target shinsoku-adapter-check
./build/Debug/shinsoku-adapter-check \
  --trace tests/fixtures/device_adapter_valid.jsonl \
  --require-audio \
  --pretty
```

The bundled Python example can generate the same full trace without external
dependencies:

```bash
python3 examples/device-adapters/synthetic_adapter.py \
  --emit-conformance-trace > /tmp/shinsoku-adapter.jsonl
./build/Debug/shinsoku-adapter-check \
  --trace /tmp/shinsoku-adapter.jsonl --require-audio --pretty
```

Passing conformance proves manifest/event/framing correctness. It does not
grant execution approval or verify hardware behavior. The protocol does not
send ASR keys, transcript history, or provider configuration; the same-user
process caveat above still applies.

## Desktop Runtime

The runtime currently manages one explicitly configured adapter:

1. Resolve and verify the absolute executable path.
2. Start it directly with separate JSONL stdout and diagnostic stderr.
3. Send `host.hello`, enforce a three-second manifest timeout, then discover.
4. Connect the first discovered device.
5. Route accepted PCM into Shinsoku's existing Profile, ASR, transform,
   insertion, and history pipeline.
6. Stop the active stream on protocol failure, process exit, disable, or app
   shutdown.

`profile.select:<id>`, `profile.next`, and `profile.previous` button-down events
switch the desktop Profile. Other reserved actions remain policy placeholders
until their ownership and focus behavior are specified.

The runtime process E2E fixture validates launch, secret-environment stripping,
handshake, discovery, connection, PCM transfer, Profile request propagation,
and shutdown. It does not replace hardware tests.
