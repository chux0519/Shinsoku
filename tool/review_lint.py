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
