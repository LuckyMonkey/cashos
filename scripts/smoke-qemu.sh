#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
LOG=build/debug.log
rm -f "$LOG"
set +e
timeout 5s qemu-system-i386 -machine pc -m 64M -drive file="$IMAGE",format=raw,if=floppy -boot order=a -display none -no-reboot -no-shutdown -debugcon "file:$LOG" -global isa-debugcon.iobase=0xe9
qemu_status=$?
set -e
if grep -q 'CASHOS_READY' "$LOG" 2>/dev/null; then
    echo 'PASS: CASHOS_READY observed'
    grep -E 'CASHOS|STAGE2|UI_READY|KEY=|ADD_ITEM|TOTAL|SALE_COMPLETE' "$LOG" || true
    exit 0
fi
echo "FAIL: CashOS did not report readiness (qemu status $qemu_status)" >&2
cat "$LOG" 2>/dev/null || true
exit 1

