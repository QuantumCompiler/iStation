# The trace format — one record per guest instruction, and the first divergence between two traces

**What / why.** The re-vision's rule is "the reference decides" ([SPEC.md](../../assistant/SPEC.md), [ADR 0010](../../adrs/cores-are-ports-of-open-references.md)): a ported subsystem is right when its trace matches the reference's compiled build, and the first divergence is the bug. That needs one format that both sides write — SwanStation's C++ build (2b) and the Swift R3000A (2c onward) — and a reader that finds where two traces first differ. This item defines the format as a reference contract and builds the shared module that writes, reads and compares it. It holds no emulator code: it is shared infrastructure, GPL-2.0-or-later ([ADR 0011](../../adrs/each-module-carries-its-licence.md)).

Measured, not guessed (2026-11-07): tracing through Revula's tool calls (one MCP round trip per instruction) is far too slow for a BIOS boot, so the trace is written by the emulator itself and compared offline. The size matters: at one record per instruction, a boot of tens of millions of instructions is a file of hundreds of megabytes, which is why the record is fixed and small and the gate (2e) compares checkpoints.

**Core constraint(s).** The layer law: a new module is a row, a source and test directory, a card line, an ADR 0002 row and a test target in the Xcode scheme, in one change. Shared infrastructure never contains emulator code and never imports a core (⚠ in CLAUDE.md). The real home untouched: the writer writes only where it is told; tests write only inside a `Sandbox`. Readers tolerate bad input: a truncated or foreign file is a thrown error, never a trap.

**Seam + files.**
- New module, Data layer: `Module(.data, "Tracing", testSupport: ["SupportSandbox"]),` — target `DataTracing`, licence GPL-2.0-or-later (A1's tag, if A1 has landed).
- `src/istation/source/data/tracing/`: `TraceRecord.swift` (the record and its encoding), `TraceFile.swift` (a buffered writer and a streaming reader), `TraceDiff.swift` (`firstDivergence(_:_:ignoring:)` → the index, both records and the differing fields), `Checkpoints.swift` (every Nth record reduced to one line, for the committed fixtures in 2e).
- `src/istation/tests/data/tracing/`: round trips, truncated and foreign files, the first divergence by field, ignoring cycles on request, checkpoint reduction.
- `documentation/istation/reference/cpu-trace-format.md`: the contract, byte by byte, that 2b's C writer follows; a row in `reference/README.md`.
- The data layer card, ADR 0002's table, the Codebase Map, DEVELOPER.md, the `iStation` scheme.

**Reference.** In-house: `DataISO9660` and `DataParamSFO` (binary readers that throw on bad input, built over `InfrastructureBytes`). External: the per-instruction logs emulator developers diff against each other — a fixed record, a register checksum, a full dump on demand — written here from scratch.

**Decisions made** (dated):
- 2026-11-07: a port is checked by diffing its trace against the reference's (the user's brief); the format is shared infrastructure under GPL-2.0-or-later (the user's call).

**Open calls:**
- [default: binary, little-endian; a 16-byte header (magic `ISTRACE1`, a format version, a record kind) then fixed 24-byte records — guest PC (u32), instruction word (u32), cycle count since reset (u64), and a 64-bit FNV-1a checksum over r1–r31, HI, LO and COP0's SR, CAUSE and EPC — plus a full-register record every 65,536 instructions and at every exception] The record.
- [default: the diff compares every field; a flag ignores cycle counts while timing is being ported, and the gate (2e) never uses it] What counts as a divergence.
- [default: a checkpoint is the full-register record every 1,048,576 instructions, written as one text line, so a whole boot's checkpoints are kilobytes] The checkpoint the gate commits.

**Guardrail(s).** Tests pin the encoding byte for byte against a hand-written record, the reader rejecting a truncated record and a wrong magic, and the diff naming the first differing record and field.

**Acceptance criteria:**
- [ ] `reference/cpu-trace-format.md` specifies the header, the records and the checkpoints, byte by byte.
- [ ] `DataTracing` writes and reads that format, finds the first divergence by field, and reduces a trace to checkpoints.
- [ ] Its tests pass; the layer checks pass with the new module in every place they look.
- [ ] Writing 100 million records and reading them back is measured, and the number recorded in MILESTONES.

**Scope note.** v0.0.1, track 2, first: no gate (it builds on shared infrastructure only). 2b writes this format from C++; 2c and 2d emit it from Swift; 2e diffs and commits checkpoints. Out of scope: per-frame VRAM, SPU and CD-ROM trace formats (v0.1.0 onward), and any disassembly in the diff (the reader prints raw instruction words).
