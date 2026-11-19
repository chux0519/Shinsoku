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
  BAILIAN_OPENAI_MODEL \
  BAILIAN_OPENAI_ASR_MODEL \
  BAILIAN_REALTIME_URL \
  BAILIAN_REALTIME_MODEL \
  SONIOX_MODEL; do
  # R04: no API key may be compiled into the app; users enter keys in Settings.
  if [[ "$name" == *_API_KEY ]]; then
    echo "Refusing to pass $name as a dart-define (keys must not be in the app binary)." >&2
    exit 1
  fi
  if [[ -n "${!name:-}" ]]; then
    DART_DEFINES+=("--dart-define=$name=${!name}")
  fi
done

KEY_PATH="${APPSTORE_API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY}.p8}"
ARCHIVE="build/ios/archive/Runner.xcarchive"
EXPORT_DIR="build/ios/ipa"

# Generate Flutter's xcconfig (build name/number, dart-defines) without signing, then archive with
# xcodebuild so automatic signing may create a development profile that carries the App Group.
flutter build ios --release --config-only "${DART_DEFINES[@]}"

rm -rf "${ARCHIVE:?}" "${EXPORT_DIR:?}"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$API_KEY" -authenticationKeyIssuerID "$API_ISSUER" \
  archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ios/ExportOptionsAppStore.plist

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "$IPA_PATH" ]]; then
  echo "No IPA found under $EXPORT_DIR" >&2
  exit 1
fi

xcrun altool --upload-app \
  --type ios \
  -f "$IPA_PATH" \
  --api-key "$API_KEY" \
  --api-issuer "$API_ISSUER"
