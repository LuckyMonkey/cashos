# CashOS

CashOS is a deliberately tiny bare-metal x86 cash register. The guest is a flat floppy image containing a 16-bit boot sector and a fixed-sector NASM real-mode application. Linux is used only on the development host for building and running QEMU; it is not present in `register.img`.

## Prerequisites

On Debian/Ubuntu/Xubuntu, run `./scripts/bootstrap-debian.sh` to print the required packages (or install them when run as root). The important tools are NASM, GNU Make, QEMU, binutils, GDB multiarch, and ordinary shell utilities.

## Build and run

```sh
make
make smoke
make run
```

`make smoke` runs QEMU headlessly for five seconds and checks the debug port for `CASHOS_READY`. `make run` opens the VGA window. Press `1`–`4` to add catalog products, `L` then digits to enter a produce PLU from any sale screen, `P` then digits to enter a custom price in cents, `X` then digits to enter a quantity, `+` to add, `-` to subtract, `E` to clear the entry, Backspace to delete a digit, `V` to void the last item, `C` to clear, `R` to rescan the journal, and Enter to commit or complete a sale. Produce PLUs and their CashOS-local prices are listed in `data/fruit_plu.csv`.

Useful inspection targets are `make size`, `make layout`, `make disasm`, and `make hex`. `make debug` starts QEMU paused with its GDB stub on TCP port 1234; connect with `gdb-multiarch` as described in HACKING.md.

Transactions are persisted as fixed 32-byte records beginning at LBA 128. Use `make journal` to build the Linux-side inspector. Use `make clean && make journal-test` to boot the same writable image twice and verify two completed sales remain after reboot.

`make check` runs the boot smoke test, two-boot persistence test, checksum-corruption test, disassembly, and size checks.

## Browser demo

`make web` builds a static site around the same `build/register.img`; it does not reimplement CashOS in JavaScript. `make web-serve` serves the result at `http://localhost:8000/`. Open it over HTTP, click the emulator, and use the normal register keyboard controls. The site uses pinned v86 assets and the actual CashOS floppy image. Browser-session floppy writes are not persisted across refreshes yet.

## Physical floppy warning

`scripts/write-floppy.sh` requires an explicit block-device path and the exact confirmation `CASHOS-WRITE`. It is intentionally not part of a normal build. Verify the target with `lsblk` before allowing the write.

Persistence, FAT12, protected mode, C, LVGL, networking, printers, and other platform services are future work.
