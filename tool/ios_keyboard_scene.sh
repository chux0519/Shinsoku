#!/usr/bin/env bash
# Tier-B keyboard scene (ios-ui-01 U2). Coordinator only: runs on a shared simulator that is ALREADY booted;
# this script never boots, creates or shuts down simulators.
#
#   tool/ios_keyboard_scene.sh <UDID> <out-dir under build/>   # build, run light + dark, export PHASE PNGs
#   tool/ios_keyboard_scene.sh --build-only                     # build-for-testing, generic simulator
#
# Xcode: the default Xcode 26.0.1 cannot drive iOS 27 simulators (the test runner hangs; DTServiceHub bless
# failure). For the shared iOS 27.x simulators run the script under Xcode 27.2, for this command only:
#   bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh <UDID> <out-dir>
# The shared simulators run in Chinese; the scene launches Settings/Safari in English and also matches Chinese
# labels. Never change the simulator's language.
#
# Run from a shell where `proxy_on; nvm use --lts` was done (flutter may fetch packages).
# Output: <out-dir>/{light,dark}/PHASE-xx-<name>.png (+ FAIL-<step>.png and FAIL-<step>.txt, the element
# tree of the foreground app, where a run stopped), <look>.xcresult, <look>.log, <look>-scene.txt
# (the SCENE lines: phases and any paste banner seen).
# <look>-keyboard.log: the extension's os_log (subsystem net.potafree.shinsoku.keyboard, last 5 min).
# Signing: ad-hoc for the simulator by default (app, keyboard extension and test runner), so the extension
# registers. Override with SCENE_SIGN_ARGS, e.g. SCENE_SIGN_ARGS='CODE_SIGNING_ALLOWED=NO'.
# App Group: app and extension must carry group.net.potafree.shinsoku (ad-hoc signing keeps
# CODE_SIGN_ENTITLEMENTS); checked on the built and the installed bundles.
# Install: xcodebuild test does not install the host app here, so the script installs the built Runner.app
# (checked to contain PlugIns/ShinsokuKeyboard.appex) with simctl before the runs and prints the pluginkit
# registration of net.potafree.shinsoku.keyboard.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MOBILE="$ROOT/mobile"
DD="$ROOT/build/ios-keyboard-scene/DerivedData"
DEFAULT_SIGN_ARGS="CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER="
read -r -a SIGN_ARGS <<<"${SCENE_SIGN_ARGS:-$DEFAULT_SIGN_ARGS}"
KEYBOARD_ID=net.potafree.shinsoku.keyboard

usage() {
  echo "usage: $0 <UDID> <out-dir under build/> | $0 --build-only" >&2
  exit 2
}

BUILD_ONLY=0
UDID=""
OUT=""
if [[ ${1:-} == --build-only ]]; then
  BUILD_ONLY=1
  DEST="generic/platform=iOS Simulator"
else
  [[ $# -eq 2 ]] || usage
  UDID=$1
  case "$2" in
    build/*) OUT="$ROOT/$2" ;;
    *) echo "out-dir must be a relative path under build/" >&2; exit 2 ;;
  esac
  if ! xcrun simctl list devices booted | grep -q "$UDID"; then
    echo "simulator $UDID is not booted; boot it first (this script never boots one)" >&2
    exit 2
  fi
  DEST="id=$UDID"
fi

cd "$ROOT"

# Flutter regenerates tracked files (SwiftPM migration in the pbxproj/scheme, lockfiles, plists).
# Restore every tracked file under mobile/ that was clean before and is modified after.
DIRTY_BEFORE=$(git diff --name-only HEAD -- mobile | sort)
ORIGINAL_LOOK=""
cleanup() {
  local now churn
  now=$(git diff --name-only HEAD -- mobile | sort)
  churn=$(comm -13 <(printf '%s\n' "$DIRTY_BEFORE") <(printf '%s\n' "$now") | sed '/^$/d' || true)
  if [[ -n $churn ]]; then
    echo "Restoring generated changes:"
    printf '  %s\n' $churn
    printf '%s\n' "$churn" | xargs git checkout HEAD --
  fi
  if [[ -n $ORIGINAL_LOOK && -n $UDID ]]; then
    xcrun simctl ui "$UDID" appearance "$ORIGINAL_LOOK" || true
  fi
}
trap cleanup EXIT

echo "== flutter config (SwiftPM / pods)"
(cd "$MOBILE" && nice -n 10 flutter build ios --simulator --debug --config-only)

XCB=(xcodebuild -workspace "$MOBILE/ios/Runner.xcworkspace" -scheme Runner -configuration Debug
  -sdk iphonesimulator -derivedDataPath "$DD" "${SIGN_ARGS[@]}")

echo "== build-for-testing ($DEST)"
mkdir -p "$(dirname "$DD")"
BUILD_LOG="$(dirname "$DD")/build-for-testing.log"
if ! nice -n 10 "${XCB[@]}" -destination "$DEST" build-for-testing >"$BUILD_LOG" 2>&1; then
  grep -E "error:" "$BUILD_LOG" | sort -u | head -20 >&2 || true
  echo "build-for-testing failed; full log: $BUILD_LOG" >&2
  exit 1
fi
grep -E "warning: .*(ShinsokuKeyboard|KeyboardSceneTests)/" "$BUILD_LOG" | sort -u || true
grep -E "\*\* TEST BUILD" "$BUILD_LOG" || true

APP="$DD/Build/Products/Debug-iphonesimulator/Runner.app"
APPEX="$APP/PlugIns/ShinsokuKeyboard.appex"
if [[ ! -d $APPEX ]]; then
  echo "missing $APPEX (Runner.app built without the keyboard extension)" >&2
  exit 1
fi
# App Groups of a bundle. Simulator builds carry entitlements in the binary's __TEXT,__entitlements
# section (Entitlements-Simulated.plist), not in the code signature; read that, else the signature.
app_groups() {
  local bin
  bin="$1/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$1/Info.plist")"
  python3 -I - "$bin" <<'PY'
import plistlib, subprocess, sys
binary = sys.argv[1]
def from_section():
    for arch in ("arm64", "x86_64"):
        out = subprocess.run(["otool", "-arch", arch, "-X", "-s", "__TEXT", "__entitlements", binary],
                             capture_output=True, text=True).stdout
        raw = b""
        for line in out.splitlines():
            parts = line.split("\t", 1)
            if len(parts) == 2:
                # x86_64 prints single bytes; arm64 prints little-endian 32-bit words.
                for token in parts[1].split():
                    raw += bytes.fromhex(token) if len(token) == 2 else bytes.fromhex(token)[::-1]
        if raw:
            return raw
    return None
def from_signature():
    out = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", binary], capture_output=True).stdout
    return out or None
for source, raw in (("simulated", from_section()), ("signature", from_signature())):
    if not raw:
        continue
    try:
        groups = plistlib.loads(raw.rstrip(b"\0")).get("com.apple.security.application-groups")
    except Exception:
        continue
    if groups:
        print(f"{', '.join(groups)} ({source})")
        break
PY
}

# Prints signature + App Group entitlement of the app and its keyboard extension; fails if a group is missing.
check_signing() {
  local app=$1 label=$2 bundle groups missing=0
  echo "== signatures and App Group ($label)"
  for bundle in "$app" "$app/PlugIns/ShinsokuKeyboard.appex"; do
    printf '  %s: ' "$(basename "$bundle")"
    codesign -dv "$bundle" 2>&1 | grep -E "^Signature=|^Authority=" | head -1 || echo "unsigned"
    groups=$(app_groups "$bundle")
    echo "    application-groups: ${groups:-none}"
    [[ $groups == *group.net.potafree.shinsoku* ]] || missing=1
  done
  if [[ $missing -ne 0 ]]; then
    echo "App Group entitlement missing ($label); the keyboard cannot read the latest text" >&2
    exit 1
  fi
}
check_signing "$APP" "built"
[[ $BUILD_ONLY -eq 1 ]] && exit 0

export_phases() {
  local result=$1 dest=$2 tmp
  tmp=$(mktemp -d)
  mkdir -p "$dest"
  xcrun xcresulttool export attachments --path "$result" --output-path "$tmp" >/dev/null
  python3 -I - "$tmp" "$dest" <<'PY'
import json, os, re, shutil, sys
src, dst = sys.argv[1:3]
manifest = json.load(open(os.path.join(src, "manifest.json")))
count = 0
for test in manifest:
    attachments = test.get("attachments", [])
    if isinstance(attachments, dict):
        attachments = [attachments]
    for a in attachments:
        m = re.match(r"((?:PHASE-\d+|FAIL)-[A-Za-z0-9-]+)", a.get("suggestedHumanReadableName", ""))
        if m:
            ext = os.path.splitext(a["exportedFileName"])[1] or ".png"
            shutil.copyfile(os.path.join(src, a["exportedFileName"]), os.path.join(dst, m.group(1) + ext))
            count += 1
print(f"  {count} attachments -> {dst}")
PY
  rm -rf "${tmp:?}"
}

echo "== install Runner.app on $UDID"
xcrun simctl install "$UDID" "$APP"
check_signing "$(xcrun simctl get_app_container "$UDID" net.potafree.shinsoku app)" "installed"
echo "== keyboard extension registration"
xcrun simctl spawn "$UDID" pluginkit -m -v -i "$KEYBOARD_ID" 2>&1 || echo "  (pluginkit query failed)"
xcrun simctl listapps "$UDID" 2>/dev/null | grep -E "CFBundleIdentifier = \"?net\.potafree\.shinsoku" | sort -u || true

mkdir -p "$OUT"
ORIGINAL_LOOK=$(xcrun simctl ui "$UDID" appearance 2>/dev/null || echo "")
STATUS=0
for look in light dark; do
  echo "== scene ($look)"
  xcrun simctl ui "$UDID" appearance "$look"
  RESULT="$OUT/$look.xcresult"
  if [[ -e $RESULT ]]; then rm -rf "${RESULT:?}"; fi
  if ! nice -n 10 "${XCB[@]}" -destination "$DEST" -only-testing:KeyboardSceneTests \
      -resultBundlePath "$RESULT" test-without-building >"$OUT/$look.log" 2>&1; then
    echo "  scene failed ($look); see $OUT/$look.log" >&2
    STATUS=1
  fi
  grep "SCENE " "$OUT/$look.log" >"$OUT/$look-scene.txt" || true
  xcrun simctl spawn "$UDID" log show --last 5m --info --debug --style compact \
    --predicate 'subsystem == "net.potafree.shinsoku.keyboard"' >"$OUT/$look-keyboard.log" 2>&1 || true
  echo "  keyboard log: $(grep -c "insert tap" "$OUT/$look-keyboard.log" || true) insert-tap lines -> $OUT/$look-keyboard.log"
  cat "$OUT/$look-scene.txt"
  if [[ -d $RESULT ]]; then
    export_phases "$RESULT" "$OUT/$look"
  fi
done
exit $STATUS
