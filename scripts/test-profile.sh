#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
TOOL=${2:-build/profile-tool}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

run_boot() {
    image=$1
    log=$2
    rm -f "$log"
    set +e
    timeout 5s qemu-system-i386 -machine pc -m 64M \
        -drive file="$image",format=raw,if=floppy -boot order=a \
        -display none -no-reboot -no-shutdown \
        -debugcon "file:$log" -global isa-debugcon.iobase=0xe9 >/dev/null 2>&1
    set -e
    grep -q 'CASHOS_READY' "$log"
}

"$TOOL" --input "$IMAGE" --output "$tmp/operator.img" --id 1 --name CHARLIE --role operator >/dev/null
inspect=$("$TOOL" --inspect "$tmp/operator.img")
printf '%s\n' "$inspect"
printf '%s\n' "$inspect" | grep -q 'PROFILE VALID'
printf '%s\n' "$inspect" | grep -q 'ROLE: OPERATOR'
printf '%s\n' "$inspect" | grep -q 'EMPLOYEE ID: 1'
printf '%s\n' "$inspect" | grep -q 'NAME: CHARLIE'
run_boot "$tmp/operator.img" "$tmp/operator.log"
grep -q 'PROFILE_OK' "$tmp/operator.log"
grep -q 'EMPLOYEE_ID=1 ROLE=1' "$tmp/operator.log"

"$TOOL" --input "$IMAGE" --output "$tmp/admin.img" --id 0 --name ADMIN --role admin >/dev/null
run_boot "$tmp/admin.img" "$tmp/admin.log"
grep -q 'PROFILE_OK' "$tmp/admin.log"
grep -q 'EMPLOYEE_ID=0 ROLE=2' "$tmp/admin.log"

cp "$tmp/operator.img" "$tmp/corrupt.img"
printf '\001' | dd of="$tmp/corrupt.img" bs=1 seek=$((66 * 512 + 8)) conv=notrunc status=none
run_boot "$tmp/corrupt.img" "$tmp/corrupt.log"
grep -q 'PROFILE_INVALID' "$tmp/corrupt.log"
grep -q 'EMPLOYEE_ID=65535 ROLE=0' "$tmp/corrupt.log"

run_boot "$IMAGE" "$tmp/plain.log"
grep -q 'PROFILE_NONE' "$tmp/plain.log"
grep -q 'EMPLOYEE_ID=65535 ROLE=0' "$tmp/plain.log"

printf '%s\n' 'PASS: operator, admin, corrupt, and unprovisioned profile cases verified'
