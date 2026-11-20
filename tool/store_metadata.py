#!/usr/bin/env python3
"""App Store metadata: check the YAML in docs/store/, diff it against App Store Connect, push it.

  tool/store_metadata.py check              limits, keywords, required fields, every locale, no key-like strings
  tool/store_metadata.py push               dry run: GET-only diff against ASC (default)
  tool/store_metadata.py push --apply       PATCH/POST the differences (coordinator only)
  tool/store_metadata.py review-zh          regenerate docs/store/review-zh.md (English / zh-Hans / zh-Hant)

Stdlib only (no PyYAML): the YAML files use a small subset — `key: "scalar"`, `key: |` blocks, and one level
of nested mappings in app.yaml. Secrets: the *_API_KEY values from the environment and .env are compared
inside this script and never printed; the ASC key is read inside tool/asc.py.
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / 'docs' / 'store'
META = STORE / 'metadata'
LOCALES = ['en-US', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'de-DE', 'fr-FR', 'es-ES', 'pt-BR', 'it']
FIELDS = ['name', 'subtitle', 'promotional_text', 'description', 'keywords', 'whats_new']
# Apple's limits; keywords are counted in UTF-8 bytes (stricter than Apple's character count, on purpose).
LIMITS = {'name': 30, 'subtitle': 30, 'promotional_text': 170, 'description': 4000, 'whats_new': 4000}
KEYWORD_BYTES = 100
# Screenshot captions (release-01 R3): one per scene, in upload order (tool/store_frames.py). Not sent by push;
# tool/store_frames.py checks that each fits in 2 lines on the 1320×2868 canvas; '|' marks the line break.
CAPTION_SCENES = ['record-live', 'keyboard', 'record-done', 'drafts', 'profiles', 'field-rules', 'desktop']
CAPTION_MAX = 48  # characters; a quick bound, the real fit check is in tool/store_frames.py
# Other products and trademarks never go into keywords (App Review guideline 2.3.7).
TRADEMARKS = ['siri', 'apple', 'iphone', 'ios', 'whisper', 'wispr', 'chatgpt', 'openai', 'gpt', 'google', 'gboard',
              'otter', 'superwhisper', 'typeless', 'willow', 'aqua', 'spokenly', 'voiceink', 'microsoft', 'copilot',
              'gemini', 'claude', 'soniox', 'bailian', 'alibaba', 'qwen', 'swiftkey']
KEY_PATTERNS = [r'\bsk-[A-Za-z0-9_-]{16,}', r'\b(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[a-z])[A-Za-z0-9_-]{32,}\b', r'(?i)api[_-]?key\s*[:=]\s*\S+']


# ---------- minimal YAML subset ----------

def _scalar(raw: str) -> str:
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] == '"':
        return json.loads(raw)
    if len(raw) >= 2 and raw[0] == raw[-1] == "'":
        return raw[1:-1].replace("''", "'")
    return raw


def parse_yaml(text: str) -> dict:
    """Mappings of scalars, `|` block scalars and nested mappings (by indentation). Comments: whole lines."""
    lines = text.splitlines()
    root: dict = {}
    stack = [(-1, root)]
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.lstrip().startswith('#'):
            i += 1
            continue
        indent = len(line) - len(line.lstrip(' '))
        m = re.match(r'^\s*([A-Za-z0-9_.-]+):(?:\s+(.*))?$', line)
        if not m:
            raise ValueError(f'line {i + 1}: cannot parse {line!r}')
        key, rest = m.group(1), (m.group(2) or '').strip()
        while stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]
        if rest in ('|', '|-'):
            block, i = [], i + 1
            block_indent = None
            while i < len(lines):
                ln = lines[i]
                if ln.strip():
                    ind = len(ln) - len(ln.lstrip(' '))
                    if block_indent is None:
                        block_indent = ind
                    if ind < block_indent or ind <= indent:
                        break
                    block.append(ln[block_indent:])
                else:
                    block.append('')
                i += 1
            parent[key] = '\n'.join(block).rstrip('\n')
            continue
        if rest == '':
            child: dict = {}
            parent[key] = child
            stack.append((indent, child))
        elif rest in ('true', 'false'):
            parent[key] = rest == 'true'
        elif rest == 'null':
            parent[key] = None
        else:
            parent[key] = _scalar(rest)
        i += 1
    return root


def load(path: Path) -> dict:
    return parse_yaml(path.read_text(encoding='utf-8'))


def load_locale(locale: str) -> dict:
    return load(META / f'{locale}.yaml')


# ---------- secrets (never printed) ----------

def _env_files():
    out = [ROOT / '.env']
    try:
        common = subprocess.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], cwd=ROOT,
                                capture_output=True, text=True, check=True).stdout.strip()
        out.append(Path(common).parent / '.env')
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return [p for p in dict.fromkeys(out) if p.is_file()]


def key_values():
    """(name, value) for every *_API_KEY in the environment and .env (worktree and main checkout)."""
    found = {}
    for name, value in os.environ.items():
        if name.endswith('_API_KEY') and len(value.strip()) >= 8:
            found[(name, value.strip())] = True
    for env in _env_files():
        for line in env.read_text(errors='ignore').splitlines():
            m = re.match(r'^\s*(?:export\s+)?([A-Za-z0-9_]+_API_KEY)\s*=\s*(.*)$', line)
            if m:
                v = m.group(2).strip().strip('"').strip("'")
                if len(v) >= 8:
                    found[(m.group(1), v)] = True
    return list(found)


# ---------- check ----------

def _words(text: str):
    return {w for w in re.findall(r'[^\W_]+', text.lower()) if w}


def _is_cjk(s: str) -> bool:
    return bool(re.search(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]', s))


def check_keywords(loc: str, data: dict):
    problems = []
    kw = data.get('keywords', '')
    size = len(kw.encode('utf-8'))
    if size > KEYWORD_BYTES:
        problems.append(f'{loc}: keywords {size} bytes > {KEYWORD_BYTES}')
    if ', ' in kw or kw != kw.strip():
        problems.append(f'{loc}: keywords have spaces around commas')
    items = kw.split(',')
    if any(not x.strip() for x in items):
        problems.append(f'{loc}: empty keyword')
    seen = set()
    title = f"{data.get('name', '')} {data.get('subtitle', '')}"
    title_words = _words(title)
    for item in items:
        k = item.strip().lower()
        if k in seen:
            problems.append(f'{loc}: duplicate keyword {item!r}')
        seen.add(k)
        iw = _words(k)
        if _is_cjk(k):
            if k in title.lower():
                problems.append(f'{loc}: keyword {item!r} already in name/subtitle')
        elif iw and iw <= title_words:
            problems.append(f'{loc}: keyword {item!r} already in name/subtitle')
        for tm in TRADEMARKS:
            if tm in iw or (_is_cjk(k) and tm in k):
                problems.append(f'{loc}: keyword {item!r} is a trademark / other product')
    return problems


def check():
    problems = []
    secrets = key_values()
    texts = []
    for loc in LOCALES:
        path = META / f'{loc}.yaml'
        if not path.is_file():
            problems.append(f'{loc}: missing {path.relative_to(ROOT)}')
            continue
        try:
            data = load(path)
        except ValueError as e:
            problems.append(f'{loc}: {e}')
            continue
        for f in FIELDS:
            v = data.get(f)
            if not isinstance(v, str) or not v.strip():
                problems.append(f'{loc}: {f} missing or empty')
        if data.get('name') != 'Shinsoku':
            problems.append(f'{loc}: name must stay "Shinsoku"')
        for f, lim in LIMITS.items():
            v = data.get(f) or ''
            if len(v) > lim:
                problems.append(f'{loc}: {f} {len(v)} chars > {lim}')
        for f in ('name', 'subtitle', 'promotional_text', 'keywords'):
            if '\n' in (data.get(f) or ''):
                problems.append(f'{loc}: {f} must be one line')
        if re.search(r'<[a-zA-Z/][^>]*>', data.get('description', '')):
            problems.append(f'{loc}: description has HTML tags (plain text only)')
        problems += check_keywords(loc, data)
        caps = data.get('captions')
        if not isinstance(caps, dict):
            problems.append(f'{loc}: captions missing')
        else:
            if list(caps) != CAPTION_SCENES:
                problems.append(f'{loc}: captions must be {CAPTION_SCENES} in this order, got {list(caps)}')
            for k, v in caps.items():
                if not isinstance(v, str) or not v.strip() or '\n' in v:
                    problems.append(f'{loc}: caption {k} empty or not one line')
                elif len(v) > CAPTION_MAX:
                    problems.append(f'{loc}: caption {k} {len(v)} chars > {CAPTION_MAX}')
        unknown = set(data) - set(FIELDS) - {'captions'}
        if unknown:
            problems.append(f'{loc}: unknown fields {sorted(unknown)}')
        texts.append((loc, '\n'.join(str(v) for v in data.values())))
    app_path = STORE / 'app.yaml'
    if not app_path.is_file():
        problems.append('app.yaml missing')
    else:
        app = load(app_path)
        for k in ('bundle_id', 'version', 'primary_category', 'secondary_category', 'copyright', 'privacy_url',
                  'support_url', 'marketing_url', 'content_rights', 'release_type', 'age_rating'):
            if app.get(k) in (None, ''):
                problems.append(f'app.yaml: {k} missing')
        for k in ('privacy_url', 'support_url', 'marketing_url'):
            if not str(app.get(k, '')).startswith('https://'):
                problems.append(f'app.yaml: {k} must be https')
        texts.append(('app.yaml', app_path.read_text(encoding='utf-8')))
    for where, text in texts:
        for pat in KEY_PATTERNS:
            if re.search(pat, text):
                problems.append(f'{where}: key-like string (pattern {pat})')
        for name, value in secrets:
            if value in text:
                problems.append(f'{where}: contains the value of {name}')
    for p in problems:
        print('FAIL', p)
    if not problems:
        print(f'ok: {len(LOCALES)} locales, app.yaml, {len(secrets)} key value(s) compared (not printed)')
    return 1 if problems else 0


# ---------- push (ASC) ----------

def asc():
    sys.path.insert(0, str(ROOT / 'tool'))
    import asc as client  # noqa: E402  (reads the ASC key itself; never prints it)
    return client


def get(client, path):
    status, data = client.call('GET', path)
    if status != 200:
        raise SystemExit(f'GET {path.split("?")[0]} -> {status}: {data}')
    return data


EDITABLE = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED',
            'INVALID_BINARY'}
INFO_MAP = {'name': 'name', 'subtitle': 'subtitle'}
VERSION_MAP = {'description': 'description', 'keywords': 'keywords', 'promotional_text': 'promotionalText',
               'whats_new': 'whatsNew'}


def _short(v):
    if v is None:
        return '∅'
    s = str(v).replace('\n', '⏎')
    return (s[:48] + '…') if len(s) > 48 else s


def push(apply: bool):
    if check() != 0:  # never push something that fails check
        print('check failed; nothing pushed')
        return 1
    app_cfg = load(STORE / 'app.yaml')
    client = asc()
    q = urllib.parse.quote
    apps = get(client, f"/v1/apps?filter[bundleId]={q(app_cfg['bundle_id'])}&fields[apps]=name,contentRightsDeclaration")
    app = apps['data'][0]
    app_id = app['id']
    infos = get(client, f'/v1/apps/{app_id}/appInfos?include=primaryCategory,secondaryCategory')
    info = next((x for x in infos['data'] if x['attributes'].get('state', x['attributes'].get('appStoreState'))
                 in EDITABLE), None)
    versions = get(client, f'/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS'
                           '&fields[appStoreVersions]=versionString,appStoreState,copyright,releaseType')
    version = next((v for v in versions['data'] if v['attributes']['appStoreState'] in EDITABLE), None)
    first_release = not any(v['attributes']['appStoreState'] not in EDITABLE for v in versions['data'])
    if not info or not version:
        raise SystemExit('no editable appInfo / appStoreVersion (PREPARE_FOR_SUBMISSION) found')

    changes = []  # (description, method, path, body)

    # app level
    want_rights = app_cfg['content_rights']
    if app['attributes'].get('contentRightsDeclaration') != want_rights:
        changes.append((f"app contentRightsDeclaration: {_short(app['attributes'].get('contentRightsDeclaration'))}"
                        f" -> {want_rights}", 'PATCH', f'/v1/apps/{app_id}',
                        {'data': {'type': 'apps', 'id': app_id,
                                  'attributes': {'contentRightsDeclaration': want_rights}}}))
    rel = info.get('relationships', {})
    cur_pri = (rel.get('primaryCategory', {}).get('data') or {}).get('id')
    cur_sec = (rel.get('secondaryCategory', {}).get('data') or {}).get('id')
    if (cur_pri, cur_sec) != (app_cfg['primary_category'], app_cfg['secondary_category']):
        changes.append((f'categories: {cur_pri}/{cur_sec} -> {app_cfg["primary_category"]}/'
                        f'{app_cfg["secondary_category"]}', 'PATCH', f'/v1/appInfos/{info["id"]}',
                        {'data': {'type': 'appInfos', 'id': info['id'], 'relationships': {
                            'primaryCategory': {'data': {'type': 'appCategories',
                                                         'id': app_cfg['primary_category']}},
                            'secondaryCategory': {'data': {'type': 'appCategories',
                                                           'id': app_cfg['secondary_category']}}}}}))
    age = get(client, f'/v1/appInfos/{info["id"]}/ageRatingDeclaration')['data']
    want_age = app_cfg['age_rating']
    age_diff = {k: v for k, v in want_age.items() if age['attributes'].get(k) != v}
    missing_age = [k for k, v in age['attributes'].items() if v is None and k not in want_age
                   and k not in ('kidsAgeBand', 'gracRatingClassificationNumber', 'developerAgeRatingInfoUrl')]
    if missing_age:
        print('WARN age rating fields not in app.yaml (left unanswered):', ', '.join(missing_age))
    if age_diff:
        changes.append((f'age rating: {len(age_diff)} answer(s) ({", ".join(sorted(age_diff))})', 'PATCH',
                        f'/v1/ageRatingDeclarations/{age["id"]}',
                        {'data': {'type': 'ageRatingDeclarations', 'id': age['id'], 'attributes': age_diff}}))
    va = version['attributes']
    v_attrs = {}
    if va.get('versionString') != app_cfg['version']:
        v_attrs['versionString'] = app_cfg['version']
    if va.get('copyright') != app_cfg['copyright']:
        v_attrs['copyright'] = app_cfg['copyright']
    if va.get('releaseType') != app_cfg['release_type']:
        v_attrs['releaseType'] = app_cfg['release_type']
    if v_attrs:
        changes.append(('version ' + ', '.join(f'{k}: {_short(va.get(k))} -> {_short(v)}' for k, v in v_attrs.items()),
                        'PATCH', f'/v1/appStoreVersions/{version["id"]}',
                        {'data': {'type': 'appStoreVersions', 'id': version['id'], 'attributes': v_attrs}}))

    # localizations
    info_locs = {x['attributes']['locale']: x for x in
                 get(client, f'/v1/appInfos/{info["id"]}/appInfoLocalizations?limit=50')['data']}
    ver_locs = {x['attributes']['locale']: x for x in
                get(client, f'/v1/appStoreVersions/{version["id"]}/appStoreVersionLocalizations?limit=50')['data']}
    for loc in LOCALES:
        data = load_locale(loc)
        want_info = {INFO_MAP[k]: data[k] for k in INFO_MAP}
        want_info['privacyPolicyUrl'] = app_cfg['privacy_url']
        want_ver = {VERSION_MAP[k]: data[k] for k in VERSION_MAP}
        want_ver['supportUrl'] = app_cfg['support_url']
        want_ver['marketingUrl'] = app_cfg['marketing_url']
        if first_release:
            want_ver.pop('whatsNew')  # ASC refuses What's New on an app's first version
        for kind, have, want, typ, parent_rel, parent_type, parent_id in (
                ('info', info_locs, want_info, 'appInfoLocalizations', 'appInfo', 'appInfos', info['id']),
                ('version', ver_locs, want_ver, 'appStoreVersionLocalizations', 'appStoreVersion',
                 'appStoreVersions', version['id'])):
            cur = have.get(loc)
            if cur is None:
                changes.append((f'{loc} {kind}: create ({", ".join(want)})', 'POST', f'/v1/{typ}',
                                {'data': {'type': typ, 'attributes': {'locale': loc, **want},
                                          'relationships': {parent_rel: {'data': {'type': parent_type,
                                                                                  'id': parent_id}}}}}))
                continue
            diff = {k: v for k, v in want.items() if (cur['attributes'].get(k) or '') != v}
            if diff:
                desc = '; '.join(f'{k}: {_short(cur["attributes"].get(k))} -> {_short(v)}' for k, v in diff.items())
                changes.append((f'{loc} {kind}: {desc}', 'PATCH', f'/v1/{typ}/{cur["id"]}',
                                {'data': {'type': typ, 'id': cur['id'], 'attributes': diff}}))
        extra = set(ver_locs) - set(LOCALES)
        if extra and loc == LOCALES[-1]:
            print('WARN localizations in ASC but not in docs/store:', ', '.join(sorted(extra)))

    print(f"\n{'APPLY' if apply else 'DRY RUN'}: app {app_id}, version {va.get('versionString')} "
          f"({va.get('appStoreState')}), first release: {first_release}, {len(changes)} change(s)")
    for desc, method, path, _ in changes:
        print(f'  {method:5} {desc}')
    if not apply:
        print('\nNothing sent. Run with --apply to write these changes.')
        return 0
    failed = 0
    for desc, method, path, body in changes:
        status, data = client.call(method, path, body)
        ok = status in (200, 201)
        failed += not ok
        print(f"  {'ok ' if ok else 'ERR'} {status} {method} {desc.split(':')[0]}")
        if not ok:
            errs = data.get('errors', []) if isinstance(data, dict) else [data]
            for e in errs:
                print('      ', e.get('detail', e) if isinstance(e, dict) else e)
    return 1 if failed else 0


# ---------- review table ----------

FIELD_LABELS = {'name': 'Name', 'subtitle': 'Subtitle (≤30)', 'promotional_text': 'Promotional text (≤170)',
                'keywords': 'Keywords (≤100 bytes)', 'description': 'Description', 'whats_new': "What's New"}


def review_zh():
    en, hans, hant = (load_locale(x) for x in ('en-US', 'zh-Hans', 'zh-Hant'))

    def cell(s):
        return s.replace('|', '\\|').replace('\n\n', '<br><br>').replace('\n', '<br>')

    out = ['# App Store metadata — Chinese review', '',
           'Generated by `python3 tool/store_metadata.py review-zh` from `docs/store/metadata/*.yaml`; do not edit '
           'by hand. Terms follow `docs/i18n/glossary.md`.', '',
           'How to review: mark a row (or write the better wording next to it) and send it back; the fix goes into '
           'the YAML and this file is regenerated. zh-Hans is for Singapore, Malaysia and overseas readers '
           '(mainland-neutral; the app is not offered in mainland China); zh-Hant uses Taiwan wording. '
           "What's New is stored but not sent for 1.0 (App Store Connect does not accept it on a first version).", '',
           '| Field | English | 简体中文 (zh-Hans) | 繁體中文 (zh-Hant) |', '|---|---|---|---|']
    for f in FIELDS:
        out.append(f'| {FIELD_LABELS[f]} | {cell(en[f])} | {cell(hans[f])} | {cell(hant[f])} |')
    out += ['', '## Screenshot captions (upload order)', '',
            '| Scene | English | 简体中文 (zh-Hans) | 繁體中文 (zh-Hant) |', '|---|---|---|---|']
    for k in CAPTION_SCENES:
        out.append(f"| {k} | {cell(en['captions'][k])} | {cell(hans['captions'][k])} | {cell(hant['captions'][k])} |")
    app = load(STORE / 'app.yaml')
    out += ['', '## App-level (all languages)', '', '| Field | Value |', '|---|---|']
    for k in ('primary_category', 'secondary_category', 'copyright', 'privacy_url', 'support_url', 'marketing_url'):
        out.append(f'| {k} | {app[k]} |')
    (STORE / 'review-zh.md').write_text('\n'.join(out) + '\n', encoding='utf-8')
    print('wrote docs/store/review-zh.md')
    return 0


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    if cmd == 'check':
        sys.exit(check())
    if cmd == 'push':
        sys.exit(push('--apply' in sys.argv[2:]))
    if cmd == 'review-zh':
        sys.exit(review_zh())
    print(__doc__)
    sys.exit(2)
