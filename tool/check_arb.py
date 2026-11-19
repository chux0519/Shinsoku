#!/usr/bin/env python3
"""ARB translation check (i18n-01 I5, rule R07). Exit 1 on any problem.

For every `mobile/lib/l10n/app_<tag>.arb` against the template `app_en.arb`:
1. Same message keys; no empty value.
2. Same placeholders (`{name}`, `{count, plural, ...}`).
3. Plural messages stay plural on the same variable, use only CLDR categories or `=N`, and have `other`.
4. Every language of LANGUAGES has its file; the gen-l10n fallbacks (`app_zh.arb`, `app_pt.arb`) equal
   zh-Hans / pt-BR.
5. Shortcuts names quoted in the app match the native strings of that language (tool/i18n/native.json):
   `useInAppsReadyMade` quotes the "Switch ${applicationName} to ${profile}" phrase with the translated Chat
   profile name; `useInAppsOpenStep3` / `useInAppsCloseStep2` name the translated "Set Shinsoku Profile".
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / 'mobile/lib/l10n'
NATIVE = ROOT / 'tool/i18n/native.json'
# ARB tag → native (Xcode) language.
LANGUAGES = {'ja': 'ja', 'zh_Hant': 'zh-Hant', 'ko': 'ko', 'de': 'de', 'es': 'es', 'zh_Hans': 'zh-Hans',
             'fr': 'fr', 'pt_BR': 'pt-BR', 'it': 'it'}
FALLBACKS = {'zh': 'zh_Hans', 'pt': 'pt_BR'}
PLURAL = re.compile(r'\{(\w+),\s*plural,')
PLURAL_FORMS = {'zero', 'one', 'two', 'few', 'many', 'other'}


def messages(path):
    doc = json.loads(path.read_text())
    return {k: v for k, v in doc.items() if not k.startswith('@')}


def placeholders(text):
    # Plural branch openers (`=1{`, `other{`) are not placeholders.
    text = re.sub(r'(?:=\d+|\b(?:zero|one|two|few|many|other))\s*\{', '(', text)
    return sorted(set(re.findall(r'\{(\w+)[},]', text)))


def plural_forms(text):
    """Selectors of the first plural block, e.g. ['=1', 'other']."""
    m = PLURAL.search(text)
    if not m:
        return None
    depth, i, forms, body = 1, m.end(), [], text[m.end():]
    selector = ''
    for ch in body:
        if ch == '{':
            if depth == 1:
                forms.append(selector.strip())
                selector = ''
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                break
        elif depth == 1:
            selector += ch
    return m.group(1), forms


def main():
    problems = []
    template = messages(ARB_DIR / 'app_en.arb')
    files = sorted(p for p in ARB_DIR.glob('app_*.arb') if p.name != 'app_en.arb')
    tags = {p.stem[len('app_'):]: p for p in files}
    for tag in [*LANGUAGES, *FALLBACKS]:
        if tag not in tags:
            problems.append(f'app_{tag}.arb missing')
    for tag, path in tags.items():
        arb = messages(path)
        for key in sorted(set(template) ^ set(arb)):
            problems.append(f'{path.name}: key "{key}" ' + ('missing' if key in template else 'not in the template'))
        for key, english in template.items():
            value = arb.get(key)
            if value is None:
                continue
            if not str(value).strip():
                problems.append(f'{path.name}: "{key}" is empty')
                continue
            if placeholders(value) != placeholders(english):
                problems.append(f'{path.name}: "{key}" placeholders {placeholders(value)} != {placeholders(english)}')
            en_plural, plural = plural_forms(english), plural_forms(value)
            if en_plural and not plural:
                problems.append(f'{path.name}: "{key}" is no longer a plural')
            elif plural:
                var, forms = plural
                if en_plural and var != en_plural[0]:
                    problems.append(f'{path.name}: "{key}" plural on {var}, English on {en_plural[0]}')
                bad = [f for f in forms if f not in PLURAL_FORMS and not re.fullmatch(r'=\d+', f)]
                if bad or 'other' not in forms:
                    problems.append(f'{path.name}: "{key}" plural forms {forms} (need other; CLDR or =N only)')
    for fallback, source in FALLBACKS.items():
        if fallback in tags and source in tags and messages(tags[fallback]) != messages(tags[source]):
            problems.append(f'app_{fallback}.arb differs from app_{source}.arb (regenerate the fallback copy)')

    native = json.loads(NATIVE.read_text())
    index = {lang: i for i, lang in enumerate(native['languages'])}
    phrase = native['AppShortcuts.strings']['Switch ${applicationName} to ${profile}']
    set_title = native['mobile/ios/Runner/Localizable.xcstrings']['Set Shinsoku Profile']
    for tag, lang in LANGUAGES.items():
        if tag not in tags:
            continue
        arb = messages(tags[tag])
        i = index[lang]
        example = phrase[i].replace('${applicationName}', 'Shinsoku').replace('${profile}', arb['profileChatName'])
        if example not in arb['useInAppsReadyMade']:
            problems.append(f'app_{tag}.arb: useInAppsReadyMade does not quote the Shortcuts phrase "{example}"')
        for key in ('useInAppsOpenStep3', 'useInAppsCloseStep2'):
            if set_title[i] not in arb[key]:
                problems.append(f'app_{tag}.arb: {key} does not name the action "{set_title[i]}"')

    for p in problems:
        print(p)
    print(f'check_arb: {len(tags)} file(s), {len(problems)} problem(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
