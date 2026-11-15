# DeskJet Scan

A small macOS app for the **HP DeskJet 2300 series** flatbed scanner, plus a
**self-contained USB driver kit** in [`driver/`](driver/).

HP Easy Scan does not list this printer (no Image Capture / AirScan path). This
project speaks the printer’s USB LEDM scanner stack through `hp-scan`, built
from **HPLIP** sources and packaged here so you are **not** dependent on any
other GitHub repository.

## Prerequisites

- macOS 14+
- DeskJet 2300 series on USB
- Xcode Command Line Tools only if you build the app from source:
  `xcode-select --install`

## Install driver support (required once)

Everything lives in this repo under `driver/`. No external clone.

```sh
git clone git@github.com:ahsanaasim/hp-deskjet-2300-series-macos-app.git
cd hp-deskjet-2300-series-macos-app

# Enough for the scan app:
sh install.sh --scan-only

# Or printing + scanning:
sh install.sh
```

Check:

```sh
hp-scan -L
```

Attribution and licenses for the kit: [`driver/ATTRIBUTION.md`](driver/ATTRIBUTION.md),
[`driver/NOTICE.md`](driver/NOTICE.md).

## How to run (from a release)

1. Download **DeskJet-Scan-*-macOS.zip** from
   [Releases](https://github.com/ahsanaasim/hp-deskjet-2300-series-macos-app/releases).
2. Unzip. You get `DeskJet Scan.app`, `install.sh`, and `driver/`.
3. Run **`sh install.sh --scan-only`** once (admin password).
4. Open **DeskJet Scan.app** (right-click → Open the first time if Gatekeeper warns).
5. Scan; files go to `~/Desktop/Scans/`.

Details: [`RELEASE_NOTES.md`](RELEASE_NOTES.md).

## How to run (from source)

```sh
sh install.sh --scan-only
sh app/build.sh
open "dist/DeskJet Scan.app"
```

## How to build

### App only

```sh
sh app/build.sh
# → dist/DeskJet Scan.app  (universal arm64 + x86_64)
```

### Release zip (app + driver kit + notes)

```sh
sh scripts/make-release.sh 1.1.0
# → release/DeskJet-Scan-1.1.0-macOS.zip
```

### Rebuild HPLIP binaries (optional)

```sh
sh driver/scripts/build.sh                 # hpcups
sh driver/scanner/src/build-scanner.sh     # hp-scan (+ downloads HPLIP/libusb)
```

## Features

- Color / grayscale @ 75–600 dpi
- Progress ring while scanning; reveal animation when done
- Rotate and crop (saves over the PNG)

## Credits

- **HPLIP** — HP Development Company (print/scan engines, `models.dat`)
- macOS packaging approach originally demonstrated by
  [squatchus/hp-deskjet-2320-macos-driver](https://github.com/squatchus/hp-deskjet-2320-macos-driver);
  this repo vendors and maintains its own kit so releases stay self-contained
- **DeskJet Scan.app** — this project
