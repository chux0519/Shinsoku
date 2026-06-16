#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

API_KEY="${APPSTORE_API_KEY:-7FH2PAXHPQ}"
API_ISSUER="${APPSTORE_API_ISSUER:-8cc2abdc-3f44-41e4-89ae-4ec5ec7dbfc3}"

flutter build ipa --release \
  --export-options-plist=ios/ExportOptionsAppStore.plist

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "$IPA_PATH" ]]; then
  echo "No IPA found under build/ios/ipa" >&2
  exit 1
fi

xcrun altool --upload-app \
  --type ios \
  -f "$IPA_PATH" \
  --api-key "$API_KEY" \
  --api-issuer "$API_ISSUER"
