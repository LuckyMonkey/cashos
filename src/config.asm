; Machine configuration lives in raw sector LBA 65.
; The sector is loaded through 8000:0000, validated, and copied into runtime
; fields before profile/journal reads reuse the same scratch buffer.

config_valid             db 0
config_error_code        db 0       ; 0=none/missing, 1=read, 2=invalid
config_printer_enabled   db 0
config_printer_protocol  db 0
config_printer_port      db 0
config_serial_divisor    dw 12      ; 115200 / 12 = 9600 baud

; config_set_defaults
; A blank or invalid disk never enables hardware output.
config_set_defaults:
    mov byte [config_valid], 0
    mov byte [config_error_code], 0
    mov byte [config_printer_enabled], 0
    mov byte [config_printer_protocol], 0
    mov byte [config_printer_port], 0
    mov word [config_serial_divisor], 12
    ret

; config_init
; OUT: CF clear=valid config or blank/default config, CF set=read/validation error.
; CLOBBERS: EAX, EDX, AX, CX, SI, ES
config_init:
    call config_set_defaults
    mov ax, CONFIG_LBA
    call disk_read_sector
    jc .read_error

    cmp dword [es:0], 0
    je .blank
    cmp dword [es:0], CONFIG_MAGIC
    jne .invalid
    cmp byte [es:4], CONFIG_VERSION
    jne .invalid

    xor eax, eax
    xor edx, edx
    xor si, si
    mov cx, CONFIG_CHECKSUM_OFFSET
.sum:
    mov dl, [es:si]
    add eax, edx
    inc si
    loop .sum
    cmp eax, [es:CONFIG_CHECKSUM_OFFSET]
    jne .invalid

    mov al, [es:5]
    test al, CONFIG_FLAG_PRINTER
    jz .copy_disabled
    cmp byte [es:6], CONFIG_PRINTER_ZPL_SERIAL
    jne .invalid
    cmp byte [es:7], 1
    jne .invalid
    cmp word [es:8], 0
    je .invalid

    mov byte [config_printer_enabled], 1
    mov al, [es:6]
    mov [config_printer_protocol], al
    mov al, [es:7]
    mov [config_printer_port], al
    mov ax, [es:8]
    mov [config_serial_divisor], ax
.copy_disabled:
    mov byte [config_valid], 1
    DEBUG_STRING debug_config_ok
    cmp byte [config_printer_enabled], 1
    jne .ok
    DEBUG_STRING debug_printer_divisor
    mov ax, [config_serial_divisor]
    call debug_u16
    DEBUG_STRING config_debug_newline
.ok:
    clc
    ret

.blank:
    DEBUG_STRING debug_config_none
    clc
    ret

.invalid:
    mov byte [config_error_code], 2
    DEBUG_STRING debug_config_invalid
    stc
    ret

.read_error:
    mov byte [config_error_code], 1
    DEBUG_STRING debug_config_read_error
    stc
    ret

debug_config_ok         db 'CONFIG_OK', 13, 10, 0
debug_config_none       db 'CONFIG_NONE', 13, 10, 0
debug_config_invalid    db 'CONFIG_INVALID', 13, 10, 0
debug_config_read_error db 'CONFIG_READ_ERROR', 13, 10, 0
debug_printer_divisor   db 'PRINTER_DIVISOR=', 0
config_debug_newline    db 13, 10, 0
