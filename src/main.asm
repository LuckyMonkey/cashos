bits 16
org 0

%include "../include/constants.inc"
%include "../include/disk_layout.inc"
%include "../include/macros.inc"

main_start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov [boot_drive], dl
    mov ax, STACK_SEGMENT
    mov ss, ax
    mov sp, STACK_TOP
    sti
    cld

    call debug_init
    DEBUG_STRING debug_stage2
    mov ax, 0x0003
    int 0x10
    call vga_clear
    call register_init
    call journal_init
    call draw_register
    DEBUG_STRING debug_ui_ready
    DEBUG_STRING debug_ready

main_loop:
    DEBUG_STRING debug_wait
    call keyboard_wait
    push ax
    DEBUG_STRING debug_key
    pop ax
    push ax
    call debug_u16
    DEBUG_STRING debug_newline
    pop ax
    call dispatch_key
    jmp main_loop

%include "vga.asm"
%include "keyboard.asm"
%include "products.asm"
%include "money.asm"
%include "ui.asm"
%include "disk.asm"
%include "journal.asm"

debug_stage2 db 'STAGE2_START', 13, 10, 0
debug_ui_ready db 'UI_READY', 13, 10, 0
debug_ready  db 'CASHOS_READY', 13, 10, 0
debug_wait   db 'WAIT_KEY', 13, 10, 0
debug_key    db 'KEY=', 0
