#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# Runs the traced ProjectPSX built by build.sh; the arguments are the host's (see README.md).
set -eu
cd "$(dirname "$0")"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
DOTNET=${DOTNET:-$(command -v dotnet || true)}
if [ -z "$DOTNET" ] && [ -x .build/dotnet/dotnet ]; then DOTNET=.build/dotnet/dotnet; fi
exec "$DOTNET" .build/host/ProjectPSXTrace.dll "$@"
