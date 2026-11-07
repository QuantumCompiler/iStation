# The R3000A interpreter — ported from ProjectPSX, generic over its bus

**What / why.** The first ported code: the PS1's CPU as an interpreter, ported from ProjectPSX's `ProjectPSX/Core/CPU.cs` (MIT). The interpreter is the only CPU path that works on iOS and the accuracy baseline for everything after ([SPEC.md](../../assistant/SPEC.md) → Porting). It serves two consoles — the PS2's I/O processor is an R3000A too — so it runs with no PS1 device attached: generic over the bus it is given, calling out for coprocessor 2 instead of owning the GTE ([ADR 0015](../../adrs/a-core-is-a-cpu-module-and-a-console-module.md)).

Its hot path is shaped by measurement (2026-11-07, iStation's own toy MIPS loop, 300 million instructions, optimized, M3 Max): a CPU module generic over its bus with `@inlinable` hot functions ran at 705 M instructions/s, as fast as code in one module (697–808 M); without `@inlinable` it fell to ~500 M, and a protocol-typed bus to 496–558 M.

**Core constraint(s).** Shipped code only from permissive sources (⚠ in CLAUDE.md): ProjectPSX's `CPU.cs`, psx-spx and iStation's own code — never a GPL emulator's source; this item is built by a session that hasn't read one ([ADR 0013](../../adrs/shipped-code-derives-only-from-permissive-references.md) §3). Every file carries its SPDX header and provenance line ([ADR 0014](../../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)). No UI or Apple framework; hot paths with concrete types — no `any`, no unspecialized generic, no allocation per instruction ([ADR 0015](../../adrs/a-core-is-a-cpu-module-and-a-console-module.md)). Release builds carry no tracing: the tracer is a generic parameter that release builds specialize to nothing. Tests hermetic, over an in-memory bus.

**Seam + files.**
- New module, Business layer: `Module(.business, "R3000A", derivedFrom: .projectPSX),` — target `BusinessR3000A`, in the `PS1Core` product (A2's field).
- `src/istation/source/business/r3000a/`: the bus protocol a console conforms to (used only as a generic constraint: fetch, byte/half/word access that can raise a bus error, ticks), the coprocessor-2 hook ("none" raises Coprocessor Unusable, as on the IOP), the state (registers, HI/LO, PC and next PC, the load-delay slot, COP0), decode and execute (`@inlinable`), exceptions and RFE, and the generic tracer hook.
- `src/istation/tests/business/r3000a/`: per instruction family — ALU and overflow traps, shifts, MULT/DIV with HI/LO, loads with the load-delay slot, LWL/LWR/SWL/SWR, branches and jumps with the delay slot, SYSCALL, BREAK, reserved instructions, address errors, interrupts, RFE, COP0 moves, the cache-isolation bit — with expected results from psx-spx.

**Reference.** ProjectPSX `ProjectPSX/Core/CPU.cs` at 3d's pinned commit (MIT). psx-spx's CPU, COP0 and exception chapters. The ps1-tests `cpu/cop` source (MIT).

**Decisions made** (dated):
- 2026-11-07: PS1 from ProjectPSX; the IOP reuses this CPU (the user's brief).
- 2026-11-07: one CPU module generic over its bus, concrete types in the hot path (ADR 0015).

**Open calls:**
- [default: where ProjectPSX and psx-spx disagree, psx-spx and SwanStation's recorded behaviour (3d) decide, and the difference is noted beside the code] Correcting the reference.
- [default: no disassembler in this item; TraceKit's diff prints raw instruction words] Disassembly.

**Guardrail(s).** The instruction tests pin semantics against psx-spx; a short MIPS program written in a test runs on the Swift CPU and, in a personal run, on ProjectPSX's traced build (3d), and the two traces must match; a benchmark test reports instructions per second.

**Acceptance criteria:**
- [ ] `BusinessR3000A` executes every R3000A instruction with psx-spx's semantics, including both delay slots and every exception the tests name.
- [ ] It runs over any concrete bus, its hot path `@inlinable` with no `any` in it; tracing off costs nothing measurable.
- [ ] Every file carries its header and provenance line; A2's check passes.
- [ ] Instructions per second on the spike's loop are recorded in MILESTONES.

**Scope note.** v0.0.1, track 3; gated on A2 (headers before the first ported module) and 3c (the tracer's records). 3f gives it the PS1's bus. Out of scope: the GTE (v0.2.0), any code generator, the IOP's differences (v2.x).
