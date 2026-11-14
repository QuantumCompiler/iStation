#!/bin/bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# The Apple apps' one build entry point (Apogee's form): a routine and a platform.
#
#   lib/src/darwin/scripts/build.sh personal macOS|iOS [--unsigned]   the personal routine (build-personal.sh)
#   lib/src/darwin/scripts/build.sh appstore macOS|iOS    the App Store routine (archive-appstore.sh)
#
# The two routines' scripts stay its helpers until lib/scripts/cicd.sh becomes the one path (4d).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

# The apps' version follows the release: lib/release/VERSION is the one place it is edited (4c).
version="$(tr -d ' \r\n' <"$here/../../../release/VERSION")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "lib/release/VERSION must hold x.y.z (got '$version')" >&2; exit 2; }
config="$here/../apps/Config/Version.xcconfig"
if ! grep -qx "MARKETING_VERSION = $version" "$config"; then
    sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $version/" "$config"
    echo "MARKETING_VERSION is now $version, from lib/release/VERSION"
fi

routine="${1:-}"
platform="${2:-}"
case "$routine" in
    personal) exec "$here/build-personal.sh" "$platform" "${3:-}" ;;
    appstore) exec "$here/archive-appstore.sh" "$platform" ;;
    *) echo "usage: $0 personal macOS|iOS [--unsigned] | appstore macOS|iOS" >&2; exit 2 ;;
esac
