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
