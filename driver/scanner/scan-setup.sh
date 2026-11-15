#!/bin/sh
# Install the self-contained hp-scan tool for DeskJet 2300 series on macOS.
# Usage: sudo sh scan-setup.sh
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo:  sudo sh $0" >&2
  exit 1
fi

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"

xattr -dr com.apple.quarantine "$KIT_DIR" 2>/dev/null || true

mkdir -p /Library/Printers/hplip /Library/Printers/hplip/share/hplip/data/models /etc/hp
install -m 755 "$KIT_DIR/hp-scan" /Library/Printers/hplip/hp-scan
install -m 644 "$KIT_DIR/models.dat" /Library/Printers/hplip/share/hplip/data/models/models.dat

cat > /etc/hp/hplip.conf <<CONF
[hplip]
version=3.25.2

[dirs]
home=/Library/Printers/hplip/share/hplip
CONF

ln -sf /Library/Printers/hplip/hp-scan /usr/local/bin/hp-scan 2>/dev/null || true

# Optional: hook into Homebrew sane-backends when present (Apple Silicon).
BP="$(su "${SUDO_USER:-$USER}" -c 'brew --prefix' 2>/dev/null || true)"
if [ -n "$BP" ] && [ -d "$BP/opt/sane-backends" ] && [ "$(uname -m)" = "arm64" ]; then
  mkdir -p /Library/Printers/hplip/sane
  install -m 755 "$KIT_DIR/libsane-hpaio.1.dylib" /Library/Printers/hplip/sane/
  SANE_LIB="$(ls -d "$BP"/Cellar/sane-backends/*/lib/sane 2>/dev/null | head -1)"
  if [ -n "$SANE_LIB" ]; then
    ln -sf /Library/Printers/hplip/sane/libsane-hpaio.1.dylib "$SANE_LIB/libsane-hpaio.1.so"
    grep -q '^hpaio' "$BP/etc/sane.d/dll.conf" 2>/dev/null || echo hpaio >> "$BP/etc/sane.d/dll.conf"
    echo "Also linked the SANE backend for scanimage."
  fi
fi

echo ""
echo "Done. Check:  hp-scan -L"
echo "Scan:         hp-scan -m Color -r 300 -o scan.png"
