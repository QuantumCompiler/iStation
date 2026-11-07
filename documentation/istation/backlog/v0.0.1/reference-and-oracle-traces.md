# The reference and the oracle — ProjectPSX with trace logging; SwanStation unmodified, recorded from outside

**What / why.** The Swift PS1 core is checked two ways ([SPEC.md](../../assistant/SPEC.md) → Porting): instruction by instruction against the permissive reference it is ported from, ProjectPSX, and by guest-visible state against the more accurate GPL oracle, SwanStation. Neither can produce a trace yet. What shapes this item, checked 2026-11-07:

- **ProjectPSX** (MIT) is a .NET 10 core library (`ProjectPSX/`) with a cross-platform OpenTK frontend; its README says a valid BIOS is required (SCPH1001 is its development default). The .NET SDK is not installed on the user's Mac. MIT allows adding trace logging to its source.
- **SwanStation** (GPLv3) may only be built unmodified from its public repository and run ([ADR 0013](../../adrs/shipped-code-derives-only-from-permissive-references.md) §2): its source is never opened. It ships as a libretro core, and the libretro API exposes guest-visible state without its internals — guest RAM through `retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM)`, each video frame through the video callback, audio through the audio callbacks, and its options through the environment calls it makes. RetroArch is not installed, so a small headless frontend of iStation's own drives it.
- **Revula** records from outside only where the libretro API is not enough — LLDB or Frida for guest state — and never disassembles or decompiles SwanStation.

**Core constraint(s).** GPL emulators are black boxes (⚠ in CLAUDE.md): SwanStation is built unmodified and only run; its options are learned from the requests it makes and libretro's public documentation, not its source; the frontend's libretro header comes from libretro's own MIT-licensed `libretro-common`, not from SwanStation's tree. A session that has read a GPL emulator's source doesn't build this. No Sony files: the user's BIOS dump is passed by path at run time and never copied into the repository — a run with it is the user's to start. Nothing here ships: both tools live under `tools/`, git-ignored builds in their `.build/`.

**Seam + files.** No module.
- `tools/projectpsx-trace/` — `README.md` (MIT, the pinned ProjectPSX commit), `build.sh` (clone at the pinned commit into `.build/`, apply the patch, build with the .NET SDK), `trace.patch` (per-instruction records in the trace format ([reference/trace-formats.md](../../reference/trace-formats.md), shipped with 3c) from ProjectPSX's CPU loop; per-frame records from its frame loop), and a small console host that runs a BIOS, or a BIOS then a PS-EXE, for a given number of frames.
- `tools/swanstation-oracle/` — `README.md` (the pinned SwanStation commit; "built unmodified, source never read"), `build.sh` (clone and build the libretro core unmodified into `.build/`), and `frontend.c` (MIT, iStation's own): loads the core, logs every option key it asks for, answers with the interpreter and a system directory holding only the BIOS the user names, runs a given number of frames, and writes per-frame records in 3c's format.
- Docs: DEVELOPER.md's tree and commands; the router's note on `tools/`.

**Reference.** ProjectPSX's own source (MIT). libretro's public API documentation and `libretro.h` from `libretro-common` (MIT). psx-spx for the guest-visible state worth recording.

**Decisions made** (dated):
- 2026-11-07: ProjectPSX may be traced from inside its source; SwanStation only from outside, unmodified, guest state only (the user's brief).
- 2026-11-07: the agent installs the .NET 10 SDK with Homebrew (`brew install --cask dotnet-sdk`, 10.0.403 on 2026-11-07) (the user's call).
- 2026-11-07: the pinned commits are those current when the item starts, recorded in each README and moved forward only by a dated decision (the default, confirmed by the user).
- 2026-11-07: the oracle records per frame only — guest RAM, image and audio checksums; per-instruction state comes from ProjectPSX, and from SwanStation only by LLDB breakpoints when a divergence needs narrowing (the default, confirmed by the user).
- 2026-11-07: in the execute-group run this item is built after 3e and 3f (the gates allow it: neither depends on 3d), and SwanStation is cloned and built by a separate helper session that relays no source text, so nothing of SwanStation's source can reach a session writing core code (the default, taken; [ADR 0013](../../adrs/shipped-code-derives-only-from-permissive-references.md) §3).
- 2026-11-07: runs with the user's BIOS dump are prepared with exact steps and made later; the item stops at that point if it reaches it first (the user's call).

**Open calls:** none — all answered 2026-11-07.

**Guardrail(s).** Both tools run ps1-tests' `cpu/cop` and `cpu/code-in-io`, whose `psx.log` files were recorded on a real PS1: each tool's TTY output must reproduce them before its traces are trusted (a difference is recorded as that tool's known gap). Both tools' traces must read cleanly with `DataTracing`.

**Acceptance criteria:**
- [ ] `tools/projectpsx-trace/build.sh` and `tools/swanstation-oracle/build.sh` build from a clean checkout into git-ignored `.build/` folders.
- [ ] With the user's BIOS (the user's run), each writes a BIOS-boot trace that `DataTracing` reads; ProjectPSX's per instruction and per frame, SwanStation's per frame.
- [ ] Each tool's TTY for ps1-tests' `cop` and `code-in-io` is compared with `psx.log`, and the result recorded.
- [ ] The boot's instruction count, trace sizes and run times are recorded in MILESTONES.
- [ ] Nothing from `.build/` is tracked, and no SwanStation source file was opened.

**Scope note.** v0.0.1, track 3; gated on 3c (the formats). 3g compares against both. Out of scope: PCSX2 and Play! (v2.x), VRAM-level traces (v0.1.0).
