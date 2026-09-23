#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
DUMP=${2:-build/journal-dump}

run_transaction() {
    log=$1
    { sleep 1; printf 'sendkey 1\n'; sleep .2; printf 'sendkey ret\n'; sleep 1; printf 'quit\n'; } |
        timeout 10s qemu-system-i386 -machine pc -m 64M \
        -drive file="$IMAGE",format=raw,if=floppy -boot order=a \
        -display none -monitor stdio -debugcon "file:$log" \
        -global isa-debugcon.iobase=0xe9 >/dev/null 2>&1 || true
}

run_transaction build/journal-run1.log
first=$($DUMP "$IMAGE")
printf '%s\n' "$first"
printf '%s\n' "$first" | grep -q 'TX 0001  ITEMS=1  TOTAL=$3.25  VALID'

run_transaction build/journal-run2.log
second=$($DUMP "$IMAGE")
printf '%s\n' "$second"
printf '%s\n' "$second" | grep -q 'TX 0001  ITEMS=1  TOTAL=$3.25  VALID'
printf '%s\n' "$second" | grep -q 'TX 0002  ITEMS=1  TOTAL=$3.25  VALID'
printf '%s\n' 'PASS: two transactions survived a QEMU shutdown and reboot'
