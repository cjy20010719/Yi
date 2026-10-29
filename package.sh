#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
zsh build.sh
app_path="$PWD/dist/翻译一下.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
release_dir="$PWD/dist/releases"
mkdir -p "$release_dir"
package_stage=$(mktemp -d "$PWD/dist/yi-package.XXXXXX")
trap 'rm -rf -- "$package_stage"' EXIT
ditto "$app_path" "$package_stage/翻译一下.app"
ln -s /Applications "$package_stage/Applications"
cp docs/安装说明.txt "$package_stage/安装说明.txt"
cp Assets/AppIcon.icns "$package_stage/.VolumeIcon.icns"
xcrun SetFile -a C "$package_stage"
codesign --verify --deep --strict "$package_stage/翻译一下.app"
lipo "$package_stage/翻译一下.app/Contents/MacOS/翻译一下" -verify_arch arm64 x86_64
dmg_name="Yi-${version}-universal.dmg"
zip_name="Yi-${version}-universal.zip"
hdiutil create -volname 翻译一下 -srcfolder "$package_stage" -ov -format UDZO "$release_dir/$dmg_name"
hdiutil verify "$release_dir/$dmg_name"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$release_dir/$zip_name"
cp docs/安装说明.txt "$release_dir/INSTALL.zh-CN.txt"
(
  cd "$release_dir"
  env LC_ALL=C shasum -a 256 "$dmg_name" "$zip_name" INSTALL.zh-CN.txt > SHA256SUMS.txt
)
python3 scripts/verify-release.py
print "Packages: $release_dir"
