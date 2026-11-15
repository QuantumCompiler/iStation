#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# Builds ProjectPSX with iStation's trace logging: clones it at the pinned commit into .build/,
# applies trace.patch, and builds the headless host. Needs the .NET 10 SDK (see README.md).
set -eu
cd "$(dirname "$0")"
COMMIT=f4dc13aea42d
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1

DOTNET=${DOTNET:-$(command -v dotnet || true)}
if [ -z "$DOTNET" ] && [ -x .build/dotnet/dotnet ]; then DOTNET=.build/dotnet/dotnet; fi
if [ -z "$DOTNET" ]; then
    echo "The .NET 10 SDK is missing: brew install --cask dotnet-sdk (it asks for your password), or set DOTNET." >&2
    exit 1
fi

mkdir -p .build
[ -d .build/ProjectPSX ] || git clone -q https://github.com/BluestormDNA/ProjectPSX.git .build/ProjectPSX
git -C .build/ProjectPSX checkout -q --force "$COMMIT"
git -C .build/ProjectPSX clean -fdq
git -C .build/ProjectPSX apply ../../trace.patch
"$DOTNET" build host/ProjectPSXTrace.csproj -c Release -o .build/host
echo "Built: ./run.sh --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>] [--frame-trace <trace>] [--tty <file>]"
