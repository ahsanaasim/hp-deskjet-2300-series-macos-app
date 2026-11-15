# DeskJet Scan — Release notes

## What this is

**DeskJet Scan** is a lightweight macOS app for scanning with an **HP DeskJet 2300 series** printer connected over **USB**.

Use this when **HP Easy Scan** / Image Capture does not detect the scanner.

## Requirements

- macOS 14 or later
- DeskJet 2300 series connected by USB and powered on
- The community driver / `hp-scan` tool installed first:

  https://github.com/squatchus/hp-deskjet-2320-macos-driver

  ```sh
  git clone https://github.com/squatchus/hp-deskjet-2320-macos-driver.git
  cd hp-deskjet-2320-macos-driver
  sh install.sh
  hp-scan -L
  ```

## Install (from this release)

1. Download **DeskJet-Scan-*-macOS.zip** from the release assets.
2. Unzip the archive.
3. Drag **DeskJet Scan.app** to your **Applications** folder (or the Desktop).
4. Open it.
   - If macOS says the app can’t be opened because it is from an unidentified developer: right-click the app → **Open** → **Open**.
   - The release build is ad-hoc signed (not notarized).

## Use

1. Connect the printer over USB and turn it on.
2. Launch **DeskJet Scan**.
3. Confirm the scanner appears in the **Scanner** list (use **Refresh** if needed).
4. Choose **Color** or **Grayscale** and a resolution.
5. Place the page **face down** on the glass.
6. Click **Scan**.

Files are written to:

```text
~/Desktop/Scans/
```

After a scan you can:

- **Rotate Left / Rotate Right**
- **Crop…** (drag the box, then **Apply Crop**)

Edits overwrite the same PNG on disk. **Show in Finder** selects the last saved file.

## Troubleshooting

| Problem | What to try |
| --- | --- |
| App says `hp-scan` is not installed | Run the DeskJet driver `install.sh`, then confirm `/Library/Printers/hplip/hp-scan` exists. |
| No scanner found | USB cable, power on, try another port; run `hp-scan -L` in Terminal. |
| Gatekeeper blocks the app | Right-click → **Open**, or remove quarantine: `xattr -dr com.apple.quarantine "/Applications/DeskJet Scan.app"` |
| `hp-scan -L` exits with code 1 | If a device line is printed, discovery worked; the exit code quirk is known. |

## Version

See the GitHub release tag for the exact version of this build.
