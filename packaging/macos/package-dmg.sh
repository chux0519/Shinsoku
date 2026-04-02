#!/bin/zsh

set -euo pipefail

APP_NAME=""
VERSION=""
CONFIG=""
EXECUTABLE_PATH=""
MACDEPLOYQT_PATH=""
PLIST_PATH=""
ENTITLEMENTS_PATH=""
ICON_SVG_PATH=""
OUTPUT_DIR=""
CODESIGN_IDENTITY="${SHINSOKU_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${SHINSOKU_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${SHINSOKU_NOTARY_KEYCHAIN:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --executable)
            EXECUTABLE_PATH="$2"
            shift 2
            ;;
        --macdeployqt)
            MACDEPLOYQT_PATH="$2"
            shift 2
            ;;
        --plist)
            PLIST_PATH="$2"
            shift 2
            ;;
        --entitlements)
            ENTITLEMENTS_PATH="$2"
            shift 2
            ;;
        --icon-svg)
            ICON_SVG_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --codesign-identity)
            CODESIGN_IDENTITY="$2"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --notary-keychain)
            NOTARY_KEYCHAIN="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$APP_NAME" || -z "$VERSION" || -z "$CONFIG" || -z "$EXECUTABLE_PATH" || -z "$MACDEPLOYQT_PATH" || -z "$PLIST_PATH" || -z "$OUTPUT_DIR" ]]; then
    echo "Missing required arguments." >&2
    exit 1
fi

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Executable not found: $EXECUTABLE_PATH" >&2
    exit 1
fi

if [[ ! -x "$MACDEPLOYQT_PATH" ]]; then
    echo "macdeployqt not found: $MACDEPLOYQT_PATH" >&2
    exit 1
fi

if [[ ! -f "$PLIST_PATH" ]]; then
    echo "Info.plist template not found: $PLIST_PATH" >&2
    exit 1
fi

if [[ -n "$ENTITLEMENTS_PATH" && ! -f "$ENTITLEMENTS_PATH" ]]; then
    echo "Entitlements file not found: $ENTITLEMENTS_PATH" >&2
    exit 1
fi

if [[ -n "$NOTARY_PROFILE" && -z "$CODESIGN_IDENTITY" ]]; then
    echo "Notarization requires a Developer ID signing identity." >&2
    exit 1
fi

if [[ "${CONFIG:l}" != "release" ]]; then
    echo "package_macos_dmg is intended for a Release-configured build tree. Current config: $CONFIG" >&2
    exit 1
fi

PACKAGE_ROOT_NAME="${APP_NAME}-${VERSION}-macos-arm64"
STAGE_ROOT="${OUTPUT_DIR}/stage-${CONFIG:l}"
APP_BUNDLE_PATH="${STAGE_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
DMG_ROOT="${STAGE_ROOT}/dmg-root"
DMG_PATH="${OUTPUT_DIR}/${PACKAGE_ROOT_NAME}.dmg"

rm -rf "$STAGE_ROOT"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_ROOT"
mkdir -p "$OUTPUT_DIR"

cp "$EXECUTABLE_PATH" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "$PLIST_PATH" "${CONTENTS_DIR}/Info.plist"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

if [[ -n "$ICON_SVG_PATH" && -f "$ICON_SVG_PATH" ]] && command -v qlmanage >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
    ICON_TMP_DIR="$(mktemp -d)"
    ICONSET_DIR="${ICON_TMP_DIR}/Shinsoku.iconset"
    mkdir -p "$ICONSET_DIR"

    qlmanage -t -s 1024 -o "$ICON_TMP_DIR" "$ICON_SVG_PATH" >/dev/null 2>&1 || true
    RENDERED_ICON="$(find "$ICON_TMP_DIR" -maxdepth 1 -type f | head -n 1 || true)"

    if [[ -n "$RENDERED_ICON" && -f "$RENDERED_ICON" ]]; then
        for size in 16 32 128 256 512; do
            sips -z "$size" "$size" "$RENDERED_ICON" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
            double_size=$((size * 2))
            sips -z "$double_size" "$double_size" "$RENDERED_ICON" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null
        done
        iconutil -c icns "$ICONSET_DIR" -o "${RESOURCES_DIR}/Shinsoku.icns"
    fi

    rm -rf "$ICON_TMP_DIR"
fi

deploy_args=("$APP_BUNDLE_PATH" -always-overwrite -verbose=2)
if [[ -n "$CODESIGN_IDENTITY" ]]; then
    deploy_args+=("-codesign=$CODESIGN_IDENTITY" -hardened-runtime -timestamp)
fi
"$MACDEPLOYQT_PATH" "${deploy_args[@]}"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
    executable_codesign_args=(--force --options runtime --timestamp --sign "$CODESIGN_IDENTITY")
    if [[ -n "$ENTITLEMENTS_PATH" ]]; then
        executable_codesign_args+=(--entitlements "$ENTITLEMENTS_PATH")
    fi
    codesign "${executable_codesign_args[@]}" "${MACOS_DIR}/${APP_NAME}"
    codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE_PATH"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"
fi

cp -R "$APP_BUNDLE_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null

if [[ -n "$NOTARY_PROFILE" ]]; then
    notary_args=(submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait)
    if [[ -n "$NOTARY_KEYCHAIN" ]]; then
        notary_args+=(--keychain "$NOTARY_KEYCHAIN")
    fi
    xcrun notarytool "${notary_args[@]}"
    xcrun stapler staple -v "$DMG_PATH"
fi

echo "macOS package created:"
echo "  $DMG_PATH"
