; Product prices are integer cents. Table order is the visible key order.
; Main register shortcuts: keys 1..4.
product_count equ 4
product_prices dw 325, 250, 150, 200

; The PLU table is imported from data/fruit_plu.csv into a generated,
; reviewable NASM include before assembly. PLUs are a lookup path, not a
; second on-screen category.
%include "../build/fruit_plu.inc"
