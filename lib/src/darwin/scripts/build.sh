#!/bin/bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# The Apple apps' one build entry point (Apogee's form): a routine and a platform.
#
#   lib/src/darwin/scripts/build.sh personal macOS|iOS    the personal routine (build-personal.sh)
#   lib/src/darwin/scripts/build.sh appstore macOS|iOS    the App Store routine (archive-appstore.sh)
#
# The two routines' scripts stay its helpers until lib/scripts/cicd.sh becomes the one path (4d).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

routine="${1:-}"
platform="${2:-}"
case "$routine" in
    personal) exec "$here/build-personal.sh" "$platform" ;;
    appstore) exec "$here/archive-appstore.sh" "$platform" ;;
    *) echo "usage: $0 personal|appstore macOS|iOS" >&2; exit 2 ;;
esac
