#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum {
    sector_size = 512,
    journal_lba = 128,
    record_size = 32,
    journal_end_lba = 2880,
    magic = 0x5458,
    legacy_version = 1,
    version = 2,
    committed = 1
};

static uint16_t get_u16(const unsigned char *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t get_u32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint32_t checksum(const unsigned char *record) {
    uint32_t sum = 0;
    for (size_t i = 0; i < 16; ++i) sum += record[i];
    return sum;
}

static int all_zero(const unsigned char *record) {
    for (size_t i = 0; i < record_size; ++i) {
        if (record[i] != 0) return 0;
    }
    return 1;
}

static int valid_record(const unsigned char *record) {
    int known_version = record[2] == version || record[2] == legacy_version;
    return get_u16(record) == magic && known_version &&
           record[3] == committed && get_u32(record + 16) == checksum(record);
}

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "build/register.img";
    FILE *image = fopen(path, "rb");
    if (!image) {
        perror(path);
        return 1;
    }

    unsigned char record[record_size];
    unsigned valid = 0;
    for (unsigned lba = journal_lba; lba < journal_end_lba; ++lba) {
        if (fseek(image, (long)lba * sector_size, SEEK_SET) != 0) {
            perror("fseek");
            fclose(image);
            return 1;
        }
        for (unsigned slot = 0; slot < sector_size / record_size; ++slot) {
            if (fread(record, 1, sizeof record, image) != sizeof record) {
                perror("fread");
                fclose(image);
                return 1;
            }
            if (all_zero(record)) {
                printf("%u valid transaction record(s)\n", valid);
                fclose(image);
                return 0;
            }
            unsigned record_number = (lba - journal_lba) * 16 + slot;
            if (!valid_record(record)) {
                printf("RECORD %04u INVALID\n", record_number);
                continue;
            }
            uint32_t total = get_u32(record + 8);
            if (record[2] == version) {
                printf("TX %04u  ITEMS=%u  TOTAL=$%u.%02u  VALID  EMP=%u\n",
                       get_u32(record + 4), get_u16(record + 12),
                       total / 100, total % 100, get_u16(record + 14));
            } else {
                printf("TX %04u  ITEMS=%u  TOTAL=$%u.%02u  VALID  EMP=LEGACY\n",
                       get_u32(record + 4), get_u16(record + 12),
                       total / 100, total % 100);
            }
            ++valid;
        }
    }
    printf("%u valid transaction record(s)\n", valid);
    fclose(image);
    return 0;
}
