%define SECTOR_SIZE             512
%define FLOPPY_SECTORS          2880
%define APP_LBA                 1
%define APP_SECTORS             64
%define APP_BYTES               (APP_SECTORS * SECTOR_SIZE)
%define CONFIG_LBA              65
%define PROFILE_LBA             66
%define RESERVED_END_LBA       126
%define JOURNAL_META_LBA       127
%define JOURNAL_LBA            128
%define JOURNAL_RECORD_SIZE    32
%define JOURNAL_RECORDS_PER_SECTOR 16
%define JOURNAL_MAGIC           0x5458
%define JOURNAL_VERSION         1
%define JOURNAL_FLAG_COMMITTED  1
