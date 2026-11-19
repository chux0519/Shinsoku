#!/usr/bin/env python3
"""Native string check (i18n-01 I2, rule R06). Exit 1 on any problem.

1. Every String Catalog entry has an English value (entries marked `shouldTranslate: false` are exempt).
2. Every localizable key in the Swift sources is in the target's catalog:
   - keyboard: `String(localized: "...")` → ShinsokuKeyboard/Localizable.xcstrings
   - Runner: App Intents strings (title, IntentDescription, @Parameter title, dialogs, errors, short titles,
     TypeDisplayRepresentation, DisplayRepresentation, Summary) → Runner/Localizable.xcstrings
   - App Shortcut phrases → Runner/en.lproj/AppShortcuts.strings (the catalog form needs iOS 17; Runner is 15)
3. No bare string literal goes to a UI sink (`.text =`, accessibility label/hint/value, key/menu/action titles,
   announcements) in the native targets.
4. Info.plist permission texts (`NS*UsageDescription`) are in InfoPlist.xcstrings with the same English value.
5. Catalog keys no longer found in the source are reported as warnings (stale; don't translate them).
6. (I5) Every translatable catalog entry has a `translated` value in all of LANGUAGES, with the same
   placeholders (%@, %lld, %d, ${…}) as English; every language has `Runner/<lang>.lproj/AppShortcuts.strings`
   with every English phrase, the same `${…}` placeholders, and a file reference in the pbxproj variant group.

`--stringsdata DIR` also checks the keys the Swift compiler extracted (`*.stringsdata` under DIR, e.g. the
DerivedData `Runner.build/Debug-iphonesimulator` folder after a build with SWIFT_EMIT_LOC_STRINGS=YES): this is
the authoritative list; the source scan above is the fast approximation.
"""
import argparse
import glob
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'mobile/ios'
TARGETS = {
    'ShinsokuKeyboard': IOS / 'ShinsokuKeyboard/Localizable.xcstrings',
    'Runner': IOS / 'Runner/Localizable.xcstrings',
}
INFOPLIST_CATALOG = IOS / 'Runner/InfoPlist.xcstrings'
SHORTCUTS_STRINGS = IOS / 'Runner/en.lproj/AppShortcuts.strings'
PBXPROJ = IOS / 'Runner.xcodeproj/project.pbxproj'
LANGUAGES = ['en', 'ja', 'zh-Hant', 'ko', 'de', 'es', 'zh-Hans', 'fr', 'pt-BR', 'it']
PLACEHOLDER = re.compile(r'%(?:\d+\$)?(?:@|lld|ld|d|f)|\$\{\w+\}')

STR = r'"((?:[^"\\]|\\.)*)"'
# Localizable forms. Group 1 is the Swift literal.
LOCALIZED_FORMS = [
    r'String\(\s*localized:\s*' + STR,
    r'LocalizedStringResource\(\s*' + STR,
    r'LocalizedStringResource\s*=\s*' + STR,
    r'TypeDisplayRepresentation\s*=\s*' + STR,
    r'IntentDescription\(\s*' + STR,
    r'@Parameter\(\s*title:\s*' + STR,
    r'DisplayRepresentation\(\s*title:\s*' + STR,
    r'dialog:\s*' + STR,
    r'shortTitle:\s*' + STR,
    r'Summary\(\s*' + STR,
]
# Inside `var localizedStringResource: LocalizedStringResource { ... }` every `return "..."` is localizable.
RESOURCE_RETURN = r'return\s+' + STR
# UI sinks that must never receive a bare literal.
SINKS = [
    r'\.text\s*=\s*"',
    r'accessibility(?:Label|Hint|Value)\s*=\s*(?:[^"\n]*\?\s*)?"',
    r'UIMenu\(\s*title:\s*"',
    r'UIAction\(\s*title:\s*"',
    r'UIAccessibilityCustomAction\(\s*name:\s*"',
    r'setTitle\(\s*"',
    r'KeyboardKey\([^)]*title:\s*"',
    r'argument:\s*"',
    r'config\.title\s*=\s*"',
]
PHRASES = re.compile(r'phrases:\s*\[(.*?)\]', re.S)


def swift_key(literal):
    """Swift literal → catalog key: `\\(x)` → `%@`, `\\(\\.$p)` → `${p}`, `\\"` → `"`."""
    key = re.sub(r'\\\(\\\.\$(\w+)\)', r'${\1}', literal)
    key = re.sub(r'\\\(\.applicationName\)', '${applicationName}', key)
    key = re.sub(r'\\\((?:[^()]|\([^()]*\))*\)', '%@', key)
    return key.replace('\\"', '"').replace('\\\\', '\\')


def strip_comments(text):
    # Line comments only (doc comments carry English prose that is not UI text).
    return '\n'.join(re.sub(r'^\s*//.*$', '', line) for line in text.splitlines())


def load_catalog(path, problems):
    if not path.is_file():
        problems.append(f'{path.relative_to(ROOT)}: missing')
        return {}
    doc = json.loads(path.read_text())
    if doc.get('sourceLanguage') != 'en':
        problems.append(f'{path.relative_to(ROOT)}: sourceLanguage is not en')
    strings = doc.get('strings', {})
    for key, entry in strings.items():
        if entry.get('shouldTranslate') is False:
            continue
        value = entry.get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value', '')
        if not value.strip():
            problems.append(f'{path.relative_to(ROOT)}: "{key}" has no English value')
    return strings


def placeholders(text):
    return sorted(PLACEHOLDER.findall(text))


def check_languages(path, strings, problems):
    """Every translatable entry: a translated value per language, placeholders as in English."""
    rel = path.relative_to(ROOT)
    for key, entry in strings.items():
        if entry.get('shouldTranslate') is False:
            continue
        locs = entry.get('localizations', {})
        english = placeholders(locs.get('en', {}).get('stringUnit', {}).get('value', ''))
        for lang in LANGUAGES[1:]:
            unit = locs.get(lang, {}).get('stringUnit', {})
            value = unit.get('value', '')
            if not value.strip():
                problems.append(f'{rel}: "{key}" has no {lang} value')
            elif unit.get('state') != 'translated':
                problems.append(f'{rel}: "{key}" {lang} state is {unit.get("state")!r}, not translated')
            elif placeholders(value) != english:
                problems.append(f'{rel}: "{key}" {lang} placeholders {placeholders(value)} != English {english}')


def check_shortcut_languages(english, problems):
    pbxproj = PBXPROJ.read_text() if PBXPROJ.is_file() else ''
    for lang in LANGUAGES[1:]:
        path = IOS / f'Runner/{lang}.lproj/AppShortcuts.strings'
        if f'path = {quote_pbx(lang + ".lproj/AppShortcuts.strings")};' not in pbxproj:
            problems.append(f'{path.relative_to(ROOT)}: not in the AppShortcuts.strings variant group (pbxproj)')
        strings = load_strings_file(path, problems)
        for key in english:
            value = strings.get(key)
            if value is None:
                problems.append(f'{path.relative_to(ROOT)}: "{key}" missing')
            elif placeholders(value) != placeholders(key):
                problems.append(f'{path.relative_to(ROOT)}: "{key}" placeholders differ: "{value}"')
        for key in strings:
            if key not in english:
                problems.append(f'{path.relative_to(ROOT)}: "{key}" is not an English phrase')


def quote_pbx(value):
    return value if re.fullmatch(r'[\w./]+', value) else f'"{value}"'


def load_strings_file(path, problems):
    if not path.is_file():
        problems.append(f'{path.relative_to(ROOT)}: missing')
        return {}
    try:
        return plistlib.loads(path.read_bytes()) if path.read_bytes().startswith(b'<?xml') else parse_strings(path)
    except ValueError as error:
        problems.append(f'{path.relative_to(ROOT)}: {error}')
        return {}


def parse_strings(path):
    text = re.sub(r'/\*.*?\*/', '', path.read_text(), flags=re.S)
    pairs = re.findall(STR + r'\s*=\s*' + STR + r'\s*;', text)
    rest = re.sub(STR + r'\s*=\s*' + STR + r'\s*;', '', text).strip()
    if rest:
        raise ValueError(f'unparsed text: {rest[:60]!r}')
    return {k.replace('\\"', '"'): v.replace('\\"', '"') for k, v in pairs}


def scan_sources(target):
    keys, phrases, problems = {}, {}, []
    for path in sorted((IOS / target).rglob('*.swift')):
        rel = path.relative_to(ROOT)
        if 'ResolverChecks' in path.parts:
            continue
        text = strip_comments(path.read_text())
        for pattern in LOCALIZED_FORMS:
            for m in re.finditer(pattern, text):
                keys.setdefault(swift_key(m.group(1)), f'{rel}:{text.count(chr(10), 0, m.start()) + 1}')
        for block in re.finditer(r'var localizedStringResource: LocalizedStringResource \{(.*?)\n  \}', text, re.S):
            for m in re.finditer(RESOURCE_RETURN, block.group(1)):
                keys.setdefault(swift_key(m.group(1)), f'{rel}')
        for block in PHRASES.finditer(text):
            for m in re.finditer(STR, block.group(1)):
                phrases.setdefault(swift_key(m.group(1)), f'{rel}')
        for n, line in enumerate(text.splitlines(), 1):
            for sink in SINKS:
                if re.search(sink, line):
                    problems.append(f'{rel}:{n}: bare literal to a UI sink: {line.strip()}')
    return keys, phrases, problems


def check_stringsdata(directory, catalogs, shortcuts, problems):
    seen = 0
    for target, catalog in catalogs.items():
        for path in glob.glob(f'{directory}/**/{target}.build/**/*.stringsdata', recursive=True):
            data = json.loads(Path(path).read_text())
            for table, items in data.get('tables', {}).items():
                for item in items:
                    key = item.get('key')
                    seen += 1
                    if table == 'Localizable' and key not in catalog:
                        problems.append(f'compiler-extracted "{key}" ({target}) missing from its catalog')
                    if table == 'AppShortcuts' and target == 'Runner':
                        for value in [key, *item.get('values', [])]:
                            if value not in shortcuts:
                                problems.append(f'compiler-extracted phrase "{value}" missing from AppShortcuts.strings')
    if not seen:
        problems.append(f'--stringsdata {directory}: no .stringsdata found (build with SWIFT_EMIT_LOC_STRINGS=YES)')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--stringsdata', help='build intermediates folder with *.stringsdata')
    args = parser.parse_args()
    problems, warnings = [], []

    catalogs = {target: load_catalog(path, problems) for target, path in TARGETS.items()}
    shortcuts = load_strings_file(SHORTCUTS_STRINGS, problems)
    for target, catalog in catalogs.items():
        check_languages(TARGETS[target], catalog, problems)
    check_shortcut_languages(shortcuts, problems)

    for target, catalog in catalogs.items():
        keys, phrases, sink_problems = scan_sources(target)
        problems += sink_problems
        for key, where in keys.items():
            if key not in catalog:
                problems.append(f'{where}: "{key}" missing from {TARGETS[target].relative_to(ROOT)}')
        for key in catalog:
            if key not in keys:
                warnings.append(f'{TARGETS[target].relative_to(ROOT)}: "{key}" not found in source (stale?)')
        if target == 'Runner':
            for phrase, where in phrases.items():
                if '${applicationName}' not in phrase:
                    problems.append(f'{where}: phrase "{phrase}" lacks \\(.applicationName)')
                if phrase not in shortcuts:
                    problems.append(f'{where}: phrase "{phrase}" missing from {SHORTCUTS_STRINGS.relative_to(ROOT)}')
            for key, value in shortcuts.items():
                if '${applicationName}' not in value:
                    problems.append(f'AppShortcuts.strings: "{key}" value lacks ${{applicationName}}')
                if key not in phrases:
                    warnings.append(f'AppShortcuts.strings: "{key}" not found in source (stale?)')

    info = plistlib.loads((IOS / 'Runner/Info.plist').read_bytes())
    info_catalog = load_catalog(INFOPLIST_CATALOG, problems)
    check_languages(INFOPLIST_CATALOG, info_catalog, problems)
    for key, value in info.items():
        if key.startswith('NS') and key.endswith('UsageDescription'):
            entry = info_catalog.get(key)
            en = (entry or {}).get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value')
            if en is None:
                problems.append(f'Info.plist {key} missing from InfoPlist.xcstrings')
            elif en != value:
                problems.append(f'Info.plist {key}: English value differs from InfoPlist.xcstrings')

    if args.stringsdata:
        check_stringsdata(args.stringsdata, catalogs, shortcuts, problems)

    for w in warnings:
        print(f'warning: {w}')
    for p in problems:
        print(p)
    print(f'check_xcstrings: {len(problems)} problem(s), {len(warnings)} warning(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
