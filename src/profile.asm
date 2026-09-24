; CashOS portable operator profile.
; LBA 66 is read through the shared 512-byte buffer at 8000:0000, validated,
; then copied into stage-two memory because later journal I/O reuses that buffer.

profile_valid          db 0
current_role           db PROFILE_ROLE_NONE
current_employee_id    dw 0xFFFF
current_employee_name  times PROFILE_NAME_SIZE db 0

; profile_set_guest
; OUT: runtime identity becomes non-admin GUEST / employee 0xFFFF.
; CLOBBERS: AX, CX, SI, DI
profile_set_guest:
    mov byte [profile_valid], 0
    mov byte [current_role], PROFILE_ROLE_NONE
    mov word [current_employee_id], 0xFFFF
    mov di, current_employee_name
    mov cx, PROFILE_NAME_SIZE
    xor ax, ax
.zero_name:
    mov [di], al
    inc di
    loop .zero_name
    mov si, profile_guest_name
    mov di, current_employee_name
.copy_guest:
    lodsb
    mov [di], al
    inc di
    test al, al
    jnz .copy_guest
    ret

; profile_init
; Reads/validates LBA 66 and copies identity out of the shared sector buffer.
; OUT: CF clear=valid profile loaded, CF set=missing/corrupt/read failure.
; CLOBBERS: EAX, EDX, AX, CX, SI, DI, ES
profile_init:
    call profile_set_guest
    mov ax, PROFILE_LBA
    call disk_read_sector
    jc .read_error

    cmp dword [es:0], PROFILE_MAGIC
    jne .bad_magic
    cmp byte [es:4], PROFILE_VERSION
    jne .invalid

    mov al, [es:5]
    cmp al, PROFILE_ROLE_OPERATOR
    je .role_ok
    cmp al, PROFILE_ROLE_ADMIN
    jne .invalid
.role_ok:
    mov si, PROFILE_NAME_OFFSET
    mov cx, PROFILE_NAME_SIZE
.name_scan:
    cmp byte [es:si], 0
    je .name_ok
    inc si
    loop .name_scan
    jmp .invalid

.name_ok:
    xor eax, eax
    xor edx, edx
    xor si, si
    mov cx, PROFILE_CHECKSUM_OFFSET
.checksum:
    mov dl, [es:si]
    add eax, edx
    inc si
    loop .checksum
    cmp eax, [es:PROFILE_CHECKSUM_OFFSET]
    jne .invalid

    mov ax, [es:6]
    mov [current_employee_id], ax
    mov al, [es:5]
    mov [current_role], al

    mov si, PROFILE_NAME_OFFSET
    mov di, current_employee_name
    mov cx, PROFILE_NAME_SIZE
.copy_name:
    mov al, [es:si]
    mov [di], al
    inc si
    inc di
    loop .copy_name

    mov byte [profile_valid], 1
    DEBUG_STRING debug_profile_ok
    call profile_debug_identity
    clc
    ret

.bad_magic:
    cmp dword [es:0], 0
    jne .invalid
    DEBUG_STRING debug_profile_none
    call profile_debug_identity
    stc
    ret

.invalid:
    DEBUG_STRING debug_profile_invalid
    call profile_debug_identity
    stc
    ret

.read_error:
    DEBUG_STRING debug_profile_read_error
    call profile_debug_identity
    stc
    ret

; profile_debug_identity
; Emits the active in-RAM identity, including the guest fallback.
; CLOBBERS: AX, SI
profile_debug_identity:
    DEBUG_STRING debug_employee_id
    mov ax, [current_employee_id]
    call debug_u16
    DEBUG_STRING debug_role
    xor ax, ax
    mov al, [current_role]
    call debug_u16
    DEBUG_STRING profile_debug_newline
    ret

; profile_draw_identity
; Draws the copied runtime identity. Row 9 is otherwise unused by the register.
; CLOBBERS: AX, BX, DX, SI
profile_draw_identity:
    mov si, profile_operator_label
    mov dh, 9
    mov dl, 2
    mov bl, COLOR_ACCENT
    call vga_write_at

    mov si, current_employee_name
    mov dh, 9
    mov dl, 12
    mov bl, COLOR_NORMAL
    call vga_write_at

    cmp byte [profile_valid], 1
    jne .unprovisioned

    mov si, profile_id_label
    mov dh, 9
    mov dl, 38
    mov bl, COLOR_DIM
    call vga_write_at
    mov ax, [current_employee_id]
    mov dh, 9
    mov dl, 42
    mov bl, COLOR_NORMAL
    call write_number_at

    cmp byte [current_role], PROFILE_ROLE_ADMIN
    je .admin
    mov si, profile_operator_role
    mov dh, 9
    mov dl, 55
    mov bl, COLOR_SUCCESS
    jmp vga_write_at
.admin:
    mov si, profile_admin_role
    mov dh, 9
    mov dl, 55
    mov bl, COLOR_WARNING
    jmp vga_write_at

.unprovisioned:
    mov si, profile_unprovisioned
    mov dh, 9
    mov dl, 38
    mov bl, COLOR_WARNING
    jmp vga_write_at

; profile_admin_action
; A tiny role gate for this milestone. This is not strong authentication.
profile_admin_action:
    cmp byte [profile_valid], 1
    jne .denied
    cmp byte [current_role], PROFILE_ROLE_ADMIN
    jne .denied
    mov si, profile_admin_active_message
    call show_notice
    ret
.denied:
    mov si, profile_admin_only_message
    call show_notice
    ret

profile_guest_name           db 'GUEST', 0
profile_operator_label       db 'OPERATOR:', 0
profile_id_label             db 'ID:', 0
profile_operator_role        db '[OPERATOR]', 0
profile_admin_role           db '[ADMIN]', 0
profile_unprovisioned        db '[UNPROVISIONED]', 0
profile_admin_active_message db 'ADMIN PROFILE ACTIVE', 0
profile_admin_only_message   db 'ADMIN ONLY', 0
debug_profile_ok             db 'PROFILE_OK', 13, 10, 0
debug_profile_none           db 'PROFILE_NONE', 13, 10, 0
debug_profile_invalid        db 'PROFILE_INVALID', 13, 10, 0
debug_profile_read_error     db 'PROFILE_READ_ERROR', 13, 10, 0
debug_employee_id            db 'EMPLOYEE_ID=', 0
debug_role                   db ' ROLE=', 0
profile_debug_newline        db 13, 10, 0
