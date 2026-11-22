# The narrow interface: save states

**What / why.** **Split first.** Gap G7 of the design: the whole console saved at a moment and restored later (contract rows C31, C32). Save states are one of ADR 0015 §5's five crossings, and ROADMAP v0.2.0 lists "Save states, versioned". ProjectPSX has none, so this is iStation's own design. Every device must write and read its state:
- the CPU and its coprocessors;
- RAM and the memory map;
- the interrupt controller, timers and DMA;
- the GPU and VRAM (6b's split);
- the CD-ROM drive (6d's split);
- the ports and cards (6e, 6f);
- the GTE, SPU and MDEC (ROADMAP v0.2.0's second line).

Split before building: one document for the state format and `PS1Console`'s members (this one), then one per device group, each adding its part with a test.

**Core constraint(s).**
- **The clean room**: iStation's own code over the ported devices; no GPL emulator's save-state format is read or copied ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- A save state carries its version, and an older one is refused with a message; each released shape gets a recorded fixture its tests read, never edited ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- Business imports no Apple framework: the state is bytes the app writes.
- Saving and loading happen between frames, never inside the hot loop.

**Seam + files.**
- Business, `ps1`: `PS1Console.saveState() -> PS1SaveState` (format version and bytes); `loadState(_:) throws(PS1SaveStateError)` with `.unsupportedVersion(found:supported:)` and `.corrupt`. Each device gets a `write(to:)` and `read(from:)` over a small byte writer.
- Tests: `tests/business/ps1/` (round trip after a code-built program runs, identical following frames; a format 1 fixture refused by format 2 with both numbers).

**Reference.** The design: contract rows C31 and C32 and gap G7 on the `Contract` board; the refusal on `Mac-StatesVersionError` quotes `SaveStateError.unsupportedVersion(found: 1, supported: 2...2)`. In-house: TraceKit's versioned file header ([reference/trace-formats.md](../../../reference/darwin/trace-formats.md)) and DEVELOPER.md's "Adding a persisted format" recipe.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).

**Open calls:**
- [default: one little-endian byte stream with a header (magic, format version, console) and a section per device, each with its own length] A device added later appends a section, and an older loader can skip what it doesn't know only when the version allows it.
- [default: the split happens before anyone builds: the device groups above each get a document, ordered after the devices they serialize exist]
- [default: a save state is refused across formats, never migrated] The design refuses with both formats named.

**Guardrail(s).** A save, load and run-on test: after loading, the next N frames' RAM checksums equal those of an uninterrupted run, the way TraceKit's frame records compare runs. A fixture per released format.

**Acceptance criteria:**
- [ ] The split's documents exist, and every device in the console saves and loads its state.
- [ ] `saveState` and `loadState` round-trip and refuse other formats, tested as above.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6, split first, gated on 6d and 6f. Unblocks 5l.
