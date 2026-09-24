%define SECTOR_SIZE             512
%define FLOPPY_SECTORS          2880
%define APP_LBA                 1
%define APP_SECTORS             64
%define APP_BYTES               (APP_SECTORS * SECTOR_SIZE)
%define CONFIG_LBA              65
%define CONFIG_MAGIC            0x31474643 ; bytes "CFG1"
%define CONFIG_VERSION          1
%define CONFIG_FLAG_PRINTER     0x01
%define CONFIG_PRINTER_ZPL_SERIAL 1
%define CONFIG_CHECKSUM_OFFSET 16
%define PROFILE_LBA             66
%define PROFILE_MAGIC            0x48534143 ; bytes "CASH"
%define PROFILE_VERSION          1
%define PROFILE_ROLE_NONE        0
%define PROFILE_ROLE_OPERATOR    1
%define PROFILE_ROLE_ADMIN       2
%define PROFILE_NAME_OFFSET      8
%define PROFILE_NAME_SIZE        24
%define PROFILE_CHECKSUM_OFFSET 40
%define RESERVED_END_LBA       126
%define JOURNAL_META_LBA       127
%define JOURNAL_LBA            128
%define JOURNAL_RECORD_SIZE    32
%define JOURNAL_RECORDS_PER_SECTOR 16
%define JOURNAL_MAGIC           0x5458
%define JOURNAL_VERSION_LEGACY  1
%define JOURNAL_VERSION         2
%define JOURNAL_FLAG_COMMITTED  1
