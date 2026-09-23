# CashOS produce PLUs

`fruit_plu.csv` is the editable source list for the produce lookup table.
`make` converts it to `build/fruit_plu.inc`, the flat NASM include consumed by
the guest build. Its parallel `plu_codes` and `plu_prices` arrays are
intentionally easy to audit.

The codes are common IFPS produce PLUs. IFPS assigns a PLU to identify a
commodity/variety/production method; it does not set CashOS's selling price.
The prices in this file are therefore local demo defaults in integer cents.
Organic entries use the conventional code with a leading `9`, as specified by
the PLU convention.

Reference: <https://www.ifpsglobal.com/plu-codes>
