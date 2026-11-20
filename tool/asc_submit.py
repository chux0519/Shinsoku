#!/usr/bin/env python3
"""Submit the app version in PREPARE_FOR_SUBMISSION for App Review (release-01 R5). Coordinator only.

  python3 tool/asc_submit.py --build 23            # dry run: shows what it would set, sends nothing
  python3 tool/asc_submit.py --build 23 --apply    # sets review details, attaches build, submits

Review contact is copied from another app of the same team (POTASMS) and never printed. The review key is
read from .env (REVIEW_SONIOX_API_KEY) inside this script, written only into the review notes (visible to
Apple only), never printed or logged. Run without proxies.
"""
import argparse, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP_ID = '6779534781'
IAP_ID = '6836728985'
ROOT = Path(__file__).resolve().parent.parent

NOTES = """Shinsoku is voice input that uses the user's own speech-provider API key (no account, no server of ours).

To test, please add this Soniox key (created for App Review only, low quota):
  Settings > Recognition > Soniox > API key: {key}
Then: Record tab > tap Record > speak > tap Stop. The text appears live and is cleaned up.

Keyboard: Settings app > General > Keyboard > Keyboards > Add New Keyboard > Shinsoku, enable Allow Full Access.
In any app, switch to Shinsoku; Record opens the app to record (keyboards cannot use the microphone), then
return and tap Insert. The keyboard itself has no network code; Full Access lets it read the text, profiles
and field rules the app shares through the App Group.

In-app purchase "Shinsoku Pro" (non-consumable, Family Sharing) unlocks custom profiles, per-app automatic
switching (field rules and Shortcuts) and Desktop. Settings > Shinsoku Pro > Unlock / Restore Purchases.

Desktop requires our desktop app on the same local network; it is optional and not needed to review the app.
"""


def env_value(name):
    for line in (ROOT / '.env').read_text().splitlines():
        if line.startswith(name + '='):
            return line.split('=', 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f'{name} missing in .env')


def ok(status, data, what):
    if status >= 300:
        errs = data.get('errors', data) if isinstance(data, dict) else data
        raise SystemExit(f'{what}: HTTP {status}: {errs}')
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', required=True)
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()

    s, r = asc.call('GET', f'/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION'
                    '&include=appStoreReviewDetail,build')
    ver = ok(s, r, 'version')['data'][0]
    vid = ver['id']
    print('version', ver['attributes']['versionString'], vid)

    s, r = asc.call('GET', f'/v1/builds?filter[app]={APP_ID}&filter[version]={a.build}'
                    f'&filter[preReleaseVersion.version]={ver["attributes"]["versionString"]}&fields[builds]=processingState')
    builds = ok(s, r, 'build')['data']
    if not builds or builds[0]['attributes']['processingState'] != 'VALID':
        raise SystemExit(f'build {a.build} not VALID yet: {[b["attributes"] for b in builds]}')
    bid = builds[0]['id']
    print('build', a.build, 'VALID')

    # Contact from POTASMS (same team), not printed.
    s, r = asc.call('GET', '/v1/apps?limit=50&fields[apps]=name')
    pid = [x['id'] for x in ok(s, r, 'apps')['data'] if x['attributes']['name'].startswith('POTASMS')][0]
    s, r = asc.call('GET', f'/v1/apps/{pid}/appStoreVersions?limit=5&include=appStoreReviewDetail')
    src = [x for x in ok(s, r, 'potasms')['included'] if x['type'] == 'appStoreReviewDetails'][0]['attributes']
    contact = {k: src[k] for k in ('contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail')}
    notes = NOTES.format(key=env_value('REVIEW_SONIOX_API_KEY'))
    attrs = dict(contact, notes=notes, demoAccountRequired=False)
    print('review detail: contact copied (4 fields, not printed), notes', len(notes), 'chars (key not printed)')
    print('plan: attach build, set review detail, add version to a review submission (IAP must already be in it), submit')
    if not a.apply:
        print('DRY RUN: nothing sent.')
        return

    ok(*asc.call('PATCH', f'/v1/appStoreVersions/{vid}', {'data': {'type': 'appStoreVersions', 'id': vid,
       'relationships': {'build': {'data': {'type': 'builds', 'id': bid}}}}}), 'attach build')
    print('attached build')

    rd = (ver.get('relationships', {}).get('appStoreReviewDetail', {}) or {}).get('data')
    if rd:
        ok(*asc.call('PATCH', f'/v1/appStoreReviewDetails/{rd["id"]}', {'data': {
            'type': 'appStoreReviewDetails', 'id': rd['id'], 'attributes': attrs}}), 'review detail')
    else:
        ok(*asc.call('POST', '/v1/appStoreReviewDetails', {'data': {'type': 'appStoreReviewDetails',
           'attributes': attrs, 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions',
                                                                                 'id': vid}}}}}), 'review detail')
    print('review detail set')

    # Apple refuses the first non-consumable IAP through the API (FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION,
    # 2026-11-20). What worked: IAP page > "Add for Review" (creates the draft with the IAP), then add the version
    # to that draft, then submit the draft. So: if the IAP still waits for its first review, stop and say so.
    s, r = asc.call('GET', f'/v2/inAppPurchases/{IAP_ID}?fields[inAppPurchases]=state')
    if ok(s, r, 'iap')['data']['attributes']['state'] in ('READY_TO_SUBMIT', 'MISSING_METADATA'):
        raise SystemExit('IAP not submitted yet. In App Store Connect: In-App Purchases > Shinsoku Pro > Add for '
                         'Review, then rerun this script (it adds the version to that draft and submits).')

    # Reuse an open (not yet submitted) submission: the draft holding the IAP, or one left by a failed attempt.
    s, r = asc.call('GET', f'/v1/reviewSubmissions?filter[app]={APP_ID}&filter[state]=READY_FOR_REVIEW')
    open_subs = ok(s, r, 'open submissions')['data']
    if open_subs:
        sub = open_subs[0]['id']
        print('reusing open submission', sub)
    else:
        s, r = asc.call('POST', '/v1/reviewSubmissions', {'data': {'type': 'reviewSubmissions',
                        'attributes': {'platform': 'IOS'},
                        'relationships': {'app': {'data': {'type': 'apps', 'id': APP_ID}}}}})
        sub = ok(s, r, 'review submission')['data']['id']
    ok(*asc.call('POST', '/v1/reviewSubmissionItems', {'data': {'type': 'reviewSubmissionItems',
       'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sub}},
                         'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}}), 'add version')
    print('added version')
    ok(*asc.call('PATCH', f'/v1/reviewSubmissions/{sub}', {'data': {'type': 'reviewSubmissions', 'id': sub,
       'attributes': {'submitted': True}}}), 'submit')
    print('SUBMITTED', sub)


if __name__ == '__main__':
    main()
