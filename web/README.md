# CashOS browser demo

The browser demo boots the same `build/register.img` produced by the normal
CashOS Makefile. It does not recreate the register in HTML or JavaScript:
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
