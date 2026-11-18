#!/usr/bin/env python3
"""Copy build N-1's scripts to N, replacing the build number only where it stands alone.

  python3 tool/next_build.py 171 build/tf170-build.sh build/tf170-deliver.sh ...
writes the same files with 170 → 171 in names and contents. A number that is part of a longer number, or
sandwiched between hex characters (an id like 9c170f61-...), is left alone. Prints every changed line so a
human sees anything unexpected. Never overwrites.
"""
import re
import sys
from pathlib import Path

HEX = re.compile(r'[0-9a-fA-F]')


def bump(text, old, new):
    def swap(m):
        before = text[m.start() - 1] if m.start() else ''
        after = text[m.end()] if m.end() < len(text) else ''
        if before.isdigit() or after.isdigit():
            return m.group(0)
        if before and after and HEX.match(before) and HEX.match(after):
            return m.group(0)
        return str(new)
    return re.sub(str(old), swap, text)


def main():
    new = int(sys.argv[1]); old = new - 1
    for src in map(Path, sys.argv[2:]):
        dst = src.with_name(bump(src.name, old, new))
        if dst.exists():
            sys.exit(f'{dst} exists; refusing to overwrite')
        a, b = src.read_text(), bump(src.read_text(), old, new)
        dst.write_text(b)
        dst.chmod(src.stat().st_mode)
        for x, y in zip(a.splitlines(), b.splitlines()):
            if x != y:
                print(f'{dst}: {y.strip()}')


if __name__ == '__main__':
    main()
