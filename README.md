# DeskJet Scan

A small macOS app for the **HP DeskJet 2300 series** flatbed scanner.

HP Easy Scan does not list this printer. The scanner speaks HP LEDM over a vendor USB interface, while Easy Scan only discovers Image Capture and AirScan / Bonjour devices. This app is a window around [`hp-scan`](https://github.com/squatchus/hp-deskjet-2320-macos-driver) from the community DeskJet driver — it does not embed or reverse-engineer HP Easy Scan’s binary.

## Prerequisites

1. **macOS 14+** (Apple Silicon or Intel)
2. **Xcode Command Line Tools** (for building from source):

   ```sh
   xcode-select --install
   ```

3. **`hp-scan` installed** (from the DeskJet driver):

   ```sh
   git clone https://github.com/squatchus/hp-deskjet-2320-macos-driver.git
   cd hp-deskjet-2320-macos-driver
   sh install.sh
   ```

   Confirm the scanner is visible:

   ```sh
   hp-scan -L
   ```

   You should see a line like:

   ```text
   /usb/DeskJet_2300_series?serial=…  (Hewlett-Packard DeskJet_2300_series)
   ```

   Note: `hp-scan -L` may exit with code `1` even when a device is listed. That is a known quirk; a printed device line means discovery worked.

## How to run (from a release)

1. Install the DeskJet driver / `hp-scan` (see Prerequisites).
2. Download **DeskJet-Scan-macOS.zip** from the GitHub release.
3. Unzip it.
4. Move **DeskJet Scan.app** to Applications (or leave it on the Desktop).
5. Open the app (right-click → **Open** the first time if macOS blocks an unsigned app).
6. Connect the DeskJet over USB, power it on, put the page face down, then click **Scan**.

Scans are saved to `~/Desktop/Scans/`.

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for install notes shipped with each release.

## How to run (from source)

```sh
git clone <this-repo-url>
cd hp-scanner
sh app/build.sh
open "dist/DeskJet Scan.app"
```

## How to build

### Dev build (local `.app`)

```sh
sh app/build.sh
```

Output:

```text
dist/DeskJet Scan.app
```

The binary is a **universal** Mach-O (arm64 + x86_64), ad-hoc signed.

### Release package (zip + notes)

```sh
sh scripts/make-release.sh
```

Optional version tag:

```sh
sh scripts/make-release.sh 1.0.0
```

Output:

```text
release/DeskJet-Scan-<version>-macOS/
  DeskJet Scan.app
  RELEASE_NOTES.md
release/DeskJet-Scan-<version>-macOS.zip
```

Upload the `.zip` (and paste `RELEASE_NOTES.md`) when creating a GitHub Release.

## Features

- Color / grayscale scan at 75–600 dpi
- Progress ring in the preview while scanning (`hp-scan` does not report percent)
- Reveal animation when the scan finishes
- Rotate left / right and crop (edits overwrite the saved PNG)

## License / credit

- App UI and scripts: use as you like for this project.
- Scanning depends on HPLIP-derived `hp-scan` from [squatchus/hp-deskjet-2320-macos-driver](https://github.com/squatchus/hp-deskjet-2320-macos-driver) (GPLv2 for the scanner stack). Install that driver separately; this repo does not redistribute those binaries.
