; Product prices are integer cents. Table order is the visible key order.
; Main register shortcuts: keys 1..4.
%include "../build/catalog.inc"
product_count equ catalog_count
product_names equ catalog_names
product_prices equ catalog_prices
product_skus equ catalog_skus
product_upcs equ catalog_upcs
product_departments equ catalog_departments
product_tax_class equ catalog_tax_class
product_payment_flags equ catalog_payment_flags

; The PLU table is imported from data/fruit_plu.csv into a generated,
; reviewable NASM include before assembly. PLUs are a lookup path, not a
; second on-screen category.
%include "../build/fruit_plu.inc"
