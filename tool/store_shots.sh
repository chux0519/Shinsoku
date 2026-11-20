#!/bin/bash
# App Store screenshots, step 1 (release-01 R3): host-render the store scenes for each locale.
#   tool/store_shots.sh [locale,…] [theme,…]     # default: all 10 store locales, light
# One flutter test process per locale (the UI font is loaded once per process). Output:
# build/store/raw/<locale>/NN-<scene>-<theme>.png (+ .json). Then: tool/store_frames.py.
set -euo pipefail
cd "$(dirname "$0")/.."
ALL="en-US zh-Hans zh-Hant ja ko de-DE fr-FR es-ES pt-BR it"
LOCALES=${1:-}
LOCALES=${LOCALES//,/ }
LOCALES=${LOCALES:-$ALL}
THEMES=${2:-light}
OUT="$PWD/build/store/raw"
mkdir -p "$OUT"
start=$(date +%s)
status=0
for loc in $LOCALES; do
  case " $ALL " in *" $loc "*) ;; *) echo "unknown store locale: $loc" >&2; exit 2 ;; esac
  D="$OUT/$loc"
  if [ -d "$D" ]; then find "$D" -name '*.png' -delete; find "$D" -name '*.json' -delete; fi
  mkdir -p "$D"
  if (cd mobile && SHINSOKU_STORE_SHOTS=1 SHINSOKU_STORE_OUT="$OUT" SHINSOKU_STORE_LOCALE="$loc" \
      SHINSOKU_STORE_THEMES="$THEMES" nice -n 10 flutter test --no-pub test/host_review/store_test.dart) \
      >"$D/run.log" 2>&1; then
    echo "$loc: $(find "$D" -name '*.png' | wc -l | tr -d ' ') images"
  else
    status=1
    echo "$loc: FAILED (see $D/run.log)" >&2
    tail -5 "$D/run.log" >&2
  fi
  grep "CLIPPED" "$D/run.log" | sed 's/^/  /' || true
done
echo "store renders in $(( $(date +%s) - start ))s -> $OUT"
exit $status
