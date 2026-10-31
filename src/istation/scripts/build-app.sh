#!/bin/bash
# Builds iStation in release mode and wraps it in a proper .app bundle (build/iStation.app),
# ad-hoc signed so Gatekeeper lets it run on this Mac. Developer ID signing and notarization
# are v1.0.0's (SPEC.md → Distribution).
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

APP="build/iStation.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/iStation" "$APP/Contents/MacOS/iStation"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>iStation</string>
    <key>CFBundleDisplayName</key><string>iStation</string>
    <key>CFBundleIdentifier</key><string>local.istation.iStation</string>
    <key>CFBundleExecutable</key><string>iStation</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
