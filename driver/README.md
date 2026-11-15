# Driver kit (DeskJet 2300 series on macOS)

Self-contained USB **print** and **scan** support for the HP DeskJet 2300
series, shipped inside this repository.

You do **not** need to clone any other GitHub project.

## Install

From the repository root (or from a release folder that includes `driver/`):

```sh
sh install.sh --scan-only   # enough for DeskJet Scan.app
# or
sh install.sh               # printing + scanning
```

## Rebuild from source (optional)

```sh
# Print filter (needs cups / jpeg headers — see scripts/build.sh)
sh driver/scripts/build.sh

# Scanner stack (downloads HPLIP + libusb, needs Xcode CLT only)
sh driver/scanner/src/build-scanner.sh
```

## License

- Our packaging scripts: see repo root and `ATTRIBUTION.md`
- HPLIP-derived binaries: `NOTICE.md` (scanner = GPL-2.0)
