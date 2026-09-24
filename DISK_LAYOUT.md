# CashOS floppy layout

The image is exactly 1,474,560 bytes: 2,880 sectors of 512 bytes. It is raw media, not FAT12.

| LBA | Contents | Size |
| --- | --- | ---: |
| 0 | boot sector | 512 bytes |
| 1–64 | CashOS stage two | 32 KiB maximum |
| 65 | future configuration | 512 bytes |
| 66 | employee/profile data | 512 bytes |
| 67–126 | reserved | 60 sectors |
| 127 | reserved future journal metadata | 512 bytes |
| 128–2879 | future transaction journal | 2752 sectors |

The image builder writes only LBA 0 and the stage-two bytes beginning at LBA 1. All other bytes remain zero until a host-side profile tool provisions LBA 66 or CashOS writes journal data. The journal uses a scan strategy and does not currently write LBA 127. The build fails rather than truncating a stage-two binary larger than 64 sectors.

## Employee/profile sector

LBA 66 is a fixed 512-byte profile record. The guest copies validated fields into its own stage-two memory because the shared disk buffer at `8000:0000` is reused by journal reads.

| Offset | Size | Meaning |
| ---: | ---: | --- |
| 0 | 4 | magic bytes `CASH` |
| 4 | 1 | profile version, currently `1` |
| 5 | 1 | role: `1` operator, `2` admin |
| 6 | 2 | employee ID (little-endian) |
| 8 | 24 | NUL-terminated/padded display name |
| 32 | 8 | reserved zero bytes |
| 40 | 4 | checksum: sum of bytes 0-39 |
| 44 | 468 | reserved zero bytes |

An all-zero or corrupt profile falls back to the non-admin guest identity (employee ID `65535`). This is portable identity/configuration, not strong authentication: cloning the floppy clones the profile.

## Transaction record

CashOS uses 32-byte records. A 512-byte sector therefore contains 16 records. Records begin at LBA 128; record `n` is in sector `128 + (n / 16)` at byte offset `(n % 16) * 32`.

| Offset | Size | Meaning |
| ---: | ---: | --- |
| 0 | 2 | magic `0x5458` (`TX` in little-endian bytes) |
| 2 | 1 | format version, currently `2` (version 1 remains readable) |
| 3 | 1 | flags, `1` means committed |
| 4 | 4 | transaction ID |
| 8 | 4 | total cents |
| 12 | 2 | item count |
| 14 | 2 | employee ID in version 2; zero/reserved in version 1 |
| 16 | 4 | checksum: sum of bytes 0–15 |
| 20 | 12 | reserved zero bytes |

The scan stops at the first invalid or empty record. This is intentionally understandable rather than crash-perfect: a torn sector can hide later records. Multi-byte values are little-endian because that is the native byte order of the x86 CPU.
