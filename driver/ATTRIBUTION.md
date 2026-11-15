# Attribution

This `driver/` tree is the **USB print + scan kit** maintained inside
[ahsanaasim/hp-deskjet-2300-series-macos-app](https://github.com/ahsanaasim/hp-deskjet-2300-series-macos-app).
It exists so the app does **not** depend on any third-party GitHub repository
staying online.

## What is original here

- Packaging layout and install scripts for this project
- The DeskJet Scan.app UI (outside this folder)
- Bugfix in `scanner/src/hp-scan.c` (list devices before freeing the SANE list)

## Upstream software (required credit)

### HPLIP — Hewlett-Packard Development Company, L.P.

Print filter (`bin/hpcups`), PPD, scanner backend, `models.dat`, and related
code come from **HPLIP 3.25.2**:

https://sourceforge.net/projects/hplip/files/hplip/3.25.2/

Licenses: GPL-2.0 / MIT / BSD (see `NOTICE.md`). Scanner binaries in
`scanner/` are distributed under **GPL-2.0**. Corresponding source to rebuild
them is `scanner/src/build-scanner.sh` plus the official HPLIP tarball (and
libusb as documented in `NOTICE.md`).

### Prior macOS packaging work

The macOS build recipe (universal `hpcups` / static `hp-scan`, Orblite stubs,
PPD `cupsFilter` path) was pioneered publicly by:

https://github.com/squatchus/hp-deskjet-2320-macos-driver

That project’s MIT-licensed scripts are acknowledged in
`LICENSE-SCRIPTS-UPSTREAM.txt`. This repository **vendors and maintains its own
copy** of the kit so users of DeskJet Scan are not broken if that remote
disappears. This is not an attempt to claim authorship of HPLIP or of that
earlier packaging effort.

### libusb / libjpeg-turbo

See `NOTICE.md`.

## Trademarks

HP and DeskJet are trademarks of HP Inc. This project is not affiliated with,
endorsed, or supported by HP Inc. or Apple Inc.
