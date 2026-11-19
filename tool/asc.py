#!/usr/bin/env python3
"""Minimal App Store Connect API client (stdlib + openssl). Never prints the key or the token.

  tool/asc.py GET  /v1/apps?filter[bundleId]=net.potafree.shinsoku
  tool/asc.py POST /v2/inAppPurchases '<json body>'
  tool/asc.py PATCH /v2/inAppPurchases/<id> '<json body>'

Key: ASC_KEY_ID / ASC_ISSUER_ID env or the defaults below; private key read from
~/.appstoreconnect/private_keys/AuthKey_<id>.p8 inside this script only.
"""
import base64, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

KEY_ID = os.environ.get('ASC_KEY_ID', '7FH2PAXHPQ')
ISSUER = os.environ.get('ASC_ISSUER_ID', '8cc2abdc-3f44-41e4-89ae-4ec5ec7dbfc3')
KEY_PATH = os.path.expanduser(f'~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8')
BASE = 'https://api.appstoreconnect.apple.com'


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def der_to_raw(der: bytes) -> bytes:
    # ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER } -> r||s (32 bytes each)
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
    out = b''
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        v = der[i + 2:i + 2 + n].lstrip(b'\x00')
        out += v.rjust(32, b'\x00')
        i += 2 + n
    return out


def token() -> str:
    now = int(time.time())
    head = b64(json.dumps({'alg': 'ES256', 'kid': KEY_ID, 'typ': 'JWT'}).encode())
    body = b64(json.dumps({'iss': ISSUER, 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'}).encode())
    msg = f'{head}.{body}'.encode()
    with tempfile.NamedTemporaryFile() as f:
        f.write(msg)
        f.flush()
        der = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', KEY_PATH, f.name],
                             capture_output=True, check=True).stdout
    return f'{head}.{body}.{b64(der_to_raw(der))}'


def call(method: str, path: str, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=None if body is None else json.dumps(body).encode())
    req.add_header('Authorization', 'Bearer ' + token())
    req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, raw.decode(errors='replace')


if __name__ == '__main__':
    m, p = sys.argv[1], sys.argv[2]
    b = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    status, data = call(m, p, b)
    print(status)
    print(json.dumps(data, indent=1, ensure_ascii=False) if not isinstance(data, str) else data)
