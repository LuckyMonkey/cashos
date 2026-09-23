bits 16
org 0x7C00

%include "../include/constants.inc"
%include "../include/disk_layout.inc"

jmp short boot_start
nop

; Minimal BPB-shaped header keeps old BIOSes and disk tools unsurprised.
oem_id              db 'CASHOS  '
bytes_per_sector    dw 512
sectors_per_cluster db 1
reserved_sectors    dw 1
fat_count           db 0
root_entries        dw 0
total_sectors_16    dw 2880
media               db 0xF0
sectors_per_fat     dw 0
sectors_per_track   dw 18
head_count          dw 2
hidden_sectors      dd 0
total_sectors_32    dd 0

boot_drive          db 0
current_lba         dw 0
remaining_sectors   dw APP_SECTORS
load_segment        dw BOOT_LOAD_SEGMENT

boot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    mov [boot_drive], dl
    mov word [current_lba], APP_LBA
    mov word [remaining_sectors], APP_SECTORS
    mov word [load_segment], BOOT_LOAD_SEGMENT

load_next_sector:
    cmp word [remaining_sectors], 0
    je boot_stage2

    mov ax, [current_lba]
    xor dx, dx
    mov bx, 18
    div bx
    mov cl, dl
    inc cl
    xor dx, dx
    mov bx, 2
    div bx
    mov ch, al
    mov dh, dl
    mov dl, [boot_drive]

    mov ax, [load_segment]
    mov es, ax
    xor bx, bx
    mov si, 3

read_retry:
    mov ah, 0x02
    mov al, 1
    int 0x13
    jnc sector_loaded
    xor ah, ah
    mov dl, [boot_drive]
    int 0x13
    dec si
    jnz read_retry
    jmp disk_error

sector_loaded:
    inc word [current_lba]
    dec word [remaining_sectors]
    add word [load_segment], 0x20
    jmp load_next_sector

boot_stage2:
    mov dl, [boot_drive]     ; explicitly pass the BIOS drive to stage two
    push word BOOT_LOAD_SEGMENT
    push word 0
    retf

disk_error:
    mov si, disk_error_message
    call print_string
    cli
.halt:
    hlt
    jmp .halt

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print_string
.done:
    ret

disk_error_message db 13, 10, 'CASHOS: DISK READ ERROR', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55
