# istation-run — the Swift PS1 console from the command line

A personal tool outside the iStation package (it depends on the package's `PS1Core` and `TraceKit` products by path): runs `PS1Machine` with TraceKit recording, writes the CPU-check program, and diffs traces (v0.0.1 items 3d and 3g). Nothing here ships; builds live in `.build/`.

```sh
swift build -c release
.build/release/istation-run cpu-check-image <out>
.build/release/istation-run run --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>] [--full-state-interval <n>] [--frame-trace <trace>] [--tty <file>]
.build/release/istation-run diff <left> <right> [--ignore-cycles] [--min-records <n>]
.build/release/istation-run frames <trace>…
```

Exit status: 0 done (`diff`: the traces agree), 1 `diff` found a divergence or a trace too short, 2 the arguments or a file were wrong — an unknown option and a bad number included — and 3 `run`'s EXE never started (the BIOS didn't reach its shell), each with a message.

- **`cpu-check-image`** writes `CPUCheck.swift`'s program — R3000A code built here, never Sony's — as a 512 KB image, its code at the reset vector, so both consoles start it from the same state. It covers the ALU, shifts, comparisons, multiply and divide with psx-spx's division edge cases (by zero, signed and unsigned, and 0x80000000 ÷ −1), every load and store width with the load-delay slot, LWL/LWR/SWL/SWR, every branch and jump with its delay slot, code copied to and run from RAM, the COP0 moves, SYSCALL and BREAK through a handler and RFE, and a counted loop — and none of the places iStation departs from ProjectPSX on psx-spx's evidence.
- **`run`** boots a BIOS image (yours, or one built in code), or starts a PS-EXE once the BIOS reaches its shell (any BIOS: it watches for the shell's address); `--tty` writes what the console printed, the BIOS's putchar included, to a file — with `--exe`, only what was printed once the EXE started, and nothing if it never did. Its last line gives the instructions run and the instructions per second, counting the emulation's time alone, not the frame records' checksums.
- **`frames`** prints frame traces side by side: a line per frame, each trace's RAM checksum — `-` past a trace's end, `?` where it can't be read (named on stderr, exit 2), so one bad trace never hides the others.
- **`diff`** streams both traces and prints the first divergence by field; agreeing to the shorter trace's end exits 0, unless the shorter one has fewer than `--min-records`.

**`cpu-check.sh`** runs the whole check: the image, ProjectPSX's trace (`../projectpsx-trace/build.sh` first), the Swift console's, and the diff, which must cover at least 3,000 records — the whole program and into its closing loop.

## Your runs (with your own BIOS)

With `BIOS=/path/to/your/bios.bin`:

1. `.build/release/istation-run run --bios "$BIOS" --frames 60 --instructions /tmp/swift-boot.trace --frame-trace /tmp/swift-boot-frames.trace`
2. After `../ps1-tests/fetch.sh`: `.build/release/istation-run run --bios "$BIOS" --exe ../ps1-tests/.build/tests/cpu/cop/cop.exe --frames 600 --tty /tmp/swift-cop.tty` (and the same for `code-in-io`)
