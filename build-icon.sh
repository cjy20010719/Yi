#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
icon_work=$(mktemp -d "${TMPDIR:-/tmp}/yi-icon.XXXXXX")
trap 'rm -rf "$icon_work"' EXIT
mkdir -p "$icon_work/AppIcon.iconset"
cp Assets/Yi.png "$icon_work/source.png"
for points in 16 32 128 256 512; do
    sips -z "$points" "$points" "$icon_work/source.png" --out "$icon_work/AppIcon.iconset/icon_${points}x${points}.png" >/dev/null
    pixels=$((points * 2))
    sips -z "$pixels" "$pixels" "$icon_work/source.png" --out "$icon_work/AppIcon.iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns "$icon_work/AppIcon.iconset" -o Assets/AppIcon.icns
clang -fobjc-arc tools/build-menu-icon.m -framework Cocoa -o "$icon_work/build-menu-icon"
"$icon_work/build-menu-icon"
