#!/bin/sh
# ============================================================================
# Install the hpcups driver and create a print queue for the HP DeskJet 2320
# (DeskJet 2300 series) connected over USB on macOS.
#
# Usage:  sudo sh setup.sh
#
# What it does:
#   1. Removes the quarantine attribute from the kit files
#   2. Installs bin/hpcups        -> /Library/Printers/hplip/hpcups
#   3. Installs the PPD           -> /Library/Printers/PPDs/Contents/Resources/
#   4. Finds the printer on USB and (re)creates the CUPS queue HP_DeskJet_2320
# ============================================================================
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo:  sudo sh $0" >&2
  exit 1
fi

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # driver/ kit root
PPD_NAME="HP DeskJet 2300 series hpcups.ppd"

[ -f "$KIT_DIR/bin/hpcups" ] || { echo "bin/hpcups not found — run 'bash scripts/build.sh' first or download a release" >&2; exit 1; }

# 1. Quarantine flags appear when files are copied via AirDrop/browser
xattr -dr com.apple.quarantine "$KIT_DIR" 2>/dev/null || true

# 2-3. Filter + PPD
mkdir -p /Library/Printers/hplip
install -m 755 "$KIT_DIR/bin/hpcups" /Library/Printers/hplip/hpcups
install -m 644 "$KIT_DIR/ppd/$PPD_NAME" "/Library/Printers/PPDs/Contents/Resources/$PPD_NAME"

# 4. Find the printer on USB
URI="$(/usr/libexec/cups/backend/usb 2>/dev/null | awk '{print $2}' | grep -i 'usb://HP/DeskJet' | head -1)"
if [ -z "$URI" ]; then
  echo "No DeskJet found on USB. Check the cable and power." >&2
  exit 1
fi
echo "==> Found printer: $URI"

lpadmin -x HP_DeskJet_2320 2>/dev/null || true
lpadmin -p HP_DeskJet_2320 \
  -v "$URI" \
  -P "/Library/Printers/PPDs/Contents/Resources/$PPD_NAME" \
  -D "HP DeskJet 2320" \
  -L "USB" \
  -o printer-error-policy=retry-current-job \
  -E

echo ""
echo "Done. Queue 'HP_DeskJet_2320' is ready."
echo "Test it:  echo test | lp -d HP_DeskJet_2320"
