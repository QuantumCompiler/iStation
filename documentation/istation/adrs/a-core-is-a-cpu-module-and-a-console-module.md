# ADR 0015 — A core is a CPU module and a console module behind one narrow interface, and its hot paths use concrete types

**Status:** Accepted · **Date:** 2026-11-07 · Supersedes [ADR 0012](cores-shape-and-hot-paths.md)

## Context

[ADR 0012](cores-shape-and-hot-paths.md) shaped the cores around a GPL reference's internals. The App Store brief (2026-11-07) changes the references ([ADR 0013](shipped-code-derives-only-from-permissive-references.md)) but keeps the requirements that shaped the cores:

- **The PS2's I/O processor is the PS1's CPU**, so the R3000A must run with no PS1 device attached, under two different buses.
- **Cores are emulation only**: no UI or Apple frameworks, and one narrow, serializable interface — video frames, audio buffers, input state, save states, settings — so a core could later run out of process.
- **Hot paths avoid ARC retain/release traffic, existential types and bounds-check overhead.**
- **ProjectPSX keeps its whole console in one project** (`ProjectPSX/Core/` — `BUS.cs`, `CPU.cs`, `GTE.cs` — and `ProjectPSX/Devices/`), its devices reaching each other through the bus.

Measured on 2026-11-07 with code written for iStation (a toy MIPS loop of 300 million instructions, a fetch and a load or store each, optimized build, Apple M3 Max, two runs, about ±10% noise):

| Shape of the bus and CPU | Instructions per second |
|---|---|
| bus in the CPU's own module | 697–808 M |
| bus in another module, concrete type | 704–816 M |
| CPU in its own module, generic over the bus, hot functions `@inlinable` | 705 M |
| the same generic CPU without `@inlinable` | ~500 M |
| bus behind a protocol type (`any MemoryBus`) | 496–558 M |

## Decision

1. **Cores live in Business** and import neither UI nor Apple frameworks: the Swift standard library, and nothing else without a recorded reason.
2. **A CPU family is one module, generic over the bus it is given.** The R3000A serves the PS1 and the PS2's I/O processor; its per-instruction functions are `@inlinable`, so each console's bus is specialized into it.
3. **A console is one module** that owns its memory map and wires its devices, as ProjectPSX's project does. A device moves into its own module only when no dependency cycle results and the trace harness already guards its behavior — an exception to "one concern per module" ([ADR 0003](granular-modules.md)) whose concern is the whole console.
4. **Hot paths use concrete types.** Per-instruction, per-pixel and per-sample code uses final classes, structs or `@inlinable` generics — never a protocol-typed value, an unspecialized generic, or an allocation. Guest memory is an unsafe buffer, bounds-checked once at the bus.
5. **The frontend reaches a core through one narrow, serializable interface**: video frames, audio buffers, input state, save states and settings — nothing else.

## Consequences

- The R3000A is written once and specialized twice.
- The PS1 console module starts as large as ProjectPSX's core; it shrinks only behind the trace harness.
- Unsafe buffers and `@inlinable` are expected in core code and nowhere else.
- The interface in §5 is designed with the first picture (v0.1.0) and stays narrow.

## Enforcement

§1–§3 by the existing layering checks (`LayeringTests`: edges point down, no cycles, every edge declared) and by A2's header check for core files. §4 by review until v0.0.1's gate (item 3g) ships; from then on each gate run reports instructions per second, so a regression shows. §5 is checked when the interface is designed (v0.1.0).
