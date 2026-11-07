# The PS1 console — memory map, interrupt controller, timers, DMA and the devices the BIOS needs

**What / why.** Before a BIOS can boot, the R3000A (3e) needs a PS1 around it: the memory map, the interrupt controller, the timers, DMA, the expansion port the BIOS writes its TTY to, and enough of the other devices to answer the BIOS. This item ports those from ProjectPSX (MIT) — `ProjectPSX/Core/BUS.cs`, `Devices/InterruptController.cs`, `Devices/TIMERS.cs`, `Devices/DMA/`, `Devices/Expansion/Exp2.cs` — into one console module, stubs the GPU, SPU, CD-ROM, MDEC and pads at their power-on state, and adds PS-EXE side-loading for the test programs. ProjectPSX keeps its whole console in one project, its devices reaching each other through the bus, so the port keeps one module and carves devices out only behind the trace harness ([ADR 0015](../../adrs/a-core-is-a-cpu-module-and-a-console-module.md) §3). Its README lists resumable DMA transfers and CD-ROM timing as missing (checked 2026-11-07): the DMA here needs only what the BIOS uses, and CD-ROM timing is v0.2.0's.

**Core constraint(s).** Shipped code only from permissive sources, built by a session that hasn't read a GPL emulator's source; headers and provenance lines on every file (⚠ in CLAUDE.md; ADRs 0013, 0014). No UI or Apple framework; the bus a final type the R3000A is specialized over; guest memory an unsafe buffer bounds-checked once at the bus (ADR 0015 §4). No Sony files: tests build their memory images and programs in code. The layer law, as for 3e.

**Seam + files.**
- New module, Business layer: `Module(.business, "PS1", uses: ["BusinessR3000A"], derivedFrom: .projectPSX),` — target `BusinessPS1`, in `PS1Core`.
- `src/istation/source/business/ps1/`: the console (RAM, BIOS image, devices, the run loop), the bus (2 MB RAM mirrored, the 1 KB scratchpad, the 512 KB BIOS read-only, the I/O ports, expansion regions 1 and 2, memory and cache control, segment masking, access timing, bus errors), the interrupt controller, the timers, DMA, the TTY from expansion region 2, the device stubs (including the vertical-blank interrupt on NTSC timing), the BIOS image loader, and the PS-EXE loader (its header, and a stack pointer when the header's is 0, as ps1-tests' programs need).
- `src/istation/tests/business/ps1/`: mirrors and masking, the scratchpad, BIOS read-only, I/O widths, interrupt status and mask, timer counting, DMA's ordering-table clear, the VBlank cadence, PS-EXE parsing, TTY lines.

**Reference.** ProjectPSX's `Core/BUS.cs`, `Devices/` and `Core/ProjectPSX.cs` at 3d's pinned commit (MIT); psx-spx's memory map, I/O, interrupt, timer, DMA, expansion-region and PS-EXE chapters.

**Decisions made** (dated):
- 2026-11-07: one console module, devices carved out only behind the trace harness (ADR 0015).
- 2026-11-07: the stubs answer as psx-spx documents each device's power-on state; which registers the BIOS touches is read from ProjectPSX's and SwanStation's traces (3d), not guessed (the default, confirmed by the user).
- 2026-11-07: NTSC timing only (the default, confirmed by the user).
- 2026-11-07: what ps1-tests' `access-time` and `io-access-bitwidth` need (memory wait states, device register widths) is ported here too, so 3g can pass all four CPU tests (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-07.

**Guardrail(s).** The tests above; and in a personal run, the console's per-frame trace for the BIOS boot matches ProjectPSX's (3d) frame by frame, its first divergence naming the frame.

**Acceptance criteria:**
- [ ] `BusinessPS1` wires `BusinessR3000A` to a concrete PS1 bus and runs it.
- [ ] The memory map, interrupt controller, timers and DMA behave as psx-spx documents, by the tests above.
- [ ] A PS-EXE built in a test loads and runs, and its TTY output is captured.
- [ ] Every file carries its header and provenance line; the provenance and layer checks pass.

**Scope note.** v0.0.1, track 3; gated on 3e. 3g boots the user's BIOS on it. Out of scope: the GPU's drawing (v0.1.0), the CD-ROM's commands, SPU sound, MDEC and pads (v0.2.0).
