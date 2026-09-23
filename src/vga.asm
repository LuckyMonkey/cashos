; VGA text mode is 80 columns by 25 rows at physical address B8000.
; Each cell is two bytes: ASCII character followed by color attribute.

vga_clear:
    push ax
    push cx
    push di
    mov ax, VGA_SEGMENT
    mov es, ax
    xor di, di
    mov ax, (COLOR_NORMAL << 8) | ' '
    mov cx, VGA_COLUMNS * VGA_ROWS
    rep stosw
    pop di
    pop cx
    pop ax
    ret

; vga_write_at: DH=row, DL=column, SI=DS:NUL string, BL=attribute.
vga_write_at:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, VGA_SEGMENT
    mov es, ax
    mov [vga_attribute], bl
    ; MUL writes DX, so calculate the column offset before using DH/DL for the row.
    xor bx, bx
    mov bl, dl
    shl bx, 1
    xor ax, ax
    mov al, dh
    mov cx, 160
    mul cx
    add ax, bx
    mov di, ax
.next:
    lodsb
    test al, al
    jz .done
    stosb
    mov al, [vga_attribute]
    stosb
    jmp .next
.done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

vga_attribute db 0

debug_init:
    ret

debug_putc:
    out DEBUG_PORT, al
    ret

; IN: SI=DS:NUL string.
debug_puts:
    lodsb
    test al, al
    jz .done
    call debug_putc
    jmp debug_puts
.done:
    ret

; IN: AX=value. CLOBBERS AX, BX, CX, DX.
debug_u16:
    mov bx, 10
    xor cx, cx
    test ax, ax
    jnz .divide
    mov al, '0'
    jmp debug_putc
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.emit:
    pop dx
    add dl, '0'
    mov al, dl
    call debug_putc
    loop .emit
    ret

; IN: EAX=value. CLOBBERS EAX, EBX, ECX, EDX.
debug_u32:
    mov ebx, 10
    xor ecx, ecx
    test eax, eax
    jnz .divide
    mov al, '0'
    jmp debug_putc
.divide:
    xor edx, edx
    div ebx
    push dx
    inc cx
    test eax, eax
    jnz .divide
.emit:
    pop dx
    add dl, '0'
    mov al, dl
    call debug_putc
    loop .emit
    ret
