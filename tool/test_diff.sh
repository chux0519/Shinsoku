#!/bin/bash
# Only new failures count. Runs the test command, extracts failing test names with FAIL_PATTERN,
# and compares them with the baseline file (one name per line, committed).
#   tool/test_diff.sh                 compare
#   tool/test_diff.sh --update        rewrite the baseline (only on a reviewed main)
# Configure: TEST_CMD (default: flutter test in mobile/), FAIL_PATTERN (extended regex whose first capture group is the
# test name), BASELINE (default: tool/test_baseline.txt).
set -uo pipefail
cd "$(dirname "$0")/.."
TEST_CMD=${TEST_CMD:-cd mobile && flutter test --reporter expanded}
FAIL_PATTERN=${FAIL_PATTERN:-'^[0-9:]+ \+[0-9]+.*-[0-9]+: (.*) \[E\]$'}
BASELINE=${BASELINE:-tool/test_baseline.txt}
LOG=$(mktemp); NOW=$(mktemp)
bash -c "$TEST_CMD" > "$LOG" 2>&1
sed -nE "s/${FAIL_PATTERN}/\1/p" "$LOG" | sort -u > "$NOW"
if [ "${1:-}" = "--update" ]; then cp "$NOW" "$BASELINE"; echo "baseline: $(wc -l < "$BASELINE") failure(s)"; exit 0; fi
touch "$BASELINE"
NEW=$(comm -13 "$BASELINE" "$NOW"); FIXED=$(comm -23 "$BASELINE" "$NOW")
[ -n "$FIXED" ] && { echo "now passing (update the baseline):"; echo "$FIXED" | sed 's/^/  /'; }
if [ -n "$NEW" ]; then
  echo "NEW failures:"; echo "$NEW" | sed 's/^/  /'
  echo "Wall-clock benchmarks: rerun alone before counting them (explain the number)."
  exit 1
fi
echo "no new failures ($(wc -l < "$NOW") known)"
