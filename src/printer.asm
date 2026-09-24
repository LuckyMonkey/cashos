; Zebra Programming Language transaction output over direct COM1 UART.
; Printing is best-effort after the journal commit: printer failure never rolls
; back a transaction that has already been persisted.

printer_last_error db 0

; printer_print_sale
; Uses journal_tx_temp/journal_total_temp and current_employee_id.
; OUT: CF clear=disabled or printed, CF set=configured printer failed.
; CLOBBERS: EAX, AX, BX, CX, DX, SI, DI, BP, ES
printer_print_sale:
    cmp byte [config_printer_enabled], 1
    jne .disabled
    cmp byte [serial_ready], 1
    jne .fail

    DEBUG_STRING debug_print_begin

    mov si, zpl_start
    call serial_puts
    jc .fail

    mov si, zpl_tx_prefix
    call serial_puts
    jc .fail
    mov ax, [journal_tx_temp]
    call serial_write_u16
    jc .fail
    mov si, zpl_field_end
    call serial_puts
    jc .fail

    mov si, zpl_emp_prefix
    call serial_puts
    jc .fail
    mov ax, [current_employee_id]
    call serial_write_u16
    jc .fail
    mov si, zpl_field_end
    call serial_puts
    jc .fail

    mov si, zpl_total_prefix
    call serial_puts
    jc .fail
    mov eax, [journal_total_temp]
    mov di, money_buffer
    call money_format
    mov si, money_buffer
    call serial_puts
    jc .fail
    mov si, zpl_field_end
    call serial_puts
    jc .fail

    mov si, zpl_finish
    call serial_puts
    jc .fail

    mov byte [printer_last_error], 0
    DEBUG_STRING debug_print_ok
    clc
    ret

.disabled:
    clc
    ret

.fail:
    mov byte [printer_last_error], 1
    DEBUG_STRING debug_print_fail
    stc
    ret

; printer_draw_status
; Shares row 16 with journal status, but on the right side of the 80-column UI.
printer_draw_status:
    cmp byte [config_error_code], 0
    jne .config_error
    cmp byte [config_printer_enabled], 1
    jne .off
    cmp byte [printer_last_error], 0
    jne .error
    cmp byte [serial_ready], 1
    jne .error
    mov si, printer_ready_message
    mov bl, COLOR_SUCCESS
    jmp .show
.off:
    mov si, printer_off_message
    mov bl, COLOR_DIM
    jmp .show
.error:
    mov si, printer_error_message
    mov bl, COLOR_WARNING
    jmp .show
.config_error:
    mov si, config_error_message
    mov bl, COLOR_WARNING
.show:
    mov dh, 16
    mov dl, 45
    call vga_write_at
    ret

zpl_start        db '^XA',13,10,'^PW400',13,10,'^LL220',13,10,'^FO20,20^A0N,30,30^FDCASHOS^FS',13,10,0
zpl_tx_prefix    db '^FO20,60^A0N,22,22^FDTX ',0
zpl_emp_prefix   db '^FO20,92^A0N,22,22^FDEMP ',0
zpl_total_prefix db '^FO20,124^A0N,22,22^FDTOTAL ',0
zpl_field_end    db '^FS',13,10,0
zpl_finish       db '^FO20,160^A0N,18,18^FDTHANK YOU^FS',13,10,'^XZ',13,10,0

printer_ready_message db '[ZPL COM1 READY]',0
printer_off_message   db '[PRINTER OFF]',0
printer_error_message db '[PRINTER ERROR]',0
config_error_message  db '[CONFIG ERROR]',0
debug_print_begin     db 'ZPL_PRINT_BEGIN',13,10,0
debug_print_ok        db 'ZPL_PRINT_OK',13,10,0
debug_print_fail      db 'ZPL_PRINT_FAIL',13,10,0
