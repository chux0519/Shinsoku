#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f ../.env ]]; then
  set -a
  # shellcheck source=/dev/null
  source ../.env
  set +a
fi

API_KEY="${APPSTORE_API_KEY:-7FH2PAXHPQ}"
API_ISSUER="${APPSTORE_API_ISSUER:-8cc2abdc-3f44-41e4-89ae-4ec5ec7dbfc3}"

DART_DEFINES=()
for name in \
  BAILIAN_API_BASE \
  BAILIAN_API_KEY \
  BAILIAN_OPENAI_MODEL \
  BAILIAN_OPENAI_ASR_MODEL \
  BAILIAN_REALTIME_URL \
  BAILIAN_REALTIME_MODEL \
  SONIOX_API_KEY \
  SONIOX_MODEL; do
  if [[ -n "${!name:-}" ]]; then
    DART_DEFINES+=("--dart-define=$name=${!name}")
  fi
done

flutter build ipa --release \
  "${DART_DEFINES[@]}" \
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
