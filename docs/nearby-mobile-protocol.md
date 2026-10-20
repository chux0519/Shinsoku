# Shinsoku Nearby Mobile Protocol

## Status

Protocol version 1 is implemented in the desktop product and Flutter iPhone
client. The current code includes:

- a shared push-audio boundary for Nearby Mobile and future hardware adapters
- two-digit, time-limited pairing with five online attempts
- persistent client trust using a stored credential verifier, not the issued
  client credential
- single-use challenge-response authentication for returning clients
- revocation that closes an authenticated socket immediately
- validated mono PCM16LE 16 kHz binary frames with stream and sequence IDs
- a persistent self-signed TLS identity and strict client fingerprint pinning
- native macOS Bonjour publication and Flutter Bonjour discovery
- an ixWebSocket WSS server and real desktop/socket end-to-end tests
- a routed capture service that presents accepted remote samples to the normal
  Shinsoku audio pipeline
- desktop Settings for enable/port/status/fingerprint/pair/revoke
- a Flutter Desktop Mic surface with discovery, manual fallback, Keychain or
  Keystore credentials, Profile request, microphone capture, and disconnect
  recovery

Nearby listening is disabled by default and must be enabled explicitly in
desktop Settings. LAN listening is WSS-only; plaintext is restricted to
loopback test configurations.

## Security Model

Voice, transcripts, pairing credentials, and Profile choices are private data.
Production LAN connections must use TLS. The temporary two-digit code is only
an online confirmation factor; it is protected by:

- a high-entropy pairing ID
- a two-minute default lifetime
- five attempts per pairing window
- HMAC-SHA-256 proof bound to the pairing ID and client ID
- TLS, which prevents passive offline guessing and credential capture

Successful pairing returns a random 256-bit credential once. The desktop stores
only `SHA-256(credential)` in a `0600` trust file. Returning clients prove access
with HMAC-SHA-256 over a single-use server challenge. Revocation removes the
verifier, consumes pending challenges, and closes matching live connections.

For native clients, pin the desktop certificate fingerprint advertised by
Bonjour and confirmed during pairing. Do not add a "trust every certificate"
mode. A browser client will require an HTTPS origin whose certificate the user
has accepted; plain HTTP cannot be the production microphone experience.

## Discovery

The Bonjour service type is:

```text
_shinsoku-mic._tcp
```

TXT fields:

```text
v=1
transport=wss
fp=<sha256 certificate fingerprint>
instance=<non-secret desktop instance ID>
```

Do not advertise the pairing code, credentials, user name, Profile names, or
transcript data. Bonjour discovery is convenience only; authentication remains
mandatory after connecting.

## Control Messages

Control messages are UTF-8 JSON WebSocket text frames. Unknown fields may be
ignored for forward compatibility, but required fields and fixed audio values
must be validated. Control messages are limited to 16 KiB.

### Client hello

```json
{
  "type": "hello",
  "protocol_version": 1,
  "client": {
    "id": "stable-client-generated-id",
    "name": "Yongsheng's iPhone",
    "kind": "iphone"
  }
}
```

An unknown client receives `pairing.required` when the desktop has an active
pairing window, otherwise `pairing.unavailable`. The response never contains the
two-digit display code.

```json
{
  "type": "pairing.required",
  "protocol_version": 1,
  "pairing_id": "32-hex-characters",
  "expires_at_ms": 1787300000000,
  "attempts_remaining": 5
}
```

### First-time pairing

The client computes:

```text
HMAC-SHA-256(
  key = UTF8(two_digit_code),
  data = "shinsoku-nearby-pair/v1\n" + pairing_id + "\n" + client_id
)
```

It sends the lowercase hexadecimal proof:

```json
{
  "type": "pairing.prove",
  "pairing_id": "32-hex-characters",
  "proof": "64-hex-characters"
}
```

`pairing.accepted` returns a 64-hex-character credential. Store it in the iOS
Keychain, Android Keystore, or equivalent client secret store. It is never
returned again.

### Returning-client authentication

The server sends:

```json
{
  "type": "auth.challenge",
  "protocol_version": 1,
  "challenge_id": "32-hex-characters",
  "nonce": "64-hex-characters",
  "expires_at_ms": 1787300000000
}
```

The client derives `verifier = SHA-256(credential)` and computes:

```text
HMAC-SHA-256(
  key = verifier,
  data = "shinsoku-nearby-auth/v1\n" + challenge_id + "\n" + nonce + "\n" + client_id
)
```

It sends `auth.prove`. A challenge is consumed after one attempt, including a
failed attempt, and cannot be replayed.

### Audio lifecycle

After `pairing.accepted` or `auth.accepted`, the client starts one stream:

```json
{
  "type": "audio.start",
  "stream_id": 42,
  "profile_id": "translate",
  "format": {
    "encoding": "pcm16le",
    "sample_rate_hz": 16000,
    "channels": 1
  }
}
```

The server answers `audio.ready`. `profile_id` is optional; an unknown Profile
must fall back to foreground-App matching and then the desktop's manual Profile.
The client then sends binary audio frames and finishes with:

```json
{
  "type": "audio.stop",
  "stream_id": 42
}
```

Only one stream may be active per connection. The shared desktop sink may also
reject a stream while local recording or another remote is active.

## Binary PCM Frame

All integer header fields are network byte order. PCM payload samples are signed
16-bit little-endian.

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 4 | ASCII `SNPA` |
| 4 | 1 | protocol version, `1` |
| 5 | 1 | flags, currently `0` |
| 6 | 2 | header size, `20` |
| 8 | 4 | stream ID |
| 12 | 4 | monotonically increasing sequence, starting at `0` |
| 16 | 4 | sample count |
| 20 | N | PCM16LE payload |

A frame contains 1 to 3,200 samples, up to 200 ms. Duplicate and reordered
frames are rejected. A forward sequence gap is accepted but reported through
`audio.gap`, allowing diagnostics without stopping otherwise usable dictation.
Frames from a previous stream ID cannot affect the current stream.

## Client Implementation Order

1. Completed: Flutter iPhone microphone client.
2. Completed: exact certificate pinning and secure credential storage.
3. Completed: Bonjour discovery with manual WSS/fingerprint fallback.
4. Completed in simulator: start/stop, Profile request, trusted reconnect, and
   transport-loss cleanup.
5. Validate real-iPhone microphone, interruption, lock, sleep, and roaming.
6. Add a browser client after the HTTPS certificate experience is acceptable.
7. Add Watch control through the iPhone; direct Watch audio remains a later
   lifecycle and battery investigation.

## Remaining Validation Work

- validate real iPhone audio, interruption, lock-screen, sleep/wake, and Wi-Fi
  roaming behavior
- validate the packaged macOS app and physical iPhone across normal LAN/router
  configurations
- measure first-audio and stop-to-insertion latency with streaming ASR
- validate certificate identity replacement and trust-recovery UX
- add Android physical-device coverage after the iPhone path is stable

## Simulator E2E

Build and start `nearby_server_fixture`, then pass its emitted endpoint,
fingerprint, and two-digit code to the Flutter test:

```bash
cmake --build build --config Debug --target nearby_server_fixture
./build/Debug/nearby_server_fixture

cd mobile
flutter test integration_test/nearby_ios_e2e_test.dart \
  -d <IOS_SIMULATOR_UDID> \
  --dart-define=SHINSOKU_NEARBY_ENDPOINT=wss://127.0.0.1:<PORT> \
  --dart-define=SHINSOKU_NEARBY_FINGERPRINT=<SHA256> \
  --dart-define=SHINSOKU_NEARBY_PAIRING_CODE=<TWO_DIGIT_CODE>
```

The test performs first pairing, sends a PCM frame, stops cleanly, reconnects
without a code using long-term trust, and renders the Desktop Mic workflow.
