; Raw journal records live at LBA 128. No filesystem is involved.
;
; Record format, 32 bytes, little-endian multi-byte fields:
;   +0  word magic       'TX' (0x5458)
;   +2  byte version     1
;   +3  byte flags       1 = committed
;   +4  dword tx_id
;   +8  dword total_cents
;   +12 word item_count
;   +14 word reserved
;   +16 dword checksum   sum of bytes 0..15
;   +20 12 bytes reserved, zero
;
; A 512-byte sector contains 16 records. On boot we scan from LBA 128 and
; stop at the first invalid/empty record. This deliberately simple scheme
; makes the raw disk easy to inspect; a torn sector can make later records
; unreachable, which is documented as an MVP limitation.

journal_lba_current  dw JOURNAL_LBA
journal_slot_current db 0
journal_available    db 0
journal_error_code   db 0       ; 1=read, 2=write, 3=verify, 4=full
journal_last_id      dd 0
journal_last_total   dd 0
journal_last_items   dw 0
journal_last_tx      dw 0
journal_tx_temp      dd 0
journal_total_temp   dd 0
journal_items_temp   dw 0

journal_init:
    mov byte [journal_available], 0
    mov byte [journal_error_code], 0
    mov word [journal_lba_current], JOURNAL_LBA
    mov byte [journal_slot_current], 0
    mov dword [journal_last_id], 0
    mov dword [journal_last_total], 0
    mov word [journal_last_items], 0
    mov word [journal_last_tx], 0
    mov word [transaction_number], 0
.next_sector:
    mov ax, [journal_lba_current]
    call disk_read_sector
    jc .read_error
    xor bx, bx
    mov byte [journal_slot_current], 0
.next_record:
    mov di, bx
    call journal_validate_record
    jc .found_free
    mov eax, [es:di+4]
    cmp eax, [journal_last_id]
    jbe .known_id
    mov [journal_last_id], eax
    mov [transaction_number], ax
    mov [journal_last_tx], ax
    mov eax, [es:di+8]
    mov [journal_last_total], eax
    mov ax, [es:di+12]
    mov [journal_last_items], ax
.known_id:
    inc byte [journal_slot_current]
    add bx, JOURNAL_RECORD_SIZE
    cmp byte [journal_slot_current], JOURNAL_RECORDS_PER_SECTOR
    jb .next_record
    inc word [journal_lba_current]
    cmp word [journal_lba_current], FLOPPY_SECTORS
    jb .next_sector
    mov byte [journal_error_code], 4
    stc
    ret
.found_free:
    mov byte [journal_available], 1
    clc
    ret
.read_error:
    mov byte [journal_error_code], 1
    stc
    ret

; journal_validate_record
; IN:  ES:DI = candidate record
; OUT: CF clear=valid committed record, CF set=empty/corrupt record
; CLOBBERS: EAX, EDX, CX, SI
journal_validate_record:
    cmp word [es:di+0], JOURNAL_MAGIC
    jne .invalid
    cmp byte [es:di+2], JOURNAL_VERSION
    jne .invalid
    cmp byte [es:di+3], JOURNAL_FLAG_COMMITTED
    jne .invalid
    xor eax, eax
    mov si, di
    mov cx, 16
.sum:
    xor edx, edx
    mov dl, [es:si]
    add eax, edx
    inc si
    loop .sum
    cmp eax, [es:di+16]
    jne .invalid
    clc
    ret
.invalid:
    stc
    ret

; journal_build_record
; IN: EAX=tx id, EDX=total cents, CX=item count, ES:DI=record
; OUT: record populated and checksummed
; CLOBBERS: EAX, EBX, ECX, EDX, SI
journal_build_record:
    mov word [es:di+0], JOURNAL_MAGIC
    mov byte [es:di+2], JOURNAL_VERSION
    mov byte [es:di+3], JOURNAL_FLAG_COMMITTED
    mov [es:di+4], eax
    mov [es:di+8], edx
    mov [es:di+12], cx
    mov word [es:di+14], 0
    xor eax, eax
    mov [es:di+16], eax
    mov [es:di+20], eax
    mov [es:di+24], eax
    mov [es:di+28], eax
    xor eax, eax
    mov si, di
    mov cx, 16
.checksum:
    xor edx, edx
    mov dl, [es:si]
    add eax, edx
    inc si
    loop .checksum
    mov [es:di+16], eax
    ret

; journal_commit
; IN: EAX=transaction ID, EDX=total cents, CX=item count
; OUT: CF clear=persisted and read-back validated, CF set=failure
; CLOBBERS: AX, BX, CX, DX, SI, DI, ES
journal_commit:
    cmp byte [journal_available], 1
    jne .fail_full
    mov [journal_tx_temp], eax
    mov [journal_total_temp], edx
    mov [journal_items_temp], cx
    DEBUG_STRING debug_journal_lba
    mov ax, [journal_lba_current]
    call debug_u16
    DEBUG_STRING debug_journal_slot
    xor ax, ax
    mov al, [journal_slot_current]
    call debug_u16
    DEBUG_STRING debug_newline

    mov ax, [journal_lba_current]
    call disk_read_sector
    jc .fail_read
    xor ax, ax
    mov al, [journal_slot_current]
    shl ax, 5
    mov di, ax
    mov eax, [journal_tx_temp]
    mov edx, [journal_total_temp]
    mov cx, [journal_items_temp]
    call journal_build_record
    mov ax, [journal_lba_current]
    call disk_write_sector
    jc .fail_write
    mov ax, [journal_lba_current]
    call disk_read_sector
    jc .fail_verify
    xor ax, ax
    mov al, [journal_slot_current]
    shl ax, 5
    mov di, ax              ; BIOS may clobber DI during the read
    call journal_validate_record
    jc .fail_verify
    mov eax, [journal_tx_temp]
    mov [journal_last_id], eax
    mov ax, [journal_tx_temp]
    mov [journal_last_tx], ax
    mov eax, [journal_total_temp]
    mov [journal_last_total], eax
    mov ax, [journal_items_temp]
    mov [journal_last_items], ax
    DEBUG_STRING debug_journal_ok
    DEBUG_STRING debug_newline
    cmp byte [journal_slot_current], JOURNAL_RECORDS_PER_SECTOR-1
    je .next_sector
    inc byte [journal_slot_current]
    clc
    ret
.next_sector:
    mov byte [journal_slot_current], 0
    inc word [journal_lba_current]
    cmp word [journal_lba_current], FLOPPY_SECTORS
    jb .success
    mov byte [journal_available], 0
.success:
    clc
    ret
.fail_read:
    mov byte [journal_error_code], 1
    jmp .fail
.fail_write:
    mov byte [journal_error_code], 2
    jmp .fail
.fail_verify:
    mov byte [journal_error_code], 3
    jmp .fail
.fail_full:
    mov byte [journal_error_code], 4
.fail:
    stc
    ret

journal_show_status:
    cmp byte [journal_available], 1
    je .ready
    cmp byte [journal_error_code], 4
    je .full
    cmp byte [journal_error_code], 1
    je .read
    cmp byte [journal_error_code], 2
    je .write
    mov si, journal_verify_error_message
    jmp .show
.ready:
    mov si, journal_ready_message
    jmp .show
.full:
    mov si, journal_full_message
    jmp .show
.read:
    mov si, journal_read_error_message
    jmp .show
.write:
    mov si, journal_write_error_message
.show:
    mov dh, 19
    mov dl, 2
    mov bl, COLOR_TOTAL
    call vga_write_at
    ret

journal_show_write_error:
    mov si, journal_write_error_message
    mov dh, 19
    mov dl, 2
    mov bl, COLOR_TOTAL
    call vga_write_at
    ret

journal_read_error_message  db 'JOURNAL READ ERROR', 0
journal_write_error_message db 'JOURNAL WRITE ERROR', 0
journal_verify_error_message db 'JOURNAL VERIFY ERROR', 0
journal_full_message        db 'JOURNAL FULL', 0
journal_ready_message       db 'JOURNAL READY', 0
debug_tx_begin               db 'TX_BEGIN=', 0
debug_journal_lba            db 'JOURNAL_LBA=', 0
debug_journal_slot           db 'JOURNAL_SLOT=', 0
debug_journal_ok             db 'JOURNAL_WRITE_OK', 0
debug_tx_commit              db 'TX_COMMIT=', 0
