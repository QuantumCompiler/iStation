# The reference trace — SwanStation from a pinned commit, tracing every instruction of an OpenBIOS boot

**What / why.** The Swift R3000A is checked against SwanStation's compiled build ([ADR 0010](../../adrs/cores-are-ports-of-open-references.md) §3). Nothing in the repository can produce that reference yet, and four facts shape how this item does it — measured, not guessed, 2026-11-07, over a scratch clone and build:

- **SwanStation builds on Apple Silicon** from `libretro/swanstation` commit `631f0fb3` (2026-10-24): CMake and Ninja, arm64, Debug 9.2 MB and RelWithDebInfo 5.5 MB `swanstation_libretro.dylib`, 165 steps each, 53 warnings, no errors.
- **It has no trace logging**: `src/core/cpu_core.cpp` has no trace hook (grep, 2026-11-07), so a few lines are patched into its interpreter loop. The debug build keeps `CPU::FetchInstruction()` as a separate function — the place a Frida hook could attach instead — but a local patch writes at full speed.
- **It needs no Sony file**: with no BIOS in its system directory it boots the OpenBIOS it embeds (`src/core/system.cpp:678–682`); a `.exe`/`.psexe` given as the game is side-loaded by patching the BIOS (`system.cpp:692`, `bios.cpp:157`); the interpreter is forced by the core option `swanstation_CPU_ExecutionMode` (`src/libretro/libretro_core_options.h:269`); TTY output arrives as writes to expansion region 2, offsets `0x23` and `0x80` (`src/core/bus.cpp:684–705`).
- **No frontend is installed** (RetroArch is absent), so a small headless libretro frontend drives the core: it is also free of the hardened runtime, so Frida and LLDB can attach.

Revula is for spot checks, not the trace: `revula_parse_binary` fails on Mach-O (its LIEF has no `Section.address`; the field is `virtual_address`), and `revula_symbols` returns 57,302 unsized symbols a page at a time, so `nm` and `llvm-cxxfilt` map the build; `revula_frida_intercept` can count calls into subsystem entry points of the debug build.

**Core constraint(s).** Ported code from its reference only: the tool reads and patches SwanStation alone — never the current DuckStation — and its patch and frontend are GPLv3, stated in its README. The reference is never vendored: the clone and the build live in the tool's git-ignored `.build/`, from the pinned commit. No Sony files: the system directory is an empty folder, so the embedded OpenBIOS boots; the ps1-tests programs come from their MIT release, unpacked into `.build/`. The real home untouched: the frontend points the core's system and save directories into `.build/`. The process and `dlopen` rule ([ADR 0010](../../adrs/cores-are-ports-of-open-references.md) §5) covers the app's Swift sources; this C tool sits outside `src/istation/` and ships nowhere.

**Seam + files.** No module. A new top-level `tools/swanstation-trace/`:
- `README.md` — what it is, its licence (GPLv3), the pinned commit, how to run it.
- `build.sh` — clones `libretro/swanstation` at the pinned commit into `.build/`, applies the patch, builds the core (Debug and RelWithDebInfo) and the frontend.
- `trace.patch` — in `src/core/cpu_core.cpp`'s interpreter loop: one record per executed instruction in [the trace format](trace-format.md) (2a), behind an environment variable naming the output file; TTY lines copied to a side file.
- `frontend.c` — loads the core, answers its environment calls (interpreter mode, an empty system directory, a `.build/` save directory), boots OpenBIOS alone or with a PS-EXE, runs a given number of frames, and exits.
- Docs: DEVELOPER.md's tree and commands; the router's note on `tools/`.

**Reference.** SwanStation's libretro entry points (`src/libretro/libretro_host_interface.cpp`); the libretro API header in its `dep/libretro-common`. In-house: the spike's scratch build of 2026-11-07, recorded in [Milestone C](../../assistant/MILESTONES.md#milestone-c--the-re-vision).

**Decisions made** (dated):
- 2026-11-07: the reference is built and traced locally from a pinned commit, never vendored; a local trace patch and a headless frontend, not per-instruction tool calls, produce the trace; Revula maps and spot-checks (the re-vision's defaults, taken).
- 2026-11-07: building and tracing the reference on open content is the agent's to run, not the user's (CLAUDE.md → Working a backlog item, revised).

**Open calls:**
- [default: `631f0fb3`, the commit measured on 2026-11-07, moved forward only by a dated decision] The pinned commit.
- [default: 600 frames (10 seconds of NTSC) for the OpenBIOS boot, then measured: the item records the instruction count, the trace's size and the frame at which OpenBIOS's TTY output ends] How long the boot runs.

**Guardrail(s).** The tool checks itself against real hardware: running ps1-tests' `cpu/cop` and `cpu/code-in-io` through it must reproduce their `psx.log` files (recorded on a real PS1, in the ps1-tests repository) line for line, before any Swift is compared with it. Its trace must read cleanly with `DataTracing`'s reader.

**Acceptance criteria:**
- [ ] `tools/swanstation-trace/build.sh` builds the pinned SwanStation and the frontend from a clean checkout, into the git-ignored `.build/`.
- [ ] Running OpenBIOS writes a trace in 2a's format that `DataTracing` reads, and a TTY side file.
- [ ] The TTY of ps1-tests' `cop` and `code-in-io` equals their `psx.log`.
- [ ] The boot's instruction count, trace size, run time and the frame where OpenBIOS's TTY ends are recorded in MILESTONES.
- [ ] Nothing from `.build/` is tracked; no BIOS file is used.

**Scope note.** v0.0.1, track 2; gated on 2a (the format). 2e commits checkpoints made from this tool's trace. Out of scope: PCSX2 (v2.x), per-frame VRAM traces (v0.1.0), and a Revula-driven trace.
