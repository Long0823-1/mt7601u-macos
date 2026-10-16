#!/bin/bash
# Builds dist/MT7601U-WiFi-<version>.pkg (GUI installer). Needs Xcode command line tools. Usage: installer/build-pkg.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER=0.1
W="$ROOT/installer/build"
rm -rf "$W"; mkdir -p "$W/root" "$ROOT/dist"
make -C "$ROOT/port" mt7601ud
"$ROOT/menubar/build.sh" "$W/app"
[ -f "$ROOT/mt7601u/mt7601u.bin" ] || "$ROOT/scripts/fetch-firmware.sh"
R="$W/root"
install -d "$R/usr/local/libexec/mt7601u" "$R/usr/local/share/mt7601u" "$R/usr/local/bin" "$R/Applications" "$R/Library/LaunchDaemons" "$R/Library/LaunchAgents"
install -m 755 "$ROOT/port/mt7601ud" "$R/usr/local/libexec/mt7601u/mt7601ud"
install -m 755 "$ROOT/install/uninstall.sh" "$R/usr/local/libexec/mt7601u/uninstall.sh"
install -m 644 "$ROOT/mt7601u/mt7601u.bin" "$R/usr/local/share/mt7601u/mt7601u.bin"
install -m 755 "$ROOT/bin/mt7601u-wifi" "$R/usr/local/bin/mt7601u-wifi"
cp -R "$W/app/MT7601U Wi-Fi.app" "$R/Applications/"
cat > "$R/Library/LaunchDaemons/local.mt7601ud.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.mt7601ud</string>
  <key>ProgramArguments</key><array><string>/usr/local/libexec/mt7601u/mt7601ud</string><string>daemon</string></array>
  <key>EnvironmentVariables</key><dict><key>RTW89_FW_DIR</key><string>/usr/local/share/mt7601u</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardErrorPath</key><string>/var/log/mt7601ud.log</string>
  <key>StandardOutPath</key><string>/var/log/mt7601ud.log</string>
</dict></plist>
PLIST
cat > "$R/Library/LaunchAgents/local.mt7601u.wifi.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.mt7601u.wifi</string>
  <key>ProgramArguments</key><array><string>/Applications/MT7601U Wi-Fi.app/Contents/MacOS/MT7601UWiFi</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLIST
chmod +x "$ROOT/installer/scripts/"*
# never relocate the app bundle: otherwise the installer overwrites any other copy with the same bundle id (e.g. a build directory)
pkgbuild --analyze --root "$R" "$W/component.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$W/component.plist"
plutil -replace 0.BundleIsVersionChecked -bool NO "$W/component.plist"
pkgbuild --root "$R" --component-plist "$W/component.plist" --identifier local.mt7601u.pkg --version $VER --scripts "$ROOT/installer/scripts" --install-location / "$W/component.pkg"
productbuild --distribution "$ROOT/installer/distribution.xml" --resources "$ROOT/installer/resources" --package-path "$W" "$ROOT/dist/MT7601U-WiFi-$VER.pkg"
echo "built: $ROOT/dist/MT7601U-WiFi-$VER.pkg"
