#!/bin/sh
set -eu

site=$1
v86_version=0.5.462
v86_commit=5f9a90f2be01243dd0ea4fe014cce12686cf3ced
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$site/v86" "$site/bios"
npm pack "v86@$v86_version" --pack-destination "$tmp" >/dev/null
tar -xzf "$tmp/v86-$v86_version.tgz" -C "$tmp"
cp "$tmp/package/build/libv86.js" "$site/v86/libv86.js"
cp "$tmp/package/build/v86.wasm" "$site/v86/v86.wasm"
cp "$tmp/package/LICENSE" "$site/v86/LICENSE"

curl --fail --location --silent --show-error --retry 3 \
    "https://raw.githubusercontent.com/copy/v86/$v86_commit/bios/seabios.bin" \
    -o "$site/bios/seabios.bin"
curl --fail --location --silent --show-error --retry 3 \
    "https://raw.githubusercontent.com/copy/v86/$v86_commit/bios/vgabios.bin" \
    -o "$site/bios/vgabios.bin"
curl --fail --location --silent --show-error --retry 3 \
    "https://raw.githubusercontent.com/copy/v86/$v86_commit/bios/COPYING.LESSER" \
    -o "$site/bios/COPYING.LESSER"

test -s "$site/v86/libv86.js"
test -s "$site/v86/v86.wasm"
test -s "$site/bios/seabios.bin"
test -s "$site/bios/vgabios.bin"
echo "prepared v86 $v86_version and BIOS commit $v86_commit"
