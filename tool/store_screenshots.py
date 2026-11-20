#!/usr/bin/env python3
"""App Store screenshots, step 3 (release-01 R3): upload build/store/screenshots/<locale>/*.png to App Store Connect.

  python3 tool/store_screenshots.py                    dry run (GET only): what would be replaced, per locale
  python3 tool/store_screenshots.py --apply            coordinator only: replace the sets and upload
  python3 tool/store_screenshots.py --locales en-US,ja limit to some locales

Target: the editable App Store version (PREPARE_FOR_SUBMISSION or a rejected state), each locale's
appScreenshotSet of display type APP_IPHONE_67 (the 6.9" slot; it takes 1320×2868). --apply, per locale:
create the set if missing, delete its screenshots, then for each file in name order (NN-<scene>.png):
reserve (POST appScreenshots with fileName/fileSize) → PUT each uploadOperation part → commit (PATCH
uploaded=true + md5 sourceFileChecksum), then put the set in file order and wait for processing.
Locally checked before anything is sent: 1320×2868, PNG without alpha, 1–10 files per locale.
Stdlib only; the ASC key is read inside tool/asc.py and never printed.
"""
import argparse
import hashlib
import struct
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import store_metadata  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / 'build' / 'store' / 'screenshots'
DISPLAY_TYPE = 'APP_IPHONE_67'
SIZE = (1320, 2868)


def png_info(path: Path):
    """(width, height, has_alpha) from the IHDR chunk."""
    with path.open('rb') as f:
        head = f.read(33)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        raise ValueError('not a PNG')
    w, h, _depth, color = struct.unpack('>IIBB', head[16:26])
    return w, h, color in (4, 6)


def local_files(locale: str):
    files = sorted((SHOTS / locale).glob('[0-9][0-9]-*.png'))
    problems = []
    if not files:
        problems.append(f'{locale}: no screenshots in {(SHOTS / locale).relative_to(ROOT)}')
    if len(files) > 10:
        problems.append(f'{locale}: {len(files)} screenshots > 10')
    for p in files:
        try:
            w, h, alpha = png_info(p)
        except ValueError as e:
            problems.append(f'{locale}/{p.name}: {e}')
            continue
        if (w, h) != SIZE:
            problems.append(f'{locale}/{p.name}: {w}×{h}, expected {SIZE[0]}×{SIZE[1]}')
        if alpha:
            problems.append(f'{locale}/{p.name}: has an alpha channel')
    return files, problems


def get(client, path):
    status, data = client.call('GET', path)
    if status != 200:
        raise SystemExit(f'GET {path.split("?")[0]} -> {status}: {data}')
    return data


def must(status, data, what):
    if status not in (200, 201, 204):
        detail = data
        if isinstance(data, dict):
            detail = '; '.join(e.get('detail', str(e)) for e in data.get('errors', [])) or data
        raise SystemExit(f'{what} -> {status}: {detail}')
    return data


def upload_one(client, set_id: str, path: Path):
    blob = path.read_bytes()
    data = must(*client.call('POST', '/v1/appScreenshots', {'data': {
        'type': 'appScreenshots',
        'attributes': {'fileName': path.name, 'fileSize': len(blob)},
        'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': set_id}}}}}),
        f'reserve {path.name}')
    shot = data['data']
    for op in shot['attributes']['uploadOperations']:
        part = blob[op['offset']:op['offset'] + op['length']]
        req = urllib.request.Request(op['url'], data=part, method=op['method'])
        for h in op.get('requestHeaders') or []:
            req.add_header(h['name'], h['value'])
        with urllib.request.urlopen(req, timeout=120) as r:
            if r.status not in (200, 201, 204):
                raise SystemExit(f'upload part of {path.name} -> {r.status}')
    must(*client.call('PATCH', f'/v1/appScreenshots/{shot["id"]}', {'data': {
        'type': 'appScreenshots', 'id': shot['id'],
        'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(blob).hexdigest()}}}),
        f'commit {path.name}')
    return shot['id']


def wait_processed(client, ids, timeout=300):
    pending = set(ids)
    deadline = time.time() + timeout
    while pending and time.time() < deadline:
        for sid in sorted(pending):
            d = get(client, f'/v1/appScreenshots/{sid}?fields[appScreenshots]=fileName,assetDeliveryState')['data']
            state = (d['attributes'].get('assetDeliveryState') or {}).get('state')
            if state == 'COMPLETE':
                pending.discard(sid)
            elif state == 'FAILED':
                errs = (d['attributes'].get('assetDeliveryState') or {}).get('errors')
                print(f'      FAILED {d["attributes"].get("fileName")}: {errs}')
                pending.discard(sid)
        if pending:
            time.sleep(5)
    return pending


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--locales', default=','.join(store_metadata.LOCALES))
    a = ap.parse_args()
    locales = [x for x in a.locales.split(',') if x]
    unknown = set(locales) - set(store_metadata.LOCALES)
    if unknown:
        sys.exit(f'unknown locales: {sorted(unknown)}')

    plan, problems = {}, []
    for loc in locales:
        files, p = local_files(loc)
        plan[loc] = files
        problems += p
    for p in problems:
        print('FAIL', p)
    if problems:
        print('local check failed; nothing sent')
        return 1

    client = store_metadata.asc()
    app_cfg = store_metadata.load(store_metadata.STORE / 'app.yaml')
    q = urllib.parse.quote
    app_id = get(client, f"/v1/apps?filter[bundleId]={q(app_cfg['bundle_id'])}")['data'][0]['id']
    versions = get(client, f'/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS'
                           '&fields[appStoreVersions]=versionString,appStoreState')['data']
    version = next((v for v in versions if v['attributes']['appStoreState'] in store_metadata.EDITABLE), None)
    if not version:
        raise SystemExit('no editable appStoreVersion (PREPARE_FOR_SUBMISSION) found')
    va = version['attributes']
    ver_locs = {x['attributes']['locale']: x['id'] for x in get(
        client, f'/v1/appStoreVersions/{version["id"]}/appStoreVersionLocalizations?limit=50')['data']}

    print(f"{'APPLY' if a.apply else 'DRY RUN'}: app {app_id}, version {va['versionString']} "
          f"({va['appStoreState']}), display type {DISPLAY_TYPE}")
    missing_locs = []
    actions = []  # (locale, loc_id, set_id or None, [old screenshot ids], files)
    for loc in locales:
        loc_id = ver_locs.get(loc)
        if loc_id is None:
            missing_locs.append(loc)
            print(f'  {loc:8} no version localization in ASC yet (run tool/store_metadata.py push --apply first)')
            continue
        sets = get(client, f'/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets'
                           '?fields[appScreenshotSets]=screenshotDisplayType&limit=50')['data']
        cur = next((s for s in sets if s['attributes']['screenshotDisplayType'] == DISPLAY_TYPE), None)
        old = []
        if cur:
            old = get(client, f'/v1/appScreenshotSets/{cur["id"]}/appScreenshots'
                              '?fields[appScreenshots]=fileName&limit=50')['data']
        others = sorted(s['attributes']['screenshotDisplayType'] for s in sets if s is not cur)
        old_names = ', '.join(s['attributes'].get('fileName') or s['id'] for s in old) or 'none'
        new_names = ', '.join(p.name for p in plan[loc])
        print(f'  {loc:8} {"replace" if old else "upload "} {len(old)} -> {len(plan[loc])}'
              f'{"" if cur else " (new set)"}')
        print(f'           old: {old_names}')
        print(f'           new: {new_names}')
        if others:
            print(f'           other display types left as they are: {", ".join(others)}')
        actions.append((loc, loc_id, cur['id'] if cur else None, [s['id'] for s in old], plan[loc]))

    if not a.apply:
        print(f'\nNothing sent. {len(actions)} locale(s) ready'
              f'{f", {len(missing_locs)} without a localization" if missing_locs else ""}. '
              'Run with --apply to replace (coordinator only).')
        return 0
    if missing_locs:
        print('localizations missing in ASC; push the metadata first')
        return 1
    for loc, loc_id, set_id, old_ids, files in actions:
        print(f'  {loc}:')
        if set_id is None:
            set_id = must(*client.call('POST', '/v1/appScreenshotSets', {'data': {
                'type': 'appScreenshotSets', 'attributes': {'screenshotDisplayType': DISPLAY_TYPE},
                'relationships': {'appStoreVersionLocalization': {'data': {
                    'type': 'appStoreVersionLocalizations', 'id': loc_id}}}}}), 'create set')['data']['id']
            print(f'      created set {set_id}')
        for sid in old_ids:
            must(*client.call('DELETE', f'/v1/appScreenshots/{sid}'), f'delete {sid}')
        print(f'      deleted {len(old_ids)}')
        new_ids = []
        for p in files:
            new_ids.append(upload_one(client, set_id, p))
            print(f'      uploaded {p.name}')
        must(*client.call('PATCH', f'/v1/appScreenshotSets/{set_id}/relationships/appScreenshots', {
            'data': [{'type': 'appScreenshots', 'id': i} for i in new_ids]}), 'order')
        left = wait_processed(client, new_ids)
        print(f'      processed {len(new_ids) - len(left)}/{len(new_ids)}'
              f'{" (still processing: check ASC)" if left else ""}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
