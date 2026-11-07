#!/bin/bash
# The personal routine (ADR 0016): builds one app in its Debug configuration — PERSONAL_BUILD,
# get-task-allow, JIT on — into src/istation/build/DerivedData. Never distributed.
#
#   ./scripts/build-personal.sh macOS     signed to run locally; open the printed .app
#   ./scripts/build-personal.sh iOS       for the iOS Simulator
set -euo pipefail
cd "$(dirname "$0")/../../.."

platform="${1:-}"
case "$platform" in
    macOS) destination="platform=macOS"; products="Debug" ;;
    iOS) destination="generic/platform=iOS Simulator"; products="Debug-iphonesimulator" ;;
    *) echo "usage: $0 macOS|iOS" >&2; exit 2 ;;
esac

derived="src/istation/build/DerivedData"
xcodebuild build -project iStation.xcodeproj -scheme "$platform Personal" -destination "$destination" -derivedDataPath "$derived"
echo "Built $derived/Build/Products/$products/iStation.app"
