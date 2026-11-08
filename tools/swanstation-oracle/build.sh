#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# Builds the oracle: SwanStation's libretro core, cloned at the pinned commit and built unmodified
# into .build/ (no one opens .build/swanstation or .build/build: its source is never read),
# libretro.h from libretro-common (MIT) at its own pin, and frontend.c. The core's build output goes
# to .build/swanstation-build.log, never to the terminal: compiler messages can quote its source, so
# a session that writes core code never opens that log. Needs Xcode's command-line tools, git, curl,
# CMake and Ninja (brew install cmake ninja).
set -eu
cd "$(dirname "$0")"
SWANSTATION=631f0fb31b809e0f889d7c551fe695788e39c1d3
LIBRETRO_COMMON=d9597c359a5ca8399a4e244f816e7e975a92a2aa

for tool in git curl cc cmake ninja; do
    command -v "$tool" >/dev/null || { echo "$tool is missing: see README.md." >&2; exit 1; }
done

mkdir -p .build/include
[ -d .build/swanstation ] || git clone -q https://github.com/libretro/swanstation .build/swanstation
# A clone from before the pin moved has to fetch it first.
git -C .build/swanstation cat-file -e "$SWANSTATION^{commit}" 2>/dev/null || git -C .build/swanstation fetch -q origin
git -C .build/swanstation checkout -q --force "$SWANSTATION"
if ! { cmake -S .build/swanstation -B .build/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 &&
       cmake --build .build/build --target swanstation_libretro; } >.build/swanstation-build.log 2>&1; then
    echo "SwanStation's build failed; its output is in .build/swanstation-build.log." >&2
    exit 1
fi

# libretro.h once per pin: the stamp names the commit the header came from.
if [ "$(cat .build/include/libretro.h.pin 2>/dev/null)" != "$LIBRETRO_COMMON" ]; then
    curl -fsSL "https://raw.githubusercontent.com/libretro/libretro-common/$LIBRETRO_COMMON/include/libretro.h" -o .build/include/libretro.h ||
        { echo "libretro.h couldn't be fetched from libretro-common." >&2; exit 1; }
    echo "$LIBRETRO_COMMON" >.build/include/libretro.h.pin
fi
cc -std=c11 -O2 -Wall -Wextra -Wno-unused-parameter -I.build/include frontend.c -o .build/oracle
echo "Built: .build/oracle .build/build/swanstation_libretro.dylib --bios <image> [--exe <file>] [--frames <n>] [--frame-trace <trace>] [--log <file>]"
