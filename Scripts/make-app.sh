#!/bin/bash
# Assembles PortAuthority.app from the SwiftPM build products.
#
# SwiftPM cannot emit an app bundle, and a menu bar app needs one: LSUIElement
# is what keeps it out of the Dock, and that only exists in an Info.plist.
#
# Usage: Scripts/make-app.sh [output-dir]   (default: dist/)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
APP="$OUT/PortAuthority.app"
VERSION="$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo "0.1.0")"

cd "$ROOT"
swift build -c release --product PortAuthorityApp
swift build -c release --product portauth

BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/PortAuthorityApp" "$APP/Contents/MacOS/PortAuthority"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>PortAuthority</string>
    <key>CFBundleIdentifier</key><string>com.nickkrstevski.PortAuthority</string>
    <key>CFBundleName</key><string>Port Authority</string>
    <key>CFBundleDisplayName</key><string>Port Authority</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <!-- Menu bar only: no Dock icon, no main window. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT</string>
</dict>
</plist>
PLIST

# Ad-hoc signature. Locally built binaries are not quarantined, so this is
# sufficient; a notarised Developer ID signature is only needed if the app is
# ever distributed as a download rather than built on the user's machine.
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
    echo "warning: ad-hoc codesign failed; the app may not launch" >&2

echo "$APP"
