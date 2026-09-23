; BIOS disk services address a floppy sector with CHS and a memory buffer.
; The journal always uses one sector at a time through JOURNAL_BUFFER_SEGMENT:0.

disk_lba_temp      dw 0
disk_retry_count   dw 0
boot_drive         db 0

; disk_lba_to_chs
; IN:  AX = LBA (0..2879)
; OUT: CH, CL, DH, DL = cylinder, 1-based sector, head, BIOS drive
; CLOBBERS: AX, BX, DX
disk_lba_to_chs:
    xor dx, dx
    mov bx, 18
    div bx                  ; AX=track, DX=zero-based sector
    mov cl, dl
    inc cl                  ; BIOS sectors are numbered 1..18
    xor dx, dx
    mov bx, 2
    div bx                  ; AX=cylinder, DX=head
    mov ch, al
    mov dh, dl
    mov dl, [boot_drive]
    ret

disk_reset:
    xor ah, ah
    mov dl, [boot_drive]
    int 0x13
    ret

; disk_read_sector
; IN:  AX = LBA
; OUT: CF clear=sector in 8000:0000, CF set=bounded read failure
; CLOBBERS: AX, BX, CX, DX, SI, DI, ES
disk_read_sector:
    mov [disk_lba_temp], ax
    mov word [disk_retry_count], 3
.retry:
    mov ax, [disk_lba_temp]
    call disk_lba_to_chs
    mov ax, JOURNAL_BUFFER_SEGMENT
    mov es, ax              ; ES:BX is the BIOS destination buffer
    xor bx, bx
    mov ah, 0x02
    mov al, 1
    int 0x13
    jnc .success
    call disk_reset
    dec word [disk_retry_count]
    jnz .retry
    stc
    ret
.success:
    clc
    ret

; disk_write_sector
; IN:  AX = LBA; source sector is 8000:0000
; OUT: CF clear=write accepted by BIOS, CF set=bounded write failure
; CLOBBERS: AX, BX, CX, DX, SI, DI, ES
disk_write_sector:
    mov [disk_lba_temp], ax
    mov word [disk_retry_count], 3
.retry:
    mov ax, [disk_lba_temp]
    call disk_lba_to_chs
    mov ax, JOURNAL_BUFFER_SEGMENT
    mov es, ax
    xor bx, bx
    mov ah, 0x03
    mov al, 1
    int 0x13
    jnc .success
    call disk_reset
    dec word [disk_retry_count]
    jnz .retry
    stc
    ret
.success:
    clc
    ret

