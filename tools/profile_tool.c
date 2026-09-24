#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    image_size = 1474560,
    sector_size = 512,
    profile_lba = 66,
    profile_offset = profile_lba * sector_size,
    profile_magic = 0x48534143u,
    profile_version = 1,
    role_operator = 1,
    role_admin = 2,
    name_offset = 8,
    name_size = 24,
    checksum_offset = 40
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

static uint32_t checksum(const unsigned char *profile) {
    uint32_t sum = 0;
    for (size_t i = 0; i < checksum_offset; ++i) sum += profile[i];
    return sum;
}

static int profile_valid(const unsigned char *p) {
    if (get_u32(p) != profile_magic || p[4] != profile_version) return 0;
    if (p[5] != role_operator && p[5] != role_admin) return 0;
    if (memchr(p + name_offset, 0, name_size) == NULL) return 0;
    return get_u32(p + checksum_offset) == checksum(p);
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

static int inspect(const char *path) {
    unsigned char *image = read_image(path);
    if (!image) return 1;
    const unsigned char *p = image + profile_offset;
    if (!profile_valid(p)) {
        printf("PROFILE INVALID\n");
        free(image);
        return 2;
    }
    printf("PROFILE VALID\n");
    printf("VERSION: %u\n", p[4]);
    printf("ROLE: %s\n", p[5] == role_admin ? "ADMIN" : "OPERATOR");
    printf("EMPLOYEE ID: %u\n", get_u16(p + 6));
    printf("NAME: %s\n", (const char *)(p + name_offset));
    printf("CHECKSUM: 0x%08X OK\n", get_u32(p + checksum_offset));
    free(image);
    return 0;
}

static int parse_id(const char *text, uint16_t *out) {
    errno = 0;
    char *end = NULL;
    unsigned long value = strtoul(text, &end, 10);
    if (errno || !text[0] || !end || *end || value > 65534ul) return 0;
    *out = (uint16_t)value;
    return 1;
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "usage:\n"
            "  %s --inspect IMAGE\n"
            "  %s --input IMAGE --output IMAGE --id N --name NAME --role operator|admin\n",
            argv0, argv0);
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--inspect") == 0) {
        return inspect(argv[2]);
    }

    const char *input = NULL;
    const char *output = NULL;
    const char *name = NULL;
    const char *role_text = NULL;
    const char *id_text = NULL;

    for (int i = 1; i < argc; ++i) {
        if (i + 1 >= argc) {
            usage(argv[0]);
            return 2;
        }
        if (strcmp(argv[i], "--input") == 0) input = argv[++i];
        else if (strcmp(argv[i], "--output") == 0) output = argv[++i];
        else if (strcmp(argv[i], "--id") == 0) id_text = argv[++i];
        else if (strcmp(argv[i], "--name") == 0) name = argv[++i];
        else if (strcmp(argv[i], "--role") == 0) role_text = argv[++i];
        else {
            usage(argv[0]);
            return 2;
        }
    }

    if (!input || !output || !id_text || !name || !role_text) {
        usage(argv[0]);
        return 2;
    }
    if (strcmp(input, output) == 0) {
        fprintf(stderr, "input and output must be different files\n");
        return 2;
    }
    size_t len = strlen(name);
    if (len == 0 || len >= name_size) {
        fprintf(stderr, "name must be 1..%d bytes\n", name_size - 1);
        return 2;
    }

    uint16_t id;
    if (!parse_id(id_text, &id)) {
        fprintf(stderr, "employee ID must be 0..65534\n");
        return 2;
    }

    unsigned role;
    if (strcmp(role_text, "operator") == 0) role = role_operator;
    else if (strcmp(role_text, "admin") == 0) role = role_admin;
    else {
        fprintf(stderr, "role must be operator or admin\n");
        return 2;
    }

    unsigned char *image = read_image(input);
    if (!image) return 1;

    unsigned char *p = image + profile_offset;
    memset(p, 0, sector_size);
    put_u32(p + 0, profile_magic);
    p[4] = profile_version;
    p[5] = (unsigned char)role;
    put_u16(p + 6, id);
    memcpy(p + name_offset, name, len);
    p[name_offset + len] = 0;
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
