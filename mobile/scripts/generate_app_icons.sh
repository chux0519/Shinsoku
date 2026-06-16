#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$mobile_dir/.." && pwd)"

source_svg="$repo_root/resources/icons/square-bolt.svg"
ios_icon_dir="$mobile_dir/ios/Runner/Assets.xcassets/AppIcon.appiconset"
android_res_dir="$mobile_dir/android/app/src/main/res"
flutter_asset_dir="$mobile_dir/assets"

if [[ ! -f "$source_svg" ]]; then
  echo "Missing source icon: $source_svg" >&2
  exit 1
fi

command -v qlmanage >/dev/null || {
  echo "qlmanage is required to render app icons." >&2
  exit 1
}
command -v sips >/dev/null || {
  echo "sips is required to resize app icons." >&2
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

make_png() {
  local size="$1"
  local output="$2"
  local resized="$tmp_dir/$(basename "$output")"
  local flattened="$tmp_dir/$(basename "$output").jpg"
  mkdir -p "$(dirname "$output")"
  sips -z "$size" "$size" "$source_png" --out "$resized" >/dev/null
  sips -s format jpeg "$resized" --out "$flattened" >/dev/null
  sips -s format png "$flattened" --out "$output" >/dev/null
}

rm -rf "$ios_icon_dir"
mkdir -p "$ios_icon_dir"

make_png 40 "$ios_icon_dir/Icon-App-20x20@2x.png"
make_png 60 "$ios_icon_dir/Icon-App-20x20@3x.png"
make_png 58 "$ios_icon_dir/Icon-App-29x29@2x.png"
make_png 87 "$ios_icon_dir/Icon-App-29x29@3x.png"
make_png 80 "$ios_icon_dir/Icon-App-40x40@2x.png"
make_png 120 "$ios_icon_dir/Icon-App-40x40@3x.png"
make_png 120 "$ios_icon_dir/Icon-App-60x60@2x.png"
make_png 180 "$ios_icon_dir/Icon-App-60x60@3x.png"
make_png 20 "$ios_icon_dir/Icon-App-20x20@1x.png"
make_png 29 "$ios_icon_dir/Icon-App-29x29@1x.png"
make_png 40 "$ios_icon_dir/Icon-App-40x40@1x.png"
make_png 76 "$ios_icon_dir/Icon-App-76x76@1x.png"
make_png 152 "$ios_icon_dir/Icon-App-76x76@2x.png"
make_png 167 "$ios_icon_dir/Icon-App-83.5x83.5@2x.png"
make_png 1024 "$ios_icon_dir/Icon-App-1024x1024@1x.png"

cat >"$ios_icon_dir/Contents.json" <<'JSON'
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

make_png 48 "$android_res_dir/mipmap-mdpi/ic_launcher.png"
make_png 72 "$android_res_dir/mipmap-hdpi/ic_launcher.png"
make_png 96 "$android_res_dir/mipmap-xhdpi/ic_launcher.png"
make_png 144 "$android_res_dir/mipmap-xxhdpi/ic_launcher.png"
make_png 192 "$android_res_dir/mipmap-xxxhdpi/ic_launcher.png"
make_png 256 "$flutter_asset_dir/app-icon.png"

echo "Generated mobile app icons from $source_svg"
