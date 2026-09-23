%macro DEBUG_STRING 1
    mov si, %1
    call debug_puts
%endmacro

