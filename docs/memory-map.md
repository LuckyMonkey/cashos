# CashOS memory map

| Physical address | Use |
| --- | --- |
| `00000–003FF` | BIOS interrupt vector table |
| `00400–004FF` | BIOS data area |
| `07C00–07DFF` | BIOS-loaded CashOS boot sector |
| `10000–17FFF` | CashOS stage two, maximum initial load area |
| `90000–9FFFE` | CashOS real-mode stack (`SS=9000`) |
| `80000–801FF` | 512-byte BIOS journal sector buffer (`8000:0000`) |
| `B8000–B8F9F` | VGA 80×25 text framebuffer |

The bootloader starts with a stack below the boot sector and stage two moves to its own stack segment before making application calls. The journal buffer is below the stack and above the loaded application, so BIOS can use `ES:BX = 8000:0000` without overwriting CashOS or VGA memory. VGA cells are two bytes each: character then attribute.
