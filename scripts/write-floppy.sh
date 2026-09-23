#!/bin/sh
set -eu
DEVICE=${1:-}
IMAGE=${2:-build/register.img}
[ -n "$DEVICE" ] || { echo "usage: $0 /dev/fd0 [build/register.img]" >&2; exit 2; }
case "$DEVICE" in /dev/sda|/dev/nvme*|/dev/vda|/dev/xvda) echo "refusing obvious system disk: $DEVICE" >&2; exit 1;; esac
[ -b "$DEVICE" ] || { echo "not a block device: $DEVICE" >&2; exit 1; }
[ -f "$IMAGE" ] || { echo "image not found: $IMAGE" >&2; exit 1; }
lsblk -o NAME,PATH,SIZE,TYPE,MOUNTPOINTS "$DEVICE"
echo "THIS WILL OVERWRITE $DEVICE with $IMAGE"
printf 'Type CASHOS-WRITE to continue: '
read answer
[ "$answer" = CASHOS-WRITE ] || { echo 'aborted'; exit 1; }
sudo dd if="$IMAGE" of="$DEVICE" bs=1M conv=fsync,status=progress
sync
echo "wrote $IMAGE to $DEVICE"

