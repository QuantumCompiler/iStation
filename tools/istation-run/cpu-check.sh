#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# The CPU check (3e's guardrail): the same program, built here as a 512 KB image, runs on ProjectPSX's
# traced build and on the Swift console, and their instruction traces — every register after every
# instruction, and the cycle counts — must agree to the end of the shorter one. Needs
# ../projectpsx-trace/build.sh to have run. Writes into a temporary folder it prints.
set -eu
cd "$(dirname "$0")"
swift build -c release --product istation-run >/dev/null
WORK=$(mktemp -d /tmp/istation-cpu-check-XXXXXX)
.build/release/istation-run cpu-check-image "$WORK/cpu-check.bin"
../projectpsx-trace/run.sh --bios "$WORK/cpu-check.bin" --frames 1 --instructions "$WORK/projectpsx.trace" --full-state-interval 1 >/dev/null
.build/release/istation-run run --bios "$WORK/cpu-check.bin" --frames 1 --instructions "$WORK/swift.trace" --full-state-interval 1
echo "Traces in $WORK"
# The program is about 1,150 instructions before its endless loop, two records each with a full state:
# both traces must reach well into the loop for their agreement to mean anything.
.build/release/istation-run diff "$WORK/projectpsx.trace" "$WORK/swift.trace" --min-records 3000
