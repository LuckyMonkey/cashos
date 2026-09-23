#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
DUMP=${2:-build/journal-dump}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
corrupt="$tmp/corrupt.img"
cp "$IMAGE" "$corrupt"

# The first record checksum begins at LBA 128 * 512 + record offset 16.
printf '\000' | dd of="$corrupt" bs=1 seek=$((128 * 512 + 16)) conv=notrunc status=none
output=$($DUMP "$corrupt")
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q 'RECORD 0000 INVALID'
printf '%s\n' 'PASS: checksum corruption was detected'
