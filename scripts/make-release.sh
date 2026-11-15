#!/bin/sh
# Build DeskJet Scan and pack a GitHub release folder + zip.
#
# Usage:
#   sh scripts/make-release.sh           # version from Info.plist / default 1.0.0
#   sh scripts/make-release.sh 1.0.1
#
# Output:
#   release/DeskJet-Scan-<version>-macOS/
#   release/DeskJet-Scan-<version>-macOS.zip
set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-1.0.0}"
NAME="DeskJet-Scan-${VERSION}-macOS"
OUT_DIR="$ROOT/release/$NAME"
ZIP="$ROOT/release/$NAME.zip"

echo "==> Building app (universal)"
VERSION="$VERSION" sh "$ROOT/app/build.sh"

APP="$ROOT/dist/DeskJet Scan.app"
if [ ! -d "$APP" ]; then
  echo "Build failed: missing $APP" >&2
  exit 1
fi

echo "==> Staging release folder"
rm -rf "$OUT_DIR" "$ZIP"
mkdir -p "$OUT_DIR"
cp -R "$APP" "$OUT_DIR/"
cp "$ROOT/RELEASE_NOTES.md" "$OUT_DIR/RELEASE_NOTES.md"

# Strip Finder quarantine so a locally built zip is easier to open;
# downloads from GitHub may still get quarantined by the browser.
xattr -cr "$OUT_DIR/DeskJet Scan.app" 2>/dev/null || true

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
