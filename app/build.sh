#!/bin/sh
# Build an unsandboxed DeskJet Scan.app (universal arm64 + x86_64).
# Sandbox would block the USB scan helper (hp-scan).
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/dist/DeskJet Scan.app"
VERSION="${VERSION:-1.0.0}"
# CFBundleVersion: prefer numeric-looking tags, else timestamp.
BUILD_NUMBER="$(echo "$VERSION" | tr -cd '0-9')"
if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER="$(date +%Y%m%d%H%M)"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>DeskJet Scan</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>local.deskjet-scan</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>DeskJet Scan</string>
  <key>CFBundleDisplayName</key>
  <string>DeskJet Scan</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set -- "$ROOT/app/Sources/DeskJetScan/"*.swift

echo "Compiling arm64…"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
  -o "$TMP/DeskJetScan-arm64" \
  "$@" \
  -framework SwiftUI -framework AppKit

echo "Compiling x86_64…"
swiftc -parse-as-library -O -target x86_64-apple-macosx14.0 \
  -o "$TMP/DeskJetScan-x86_64" \
  "$@" \
  -framework SwiftUI -framework AppKit

lipo -create -output "$APP/Contents/MacOS/DeskJet Scan" \
  "$TMP/DeskJetScan-arm64" "$TMP/DeskJetScan-x86_64"

# Simple scanner icon so the Dock tile is recognizable.
ICONDIR="$TMP/AppIcon.iconset"
mkdir -p "$ICONDIR"
swift - "$ICONDIR" <<'SWIFT'
import AppKit
import Foundation

let dir = CommandLine.arguments[1]
let sizes = [16, 32, 64, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] where size * scale <= 1024 {
        let px = CGFloat(size * scale)
        let image = NSImage(size: NSSize(width: px, height: px), flipped: false) { rect in
            let bg = NSBezierPath(roundedRect: rect.insetBy(dx: px * 0.06, dy: px * 0.06), xRadius: px * 0.22, yRadius: px * 0.22)
            NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.62, alpha: 1).setFill()
            bg.fill()
            let page = NSBezierPath(roundedRect: NSRect(x: px * 0.28, y: px * 0.22, width: px * 0.44, height: px * 0.56), xRadius: px * 0.04, yRadius: px * 0.04)
            NSColor.white.setFill()
            page.fill()
            NSColor(calibratedWhite: 0.75, alpha: 1).setStroke()
            page.lineWidth = max(1, px * 0.015)
            page.stroke()
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            fputs("icon render failed\n", stderr)
            exit(1)
        }
        let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try png.write(to: url)
    }
}
SWIFT
iconutil -c icns "$ICONDIR" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP (v$VERSION, universal)"
