; BIOS INT 16h provides a blocking keyboard read in real mode.
keyboard_wait:
    xor ah, ah
    int 0x16
    ret

dispatch_key:
    cmp al, 'b'
    je .barcode_mode
    cmp al, 'B'
    je .barcode_mode
    cmp al, 't'
    je .tax_mode
    cmp al, 'T'
    je .tax_mode
    cmp al, 'l'
    je .plu_mode
    cmp al, 'L'
    je .plu_mode
    cmp al, 'p'
    je .price_mode
    cmp al, 'P'
    je .price_mode
    cmp al, 'e'
    je .entry_or_ebt
    cmp al, 'E'
    je .entry_or_ebt
    cmp al, 'k'
    je .card_mode
    cmp al, 'K'
    je .card_mode
    cmp al, 'n'
    je .cash_mode
    cmp al, 'N'
    je .cash_mode
    cmp al, 8
    je .backspace
    cmp al, 'x'
    je .multiply
    cmp al, 'X'
    je .multiply
    cmp al, '*'
    je .multiply
    cmp al, '+'
    je .commit_entry
    cmp al, '-'
    je .subtract_entry
    cmp al, '0'
    jb .special
    cmp al, '9'
    ja .special
    cmp byte [input_mode], 0
    jne .digit
    cmp al, '1'
    jb .special
    cmp al, '4'
    jbe .fixed_product
    cmp al, '5'
    jb .special
    cmp al, '9'
    ja .special
    call begin_price_entry
    sub al, '0'
    call append_digit
    ret
.fixed_product:
    sub al, '1'
    xor ah, ah
    call add_product
    ret
.digit:
    cmp byte [input_mode], 4
    je .barcode_digit
    sub al, '0'
    call append_digit
    ret
.barcode_digit:
    call append_barcode_digit
    ret
.special:
    cmp al, 'v'
    je .void
    cmp al, 'V'
    je .void
    cmp al, 'c'
    je .clear
    cmp al, 'C'
    je .clear
    cmp al, 'r'
    je .rescan
    cmp al, 'R'
    je .rescan
    cmp al, 13
    je .complete
    ret
.price_mode:
    call begin_price_entry
    ret
.clear_entry:
    call clear_entry
    ret
.entry_or_ebt:
    cmp byte [input_mode], 0
    jne .clear_entry
    call begin_ebt
    ret
.backspace:
    call backspace_entry
    ret
.multiply:
    call begin_quantity_entry
    ret
.commit_entry:
    call commit_entry
    ret
.subtract_entry:
    call subtract_entry
    ret
.void:
    call void_last_item
    ret
.clear:
    call clear_sale
    ret
.rescan:
    call journal_init
    call draw_register
    ret
.complete:
    cmp byte [input_mode], 0
    jne .commit_entry
    call complete_sale
    ret
.plu_mode:
    call begin_plu_entry
    ret
.barcode_mode:
    call begin_barcode_entry
    ret
.tax_mode:
    call begin_tax_entry
    ret
.card_mode:
    call begin_card
    ret
.cash_mode:
    call begin_cash
    ret
