#!/bin/bash
# Tier A UI review: render real Flutter screens on the host (no simulator) and
# write PNGs plus an index.html contact sheet.
#   tool/host_review.sh <run> [scene,…] [theme,…] [device,…]
# <run> is a path under build/ui-review/, e.g. ios-ui-01/round-01/u3-after.
# Themes: dark,light. Devices: iphone, iphone-text200, duo-outer,
# duo-inner-portrait, duo-inner-landscape, duo-inner-portrait-fold, duo-inner-landscape-fold (fake
# centre fold; a few scenes). Empty filters mean all.
# Output: build/ui-review/<run>/<device>/<scene>-<theme>.png (+ .json) and
# build/ui-review/<run>/index.html. A full run starts from an empty folder.
set -euo pipefail
cd "$(dirname "$0")/.."
RUN=${1:?usage: tool/host_review.sh <run under build/ui-review/> [scenes] [themes] [devices]}
case "$RUN" in /*|*..*) echo "run must be a relative path without .." >&2; exit 2 ;; esac
OUT="$PWD/build/ui-review/$RUN"
if [ -z "${2:-}${3:-}${4:-}" ] && [ -d "$OUT" ]; then
  find "$OUT" -name '*.png' -delete
  find "$OUT" -name '*.json' -delete
fi
mkdir -p "$OUT"
start=$(date +%s)
set +e
(cd mobile && SHINSOKU_HOST_REVIEW=1 SHINSOKU_HOST_REVIEW_OUT="$OUT" \
  SHINSOKU_HOST_REVIEW_SCENES="${2:-}" \
  SHINSOKU_HOST_REVIEW_THEMES="${3:-}" \
  SHINSOKU_HOST_REVIEW_DEVICES="${4:-}" \
  nice -n 10 flutter test test/host_review/host_review_test.dart) > "$OUT/run.log" 2>&1
status=$?
set -e
tail -3 "$OUT/run.log"
python3 - "$OUT" <<'PYINDEX'
import collections, html, pathlib, sys
out = pathlib.Path(sys.argv[1])
order = ['iphone', 'iphone-text200', 'duo-outer', 'duo-inner-portrait', 'duo-inner-portrait-fold',
         'duo-inner-landscape', 'duo-inner-landscape-fold']
scenes = collections.defaultdict(list)
for path in sorted(out.glob('*/*.png')):
    scene, theme = path.stem.rsplit('-', 1)
    scenes[scene].append((path.parent.name, theme, path.relative_to(out).as_posix()))
rank = lambda d: order.index(d) if d in order else len(order)
parts = ['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
         '<title>Shinsoku host review</title>',
         '<style>body{font:13px -apple-system,sans-serif;background:#1b1d1e;color:#ddd;margin:16px}'
         'section{margin-bottom:28px}div{display:flex;gap:12px;align-items:flex-start;flex-wrap:wrap}'
         'figure{margin:0}img{height:480px;border:1px solid #444}figcaption{margin-top:4px;color:#aaa}</style>',
         '<p>Host renders (tier A): host SF Pro, synthetic safe areas, no keyboard extension; *-fold = fake centre '
         'hinge line (real fold regions are tier B). '
         f'{sum(len(v) for v in scenes.values())} images.</p>']
for scene in sorted(scenes):
    parts.append(f'<section><h3>{html.escape(scene)}</h3><div>')
    for device, theme, rel in sorted(scenes[scene], key=lambda x: (rank(x[0]), x[1])):
        parts.append(f'<figure><a href="{html.escape(rel)}"><img src="{html.escape(rel)}" loading="lazy"></a>'
                     f'<figcaption>{html.escape(device)} · {html.escape(theme)}</figcaption></figure>')
    parts.append('</div></section>')
(out / 'index.html').write_text('\n'.join(parts) + '\n', encoding='utf-8')
PYINDEX
echo "host review: $(find "$OUT" -name '*.png' | wc -l | tr -d ' ') images in $(( $(date +%s) - start ))s -> $OUT/index.html"
exit "$status"
