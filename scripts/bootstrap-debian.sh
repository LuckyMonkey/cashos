#!/bin/sh
set -eu
packages='nasm make qemu-system-x86 qemu-utils binutils gdb-multiarch build-essential xxd bsdextrautils git ripgrep tree entr'
echo "CashOS development packages: $packages"
if [ "$(id -u)" -ne 0 ]; then
    echo 'Run with sudo to install them, for example:'
    echo "  sudo apt-get update && sudo apt-get install $packages"
    exit 0
fi
apt-get update
apt-get install -y $packages

