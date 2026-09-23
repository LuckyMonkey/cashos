register_total      dd 0
transaction_number  dw 0
item_count           dw 0
sale_items           times 32 dw 0
money_buffer         times 16 db 0
money_digits         times 10 db 0
number_buffer        times 8 db 0
number_digits        times 6 db 0
entry_value          dd 0
pending_price        dd 0
input_mode           db 0              ; 0=normal, 1=price entry, 2=quantity entry
entry_digits         db 0

register_init:
    mov word [register_total], 0
    mov word [register_total+2], 0
    mov word [transaction_number], 0
    mov word [item_count], 0
    mov word [entry_value], 0
    mov word [entry_value+2], 0
    mov byte [input_mode], 0
    mov byte [entry_digits], 0
    ret

draw_register:
    call vga_clear
    mov si, line_top
    mov dh, 0
    mov dl, 0
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, title
    mov dh, 1
    mov dl, 29
    mov bl, COLOR_TITLE
    call vga_write_at
    mov si, register_label
    mov dh, 2
    mov dl, 32
    mov bl, COLOR_TITLE
    call vga_write_at
    mov si, line_mid
    mov dh, 3
    mov dl, 0
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, produce_label
    mov dh, 4
    mov dl, 2
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, product_1
    mov dh, 5
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov si, product_2
    mov dh, 6
    call vga_write_at
    mov si, product_3
    mov dh, 7
    call vga_write_at
    mov si, product_4
    mov dh, 8
    call vga_write_at
    mov si, line_mid
    mov dh, 10
    mov dl, 0
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, current_sale
    mov dh, 11
    mov dl, 2
    mov bl, COLOR_TITLE
    call vga_write_at
    mov si, item_count_label
    mov dh, 13
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov ax, [item_count]
    mov dh, 13
    mov dl, 11
    mov bl, COLOR_NORMAL
    call write_number_at
    mov si, last_tx_label
    mov dh, 12
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov ax, [journal_last_tx]
    mov dh, 12
    mov dl, 11
    mov bl, COLOR_NORMAL
    call write_number_at
    mov eax, [journal_last_total]
    mov di, money_buffer
    call money_format
    mov si, money_buffer
    mov dh, 12
    mov dl, 58
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov si, next_tx_label
    mov dh, 14
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov ax, [transaction_number]
    inc ax
    mov dh, 14
    mov dl, 11
    mov bl, COLOR_NORMAL
    call write_number_at
    mov si, entry_label
    cmp byte [input_mode], 3
    jne .entry_label_ready
    mov si, plu_entry_label
.entry_label_ready:
    mov dh, 15
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    cmp byte [input_mode], 3
    je .draw_plu_value
    mov eax, [entry_value]
    mov di, money_buffer
    call money_format
    mov si, money_buffer
    mov dh, 15
    mov dl, 58
    mov bl, COLOR_NORMAL
    call vga_write_at
    jmp .entry_value_done
.draw_plu_value:
    mov eax, [entry_value]
    mov dh, 15
    mov dl, 58
    mov bl, COLOR_NORMAL
    mov di, number_buffer
    call format_u32
    mov si, number_buffer
    call vga_write_at
.entry_value_done:
    mov si, line_mid
    mov dh, 17
    mov dl, 0
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, total_label
    mov dh, 18
    mov dl, 2
    mov bl, COLOR_TOTAL
    call vga_write_at
    mov eax, [register_total]
    mov di, money_buffer
    call money_format
    mov si, money_buffer
    mov dh, 18
    mov dl, 58
    mov bl, COLOR_TOTAL
    call vga_write_at
    mov si, line_mid
    mov dh, 20
    mov dl, 0
    mov bl, COLOR_ACCENT
    call vga_write_at
    mov si, help_text
    mov dh, 21
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov si, help_text_2
    mov dh, 22
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    mov si, version_text
    mov dh, 23
    mov dl, 2
    mov bl, COLOR_NORMAL
    call vga_write_at
    call journal_show_status
    ret

write_small_number:
    add al, '0'
    mov [small_number], al
    mov byte [small_number+1], 0
    mov si, small_number
    mov dh, 13
    mov dl, 11
    mov bl, COLOR_NORMAL
    jmp vga_write_at

; write_number_at
; IN: AX=value, DH=row, DL=column, BL=attribute
; CLOBBERS: AX, BX, CX, DX, SI, DI, BP, ES
write_number_at:
    push dx
    push bx
    mov di, number_buffer
    call format_u16
    pop bx
    pop dx
    mov si, number_buffer
    jmp vga_write_at

begin_plu_entry:
    mov byte [input_mode], 3
    mov byte [entry_digits], 0
    mov dword [entry_value], 0
    call draw_register
    ret

; IN: AX=zero-based product index.
add_product:
    cmp ax, product_count
    jae .done
    push ax
    ; AX selects the product; item_count selects the next cart slot.
    mov bx, ax
    shl bx, 1
    mov dx, [product_prices + bx]
    mov bx, [item_count]
    cmp bx, 32
    jae .full
    shl bx, 1
    mov [sale_items + bx], dx
    inc word [item_count]
    movzx eax, dx
    add [register_total], eax
    DEBUG_STRING debug_add
    pop ax
    inc al
    mov ah, 0
    call debug_u16
    DEBUG_STRING debug_total
    mov eax, [register_total]
    call debug_u16
    DEBUG_STRING debug_newline
    call draw_register
    ret
.full:
    pop ax
.done:
    ret

; Append one decimal digit to an entry, capped at 99999 so five-digit PLUs fit.
append_digit:
    movzx ebx, al
    mov eax, [entry_value]
    mov ecx, 10
    mul ecx
    add eax, ebx
    cmp eax, 99999
    ja .done
    mov [entry_value], eax
    inc byte [entry_digits]
    call draw_register
.done:
    ret

begin_price_entry:
    mov byte [input_mode], 1
    mov byte [entry_digits], 0
    mov dword [entry_value], 0
    call draw_register
    ret

begin_quantity_entry:
    cmp byte [input_mode], 1
    jne .done
    cmp dword [entry_value], 0
    je .done
    mov eax, [entry_value]
    mov [pending_price], eax
    mov dword [entry_value], 0
    mov byte [entry_digits], 0
    mov byte [input_mode], 2
    call draw_register
.done:
    ret

clear_entry:
    mov dword [entry_value], 0
    mov byte [entry_digits], 0
    mov byte [input_mode], 0
    call draw_register
    ret

backspace_entry:
    mov eax, [entry_value]
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [entry_value], eax
    cmp byte [entry_digits], 0
    je .draw
    dec byte [entry_digits]
.draw:
    call draw_register
    ret

commit_entry:
    cmp byte [input_mode], 3
    je .plu
    cmp byte [input_mode], 2
    je .quantity
    cmp byte [input_mode], 1
    jne .done
    mov eax, [entry_value]
    call add_amount
    jmp clear_entry
.quantity:
    mov eax, [pending_price]
    mov ecx, [entry_value]
    test ecx, ecx
    jz .done
    mul ecx
    test edx, edx
    jnz .done
    call add_amount
    jmp clear_entry
.plu:
    mov eax, [entry_value]
    call add_plu
    jc .invalid_plu
    jmp clear_entry
.invalid_plu:
    mov si, invalid_plu_message
    mov dh, 19
    mov dl, 2
    mov bl, COLOR_TOTAL
    call vga_write_at
    ret
.done:
    ret

subtract_entry:
    cmp byte [input_mode], 0
    je .done
    mov eax, [entry_value]
    cmp eax, [register_total]
    ja .zero
    sub [register_total], eax
    jmp clear_entry
.zero:
    mov dword [register_total], 0
    jmp clear_entry
.done:
    ret

; Add a custom amount to the same item stack used by fixed products.
; IN: EAX=integer cents, limited to 65535 for this 16-bit MVP.
add_amount:
    cmp eax, 65535
    ja .done
    mov bx, [item_count]
    cmp bx, 32
    jae .done
    shl bx, 1
    mov [sale_items + bx], ax
    inc word [item_count]
    add [register_total], eax
    push eax
    DEBUG_STRING debug_amount
    pop eax
    call debug_u16
    DEBUG_STRING debug_total
    mov eax, [register_total]
    call debug_u16
    DEBUG_STRING debug_newline
    call draw_register
.done:
    ret

void_last_item:
    cmp word [item_count], 0
    je .done
    dec word [item_count]
    mov bx, [item_count]
    shl bx, 1
    movzx eax, word [sale_items + bx]
    sub [register_total], eax
    DEBUG_STRING debug_void
    DEBUG_STRING debug_newline
    call draw_register
.done:
    ret

clear_sale:
    mov word [item_count], 0
    mov word [register_total], 0
    mov word [register_total+2], 0
    mov dword [entry_value], 0
    mov byte [input_mode], 0
    mov byte [entry_digits], 0
    DEBUG_STRING debug_clear
    DEBUG_STRING debug_newline
    call draw_register
    ret

; IN: EAX=PLU code. OUT: CF clear=added, CF set=unknown PLU.
add_plu:
    push eax
    xor bx, bx
.find:
    cmp bx, plu_count * 4
    jae .unknown
    mov edx, [plu_codes + bx]
    cmp eax, edx
    je .found
    add bx, 4
    jmp .find
.found:
    shr bx, 1
    mov dx, [plu_prices + bx]
    movzx eax, dx
    call add_amount
    pop eax                         ; restore the code; debug_puts uses AL
    push eax
    DEBUG_STRING debug_plu
    pop eax
    call debug_u32
    DEBUG_STRING debug_newline
    clc
    ret
.unknown:
    pop eax
    stc
    ret

complete_sale:
    movzx eax, word [transaction_number]
    inc eax
    mov edx, [register_total]
    mov cx, [item_count]
    mov [journal_tx_temp], eax
    DEBUG_STRING debug_tx_begin
    mov ax, [journal_tx_temp]
    call debug_u16
    DEBUG_STRING debug_newline
    mov eax, [journal_tx_temp]
    mov edx, [register_total]
    mov cx, [item_count]
    call journal_commit
    jc .journal_error
    mov ax, [journal_tx_temp]
    mov [transaction_number], ax
    DEBUG_STRING debug_tx_commit
    mov ax, [transaction_number]
    call debug_u16
    DEBUG_STRING debug_newline
    call clear_sale
    ret
.journal_error:
    DEBUG_STRING debug_journal_fail
    DEBUG_STRING debug_newline
    call journal_show_write_error
    ret

line_top         db '+------------------------------------------------------------------------------+', 0
line_mid         db '+------------------------------------------------------------------------------+', 0
title            db 'CASHOS', 0
register_label   db 'REGISTER 01', 0
product_1        db '1  COFFEE                                      $3.25', 0
product_2        db '2  BAGEL                                       $2.50', 0
product_3        db '3  WATER                                       $1.50', 0
product_4        db '4  COOKIE                                      $2.00', 0
current_sale     db 'CURRENT SALE', 0
item_count_label db 'ITEMS: ', 0
total_label      db 'TOTAL', 0
help_text        db '1-4 ADD   L PLU   P PRICE(cents)   X QTY   + ADD   - SUB', 0
help_text_2      db 'E ENTRY   V VOID   C CLEAR   R RESCAN   ENTER COMMIT', 0
entry_label      db 'ENTRY', 0
plu_entry_label  db 'PLU:', 0
last_tx_label    db 'LAST TX:', 0
next_tx_label    db 'NEXT TX:', 0
produce_label    db 'PRODUCE: USE L + PLU CODE', 0
invalid_plu_message db 'UNKNOWN PRODUCE PLU', 0
version_text     db 'CASHOS 0.1.0  |  REAL MODE  |  FLOPPY REGISTER', 0
small_number     db '0', 0
debug_add        db 'ADD_ITEM=', 0
debug_amount     db 'ADD_AMOUNT=', 0
debug_total      db 'TOTAL=', 0
debug_complete   db 'SALE_COMPLETE=', 0
debug_journal_fail db 'JOURNAL_WRITE_FAIL', 0
debug_void       db 'VOID_LAST', 0
debug_clear      db 'CLEAR_SALE', 0
debug_plu       db 'ADD_PLU=', 0
debug_newline    db 13, 10, 0
