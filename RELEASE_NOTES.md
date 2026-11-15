# DeskJet Scan — Release notes

## What this is

**DeskJet Scan** scans with an **HP DeskJet 2300 series** over **USB** when
HP Easy Scan / Image Capture cannot see the device.

This release is **self-contained**. The USB scan/print kit is included under
`driver/` — you do **not** need to clone any other repository.

## Requirements

- macOS 14 or later
- DeskJet 2300 series connected by USB and powered on

## Install

1. Download **DeskJet-Scan-*-macOS.zip** from this release.
2. Unzip the archive.
3. In Terminal:

   ```sh
   cd /path/to/DeskJet-Scan-*-macOS
   sh install.sh --scan-only
   ```

   Enter your Mac admin password when asked.  
   (Use `sh install.sh` if you also want USB printing.)

4. Confirm:

   ```sh
   hp-scan -L
   ```

5. Open **DeskJet Scan.app**.
   - If macOS blocks it: right-click → **Open** → **Open**.
   - The app is ad-hoc signed (not notarized).

## Use

1. Connect USB, power on, place the page **face down**.
2. Choose Color/Grayscale and dpi → **Scan**.
3. Files land in `~/Desktop/Scans/`.
4. Optional: **Rotate** / **Crop…** (overwrites the PNG).

## Troubleshooting

| Problem | What to try |
| --- | --- |
| `hp-scan` not found | Run `sh install.sh --scan-only` from this unzipped release folder. |
| No scanner found | Cable, power, another USB port; run `hp-scan -L`. |
| Gatekeeper | Right-click → Open, or `xattr -dr com.apple.quarantine "DeskJet Scan.app"` |

## Credits / licenses

- Scan/print engines: **HPLIP** (GPL/MIT/BSD) — see `driver/NOTICE.md`
- This project maintains its own `driver/` kit so it does not depend on
  third-party GitHub repos remaining online. Prior macOS packaging work is
  acknowledged in `driver/ATTRIBUTION.md`.

## Version

See the GitHub release tag.
