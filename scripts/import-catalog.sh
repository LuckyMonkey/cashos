#!/bin/sh
set -eu

input=$1
output=$2
tmp="$output.tmp"

awk -F, '
BEGIN { count = 0 }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
{
    if ($1 !~ /^[1-9][0-9]*$/ || $2 == "" || $3 !~ /^[0-9]+$/ ||
        $4 !~ /^[0-9]+$/ || $5 !~ /^[0-9]{12}$/ || $6 !~ /^[0-9]+$/ ||
        $7 !~ /^[0-9]+$/ || $8 !~ /^[0-1]$/ || $9 !~ /^[0-7]$/) {
        print "invalid catalog row: " $0 > "/dev/stderr"
        exit 1
    }
    count++
    key[count] = $1
    price[count] = $3
    sku[count] = $4
    upc[count] = $5
    plu[count] = $6
    department[count] = $7
    tax_class[count] = $8
    payment_flags[count] = $9
}
END {
    if (count == 0) exit 1
    print "; Generated from data/catalog.csv. Do not edit by hand."
    print "catalog_count equ " count
    printf "catalog_prices dw "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", price[i] }
    print ""
    printf "catalog_skus dw "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", sku[i] }
    print ""
    printf "catalog_plu dd "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", plu[i] }
    print ""
    printf "catalog_departments dw "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", department[i] }
    print ""
    printf "catalog_tax_class db "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", tax_class[i] }
    print ""
    printf "catalog_payment_flags db "
    for (i = 1; i <= count; i++) { if (i > 1) printf ", "; printf "%s", payment_flags[i] }
    print ""
    print "catalog_upcs:"
    for (i = 1; i <= count; i++) printf "    db \x27%s\x27,0\n", upc[i]
}
' "$input" > "$tmp"
mv "$tmp" "$output"
