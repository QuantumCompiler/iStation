# ADR 0012 — A core is a CPU module and a console module behind one narrow interface, and its hot paths use concrete types

**Status:** Accepted · **Date:** 2026-11-07

## Context

Measured on 2026-11-07 ([Milestone C](../assistant/MILESTONES.md#milestone-c--the-re-vision)):

- **SwanStation's subsystems form one dependency cycle.** Its include graph joins all 13 core subsystems — CPU, GTE, bus, DMA, timers, interrupt controller, timing events, GPU, SPU, CD-ROM, MDEC, SIO and the system — into one strongly connected group: every one reaches every other, through shared global state. SwiftPM forbids cycles between modules, so a one-module-per-subsystem port is impossible.
- **The PS2's I/O processor is the PS1's CPU**, so the R3000A must run without any PS1 device attached.
- **C++ compiles the whole interpreter into one function**: `CPU::Execute()` is 13.7 KB of arm64 code in the optimized build, with decode, execute and memory access inlined.
- **What Swift's hot path costs** — a toy MIPS loop of 300 million instructions with a fetch and a load or store per instruction, optimized build, Apple M3 Max, two runs each, about ±10% noise:

| Shape of the bus and CPU | Instructions per second |
|---|---|
| bus in the CPU's own module | 697–808 M |
| bus in another module, concrete type | 704–816 M |
| CPU in its own module, generic over the bus, hot functions `@inlinable` | 705 M |
| the same generic CPU without `@inlinable` | ~500 M |
| bus behind a protocol type (`any MemoryBus`) | 496–558 M |

The PS1's CPU runs at 33.9 MHz. Even the slowest shape has headroom on this toy, but a real bus does far more per access, so a 25–37% loss is not free.

## Decision

1. **Cores live in Business** (they are what iStation does). They read file formats from Data modules and never import Presentation.
2. **A CPU family is one module, generic over the bus it is given.** The R3000A is one module serving the PS1 and the PS2's I/O processor; its per-instruction functions are `@inlinable`, so each console's bus is specialized into it.
3. **A console is one module** that owns its memory map and wires its devices. A device moves into its own module only when no cycle results and the trace harness already guards its behavior — an exception to "one concern per module" ([ADR 0003](granular-modules.md)), whose concern here is the whole console, because the reference's devices form one cycle.
4. **Hot paths use concrete types.** Per-instruction, per-pixel and per-sample code uses final classes, structs or `@inlinable` generics — never a protocol-typed value (`any P`), an unspecialized generic, or an allocation. Guest memory is an unsafe buffer, bounds-checked once at the bus.
5. **The frontend reaches a core through one narrow, serializable interface**: video frames, audio buffers, input state, save states and settings — nothing else. A core could then run in another process (a GPLv2-only PS3 core must, per [ADR 0010](cores-are-ports-of-open-references.md)).

## Consequences

- The R3000A is written once and specialized twice; a console's bus is a concrete type its CPU sees through generics.
- The PS1 console module starts large; it shrinks as devices are carved out behind the trace harness, never before.
- Device and CPU code reads differently from the rest of iStation: unsafe buffers and `@inlinable` are expected there and nowhere else.
- The interface in §5 is designed with the first picture (v0.1.0) and kept narrow from then on.

## Enforcement

§1–§3 by the existing layering checks (`LayeringTests`: edges point down, no cycles, every edge declared). §4 by review until v0.0.1's gate ships (item 2e): from then on its trace run reports instructions per second, so a hot-path regression shows in the numbers. §5 is checked when the interface is designed (v0.1.0).
