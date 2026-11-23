#!/bin/bash
# Builds the bookmark probe as a hardened-runtime, App Sandbox macOS app in .build/<variant>/BookmarkProbe.app.
#
#   ./build.sh                               the macOS App Store entitlements (a copy of apps/macos/AppStore.entitlements), ad-hoc signed
#   ./build.sh appscope                      the control: the same plus files.bookmarks.app-scope, ad-hoc signed
#   ./build.sh appstore "Apple Development: <Name> (<ID>)"   signed with your identity
#
# Then: open .build/<variant>/BookmarkProbe.app, Choose a File…, quit, open it again
# (or, after the relaunch, .build/<variant>/BookmarkProbe.app/Contents/MacOS/BookmarkProbe --report).
# The control has its own identifier, so its container and its bookmark never mix with the App Store variant's.
set -euo pipefail
cd "$(dirname "$0")"

variant="${1:-appstore}"
identity="${2:--}"
case "$variant" in
    appstore) entitlements=AppStore.entitlements; identifier=local.istation.bookmark-probe; name="Bookmark Probe" ;;
    appscope) entitlements=AppScope.entitlements; identifier=local.istation.bookmark-probe.appscope; name="Bookmark Probe (app-scope)" ;;
    *) echo "usage: $0 [appstore|appscope] [signing identity]" >&2; exit 2 ;;
esac

# The probe answers for the App Store build only while its copy is that build's own entitlements.
if ! cmp -s AppStore.entitlements ../../apps/macos/AppStore.entitlements; then
    echo "AppStore.entitlements differs from apps/macos/AppStore.entitlements: copy it again, and AppScope.entitlements with it" >&2
    exit 1
fi

app=".build/$variant/BookmarkProbe.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -swift-version 6 -O -parse-as-library -target arm64-apple-macos14.0 \
    Sources/BookmarkProbe.swift -o "$app/Contents/MacOS/BookmarkProbe"
cp Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$identifier" "$app/Contents/Info.plist"
plutil -replace CFBundleName -string "$name" "$app/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$name" "$app/Contents/Info.plist"
codesign --force --options runtime --entitlements "$entitlements" --sign "$identity" "$app"
codesign --display --verbose=2 "$app" 2>&1 | grep -E "^(Identifier|Authority|Signature|CodeDirectory)" || true
codesign --display --entitlements - "$app" 2>/dev/null | grep -oE "com\.apple\.security\.[a-z.-]+" | sed 's/^/entitlement: /'
echo "Built $app"
