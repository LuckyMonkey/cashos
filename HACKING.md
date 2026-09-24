# Hacking CashOS

`src/ui.asm` owns screen coordinates, register state, key actions, and the product rows. `src/products.asm` is the obvious place to change the product table. `src/keyboard.asm` owns BIOS keyboard dispatch. `src/vga.asm` shows the direct B8000 text-memory path. `src/money.asm` formats integer cents without floating point.

`src/profile.asm` owns the boot-media identity record. It reads LBA 66 through `disk_read_sector`, validates it in the shared sector buffer at `8000:0000`, and copies the useful fields into CashOS-owned memory before `journal_init` reuses the same buffer. Build an operator disk with `make employee NAME=CHARLIE ID=1`, an admin disk with `make admin`, and run `make profile-test` for valid/corrupt/unprovisioned cases.

The current input state is deliberately small: normal mode, custom-price mode, quantity mode, PLU mode, barcode mode, and tax mode. A custom `$3.25` entry is typed as `P`, `3`, `2`, `5`; `X`, `2`, Enter adds two units. Press `L`, type a code such as `4011`, and press Enter to add produce. Press `B` and type a 12-digit UPC to exercise the scanner path. Press `A` to exercise the role gate: an admin-profile disk reports active admin status; every other profile reports `ADMIN ONLY`. `T`, `8`, Enter applies an 8% rate to taxable sale items. `E`, `K`, and `N` select EBT, card, and cash in normal mode; an EBT completion is rejected if any sale item lacks the EBT flag. `R` rescans persisted journal state. Enter in normal mode completes the sale.

`src/disk.asm` converts an LBA to floppy CHS and calls BIOS `INT 13h`. `src/journal.asm` scans fixed-size records, builds checksummed records in the 512-byte buffer at `8000:0000`, writes the whole sector, and reads it back for validation. `tools/journal_dump.c` reads the same raw bytes on the Linux host; it is not placed in the floppy image.

`src/products.asm` is the catalog bridge: main item metadata is imported from `data/catalog.csv` through generated `build/catalog.inc`, while produce PLUs are a separate lookup path imported from `data/fruit_plu.csv`. `add_plu` and `add_upc` add prices plus tax/payment metadata to the same sale state.

For LBA 128, `128 / 18 = 7` with remainder 2. Track 7 divided by two gives cylinder 3 and head 1; the remainder becomes BIOS sector 3. Thus the first journal sector is cylinder 3, head 1, sector 3. BIOS receives the drive in `DL`, the CHS fields in `CH/CL/DH`, and the buffer address in `ES:BX`.

Add a routine as a small label in the relevant included module. Keep register inputs/outputs in a comment near the label. Important addresses and disk constants live in `include/constants.inc` and `include/disk_layout.inc` rather than being duplicated.

Debug output uses QEMU's ISA debug console at I/O port `0xE9`; `DEBUG_STRING` emits a NUL-terminated string, and `debug_u16` emits a decimal word. The smoke test checks for `CASHOS_READY`.

For binary inspection:

```sh
make size layout disasm
xxd -g 1 build/boot.bin | less -SR
```

For paused debugging:

```sh
make debug
gdb-multiarch
(gdb) set architecture i8086
(gdb) target remote :1234
(gdb) info registers
(gdb) x/16bx 0x7c00
```

Real-mode symbol handling is intentionally basic; the boot-sector disassembly, debug port, and direct memory inspection are the primary tools. NASM syntax support is useful in editors but not required.


## COM1 / ZPL printer path

`src/config.asm` consumes LBA 65 machine configuration. `src/serial.asm` owns direct COM1 port I/O at `0x3F8`; `src/printer.asm` owns ZPL serialization. A normal unconfigured floppy leaves the printer off.

Build a configured operator image with:

```sh
make printer-image NAME=CHARLIE ID=1 BAUD=9600
```

This produces `build/printer.img`. `make printer-test` provisions a temporary operator/configured image, boots it in QEMU, captures COM1 to a host file, completes a $3.25 Coffee transaction, verifies the raw ZPL stream contains the item name, item price, total, transaction ID, and employee ID, and independently checks that the journal still contains the sale.

The UART sequence is intentionally visible rather than abstracted away: COM1+1 disables UART interrupts; COM1+3 sets DLAB; COM1/COM1+1 receive the divisor; COM1+3 selects 8N1; COM1+2 configures the FIFO; COM1+4 asserts DTR/RTS; COM1+5 exposes the line-status register. Bit 5 of that status register means the transmit holding register is empty and can accept another byte.
\nCatalog and PLU importers also compile safe display-name pointer tables for the receipt path. Names containing `^` or `~` are rejected because those characters are ZPL control introducers; apostrophes are rejected to keep generated NASM string literals unambiguous.\n