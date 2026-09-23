#!/bin/sh
set -eu
IMAGE=$1
BOOT=$2
APP=$3
APP_SECTORS=$4
SECTOR_SIZE=512
IMAGE_BYTES=$((2880 * SECTOR_SIZE))
APP_BYTES=$((APP_SECTORS * SECTOR_SIZE))
[ "$(stat -c %s "$BOOT")" -eq 512 ] || { echo 'mkimage: boot.bin must be exactly 512 bytes' >&2; exit 1; }
app_size=$(stat -c %s "$APP")
[ "$app_size" -le "$APP_BYTES" ] || { echo "mkimage: cashos.bin is $app_size bytes, capacity is $APP_BYTES" >&2; exit 1; }
mkdir -p "$(dirname "$IMAGE")"
truncate -s "$IMAGE_BYTES" "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=512 count=2880 conv=notrunc status=none
dd if="$BOOT" of="$IMAGE" bs=512 seek=0 conv=notrunc status=none
dd if="$APP" of="$IMAGE" bs=512 seek=1 conv=notrunc status=none
[ "$(stat -c %s "$IMAGE")" -eq "$IMAGE_BYTES" ] || { echo 'mkimage: wrong final image size' >&2; exit 1; }
echo "created $IMAGE ($IMAGE_BYTES bytes; journal area zeroed)"
