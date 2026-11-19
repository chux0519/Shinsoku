#!/usr/bin/env python3
"""Rule-registry lint. `python3 tool/review_lint.py` runs all rules; `... R01` runs one.

Add a rule: write a function returning a list of problems, decorate it with @rule('Rxx', 'what it checks').
Keep each rule tied to an incident in docs/review_rules.md.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULES = {}


def rule(rid, title):
    def wrap(fn):
        RULES[rid] = (title, fn)
        return fn
    return wrap


def tracked(*globs):
    out = subprocess.run(['git', 'ls-files', '--', *globs], cwd=ROOT, capture_output=True, text=True).stdout
    return [ROOT / p for p in out.splitlines() if p]


# Fill in the names you must never ship (machine names, user names, internal domains).
FORBIDDEN_NAMES = [r'\bDESKTOP-[A-Z0-9]{5,}\b', r'(?i)\bmac-?mini\b', r'(?i)\byongsheng\b']


@rule('R01', 'No real host or user names in tests and fixtures')
def no_real_names():
    problems = []
    for f in tracked('test/**', 'tests/**', 'mobile/test/**', 'mobile/integration_test/**', '**/fixtures/**'):
        if not f.is_file():
            continue
        text = f.read_text(errors='ignore')
        for pat in FORBIDDEN_NAMES:
            for m in re.finditer(pat, text):
                problems.append(f'{f.relative_to(ROOT)}: {m.group(0)}')
    return problems


@rule('R02', 'rm -rf only as rm -rf "${VAR:?}"')
def safe_rm():
    problems = []
    for f in tracked('*.sh', '**/*.sh'):
        for n, line in enumerate(f.read_text(errors='ignore').splitlines(), 1):
            if re.search(r'rm\s+-rf\s+"?\$(?!\{\w+:\?\})', line):
                problems.append(f'{f.relative_to(ROOT)}:{n}: {line.strip()}')
    return problems


@rule('R03', 'No Color(0x / ColorScheme.fromSeed in mobile/lib outside mobile/lib/ui')
def tokens_only():
    problems = []
    for f in tracked('mobile/lib/*.dart'):
        rel = f.relative_to(ROOT).as_posix()
        if rel.startswith('mobile/lib/ui/') or not f.is_file():
            continue
        for n, line in enumerate(f.read_text(errors='ignore').splitlines(), 1):
            if re.search(r'\bColor\(0x|ColorScheme\.fromSeed', line):
                problems.append(f'{rel}:{n}: {line.strip()}')
    return problems


@rule('R04', 'No API keys compiled into the app (fromEnvironment / dart-define of *_API_KEY)')
def no_compiled_keys():
    problems = []
    for f in tracked('mobile/lib/**/*.dart'):
        if not f.is_file():
            continue
        for n, line in enumerate(f.read_text(errors='ignore').splitlines(), 1):
            if re.search(r'fromEnvironment\(\s*[\'"][A-Z_]*API_KEY', line):
                problems.append(f'{f.relative_to(ROOT).as_posix()}:{n}: {line.strip()}')
    for f in tracked('mobile/scripts/*.sh'):
        if not f.is_file():
            continue
        in_list = False
        for n, line in enumerate(f.read_text(errors='ignore').splitlines(), 1):
            st = line.strip()
            if re.match(r'for\s+name\s+in\b', st):
                in_list = True
            if in_list and re.match(r'^[A-Z_]*API_KEY\b', st):
                problems.append(f'{f.relative_to(ROOT).as_posix()}:{n}: {st}')
            if in_list and not st.endswith('\\') :
                in_list = False
            if re.search(r'--dart-define=[A-Z_]*API_KEY', line):
                problems.append(f'{f.relative_to(ROOT).as_posix()}:{n}: {st}')
    return problems

R05_KEYS = (r'Text|SelectableText|SkEmptyLine|SkPageHeader|SkStatusLine|SnackBar|'
            r'(?:label|title|subtitle|tooltip|semanticLabel|helper|placeholder|hintText|hint|text|message|detail|'
            r'confirmLabel|actionLabel|value|content|description|summary)\s*:')
R05_LITERAL = re.compile(r'(?:\b(?:' + R05_KEYS + r')\s*)\(?\s*(?:const\s+)?(r?)([\'"])((?:\\.|(?!\2).)*)\2', re.S)
R05_ALLOWED = {'Shinsoku', 'Bailian', 'Soniox', 'Qwen-ASR', 'Fun-ASR', 'OpenAI', 'SHA-256', 'WSS'}


@rule('R05', 'No literal user-facing string in UI code (features, ui, nearby, shell): use the ARB (M10)')
def no_literal_ui_strings():
    problems = []
    for f in tracked('mobile/lib/features/**/*.dart', 'mobile/lib/ui/**/*.dart', 'mobile/lib/nearby/*.dart',
                     'mobile/lib/app/shell_scaffold.dart', 'mobile/lib/app/mobile_shell.dart'):
        if not f.is_file():
            continue
        text = f.read_text(errors='ignore')
        # Developer-only regions (smoke tests) are exempt.
        text = re.sub(r'// i18n-ignore-start.*?// i18n-ignore-end', lambda m: '\n' * m.group(0).count('\n'), text,
                      flags=re.S)
        for m in R05_LITERAL.finditer(text):
            body = m.group(3)
            line = text.count('\n', 0, m.start(3)) + 1
            src = text.splitlines()[line - 1]
            if not re.search(r'[A-Za-z]{2}', re.sub(r'\$\{[^}]*\}|\$\w+', '', body)):
                continue  # punctuation, numbers, interpolation only
            if body in R05_ALLOWED or 'i18n-ignore' in src or src.lstrip().startswith(('///', '//')):
                continue
            if re.search(r'(?:key|Key|identifier|semanticsIdentifier|fieldKey)\s*[:(]', src) or 'ValueKey(' in src:
                continue
            if re.search(r'value\s*:', src) and re.fullmatch(r'[a-z_.\-]+', body):
                continue  # wire/identifier values such as value: 'soniox'
            problems.append(f'{f.relative_to(ROOT).as_posix()}:{line}: {src.strip()}')
    return problems



@rule('R06', 'Native strings localized: catalogs have English values, no bare UI literals (tool/check_xcstrings.py)')
def native_strings():
    out = subprocess.run([sys.executable, str(ROOT / 'tool/check_xcstrings.py')], cwd=ROOT,
                         capture_output=True, text=True)
    if out.returncode == 0:
        return []
    return [line for line in out.stdout.splitlines()
            if line and not line.startswith(('warning:', 'check_xcstrings:'))] or [out.stdout.strip()]

@rule('R07', 'Every language translated: ARB keys/placeholders/plurals, quoted Shortcuts names, native files '
              'generated from tool/i18n/native.json (check_arb.py, i18n_native.py --check)')
def translations():
    problems = []
    for cmd in (['tool/check_arb.py'], ['tool/i18n_native.py', '--check']):
        out = subprocess.run([sys.executable, str(ROOT / cmd[0]), *cmd[1:]], cwd=ROOT, capture_output=True, text=True)
        if out.returncode != 0:
            problems += [line for line in out.stdout.splitlines()
                         if line and not line.startswith('check_arb:')] or [out.stdout.strip() or out.stderr.strip()]
    return problems


def main(argv):
    selected = argv or sorted(RULES)
    failed = False
    for rid in selected:
        title, fn = RULES[rid]
        problems = fn()
        print(f'{rid} {title}: ' + ('ok' if not problems else f'{len(problems)} problem(s)'))
        for p in problems:
            print('   ', p)
        failed |= bool(problems)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
