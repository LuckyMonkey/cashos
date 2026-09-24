#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    image_size = 1474560,
    sector_size = 512,
    config_lba = 65,
    config_offset = config_lba * sector_size,
    config_magic = 0x31474643u,
    config_version = 1,
    flag_printer = 1,
    printer_zpl_serial = 1,
    checksum_offset = 16
};

static uint16_t get_u16(const unsigned char *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t get_u32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void put_u16(unsigned char *p, uint16_t value) {
    p[0] = (unsigned char)(value & 0xffu);
    p[1] = (unsigned char)(value >> 8);
}

static void put_u32(unsigned char *p, uint32_t value) {
    p[0] = (unsigned char)(value & 0xffu);
    p[1] = (unsigned char)((value >> 8) & 0xffu);
    p[2] = (unsigned char)((value >> 16) & 0xffu);
    p[3] = (unsigned char)((value >> 24) & 0xffu);
}

static uint32_t checksum(const unsigned char *config) {
    uint32_t sum = 0;
    for (size_t i = 0; i < checksum_offset; ++i) sum += config[i];
    return sum;
}

static unsigned char *read_image(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        perror(path);
        return NULL;
    }
    if (fseek(f, 0, SEEK_END) != 0) {
        perror("fseek");
        fclose(f);
        return NULL;
    }
    long size = ftell(f);
    if (size != image_size) {
        fprintf(stderr, "%s: expected %d bytes, got %ld\n", path, image_size, size);
        fclose(f);
        return NULL;
    }
    rewind(f);
    unsigned char *image = malloc(image_size);
    if (!image) {
        perror("malloc");
        fclose(f);
        return NULL;
    }
    if (fread(image, 1, image_size, f) != image_size) {
        perror("fread");
        free(image);
        fclose(f);
        return NULL;
    }
    fclose(f);
    return image;
}

static int config_valid(const unsigned char *p) {
    if (get_u32(p) != config_magic || p[4] != config_version) return 0;
    if (get_u32(p + checksum_offset) != checksum(p)) return 0;
    if (!(p[5] & flag_printer)) return 1;
    return p[6] == printer_zpl_serial && p[7] == 1 && get_u16(p + 8) != 0;
}

static int inspect(const char *path) {
    unsigned char *image = read_image(path);
    if (!image) return 1;
    const unsigned char *p = image + config_offset;
    if (!config_valid(p)) {
        printf("CONFIG INVALID\n");
        free(image);
        return 2;
    }
    printf("CONFIG VALID\n");
    if (p[5] & flag_printer) {
        uint16_t divisor = get_u16(p + 8);
        printf("PRINTER: ZPL SERIAL COM1\n");
        printf("DIVISOR: %u\n", divisor);
        printf("BAUD: %u\n", 115200u / divisor);
    } else {
        printf("PRINTER: OFF\n");
    }
    printf("CHECKSUM: 0x%08X OK\n", get_u32(p + checksum_offset));
    free(image);
    return 0;
}

static unsigned parse_baud(const char *text) {
    errno = 0;
    char *end = NULL;
    unsigned long baud = strtoul(text, &end, 10);
    if (errno || !text[0] || !end || *end || baud == 0 || baud > 115200ul) return 0;
    if (115200ul % baud != 0) return 0;
    unsigned long divisor = 115200ul / baud;
    if (divisor == 0 || divisor > 65535ul) return 0;
    return (unsigned)divisor;
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "usage:\n"
            "  %s --inspect IMAGE\n"
            "  %s --input IMAGE --output IMAGE --printer zpl --baud RATE\n",
            argv0, argv0);
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--inspect") == 0) return inspect(argv[2]);

    const char *input = NULL;
    const char *output = NULL;
    const char *printer = NULL;
    const char *baud_text = NULL;
    for (int i = 1; i < argc; ++i) {
        if (i + 1 >= argc) {
            usage(argv[0]);
            return 2;
        }
        if (strcmp(argv[i], "--input") == 0) input = argv[++i];
        else if (strcmp(argv[i], "--output") == 0) output = argv[++i];
        else if (strcmp(argv[i], "--printer") == 0) printer = argv[++i];
        else if (strcmp(argv[i], "--baud") == 0) baud_text = argv[++i];
        else {
            usage(argv[0]);
            return 2;
        }
    }

    if (!input || !output || !printer || !baud_text || strcmp(printer, "zpl") != 0) {
        usage(argv[0]);
        return 2;
    }
    if (strcmp(input, output) == 0) {
        fprintf(stderr, "input and output must be different files\n");
        return 2;
    }

    unsigned divisor = parse_baud(baud_text);
    if (!divisor) {
        fprintf(stderr, "baud must divide the standard 115200 Hz UART rate exactly\n");
        return 2;
    }

    unsigned char *image = read_image(input);
    if (!image) return 1;
    unsigned char *p = image + config_offset;
    memset(p, 0, sector_size);
    put_u32(p + 0, config_magic);
    p[4] = config_version;
    p[5] = flag_printer;
    p[6] = printer_zpl_serial;
    p[7] = 1;
    put_u16(p + 8, (uint16_t)divisor);
    put_u32(p + checksum_offset, checksum(p));

    FILE *f = fopen(output, "wb");
    if (!f) {
        perror(output);
        free(image);
        return 1;
    }
    if (fwrite(image, 1, image_size, f) != image_size) {
        perror("fwrite");
        fclose(f);
        free(image);
        return 1;
    }
    if (fclose(f) != 0) {
        perror("fclose");
        free(image);
        return 1;
    }
    free(image);
    return inspect(output);
}
