#!/bin/sh
set -eu

IMAGE=${1:-build/register.img}
QEMU=${QEMU:-qemu-system-i386}

run_case() {
    name=$1
    shift
    log="build/guard-${name}.log"
    vga="build/guard-${name}.vga"
    rm -f "$log" "$vga"
    {
        sleep 1
        for key in "$@"; do
            printf 'sendkey %s\n' "$key"
            sleep .12
        done
        printf 'pmemsave 0xb8000 4000 %s\n' "$vga"
        sleep .3
        printf 'quit\n'
    } | timeout 12s "$QEMU" -machine pc -m 64M \
        -drive file="$IMAGE",format=raw,if=floppy -boot order=a \
        -display none -monitor stdio -debugcon "file:$log" \
        -global isa-debugcon.iobase=0xe9 >/dev/null 2>&1 || true
}

assert_row() {
    file=$1
    row=$2
    text=$3
    perl -0777 -e '
        my ($file, $row, $needle) = @ARGV;
        open my $fh, "<:raw", $file or die "$file: $!";
        local $/;
        my $data = <$fh>;
        my $line = "";
        for my $col (0 .. 79) {
            my $ch = ord substr($data, ($row * 80 + $col) * 2, 1);
            $line .= ($ch >= 32 && $ch < 127) ? chr($ch) : " ";
        }
        die "row $row missing [$needle], got [$line]\n" unless index($line, $needle) >= 0;
    ' "$file" "$row" "$text"
}

run_case empty ret
assert_row build/guard-empty.vga 16 'NO ITEMS - ADD AN ITEM BEFORE ENTER'

run_case quantity_without_price x
assert_row build/guard-quantity_without_price.vga 16 'PRESS P AND ENTER A PRICE BEFORE X'

run_case zero_price p 0 ret
assert_row build/guard-zero_price.vga 16 'PRICE MUST BE 1..65535 CENTS'

run_case bad_tax t 9 9 9 ret
assert_row build/guard-bad_tax.vga 16 'TAX MUST BE 0..99 PERCENT'

run_case ebt_split 1 2 e
assert_row build/guard-ebt_split.vga 13 'EBT ELIG:'
assert_row build/guard-ebt_split.vga 13 '$2.50'
assert_row build/guard-ebt_split.vga 14 'BALANCE:'
assert_row build/guard-ebt_split.vga 14 '$3.25'

run_case ebt_commit 1 2 e ret
grep -q 'EBT_APPLIED=250' build/guard-ebt_commit.log
grep -q 'BALANCE_DUE=325' build/guard-ebt_commit.log
if grep -q 'PAYMENT_REJECTED' build/guard-ebt_commit.log; then
    echo 'FAIL: mixed EBT basket was rejected' >&2
    exit 1
fi

run_case input_limit p 9 9 9 9 9 9
assert_row build/guard-input_limit.vga 16 'INPUT LIMIT REACHED - BACKSPACE TO EDIT'

run_case barcode_limit b 0 1 2 3 4 5 6 7 8 9 0 1 2
assert_row build/guard-barcode_limit.vga 16 'INPUT LIMIT REACHED - BACKSPACE TO EDIT'

run_case cart_full 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
assert_row build/guard-cart_full.vga 16 'CART FULL - COMPLETE SALE OR CLEAR'

echo 'PASS: guarded input/error paths reported visible failures'
