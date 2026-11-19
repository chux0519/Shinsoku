#!/bin/sh
# Compiles KeyboardProfileResolver.swift + Runner/ProfileGroup.swift with the checks and runs them on the Mac.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
ios=$(cd "$here/../.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "${out:?}"' EXIT
xcrun swiftc -o "$out/checks" "$here/main.swift" "$ios/ShinsokuKeyboard/KeyboardProfileResolver.swift" \
  "$ios/Runner/ProfileGroup.swift"
"$out/checks"
