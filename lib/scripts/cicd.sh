#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# cicd.sh — iStation's one build path: the same command a developer runs and CI runs (Apogee's form,
# v0.0.1 item 4d).
#
#   cicd.sh [--app darwin] [--test] [--docs] [--all]
#
#   --app darwin   build both Apple apps' personal routine, unsigned (macOS, and iOS for the Simulator),
#                  through the app's own scripts/build.sh — CI never signs
#   --test         the strict build and `swift test` (the architecture checks with them: the layer law,
#                  the routines' entitlements, the version's carriers)
#   --docs         the docs validator
#   --all          all three
#
# Each application under lib/src/<app>/ owns its build; this script drives it. Its pipeline in CI
# (.github/workflows/darwin.yml) runs `--app darwin --test` and ci.yml runs `--docs`, so neither builds
# another's. Nothing here needs the network, a BIOS or a game.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
APPS=(darwin)
app="" test=0 docs=0
while [ $# -gt 0 ]; do
    case "$1" in
        --app) app="${2:-}"; shift ;;
        --test) test=1 ;;
        --docs) docs=1 ;;
        --all) app=darwin test=1 docs=1 ;;
        -h | --help) sed -n '7,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "cicd.sh: unknown argument $1 (see --help)" >&2; exit 2 ;;
    esac
    shift
done
if [ -n "$app" ] && [[ ! " ${APPS[*]} " =~ " $app " ]]; then
    echo "cicd.sh: no application named $app (known: ${APPS[*]})" >&2
    exit 2
fi
[ -n "$app" ] || [ "$test" = 1 ] || [ "$docs" = 1 ] || { echo "cicd.sh: nothing to do (see --help)" >&2; exit 2; }

step() { printf '\n== %s\n' "$*"; }

if [ "$test" = 1 ]; then
    step "darwin: the strict build"
    (cd "$root/lib/src/darwin" && swift build --explicit-target-dependency-import-check=error)
    step "darwin: swift test"
    (cd "$root/lib/src/darwin" && swift test)
fi
if [ "$app" = darwin ]; then
    step "darwin: the macOS app, personal routine, unsigned"
    "$root/lib/src/darwin/scripts/build.sh" personal macOS --unsigned
    step "darwin: the iOS app, personal routine, unsigned (Simulator)"
    "$root/lib/src/darwin/scripts/build.sh" personal iOS --unsigned
fi
if [ "$docs" = 1 ]; then
    step "the docs validator"
    python3 "$root/lib/scripts/validate_docs.py" "$root/lib/documentation"
fi
step "cicd.sh: done"
