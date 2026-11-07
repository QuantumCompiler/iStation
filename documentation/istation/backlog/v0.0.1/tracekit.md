# TraceKit — the trace format and the first divergence between two traces

**What / why.** "The oracle decides" ([SPEC.md](../../assistant/SPEC.md)): a ported subsystem is right when its guest-visible behaviour matches the oracle's, and the first divergence is the bug. Three sources must write comparable traces — the Swift port, ProjectPSX with trace logging (3d) and SwanStation recorded from outside (3d) — at two granularities: per instruction (the port and ProjectPSX) and per frame (all three). TraceKit holds the format, a recorder, a reader and the diff. It is iStation's own code, MIT, and it exists only in personal builds ([ADR 0016](../../adrs/two-build-routines-and-a-fresh-start.md)).

Measured, not guessed (2026-11-07): tracing through Revula's tool calls (one round trip per instruction) is far too slow for a BIOS boot, so traces are written by the emulator or its host and compared offline; at one record per instruction a boot is hundreds of megabytes, so records are fixed and small and gates compare checkpoints.

**Core constraint(s).** Release builds carry no tools: no shipped module imports TraceKit — a core emits through a generic tracer of its own, which a release build specializes to nothing and a personal build hands to TraceKit's recorder. The layer law for the new module. Nothing in it comes from a GPL emulator (⚠ in CLAUDE.md). Readers tolerate bad input: a truncated or foreign file is a thrown error, never a trap. Tests write only inside a `Sandbox`.

**Seam + files.**
- New module, Data layer: `Module(.data, "Tracing", testSupport: ["SupportSandbox"]),` — target `DataTracing`, product `TraceKit`, own code (MIT).
- `src/istation/source/data/tracing/`: `InstructionRecord.swift`, `FrameRecord.swift`, `TraceFile.swift` (buffered writer, streaming reader), `TraceDiff.swift` (the first divergence, with the differing fields), `Checkpoints.swift` (a whole trace reduced to a few kilobytes for committed fixtures).
- `src/istation/tests/data/tracing/`: round trips, truncated and foreign files, the first divergence by field, checkpoint reduction.
- `documentation/istation/reference/trace-formats.md`: the contract, byte by byte, that 3d's tools also write; a row in `reference/README.md`.
- The data card, ADR 0002's table, the Codebase Map, DEVELOPER.md, the personal schemes.

**Reference.** In-house: the format readers that throw on bad input (`DataISO9660`). External: the per-instruction logs emulator developers diff against each other — written here from scratch.

**Decisions made** (dated):
- 2026-11-07: TraceKit is the trace format, recorder and diff tool, personal builds only (the user's brief).

**Open calls:**
- [default: per instruction — guest PC, instruction word, cycle count, and a 64-bit checksum over the general registers, HI, LO and the COP0 status, cause and EPC registers; per frame — frame number, and checksums of guest RAM, of the displayed image and of the frame's audio samples; a full-state record at a fixed interval and on demand] The records.
- [default: the diff compares every field; a flag ignores cycle counts while timing is being ported, and no gate uses it] What counts as a divergence.

**Guardrail(s).** Tests pin both encodings byte for byte against hand-written records, the reader's rejection of truncated and foreign files, and the diff's report of the first differing record and field.

**Acceptance criteria:**
- [ ] `reference/trace-formats.md` specifies both record kinds and the checkpoints, byte by byte.
- [ ] `DataTracing` writes and reads both, finds the first divergence by field, and reduces a trace to checkpoints; its tests pass.
- [ ] No App Store build links it — checked by 3b's rule.
- [ ] Writing and reading 100 million instruction records is measured, and the number recorded in MILESTONES.

**Scope note.** v0.0.1, track 3; gated on 3b (the package's new shape). 3d writes these formats from outside the package; 3e and 3f emit them from Swift; 3g compares. Out of scope: VU and GS formats (v2.x).
