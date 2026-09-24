#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
PROFILE=${2:-build/profile-tool}
CONFIG=${3:-build/config-tool}
DUMP=${4:-build/journal-dump}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$PROFILE" --input "$IMAGE" --output "$tmp/operator.img" --id 1 --name CHARLIE --role operator >/dev/null
"$CONFIG" --input "$tmp/operator.img" --output "$tmp/printer.img" --printer zpl --baud 9600 >/dev/null

inspect=$("$CONFIG" --inspect "$tmp/printer.img")
printf '%s\n' "$inspect"
printf '%s\n' "$inspect" | grep -q 'CONFIG VALID'
printf '%s\n' "$inspect" | grep -q 'PRINTER: ZPL SERIAL COM1'
printf '%s\n' "$inspect" | grep -q 'BAUD: 9600'

{ sleep 1; printf 'sendkey 1\n'; sleep .2; printf 'sendkey ret\n'; sleep 1; printf 'quit\n'; } |
    timeout 10s qemu-system-i386 -machine pc -m 64M \
    -drive file="$tmp/printer.img",format=raw,if=floppy -boot order=a \
    -display none -monitor stdio -serial "file:$tmp/zpl.out" \
    -debugcon "file:$tmp/debug.log" -global isa-debugcon.iobase=0xe9 >/dev/null 2>&1 || true

grep -q 'CASHOS_READY' "$tmp/debug.log"
grep -q 'CONFIG_OK' "$tmp/debug.log"
grep -q 'SERIAL_COM1_READY' "$tmp/debug.log"
grep -q 'ZPL_PRINT_OK' "$tmp/debug.log"

tr -d '\r' < "$tmp/zpl.out" > "$tmp/zpl.txt"
grep -Fq '^XA' "$tmp/zpl.txt"
grep -Fq '^FDCASHOS^FS' "$tmp/zpl.txt"
grep -Fq '^FDTX 1^FS' "$tmp/zpl.txt"
grep -Fq '^FDEMP 1^FS' "$tmp/zpl.txt"
grep -Fq '^FDTOTAL $3.25^FS' "$tmp/zpl.txt"
grep -Fq '^XZ' "$tmp/zpl.txt"

journal=$("$DUMP" "$tmp/printer.img")
printf '%s\n' "$journal"
printf '%s\n' "$journal" | grep -q 'TX 0001  ITEMS=1  TOTAL=$3.25  VALID  EMP=1'

printf '%s\n' 'PASS: COM1 emitted a complete ZPL transaction label and sale remained journaled'
