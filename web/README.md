# CashOS browser demo

The browser demo boots a `build/demo.img` derived from the normal
`build/register.img` by provisioning LBA 66 as operator DEMO (employee ID
999). The CashOS executable bytes are the same. LBA 65 remains blank in the
public demo, so direct COM1/ZPL printing is intentionally disabled there. It does not recreate the register in HTML or JavaScript:
v86 emulates the PC, BIOS, VGA, keyboard, RAM, and floppy controller, and the
guest executes the CashOS boot sector and real-mode assembly.

## Local test

```sh
make web
make web-serve
```

Open `http://localhost:8000/`. Serve over HTTP rather than `file://`; the v86
WebAssembly and image assets are loaded as relative URLs.

## Dependency and licensing

The build pins the v86 npm package to `0.5.462` and fetches its matching
documented BIOS source commit into the generated site. v86 is distributed
under the Simplified BSD License; its BIOS directory includes the applicable
BIOS licensing notice. See `build/site/v86/LICENSE` and
`build/site/bios/COPYING.LESSER` after `make web`.

The deployed floppy is pristine per build. CashOS disk writes may change the
in-memory v86 floppy during a browser session, but this pass does not persist
them to GitHub Pages or IndexedDB.

Live demo: <https://luckymonkey.github.io/cashos/>

Source repository: <https://github.com/LuckyMonkey/cashos>
