#!/usr/bin/env python3
"""Generate the pseudo-locale ARB (en_XA) from app_en.arb: accented letters, ~40% longer, wrapped in [ ].

`python3 tool/pseudo_arb.py` rewrites mobile/lib/l10n/app_en_XA.arb. Run it (then `flutter gen-l10n`) after every
change to app_en.arb. The pseudo-locale is for tests and host renders only: an unextracted string stays plain
English next to accented text, and the longer text exposes overflow. Placeholders and ICU syntax are untouched.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / 'mobile' / 'lib' / 'l10n'
MAP = dict(zip('aeiouyAEIOUYcnsCNSdgDGtT', 'àéîöüýÀÉÎÖÜÝçñšÇÑŠđĝĐĜţŢ'))
FILLER = ' lorem ipsum dolor sit amet consectetur adipiscing elit sed do'


def accent(text):
    return ''.join(MAP.get(ch, ch) for ch in text)


def pad(text):
    extra = max(3, round(len(text) * 0.4))
    return text + accent(FILLER[:extra]).rstrip() if text.strip() else text


def transform_plain(text):
    return pad(accent(text)) if text.strip() else text


def transform(msg):
    """Transform literal text; leave {placeholders} and plural/select syntax alone."""
    out, buf, i = [], '', 0
    while i < len(msg):
        ch = msg[i]
        if ch != '{':
            buf += ch
            i += 1
            continue
        depth, j = 1, i + 1
        while depth:
            depth += {'{': 1, '}': -1}.get(msg[j], 0)
            j += 1
        out.append(transform_plain(buf))
        buf = ''
        body = msg[i + 1:j - 1]
        if re.fullmatch(r'\w+', body):
            out.append('{' + body + '}')
        else:
            head, kind, rest = body.split(',', 2)
            branches, k = [], 0
            while k < len(rest):
                m = re.match(r'\s*([=\w]+)\{', rest[k:])
                if not m:
                    break
                start = k + m.end()
                d, e = 1, start
                while d:
                    d += {'{': 1, '}': -1}.get(rest[e], 0)
                    e += 1
                branches.append((m.group(1), transform(rest[start:e - 1])))
                k = e
            out.append('{' + head + ',' + kind + ', ' + ' '.join(f'{s}{{{t}}}' for s, t in branches) + '}')
        i = j
    out.append(transform_plain(buf))
    return ''.join(out)


def main():
    src = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    out = {}
    for key, value in src.items():
        if key == '@@locale':
            out[key] = 'en_XA'
        elif key.startswith('@'):
            continue
        else:
            out[key] = '[' + transform(value) + ']'
    (L10N / 'app_en_XA.arb').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(out) - 1} pseudo strings')


if __name__ == '__main__':
    main()
