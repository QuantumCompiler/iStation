#!/bin/bash
# Builds the JIT probe as a hardened-runtime, App Sandbox macOS app in .build/<variant>/JITProbe.app.
#
#   ./build.sh                               App Store entitlements (sandbox + allow-jit), ad-hoc signed
#   ./build.sh nojit                         the control: sandbox, no allow-jit, ad-hoc signed
#   ./build.sh appstore "Apple Development: <Name> (<ID>)"   signed with your identity (your run)
#
# Then: .build/<variant>/JITProbe.app/Contents/MacOS/JITProbe --probe   (or open the app and press the button)
set -euo pipefail
cd "$(dirname "$0")"

variant="${1:-appstore}"
identity="${2:--}"
case "$variant" in
    appstore) entitlements=AppStore.entitlements ;;
    nojit) entitlements=NoJIT.entitlements ;;
    *) echo "usage: $0 [appstore|nojit] [signing identity]" >&2; exit 2 ;;
esac

app=".build/$variant/JITProbe.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -swift-version 6 -O -parse-as-library -target arm64-apple-macos14.0 \
    -import-objc-header Sources/OSCacheControl.h \
    Sources/JITProbe.swift -o "$app/Contents/MacOS/JITProbe"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --options runtime --entitlements "$entitlements" --sign "$identity" "$app"
codesign --display --verbose=2 "$app" 2>&1 | grep -E "^(Authority|Signature|CodeDirectory)" || true
codesign --display --entitlements - "$app" 2>/dev/null | grep -oE "com\.apple\.security\.[a-z.-]+" | sed 's/^/entitlement: /'
echo "Built $app"
