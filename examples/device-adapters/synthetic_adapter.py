#!/usr/bin/env python3
"""Minimal Shinsoku Device Adapter v1 example using only Python's stdlib."""

import argparse
import base64
import json
import sys


MANIFEST = {
    "type": "adapter.hello",
    "protocol_version": 1,
    "adapter": {
        "id": "dev.shinsoku.example.synthetic",
        "name": "Shinsoku Synthetic Adapter",
        "version": "0.1.0",
        "capabilities": ["discover", "connect", "audio.pcm16", "buttons", "battery"],
        "permissions": [],
    },
}

DEVICE = {
    "id": "synthetic-001",
    "name": "Synthetic Remote",
    "capabilities": ["audio.pcm16", "buttons", "battery"],
    "battery_percent": 100,
    "signal_dbm": -30,
}


def emit(message):
    print(json.dumps(message, separators=(",", ":")), flush=True)


def emit_conformance_trace():
    pcm = b"\x00\x80\x00\x00\xff\x7f"
    emit(MANIFEST)
    emit({"type": "device.found", "device": DEVICE})
    emit({"type": "discovery.finished", "device_count": 1})
    emit({"type": "device.status", "device_id": DEVICE["id"], "state": "connected"})
    emit({"type": "button", "device_id": DEVICE["id"], "action_id": "profile.select:default", "event": "down"})
    emit({"type": "button", "device_id": DEVICE["id"], "action_id": "profile.select:default", "event": "up"})
    emit(
        {
            "type": "audio.start",
            "stream_id": 7,
            "device_id": DEVICE["id"],
            "profile_id": "default",
            "format": {"encoding": "pcm16le", "sample_rate_hz": 16000, "channels": 1},
        }
    )
    emit(
        {
            "type": "audio.chunk",
            "stream_id": 7,
            "sequence": 0,
            "pcm16le_base64": base64.b64encode(pcm).decode("ascii"),
        }
    )
    emit({"type": "audio.stop", "stream_id": 7, "reason": "completed", "total_samples": 3})
    emit({"type": "adapter.goodbye"})


def run_protocol():
    for raw_line in sys.stdin:
        try:
            message = json.loads(raw_line)
        except json.JSONDecodeError as error:
            print(f"invalid host JSON: {error}", file=sys.stderr)
            return 2
        message_type = message.get("type")
        if message_type == "host.hello":
            emit(MANIFEST)
        elif message_type == "device.discover":
            emit({"type": "device.found", "device": DEVICE})
            emit({"type": "discovery.finished", "device_count": 1})
        elif message_type == "device.connect" and message.get("device_id") == DEVICE["id"]:
            emit({"type": "device.status", "device_id": DEVICE["id"], "state": "connected"})
        elif message_type == "device.disconnect" and message.get("device_id") == DEVICE["id"]:
            emit({"type": "device.status", "device_id": DEVICE["id"], "state": "disconnected"})
        elif message_type == "adapter.shutdown":
            emit({"type": "adapter.goodbye"})
            return 0
        else:
            print(f"unsupported host command: {message_type}", file=sys.stderr)
            return 2
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--emit-conformance-trace", action="store_true")
    args = parser.parse_args()
    return emit_conformance_trace() if args.emit_conformance_trace else run_protocol()


if __name__ == "__main__":
    raise SystemExit(main())
