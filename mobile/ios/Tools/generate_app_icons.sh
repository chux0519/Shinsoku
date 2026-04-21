#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios_dir="$(cd "$tool_dir/.." && pwd)"
repo_root="$(cd "$ios_dir/../.." && pwd)"

source_svg="$repo_root/resources/icons/square-bolt.svg"
asset_dir="$ios_dir/App/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$source_svg" ]]; then
  echo "Missing source icon: $source_svg" >&2
  exit 1
fi

command -v qlmanage >/dev/null || {
  echo "qlmanage is required to render the shared SVG into PNG icons." >&2
  exit 1
}
command -v sips >/dev/null || {
  echo "sips is required to resize generated app icons." >&2
  exit 1
}
path_d="$(sed -n 's/.*<path[^>]* d="\([^"]*\)".*/\1/p' "$source_svg" | head -n 1)"
if [[ -z "$path_d" ]]; then
  echo "Could not extract icon path from $source_svg" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

prepared_svg="$tmp_dir/shinsoku-app-icon.svg"
cat >"$prepared_svg" <<SVG
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <rect width="1024" height="1024" fill="#F8FAFC"/>
  <g transform="translate(192 192) scale(26.6666667)">
    <path fill="#020617" d="$path_d"/>
  </g>
</svg>
SVG

qlmanage -t -s 1024 -o "$tmp_dir" "$prepared_svg" >/dev/null 2>&1
source_png="$tmp_dir/$(basename "$prepared_svg").png"
if [[ ! -f "$source_png" ]]; then
  echo "Quick Look did not produce $source_png" >&2
  exit 1
fi

rm -rf "$asset_dir"
mkdir -p "$asset_dir"

make_icon() {
  local size="$1"
  local name="$2"
  local resized="$tmp_dir/$name"
  local flattened="$tmp_dir/$name.jpg"
  local output="$asset_dir/$name"
  sips -z "$size" "$size" "$source_png" --out "$resized" >/dev/null
  sips -s format jpeg "$resized" --out "$flattened" >/dev/null
  sips -s format png "$flattened" --out "$output" >/dev/null
}

make_icon 40 "Icon-App-20x20@2x.png"
make_icon 60 "Icon-App-20x20@3x.png"
make_icon 58 "Icon-App-29x29@2x.png"
make_icon 87 "Icon-App-29x29@3x.png"
make_icon 80 "Icon-App-40x40@2x.png"
make_icon 120 "Icon-App-40x40@3x.png"
make_icon 120 "Icon-App-60x60@2x.png"
make_icon 180 "Icon-App-60x60@3x.png"
make_icon 20 "Icon-App-20x20@1x.png"
make_icon 29 "Icon-App-29x29@1x.png"
make_icon 40 "Icon-App-40x40@1x.png"
make_icon 76 "Icon-App-76x76@1x.png"
make_icon 152 "Icon-App-76x76@2x.png"
make_icon 167 "Icon-App-83.5x83.5@2x.png"
make_icon 1024 "Icon-App-1024x1024@1x.png"

cat >"$asset_dir/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "Icon-App-20x20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-60x60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-60x60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-20x20@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-76x76@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-76x76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-83.5x83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Generated iOS app icons in $asset_dir"
