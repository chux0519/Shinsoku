#!/usr/bin/env bash

set -euo pipefail

APP_NAME=""
VERSION=""
EXECUTABLE_PATH=""
OUTPUT_DIR=""
LINUXDEPLOY_PATH=""
LINUXDEPLOY_PLUGIN_QT_PATH=""
DESKTOP_TEMPLATE=""
ICON_SVG_PATH=""
QT_QMAKE_PATH="${QMAKE:-}"
TRIPLET="${VCPKG_DEFAULT_TRIPLET:-x64-linux}"
VCPKG_INSTALLED_DIR="${VCPKG_INSTALLED_DIR:-}"

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
        --executable)
            EXECUTABLE_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --linuxdeploy)
            LINUXDEPLOY_PATH="$2"
            shift 2
            ;;
        --linuxdeploy-plugin-qt)
            LINUXDEPLOY_PLUGIN_QT_PATH="$2"
            shift 2
            ;;
        --desktop-template)
            DESKTOP_TEMPLATE="$2"
            shift 2
            ;;
        --icon-svg)
            ICON_SVG_PATH="$2"
            shift 2
            ;;
        --qmake)
            QT_QMAKE_PATH="$2"
            shift 2
            ;;
        --triplet)
            TRIPLET="$2"
            shift 2
            ;;
        --vcpkg-installed-dir)
            VCPKG_INSTALLED_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$APP_NAME" || -z "$VERSION" || -z "$EXECUTABLE_PATH" || -z "$OUTPUT_DIR" || -z "$LINUXDEPLOY_PATH" || -z "$LINUXDEPLOY_PLUGIN_QT_PATH" || -z "$DESKTOP_TEMPLATE" || -z "$ICON_SVG_PATH" ]]; then
    echo "Missing required arguments." >&2
    exit 1
fi

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Executable not found: $EXECUTABLE_PATH" >&2
    exit 1
fi

if [[ ! -x "$LINUXDEPLOY_PATH" ]]; then
    echo "linuxdeploy not executable: $LINUXDEPLOY_PATH" >&2
    exit 1
fi

if [[ ! -x "$LINUXDEPLOY_PLUGIN_QT_PATH" ]]; then
    echo "linuxdeploy Qt plugin not executable: $LINUXDEPLOY_PLUGIN_QT_PATH" >&2
    exit 1
fi

if [[ ! -f "$DESKTOP_TEMPLATE" ]]; then
    echo "Desktop template not found: $DESKTOP_TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$ICON_SVG_PATH" ]]; then
    echo "Icon SVG not found: $ICON_SVG_PATH" >&2
    exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert is required to render the AppImage icon." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/shinsoku-appimage.XXXXXX")"
APPDIR="$STAGE_ROOT/AppDir"
BIN_DIR="$APPDIR/usr/bin"
SHARE_DIR="$APPDIR/usr/share"
APP_SHARE_DIR="$SHARE_DIR/applications"
ICON_DIR="$SHARE_DIR/icons/hicolor/256x256/apps"
DESKTOP_FILE="$APP_SHARE_DIR/shinsoku.desktop"
ICON_PNG="$ICON_DIR/shinsoku.png"
OUTPUT_APPIMAGE="$OUTPUT_DIR/${APP_NAME}-${VERSION}-linux-x86_64.AppImage"

cleanup() {
    rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$APP_SHARE_DIR" "$ICON_DIR"
cp "$EXECUTABLE_PATH" "$BIN_DIR/shinsoku"
chmod +x "$BIN_DIR/shinsoku"
sed "s/@APP_NAME@/${APP_NAME}/g" "$DESKTOP_TEMPLATE" > "$DESKTOP_FILE"
rsvg-convert "$ICON_SVG_PATH" -w 256 -h 256 -o "$ICON_PNG"

PLUGIN_DIR="$STAGE_ROOT/plugins"
mkdir -p "$PLUGIN_DIR"
ln -sf "$LINUXDEPLOY_PLUGIN_QT_PATH" "$PLUGIN_DIR/linuxdeploy-plugin-qt"

export PATH="$PLUGIN_DIR:$PATH"
export QMAKE="$QT_QMAKE_PATH"
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_APPSTREAM=1
export EXTRA_QT_MODULES="core;gui;widgets;svg"
export EXTRA_PLATFORM_PLUGINS="libqwayland-egl.so;libqwayland-generic.so;libqxcb.so"
if [[ -n "$QT_QMAKE_PATH" ]]; then
    QT_INSTALL_PLUGINS="$("$QT_QMAKE_PATH" -query QT_INSTALL_PLUGINS 2>/dev/null || true)"
    QT_INSTALL_QML="$("$QT_QMAKE_PATH" -query QT_INSTALL_QML 2>/dev/null || true)"
    if [[ -n "$QT_INSTALL_PLUGINS" ]]; then
        export QT_PLUGIN_PATH="$QT_INSTALL_PLUGINS"
    fi
    if [[ -n "$QT_INSTALL_QML" ]]; then
        export QML2_IMPORT_PATH="$QT_INSTALL_QML"
    fi
fi
if [[ -n "$VCPKG_INSTALLED_DIR" ]]; then
    export LD_LIBRARY_PATH="${VCPKG_INSTALLED_DIR}/${TRIPLET}/lib:${LD_LIBRARY_PATH:-}"
fi

pushd "$STAGE_ROOT" >/dev/null
"$LINUXDEPLOY_PATH" \
    --appdir "$APPDIR" \
    -e "$BIN_DIR/shinsoku" \
    -d "$DESKTOP_FILE" \
    -i "$ICON_PNG" \
    --plugin qt \
    --output appimage
popd >/dev/null

GENERATED_APPIMAGE="$(find "$STAGE_ROOT" -maxdepth 1 -name '*.AppImage' | head -n 1)"
if [[ -z "$GENERATED_APPIMAGE" ]]; then
    echo "linuxdeploy did not produce an AppImage." >&2
    exit 1
fi

mv "$GENERATED_APPIMAGE" "$OUTPUT_APPIMAGE"
chmod +x "$OUTPUT_APPIMAGE"

echo "Linux package created:"
echo "  $OUTPUT_APPIMAGE"
