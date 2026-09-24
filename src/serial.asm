; Direct COM1 UART output. No BIOS serial service is used.
; The configured divisor uses the standard PC UART clock: baud = 115200/divisor.

serial_ready db 0
serial_error db 0

; serial_init
; Programs COM1 for 8 data bits, no parity, one stop bit (8N1).
; OUT: CF clear=disabled or configured, CF set=unsupported config.
; CLOBBERS: AX, BX, DX
serial_init:
    mov byte [serial_ready], 0
    mov byte [serial_error], 0
    cmp byte [config_printer_enabled], 1
    jne .disabled
    cmp byte [config_printer_protocol], CONFIG_PRINTER_ZPL_SERIAL
    jne .unsupported
    cmp byte [config_printer_port], 1
    jne .unsupported

    ; Disable UART interrupts.
    mov dx, COM1_BASE + 1
    xor al, al
    out dx, al

    ; Set DLAB so offsets 0/1 become the baud divisor registers.
    mov dx, COM1_BASE + 3
    mov al, 0x80
    out dx, al
    mov bx, [config_serial_divisor]
    mov dx, COM1_BASE
    mov al, bl
    out dx, al
    mov dx, COM1_BASE + 1
    mov al, bh
    out dx, al

    ; Clear DLAB and select 8N1.
    mov dx, COM1_BASE + 3
    mov al, 0x03
    out dx, al

    ; Enable and clear FIFOs, then assert DTR/RTS.
    mov dx, COM1_BASE + 2
    mov al, 0x07
    out dx, al
    mov dx, COM1_BASE + 4
    mov al, 0x03
    out dx, al

    mov byte [serial_ready], 1
    DEBUG_STRING debug_serial_ready
    clc
    ret

.disabled:
    DEBUG_STRING debug_serial_off
    clc
    ret

.unsupported:
    mov byte [serial_error], 1
    DEBUG_STRING debug_serial_config_error
    stc
    ret

; serial_putc
; IN: AL=byte.
; OUT: CF clear=transmitted to UART holding register, CF set=timeout/not ready.
; PRESERVES: BX, CX, DX
serial_putc:
    cmp byte [serial_ready], 1
    jne .fail
    push bx
    push cx
    push dx
    mov bl, al
    mov cx, 0xFFFF
.wait:
    mov dx, COM1_BASE + 5
    in al, dx
    test al, 0x20                 ; line-status bit 5: TX holding register empty
    jnz .send
    loop .wait
    mov byte [serial_ready], 0
    mov byte [serial_error], 1
    pop dx
    pop cx
    pop bx
.fail:
    stc
    ret
.send:
    mov dx, COM1_BASE
    mov al, bl
    out dx, al
    pop dx
    pop cx
    pop bx
    clc
    ret

; serial_puts
; IN: SI=DS:NUL string.
; OUT: CF clear=all bytes sent, CF set=UART failure.
; CLOBBERS: AL, SI
serial_puts:
.next:
    lodsb
    test al, al
    jz .done
    call serial_putc
    jc .fail
    jmp .next
.done:
    clc
    ret
.fail:
    stc
    ret

; serial_write_u16
; IN: AX=value.
; OUT: CF from serial_puts.
; CLOBBERS: AX, BX, CX, DX, SI, DI, BP, ES
serial_write_u16:
    mov di, number_buffer
    call format_u16
    mov si, number_buffer
    jmp serial_puts

debug_serial_ready        db 'SERIAL_COM1_READY', 13, 10, 0
debug_serial_off          db 'SERIAL_PRINTER_OFF', 13, 10, 0
debug_serial_config_error db 'SERIAL_CONFIG_ERROR', 13, 10, 0
