# projectpsx-trace — ProjectPSX with trace logging

The permissive reference the Swift PS1 core is ported from, [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (MIT, © 2019 Pedro Cortés), pinned at **`f4dc13aea42d`** ("Update Project to .NET 10"), built with iStation's trace logging so its execution can be compared with the Swift console's record for record (v0.0.1 item 3d). Nothing here ships; the clone and every build live in the git-ignored `.build/`.

- **`trace.patch`** — applied to the pinned clone. It adds `ProjectPSX/Core/IStationTrace.cs` (MIT, iStation's own), which writes TraceKit's instruction, full-state and frame records ([reference/trace-formats.md](../../documentation/istation/reference/trace-formats.md)) and the TTY, and small hooks: the instruction just retired, at the end of `CPU.Run()`; the BIOS's putchar, tested as ProjectPSX's own `TTY()` tests it, and expansion 2's DUART, both copied to the TTY file apart from ProjectPSX's log lines — with an EXE, from its entry point on (`IStationTrace.ttyFrom`), so the BIOS's own messages stay out; the BIOS path settable (`BUS.bios`); guest RAM readable (`BUS.Ram`, `ProjectPSX.Bus`); and "no disc" accepted, so the BIOS can run alone.
- **`host/`** — `ProjectPSXTrace`, a headless console host (MIT): runs a BIOS image, or a BIOS then a PS-EXE, for some frames. A frame record is written at each vertical blank, when ProjectPSX's GPU calls `Render`. There is never a disc, and ProjectPSX can't answer "no disc": its CD has no tracks without a disc image, so with the lid closed a GetID or ReadN would throw. The host opens the CD-ROM's lid instead (`toggleCdRomLid()`), so a BIOS sees an open lid, not an empty closed drive, and its disc checks may take another path than on the other consoles. Both controller slots are empty (`IStationTrace.portsEmpty`), as on the Swift console and the oracle: ProjectPSX always builds a digital pad and a memory card, which would answer the BIOS's polls — and the card is never written. Its JOY_STAT still carries the baud timer in bits 11 and up, which the other two read as 0. The host answers ProjectPSX's waits for console input at once, checks the BIOS's size and `--exe` before anything starts, and exits 0 done, 2 for wrong arguments or an output file it can't write, 3 when ProjectPSX throws while running (keeping what was recorded, and naming the frame), and 4 when, with `--exe` and `--tty`, the EXE never started.
- **`build.sh`** — clones at the pinned commit, applies the patch, builds the host; every output, intermediates included (`host/Directory.Build.props`), lands in `.build/`. **`run.sh`** — runs it.

## The .NET 10 SDK

`brew install --cask dotnet-sdk` (10.0.403) installs it system-wide and asks for your password. Without one — as in the agent's run of 2026-11-07 — the same package, which Homebrew downloads and checks, can be unpacked into `.build/dotnet/`, where `build.sh` and `run.sh` find it:

```sh
PKG=$(ls ~/Library/Caches/Homebrew/downloads/*dotnet-sdk-10.0.403-osx-arm64.pkg)
pkgutil --expand-full "$PKG" /tmp/dotnet-pkg && mkdir -p .build/dotnet
for d in /tmp/dotnet-pkg/*.pkg; do ditto "$d/Payload" .build/dotnet; done
```

## Using it

```sh
./build.sh
./run.sh --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>] [--full-state-interval <n>] [--frame-trace <trace>] [--tty <file>]
```

The CPU check — the same program on ProjectPSX and the Swift console — is `../istation-run/cpu-check.sh`.

## Your runs (with your own BIOS)

A BIOS dump is yours to supply and to run; it is passed by path and never copied. With `BIOS=/path/to/your/bios.bin`:

1. **The boot**, per instruction and per frame. ProjectPSX's devices run three times faster than its CPU, so a frame holds at most about 190,000 instructions: 60 frames is at most about 11.5 million records, some 290 MB.
   `./run.sh --bios "$BIOS" --frames 60 --instructions /tmp/projectpsx-boot.trace --frame-trace /tmp/projectpsx-boot-frames.trace`
2. **ps1-tests' `cop` and `code-in-io`**, after `../ps1-tests/fetch.sh`, their TTY compared with each test's `psx.log`. **This needs an SCPH-1001 dump**: ProjectPSX side-loads an EXE by patching that BIOS's LoadRunShell at 0xBFC06FF0, which is other code in any other BIOS.
   `./run.sh --bios "$BIOS" --exe ../ps1-tests/.build/tests/cpu/cop/cop.exe --frames 600 --tty /tmp/projectpsx-cop.tty`
   `./run.sh --bios "$BIOS" --exe ../ps1-tests/.build/tests/cpu/code-in-io/code-in-io.exe --frames 600 --tty /tmp/projectpsx-code-in-io.tty`

(`fetch.sh` lists the EXEs' paths inside the release; adjust the two above if they differ. With `--exe`, the TTY file holds what was printed from the EXE's entry point on: the program's output, without the BIOS's. On another BIOS the EXE never starts: the TTY file stays empty and the run exits 4.) `../gate/run.sh` makes these runs, and the other tools', in one go.
