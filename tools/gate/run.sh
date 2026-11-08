#!/bin/sh
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# v0.0.1's gate (items 3d and 3g), the user's run: boots the user's BIOS on the Swift console,
# ProjectPSX's traced build and SwanStation, diffs their traces, runs ps1-tests' four CPU tests on
# each, compares every program's TTY with the test's psx.log (recorded on a real PS1), and writes
# report.md and frames.tsv. A tool that fails is noted in the report, and the gate goes on.
#
#   tools/gate/run.sh <bios> [--scph1001] [--out <folder>]
#
# The BIOS is the user's own dump: passed by path, never copied. --scph1001 says it is SCPH-1001's,
# the only BIOS ProjectPSX can side-load an EXE into; without it ProjectPSX runs the boot only.
# FRAMES (default 1200) sets the boot's length and TRACE_FRAMES (default 60) how much of it is traced
# per instruction; TEST_FRAMES (default 600) each test's. PS1_TESTS and PS1_TEST_LOGS point at another
# copy of ps1-tests' programs and psx.log files.
#
# Needs, first: ../projectpsx-trace/build.sh, ../swanstation-oracle/build.sh, ../ps1-tests/fetch.sh.
set -eu

usage() { echo "usage: tools/gate/run.sh <bios> [--scph1001] [--out <folder>]" >&2; exit 2; }
# A path as the caller meant it, from where they ran this, before the cd below.
absolute() { case $1 in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$PWD/$1" ;; esac; }

[ $# -ge 1 ] || usage
BIOS=$(absolute "$1"); shift
SCPH1001=0
OUT=""
while [ $# -gt 0 ]; do
    case $1 in
        --scph1001) SCPH1001=1 ;;
        --out) [ $# -ge 2 ] || usage; OUT=$(absolute "$2"); shift ;;
        *) echo "unexpected argument: $1" >&2; usage ;;
    esac
    shift
done
[ -f "$BIOS" ] || { echo "No BIOS at $BIOS." >&2; exit 2; }
TESTS=$(absolute "${PS1_TESTS:-$(dirname "$0")/../ps1-tests/.build/tests}")
LOGS=$(absolute "${PS1_TEST_LOGS:-$(dirname "$0")/../ps1-tests/.build/logs}")
FRAMES=${FRAMES:-1200}
TRACE_FRAMES=${TRACE_FRAMES:-60}
TEST_FRAMES=${TEST_FRAMES:-600}
CPU_TESTS="access-time code-in-io cop io-access-bitwidth"

cd "$(dirname "$0")/.."
TOOLS=$PWD
CORE=$TOOLS/swanstation-oracle/.build/build/swanstation_libretro.dylib
ORACLE=$TOOLS/swanstation-oracle/.build/oracle
[ -f "$TOOLS/projectpsx-trace/.build/host/ProjectPSXTrace.dll" ] || { echo "ProjectPSX isn't built: tools/projectpsx-trace/build.sh" >&2; exit 2; }
[ -x "$ORACLE" ] && [ -f "$CORE" ] || { echo "The oracle isn't built: tools/swanstation-oracle/build.sh" >&2; exit 2; }
[ -d "$TESTS" ] || { echo "ps1-tests' programs aren't fetched: tools/ps1-tests/fetch.sh" >&2; exit 2; }
for TEST in $CPU_TESTS; do
    [ -f "$LOGS/$TEST.log" ] || { echo "$TEST's psx.log isn't fetched: tools/ps1-tests/fetch.sh" >&2; exit 2; }
done

# A folder of its own: an earlier run's files left beside this one's would read as its results.
if [ -n "$OUT" ] && [ -e "$OUT" ] && [ -n "$(ls -A "$OUT")" ]; then
    echo "$OUT isn't empty: choose a new folder for --out." >&2
    exit 2
fi
OUT=${OUT:-$(mktemp -d /tmp/istation-gate-XXXXXX)}
mkdir -p "$OUT"
echo "Writing to $OUT"
echo "Building istation-run…"
(cd "$TOOLS/istation-run" && swift build -c release --product istation-run >/dev/null)
RUN=$TOOLS/istation-run/.build/release/istation-run
PROJECTPSX=$TOOLS/projectpsx-trace/run.sh
REPORT=$OUT/report.md
FAILURES=$OUT/failures.md
: >"$FAILURES"

note() { printf '%s\n' "$*" >>"$REPORT"; }
block() { note '```'; cat "$1" >>"$REPORT"; note '```'; }
# A tool that exited non-zero: listed at the top of the report, with the file holding its output.
failed() { printf -- '- %s exited %s (its output: `%s`)\n' "$1" "$2" "$3" >>"$FAILURES"; }
# A TTY as text to compare: no carriage returns, no blank lines before the first line of text, every
# line ending in a newline (psx.log leaves out the programs' opening blank line, and access-time's its
# last newline); nothing when the tool wrote none.
text() { if [ -f "$1" ]; then tr -d '\r' <"$1" | awk 'NF || seen { seen = 1; print }' >"$2"; else : >"$2"; fi; }
# The last line a tool printed: its frames, instructions, cycles and time.
summary() { tail -n 1 "$1" 2>/dev/null || echo "(no output)"; }
# Runs the oracle and writes its wall time into $1 (libretro reports no cycles).
oracle() {
    TIMED=$1; shift
    START=$(date +%s)
    "$ORACLE" "$CORE" "$@" >/dev/null 2>"$TIMED.err" || { STATUS=$?; echo "exit $STATUS" >"$TIMED"; return "$STATUS"; }
    echo "$(($(date +%s) - START)) s" >"$TIMED"
}

# --- The boot -------------------------------------------------------------------------------------
echo "The boot, per frame ($FRAMES frames)…"
"$RUN" run --bios "$BIOS" --frames "$FRAMES" --frame-trace "$OUT/swift-boot-frames.trace" 2>"$OUT/swift-boot.out" ||
    failed "The Swift console's boot" $? swift-boot.out
"$PROJECTPSX" --bios "$BIOS" --frames "$FRAMES" --frame-trace "$OUT/projectpsx-boot-frames.trace" >"$OUT/projectpsx-boot.out" 2>&1 ||
    failed "ProjectPSX's boot" $? projectpsx-boot.out
oracle "$OUT/swanstation-boot.time" --bios "$BIOS" --frames "$FRAMES" --frame-trace "$OUT/swanstation-boot-frames.trace" --log "$OUT/swanstation-boot.log" ||
    failed "SwanStation's boot" $? swanstation-boot.time.err
echo "The boot, per instruction ($TRACE_FRAMES frames)…"
"$RUN" run --bios "$BIOS" --frames "$TRACE_FRAMES" --instructions "$OUT/swift-boot.trace" 2>"$OUT/swift-boot-traced.out" ||
    failed "The Swift console's traced boot" $? swift-boot-traced.out
"$PROJECTPSX" --bios "$BIOS" --frames "$TRACE_FRAMES" --instructions "$OUT/projectpsx-boot.trace" >"$OUT/projectpsx-boot-traced.out" 2>&1 ||
    failed "ProjectPSX's traced boot" $? projectpsx-boot-traced.out

# A trace cut short — a tool that stopped — must not read as agreement: each diff needs its length.
"$RUN" diff "$OUT/swanstation-boot-frames.trace" "$OUT/swift-boot-frames.trace" --min-records "$FRAMES" >"$OUT/diff-frames-swanstation.txt" 2>&1 || true
"$RUN" diff "$OUT/projectpsx-boot-frames.trace" "$OUT/swift-boot-frames.trace" --min-records "$FRAMES" >"$OUT/diff-frames-projectpsx.txt" 2>&1 || true
"$RUN" diff "$OUT/projectpsx-boot.trace" "$OUT/swift-boot.trace" --ignore-cycles --min-records 1000 >"$OUT/diff-instructions-projectpsx.txt" 2>&1 || true
# Every frame's RAM checksum side by side, to find where the boot ends (3g: where SwanStation's RAM
# settles into the shell's pattern) and how each console gets there.
"$RUN" frames "$OUT/swanstation-boot-frames.trace" "$OUT/swift-boot-frames.trace" "$OUT/projectpsx-boot-frames.trace" >"$OUT/frames.tsv" 2>"$OUT/frames.err" ||
    failed "Reading the frame traces side by side" $? frames.err

# --- ps1-tests ------------------------------------------------------------------------------------
TESTS_REPORT=$OUT/tests.md
: >"$TESTS_REPORT"
tnote() { printf '%s\n' "$*" >>"$TESTS_REPORT"; }
tblock() { tnote '```'; cat "$1" >>"$TESTS_REPORT"; tnote '```'; }
for TEST in $CPU_TESTS; do
    EXE=$(find "$TESTS" -path "*cpu*" -path "*$TEST*" -name '*.exe' | sort | head -n 1)
    tnote ""
    tnote "### $TEST"
    tnote ""
    if [ -z "$EXE" ]; then tnote "No EXE for $TEST in the release."; continue; fi
    echo "$TEST…"
    tnote "Program: \`${EXE#"$TESTS"/}\`; expected: its \`psx.log\`, recorded on a real PS1."
    tnote ""
    text "$LOGS/$TEST.log" "$OUT/$TEST.expected"

    # Each console's TTY starts at the EXE's entry: the BIOS's own messages before it aren't the test's.
    if "$RUN" run --bios "$BIOS" --exe "$EXE" --frames "$TEST_FRAMES" --tty "$OUT/$TEST.swift.tty" 2>"$OUT/$TEST.swift.out"; then
        text "$OUT/$TEST.swift.tty" "$OUT/$TEST.swift.txt"
        if diff "$OUT/$TEST.expected" "$OUT/$TEST.swift.txt" >"$OUT/$TEST.swift.diff"; then
            tnote "- **Swift console**: matches \`psx.log\`."
        else
            tnote "- **Swift console**: differs from \`psx.log\` (\`<\` expected, \`>\` printed):"
            tblock "$OUT/$TEST.swift.diff"
        fi
    else
        failed "The Swift console's $TEST" $? "$TEST.swift.out"
        tnote "- **Swift console**: its run failed (listed above)."
    fi

    # SwanStation is heard only through libretro's log, its lines tagged "[core level] [channel] ".
    if oracle "$OUT/$TEST.swanstation.time" --bios "$BIOS" --exe "$EXE" --frames "$TEST_FRAMES" --log "$OUT/$TEST.swanstation.log"; then
        sed -n 's/^\[core [a-z?]*\] \(\[[^]]*\] \)\{0,1\}//p' "$OUT/$TEST.swanstation.log" | tr -d '\r' >"$OUT/$TEST.swanstation.txt"
        FOUND=0 TOTAL=0
        while IFS= read -r LINE || [ -n "$LINE" ]; do
            [ -n "$LINE" ] || continue
            TOTAL=$((TOTAL + 1))
            if grep -qxF -- "$LINE" "$OUT/$TEST.swanstation.txt"; then FOUND=$((FOUND + 1)); fi
        done <"$OUT/$TEST.expected"
        # What was measured, nothing more: a TTY missing and a TTY that differs read the same here.
        tnote "- **SwanStation**: $FOUND of \`psx.log\`'s $TOTAL lines are in its log (\`$TEST.swanstation.log\`; with images built in code the core logged no TTY at all)."
    else
        failed "SwanStation's $TEST" $? "$TEST.swanstation.time.err"
        tnote "- **SwanStation**: its run failed (listed above)."
    fi

    if [ "$SCPH1001" = 1 ]; then
        if "$PROJECTPSX" --bios "$BIOS" --exe "$EXE" --frames "$TEST_FRAMES" --tty "$OUT/$TEST.projectpsx.tty" >"$OUT/$TEST.projectpsx.out" 2>&1; then
            text "$OUT/$TEST.projectpsx.tty" "$OUT/$TEST.projectpsx.txt"
            if diff "$OUT/$TEST.expected" "$OUT/$TEST.projectpsx.txt" >"$OUT/$TEST.projectpsx.diff"; then
                tnote "- **ProjectPSX**: matches \`psx.log\`."
            else
                tnote "- **ProjectPSX**: differs from \`psx.log\` (\`<\` expected, \`>\` printed):"
                tblock "$OUT/$TEST.projectpsx.diff"
            fi
        else
            failed "ProjectPSX's $TEST" $? "$TEST.projectpsx.out"
            tnote "- **ProjectPSX**: its run failed (listed above)."
        fi
    else
        tnote "- **ProjectPSX**: not run (it side-loads an EXE only into SCPH-1001's BIOS)."
    fi
done

# --- The report -----------------------------------------------------------------------------------
: >"$REPORT"
note "# v0.0.1 gate — $(date '+%Y-%m-%d %H:%M')"
note ""
note "BIOS: $(wc -c <"$BIOS" | tr -d ' ') bytes, SHA-256 $(shasum -a 256 "$BIOS" | cut -c1-16)…; SCPH-1001: $([ "$SCPH1001" = 1 ] && echo yes || echo no). The boot: $FRAMES frames, the first $TRACE_FRAMES traced per instruction; each test $TEST_FRAMES frames."
note ""
if [ -s "$FAILURES" ]; then
    note "## Runs that failed"
    note ""
    cat "$FAILURES" >>"$REPORT"
else
    note "Every run finished."
fi
note ""
note "## The boot"
note ""
note "- **Swift console**, frame records only (its instructions per second count emulation alone): \`$(summary "$OUT/swift-boot.out")\`"
note "- **Swift console**, traced: \`$(summary "$OUT/swift-boot-traced.out")\`"
note "- **ProjectPSX**: \`$(summary "$OUT/projectpsx-boot.out")\`; traced: \`$(summary "$OUT/projectpsx-boot-traced.out")\`"
note "- **SwanStation**: $(cat "$OUT/swanstation-boot.time" 2>/dev/null || echo "no time") for $FRAMES frames (libretro gives no cycle count)"
note "- **Trace sizes**: $(cd "$OUT" && ls -l -- *.trace 2>/dev/null | awk '{ printf "%s %.1f MB; ", $9, $5 / 1048576 }')"
note ""
# Where SwanStation's RAM stops changing, and how far the Swift console keeps to it.
note "**Frames** (\`frames.tsv\`: every frame's RAM checksum — SwanStation, the Swift console, ProjectPSX):"
note '```'
# Columns: frame, SwanStation, the Swift console, ProjectPSX; "-" is past a trace's end, "?" unreadable.
awk -F'\t' '$1 ~ /^[0-9]+$/ {
        rows++
        if ($2 == "-" || $2 == "?") { if (ended == "") ended = $1 " (" ($2 == "-" ? "its trace ends" : "unreadable") ")"; next }
        frames++
        if ($2 != previous) { changes++; last = $1 }
        previous = $2
        if ($3 == "-" || $3 == "?") { if (swiftEnded == "") swiftEnded = $1 " (" ($3 == "-" ? "its trace ends" : "unreadable") ")"; next }
        both++
        if ($2 == $3) same++; else if (first == "") first = $1
    }
    END {
        if (rows == 0) { print "frames.tsv holds no frames: see frames.err."; exit }
        if (frames > 0) printf "SwanStation'"'"'s RAM changes in %d of its %d frames, last at frame %d.\n", changes, frames, last
        if (ended != "") printf "SwanStation has no frame from frame %s.\n", ended
        if (swiftEnded != "") printf "The Swift console has no frame from frame %s.\n", swiftEnded
        printf "Over the %d frames both hold, the Swift console matches SwanStation in %d; first different frame: %s.\n", both, same, (first == "" ? "none" : first)
    }' "$OUT/frames.tsv" >>"$REPORT"
note '```'
note "**Per frame, against SwanStation** (3g: every frame up to the boot's end must match):"
block "$OUT/diff-frames-swanstation.txt"
note "**Per frame, against ProjectPSX** (expected to differ in timing: its devices run three times faster):"
block "$OUT/diff-frames-projectpsx.txt"
note "**Per instruction, against ProjectPSX**, cycles ignored (each divergence is fixed or listed with psx-spx's evidence):"
block "$OUT/diff-instructions-projectpsx.txt"
note ""
note "## ps1-tests' CPU tests"
cat "$TESTS_REPORT" >>"$REPORT"

echo
cat "$REPORT"
echo
echo "Everything is in $OUT. Send back report.md and frames.tsv (both small); keep the traces until the agent has read them."
