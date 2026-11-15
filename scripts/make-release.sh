#!/bin/sh
# Build DeskJet Scan and pack a self-contained GitHub release
# (app + driver kit + install.sh + notes).
#
# Usage:
#   sh scripts/make-release.sh           # default 1.0.0
#   sh scripts/make-release.sh 1.1.0
set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-1.0.0}"
NAME="DeskJet-Scan-${VERSION}-macOS"
OUT_DIR="$ROOT/release/$NAME"
ZIP="$ROOT/release/$NAME.zip"

if [ ! -x "$ROOT/driver/scanner/hp-scan" ]; then
  echo "Missing driver/scanner/hp-scan — vendor the driver kit first." >&2
  exit 1
fi

echo "==> Building app (universal)"
VERSION="$VERSION" sh "$ROOT/app/build.sh"

APP="$ROOT/dist/DeskJet Scan.app"
if [ ! -d "$APP" ]; then
  echo "Build failed: missing $APP" >&2
  exit 1
fi

echo "==> Staging release folder (app + driver kit)"
rm -rf "$OUT_DIR" "$ZIP"
mkdir -p "$OUT_DIR"
cp -R "$APP" "$OUT_DIR/"
cp "$ROOT/install.sh" "$OUT_DIR/install.sh"
chmod +x "$OUT_DIR/install.sh"
cp -R "$ROOT/driver" "$OUT_DIR/driver"
chmod +x "$OUT_DIR/driver/scripts/"*.sh \
  "$OUT_DIR/driver/scanner/scan-setup.sh" \
  "$OUT_DIR/driver/scanner/src/build-scanner.sh" \
  "$OUT_DIR/driver/scanner/hp-scan" \
  "$OUT_DIR/driver/bin/hpcups"
cp "$ROOT/RELEASE_NOTES.md" "$OUT_DIR/RELEASE_NOTES.md"
cp "$ROOT/README.md" "$OUT_DIR/README.md"

xattr -cr "$OUT_DIR/DeskJet Scan.app" 2>/dev/null || true
xattr -cr "$OUT_DIR/driver" 2>/dev/null || true

echo "==> Creating zip"
mkdir -p "$ROOT/release"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$OUT_DIR" "$ZIP"

echo ""
echo "Release ready:"
echo "  $OUT_DIR"
echo "  $ZIP"
echo ""
echo "Upload the zip to a GitHub Release and paste RELEASE_NOTES.md into the description."
ls -lh "$ZIP"
file "$OUT_DIR/DeskJet Scan.app/Contents/MacOS/DeskJet Scan"
