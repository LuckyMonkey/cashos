#!/bin/sh
set -eu

input=$1
output=$2
tmp="$output.tmp"

awk -F, '
BEGIN { count = 0 }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
{
    if ($1 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ || $1 > 99999 || $3 > 65535) {
        print "invalid PLU row: " $0 > "/dev/stderr"
        exit 1
    }
    count++
    code[count] = $1
    price[count] = $3
}
END {
    if (count == 0) exit 1
    print "; Generated from data/fruit_plu.csv. Do not edit by hand."
    print "; 32-bit PLU codes support conventional and organic entries."
    print "plu_count equ " count
    printf "plu_codes  dd "
    for (i = 1; i <= count; i++) {
        if (i > 1 && (i - 1) % 10 != 0) printf ", "
        printf "%s", code[i]
        if (i % 10 == 0 && i != count) { printf "\n           dd " }
    }
    print ""
    printf "plu_prices dw "
    for (i = 1; i <= count; i++) {
        if (i > 1 && (i - 1) % 10 != 0) printf ", "
        printf "%s", price[i]
        if (i % 10 == 0 && i != count) { printf "\n           dw " }
    }
    print ""
}
' "$input" > "$tmp"
mv "$tmp" "$output"
