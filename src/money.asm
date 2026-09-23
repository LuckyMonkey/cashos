; money_format: EAX=cents, DI=destination. Writes a NUL-terminated string.
money_format:
    push es
    mov bx, ds
    mov es, bx
    mov byte [di], '$'
    inc di
    mov ebx, 100
    xor edx, edx
    div ebx
    mov ecx, edx
    mov si, money_digits + 10
    xor bp, bp
.dollar_digits:
    xor edx, edx
    mov ebx, 10
    div ebx
    dec si
    add dl, '0'
    mov [si], dl
    inc bp
    test eax, eax
    jnz .dollar_digits
.copy_dollars:
    movsb
    dec bp
    jnz .copy_dollars
    mov al, '.'
    stosb
    mov eax, ecx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    stosb
    add dl, '0'
    mov al, dl
    stosb
    xor al, al
    stosb
    pop es
    ret

; format_u16
; IN: AX=value, DI=destination in DS
; OUT: NUL-terminated decimal string
; CLOBBERS: AX, BX, CX, DX, SI, DI, BP, ES
format_u16:
    push es
    mov bx, ds
    mov es, bx
    mov si, number_digits + 6
    xor bp, bp
    test ax, ax
    jnz .digits
    mov byte [di], '0'
    inc di
    jmp .done
.digits:
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    dec si
    add dl, '0'
    mov [si], dl
    inc bp
    test ax, ax
    jnz .divide
.copy:
    movsb
    dec bp
    jnz .copy
.done:
    xor al, al
    stosb
    pop es
    ret

; format_u32
; IN: EAX=value, DI=destination in DS
; OUT: NUL-terminated decimal string
; CLOBBERS: EAX, EBX, ECX, EDX, SI, DI, BP, ES
format_u32:
    push es
    mov bx, ds
    mov es, bx
    mov si, number_digits + 6
    xor bp, bp
    test eax, eax
    jnz .digits
    mov byte [di], '0'
    inc di
    jmp .done
.digits:
    mov ebx, 10
.divide:
    xor edx, edx
    div ebx
    dec si
    add dl, '0'
    mov [si], dl
    inc bp
    test eax, eax
    jnz .divide
.copy:
    movsb
    dec bp
    jnz .copy
.done:
    xor al, al
    stosb
    pop es
    ret
