# CashOS catalog source

`catalog.csv` is the editable source for the fixed register catalog. Each row
has a key, display name, integer-cent price, store SKU, 12-digit UPC, optional
PLU, department code, tax class, and payment flags. `make` converts it to
`build/catalog.inc`, which the 16-bit register includes directly.

The current four rows are deliberately small. The future admin floppy can use
the same fixed-width fields and write an updated catalog into a reserved raw
floppy region; this pass does not implement that admin OS or runtime catalog
writes yet. Department and payment policy are deliberately data, not hidden
control-flow rules.
