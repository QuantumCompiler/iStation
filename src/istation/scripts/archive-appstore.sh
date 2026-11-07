#!/bin/bash
# The App Store routine (ADR 0016): archives one app in its Release configuration into
# src/istation/build/<platform>/iStation.xcarchive.
#
#   ./scripts/archive-appstore.sh macOS
#   ./scripts/archive-appstore.sh iOS
#
# Without ISTATION_TEAM_ID the archive is not signed for distribution (macOS: ad-hoc; iOS: unsigned).
# With ISTATION_TEAM_ID=<your team ID>, Xcode signs it with your team and exports it for App Store
# Connect into build/<platform>/export. Signing, uploading and submitting are yours.
set -euo pipefail
cd "$(dirname "$0")/../../.."

platform="${1:-}"
case "$platform" in
    macOS) destination="generic/platform=macOS" ;;
    iOS) destination="generic/platform=iOS" ;;
    *) echo "usage: $0 macOS|iOS" >&2; exit 2 ;;
esac

out="src/istation/build/$platform"
archive="$out/iStation.xcarchive"
signing=()
if [ -n "${ISTATION_TEAM_ID:-}" ]; then
    signing=(DEVELOPMENT_TEAM="$ISTATION_TEAM_ID" CODE_SIGN_IDENTITY="Apple Distribution")
elif [ "$platform" = iOS ]; then
    signing=(CODE_SIGNING_ALLOWED=NO)
fi

rm -rf "$archive"
xcodebuild archive -project iStation.xcodeproj -scheme "$platform App Store" -destination "$destination" \
    -archivePath "$archive" ${signing[@]+"${signing[@]}"}

if [ -n "${ISTATION_TEAM_ID:-}" ]; then
    options="$out/ExportOptions.plist"
    cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>$ISTATION_TEAM_ID</string>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$options"
fi
echo "Archived $archive"
