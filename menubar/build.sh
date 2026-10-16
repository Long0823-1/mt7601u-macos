#!/bin/bash
# Builds "MT7601U Wi-Fi.app" (menu bar app, no Dock icon). Usage: menubar/build.sh [output-dir]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/build}"
APP="$OUT/MT7601U Wi-Fi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/MT7601UWiFi" "$HERE/MT7601UWiFi.swift"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MT7601UWiFi</string>
  <key>CFBundleIdentifier</key><string>local.mt7601u.wifi</string>
  <key>CFBundleName</key><string>MT7601U Wi-Fi</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" 2>/dev/null || true
echo "built: $APP"
