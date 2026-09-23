NASM ?= nasm
QEMU ?= qemu-system-i386
NDISASM ?= ndisasm
CC ?= cc
BUILD_DIR ?= build
IMAGE := $(BUILD_DIR)/register.img
APP_SECTORS := 64
APP_BYTES := $(shell echo $$(( $(APP_SECTORS) * 512 )))

.PHONY: all image run debug smoke disasm hex size layout journal journal-test journal-corrupt-test check web web-serve clean watch

all: image

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/boot.bin: src/boot.asm include/constants.inc include/disk_layout.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/ -I include/ -o $@ $<

$(BUILD_DIR)/fruit_plu.inc: data/fruit_plu.csv scripts/import-plu.sh | $(BUILD_DIR)
	sh scripts/import-plu.sh $< $@

$(BUILD_DIR)/catalog.inc: data/catalog.csv scripts/import-catalog.sh | $(BUILD_DIR)
	sh scripts/import-catalog.sh $< $@

$(BUILD_DIR)/cashos.bin: src/main.asm src/vga.asm src/keyboard.asm src/products.asm src/money.asm src/ui.asm src/disk.asm src/journal.asm data/fruit_plu.csv data/catalog.csv $(BUILD_DIR)/fruit_plu.inc $(BUILD_DIR)/catalog.inc include/constants.inc include/disk_layout.inc include/macros.inc | $(BUILD_DIR)
	$(NASM) -f bin -I src/ -I include/ -o $@ $<

image: $(IMAGE)

$(IMAGE): $(BUILD_DIR)/boot.bin $(BUILD_DIR)/cashos.bin scripts/mkimage.sh include/disk_layout.inc
	./scripts/mkimage.sh $(IMAGE) $(BUILD_DIR)/boot.bin $(BUILD_DIR)/cashos.bin $(APP_SECTORS)

WEB_SITE := $(BUILD_DIR)/site

web: $(WEB_SITE)/register.img
	@test -s $(WEB_SITE)/index.html
	@test -s $(WEB_SITE)/v86/libv86.js
	@test -s $(WEB_SITE)/v86/v86.wasm
	@test -s $(WEB_SITE)/bios/seabios.bin
	@test -s $(WEB_SITE)/bios/vgabios.bin
	@test -s $(WEB_SITE)/assets/cash-register-pixel.png
	@test "$$(stat -c %s $(WEB_SITE)/register.img)" -eq 1474560
	@echo "web site ready at $(WEB_SITE)/"

$(WEB_SITE)/register.img: $(IMAGE) web/index.html web/app.js web/style.css web/README.md web/assets/cash-register-pixel.png scripts/prepare-v86.sh
	rm -rf $(WEB_SITE)
	mkdir -p $(WEB_SITE)
	cp web/index.html web/app.js web/style.css web/README.md $(WEB_SITE)/
	mkdir -p $(WEB_SITE)/assets
	cp web/assets/cash-register-pixel.png $(WEB_SITE)/assets/
	cp $(IMAGE) $(WEB_SITE)/register.img
	sh scripts/prepare-v86.sh $(WEB_SITE)

web-serve: web
	python3 -m http.server 8000 --directory $(WEB_SITE)

run: image
	./scripts/run-qemu.sh $(IMAGE)

debug: image
	./scripts/debug-qemu.sh $(IMAGE)

smoke: image
	./scripts/smoke-qemu.sh $(IMAGE)

disasm: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/cashos.bin
	@$(NDISASM) -b 16 $(BUILD_DIR)/boot.bin > $(BUILD_DIR)/boot.dis
	@$(NDISASM) -b 16 $(BUILD_DIR)/cashos.bin > $(BUILD_DIR)/cashos.dis
	@echo "Wrote $(BUILD_DIR)/boot.dis and $(BUILD_DIR)/cashos.dis"

hex: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/cashos.bin
	xxd -g 1 $(BUILD_DIR)/boot.bin

size: $(BUILD_DIR)/boot.bin $(BUILD_DIR)/cashos.bin $(IMAGE)
	@boot=$$(stat -c %s $(BUILD_DIR)/boot.bin); app=$$(stat -c %s $(BUILD_DIR)/cashos.bin); img=$$(stat -c %s $(IMAGE)); \
	printf 'boot.bin       %s / 512 bytes\n' "$$boot"; \
	printf 'cashos.bin    %s / %s bytes\n' "$$app" "$(APP_BYTES)"; \
	printf 'free app      %s bytes\n' $$(( $(APP_BYTES) - app )); \
	printf 'disk image %s / 1474560 bytes\n' "$$img"

layout: image
	@stat -c 'image bytes: %s' $(IMAGE)
	@echo 'LBA 0       boot sector'
	@echo 'LBA 1-64    CashOS stage two'
	@echo 'LBA 65       future configuration'
	@echo 'LBA 66       future employee/profile'
	@echo 'LBA 67-126   reserved'
	@echo 'LBA 127      future journal metadata'
	@echo 'LBA 128-2879 future transaction journal'

$(BUILD_DIR)/journal-dump: tools/journal_dump.c | $(BUILD_DIR)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -o $@ $<

journal: image $(BUILD_DIR)/journal-dump
	$(BUILD_DIR)/journal-dump $(IMAGE)

journal-test: clean
	$(MAKE) image $(BUILD_DIR)/journal-dump
	./scripts/test-journal.sh $(IMAGE) $(BUILD_DIR)/journal-dump

journal-corrupt-test: image $(BUILD_DIR)/journal-dump
	./scripts/test-journal-corrupt.sh $(IMAGE) $(BUILD_DIR)/journal-dump

check: clean
	$(MAKE) smoke
	$(MAKE) journal-test
	$(MAKE) journal-corrupt-test
	$(MAKE) disasm size

clean:
	rm -rf $(BUILD_DIR)

watch:
	@command -v entr >/dev/null || { echo 'watch requires entr'; exit 1; }; \
	rg --files src include | entr -c sh -c 'make && make run'
