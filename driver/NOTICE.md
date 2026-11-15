# Third-party notices

## HPLIP (HP Linux Imaging and Printing)

`bin/hpcups` is compiled from the sources of HPLIP 3.25.2 (`prnt/hpcups/*` and
`common/utils.c`), and `ppd/HP DeskJet 2300 series hpcups.ppd` is HPLIP's
`ppd/hpcups/hp-deskjet_2300_series.ppd` with the `*cupsFilter` line pointed at
an absolute macOS install path.

- Copyright © Hewlett-Packard Development Company, L.P.
- The hpcups filter sources carry a BSD 3-clause license header permitting
  redistribution in source and binary forms.
- HPLIP as a whole is distributed under the GNU GPL v2, MIT and BSD licenses
  (see `COPYING` inside the HPLIP tarball).
- Official sources: https://sourceforge.net/projects/hplip/files/hplip/3.25.2/
- `scripts/build.sh` reproduces the print filter from those sources.

## HPLIP scanner components

`scanner/hp-scan` and `scanner/libsane-hpaio.1.dylib` are compiled from
HPLIP 3.25.2: the hpaio SANE backend (`scan/sane/*`), the hpmud USB transport
(`io/hpmud/*`), the image-processing library (`ip/*`) and `common/utils.c`.
`scanner/models.dat` is HPLIP's device database, redistributed verbatim.

- Copyright © Hewlett-Packard Development Company, L.P.
- These components are distributed under HPLIP's licenses (GNU GPL v2, MIT and
  BSD). Accordingly, the binaries in `scanner/` are distributed under the
  **GNU GPL v2**.
- macOS port adaptations and the `hp-scan` frontend live in
  `scanner/src/build-scanner.sh` and `scanner/src/hp-scan.c`. Rebuild with
  that script against the official HPLIP 3.25.2 tarball.

## libjpeg-turbo

The arm64 slice of `bin/hpcups` may statically link libjpeg-turbo
(BSD-style: IJG, Modified 3-clause BSD, zlib). https://libjpeg-turbo.org/

## libusb

`scanner/hp-scan` and `scanner/libsane-hpaio.1.dylib` statically link
**libusb 1.0.x**, © the libusb contributors, **GNU LGPL v2.1**.
https://libusb.info/

Relink with a modified libusb via `scanner/src/build-scanner.sh`.

## Further credit

See `ATTRIBUTION.md`.
