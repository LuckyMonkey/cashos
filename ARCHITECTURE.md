# CashOS architecture

The current machine path is:

```text
PC BIOS
  -> LBA 0: src/boot.asm at 0000:7C00
  -> fixed CHS reads of LBA 1-64
  -> src/main.asm at 1000:0000
  -> BIOS INT 13h reads LBA 66 employee/profile data into 8000:0000
  -> validated profile fields are copied into CashOS runtime state
  -> VGA text memory at B800:0000
  -> BIOS INT 16h keyboard input
  -> on Enter: policy validation and raw journal record through BIOS INT 13h to LBA 128+
```

The boot sector records the BIOS drive number, uses 18 sectors/track and two heads to convert its fixed LBA range to CHS, retries each sector three times, and halts visibly on failure. Stage two sets its own data segments and stack, initializes mode 03h, renders the fixed register screen, and blocks in a simple keyboard loop.

Stage two is one flat binary assembled through `%include`; source files remain modular without introducing an object linker. `profile.asm` reads the fixed profile sector through the same BIOS disk path as the journal, validates its magic/version/role/checksum, then copies the employee ID, role, and name out of the shared `8000:0000` sector buffer before journal scanning reuses that buffer. State is direct memory: integer cents, a transaction counter, an item count, and a small price stack. On transaction completion, `journal.asm` reads one 512-byte sector into `8000:0000`, changes one 32-byte record, writes the whole sector with BIOS `INT 13h`, and reads it back to validate the checksum. Journal format version 2 stores the current employee ID in bytes 14-15; version-1 records remain readable as legacy records. Debug text goes to QEMU's port 0xE9 independently of VGA.

Catalog metadata is source-controlled in `data/catalog.csv` and compiled into
the guest as parallel arrays: price, store SKU, UPC, department, tax class, and
payment flags. The current register uses that metadata for barcode lookup,
taxable-item selection, and EBT eligibility. Custom prices default to taxable
cash-only policy; the future admin floppy can replace the catalog record data.

The repository intentionally leaves room for a future protected-mode/freestanding-C layer, but does not add an abstraction for it yet.
