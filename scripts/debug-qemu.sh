#!/bin/sh
set -eu
IMAGE=${1:-build/register.img}
exec qemu-system-i386 -machine pc -m 64M -drive file="$IMAGE",format=raw,if=floppy -boot order=a -S -s

