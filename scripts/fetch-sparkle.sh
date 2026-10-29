#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
version=2.10.1
expected=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
if [[ -f Vendor/Sparkle/.yi-version ]] && [[ "$(<Vendor/Sparkle/.yi-version)" == "$version" ]]; then exit 0; fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/yi-sparkle.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
curl --noproxy '*' -fLsS --retry 2 "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$stage/Sparkle.tar.xz"
actual=$(env LC_ALL=C shasum -a 256 "$stage/Sparkle.tar.xz")
[[ "${actual%% *}" == "$expected" ]] || { print -u2 'Sparkle archive checksum mismatch'; exit 1; }
mkdir -p Vendor/Sparkle
env LC_ALL=C tar -xJf "$stage/Sparkle.tar.xz" -C Vendor/Sparkle
print -r -- "$version" > Vendor/Sparkle/.yi-version
