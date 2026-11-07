# The R3000A interpreter — ported from SwanStation, generic over its bus

**What / why.** The first ported code: the PS1's CPU as an interpreter, ported from SwanStation's `src/core/cpu_core.cpp` with `cpu_core.h`, `cpu_core_private.h` and `cpu_types.h`/`.cpp` (2,722 lines together, counted 2026-11-07). The code cache (`cpu_code_cache.cpp`, 1,277 lines) and the recompiler (11,996 lines) are not part of it: the interpreter is the only path that works on iOS and the accuracy reference for everything after ([SPEC.md](../../assistant/SPEC.md) → Porting).

It is one module serving two consoles: the PS2's I/O processor is an R3000A too, so the CPU must run with no PS1 device attached ([ADR 0012](../../adrs/cores-shape-and-hot-paths.md)). SwanStation can't be ported one-to-one there — its CPU includes the bus, the timing events, the GTE and the system (its include graph puts all 13 subsystems in one cycle, measured 2026-11-07) — so the port inverts it: the CPU is generic over the bus it is given, and calls out for coprocessor 2 instead of owning a GTE.

The hot path is shaped by measurement (2026-11-07, a toy MIPS loop of 300 million instructions, optimized, M3 Max): a CPU module generic over its bus with `@inlinable` hot functions ran at 705 M instructions/s, the same as code in one module (697–808 M); without `@inlinable` it fell to ~500 M, and a protocol-typed bus to 496–558 M. In C++ the whole interpreter is one 13.7 KB function, `CPU::Execute()`.

**Core constraint(s).** Ported code from its reference only: every file names the SwanStation file it comes from and its authors (A1's header), and nothing is read from the current DuckStation; the module is GPL-3.0 and no shared module imports it (⚠ in CLAUDE.md; [ADR 0011](../../adrs/each-module-carries-its-licence.md)). Hot paths use concrete types: no `any`, no unspecialized generic, no allocation per instruction ([ADR 0012](../../adrs/cores-shape-and-hot-paths.md) §4). The layer law: a new Business module with its row, directories, card line, ADR 0002 row and scheme entry. Tests hermetic, over an in-memory bus.

**Seam + files.**
- New module, Business layer: `Module(.business, "R3000A", uses: ["DataTracing"], licence: .gpl3Only),` — target `BusinessR3000A` (the `licence:` argument as A1 defines it).
- `src/istation/source/business/r3000a/`: `R3000ABus.swift` (the protocol a console's bus conforms to — used only as a generic constraint: fetch, byte/half/word reads and writes that can fail with a bus error, ticks), `Coprocessor2.swift` (the hook for COP2; "none" raises Coprocessor Unusable, as on the IOP), `State.swift` (GPRs, HI/LO, PC and next PC, the load-delay slot, COP0 registers), `Execute.swift` (decode and execute, `@inlinable`), `Exceptions.swift` (raise, vectors, RFE), `Tracing.swift` (emits 2a's records through a generic tracer that compiles away when off).
- `src/istation/tests/business/r3000a/`: per instruction family over a test bus — ALU and overflow traps, shifts, MULT/DIV and their HI/LO results (division by zero as SwanStation gives it), loads with the load-delay slot (including two loads to one register), LWL/LWR/SWL/SWR, branches and jumps with the delay slot, SYSCALL, BREAK, reserved instructions, address errors, interrupts, RFE, COP0 moves and SR's cache-isolation bit.

**Reference.** SwanStation `src/core/cpu_core.cpp`, `cpu_core_private.h`, `cpu_types.h`, `cpu_types.cpp` at the pinned commit (2b). Prior art for COP0 and exceptions: the ps1-tests `cpu/cop` source (MIT). In-house: the spike's benchmark (Milestone C) for the generic, `@inlinable` shape.

**Decisions made** (dated):
- 2026-11-07: PS1 first, from SwanStation; the IOP reuses this CPU (the user's brief).
- 2026-11-07: one CPU module generic over its bus, concrete types in the hot path (ADR 0012, the re-vision's defaults, taken).

**Open calls:**
- [default: SR's isolate-cache bit sends stores to a no-op cache stub, as SwanStation's interpreter does when the I-cache isn't emulated, so the BIOS's cache flush can't overwrite RAM] Cache isolation.
- [default: the instruction-cache timing SwanStation can model is left out of this item; ticks follow SwanStation's interpreter defaults, so cycle counts match its trace with the code cache off] Timing.
- [default: no disassembler in this item; the trace diff prints raw instruction words] Disassembly.

**Guardrail(s).** The instruction tests above pin semantics; a 2c-local test runs a short MIPS program (written in the test, not a file) and compares its trace with one hand-checked against SwanStation's patched build (2b); the benchmark from the spike, ported to a test, reports instructions per second.

**Acceptance criteria:**
- [ ] `BusinessR3000A` executes every R3000A instruction with SwanStation's semantics, including both delay slots and every exception the tests name.
- [ ] It runs over any concrete `R3000ABus`, with its hot path `@inlinable` and no `any` in it.
- [ ] It emits 2a's records, at no cost when tracing is off (measured: the same instructions per second within noise).
- [ ] Every file carries its SPDX header and credit line; the licence check passes.
- [ ] Instructions per second on the spike's loop are recorded in MILESTONES.

**Scope note.** v0.0.1, track 2; gated on A1 (the licence check, before the first GPL-3.0 module) and 2a (the format). 2d gives it the PS1's bus. Out of scope: the GTE (v0.2.0), the code cache and recompiler, and the IOP's differences (v2.x).
