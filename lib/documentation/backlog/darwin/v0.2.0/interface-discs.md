# The narrow interface: discs

**What / why.** **Split first.** Gap G9 of the design: the app inserts a disc into the console, swaps one on a multi-disc game, and ejects it (contract row C30). Today the console has a CD-ROM stub (`source/business/ps1/DeviceStubs.swift:15`), enough for the BIOS to reach its shell. ProjectPSX takes a disc's file name in its constructor and has a lid (`ProjectPSX/Core/ProjectPSX.cs:29, 75`). Its drive is `Devices/CDROM/CDROM.cs`, `CD.cs`, `Sector.cs` and `TrackBuilder.cs`, and its README names CD-ROM timing as missing. ROADMAP v0.2.0's first line already owns the drive and its timing fixes ("against psx-spx, test suites and SwanStation's recorded behaviour"). Split before building:
- **The CD-ROM drive and disc images**: its own document, from ROADMAP v0.2.0's first line, ported from ProjectPSX, its timing fixed against psx-spx and the oracle's recorded behaviour.
- **This document**: the interface members over the drive: `insertDisc(_:)`, `ejectDisc()`, the lid, and the `PS1Disc` value the app builds from a .cue, .iso or one entry of an .m3u.

**Core constraint(s).**
- **The clean room**: core code only from ProjectPSX, iStation's own code and public documentation; SwanStation is compared only by what is recorded from its runs ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework, so the core never opens a file: the app supplies sectors.
- Hot paths stay concrete ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §4): sector reads are per sector, never per instruction, with no protocol-typed value on the drive's own path.
- No disc image in the repository: tests build their sectors in memory.

**Seam + files.**
- Business, `ps1`: `PS1Console.insertDisc(_ disc: PS1Disc)`, `ejectDisc()`, `isLidOpen`. `PS1Disc` is a value with its track list and a sector-reading function the app supplies.
- The macOS app target: builds a `PS1Disc` from `DiscIdentity`'s files (6c), its sector-reading function reading the bookmarked file; Business `session` (5b: a Business module, decided 2026-11-22, importing only the standard library and Swift concurrency, its Core constraint) inserts it and never opens a file.
- Tests: `tests/business/ps1/` with in-memory discs (a data track, an audio track, two discs swapped).

**Reference.** The design: contract row C30 and gap G9 on the `Contract` board; the opening job on `Mac-PlayerOpening` ("Insert the disc", "Disc 1 of 3"). ProjectPSX: the files above, and `toggleCdRomLid()`. Public documentation: psx-spx's CD-ROM chapter.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the app supplies sectors through a function value stored once in `PS1Disc`, called once per sector] The core stays free of file I/O and Foundation.
- [default: swapping discs opens the lid, inserts the next disc and closes it, as a person would]
- [default: the split happens before anyone builds: the drive's document is written with `/istation-backlog-create-item` and takes its own v0.2.0 row ahead of this one]

**Guardrail(s).** Hermetic tests with in-memory discs: a sector read reaches the drive, a swap is seen by the guest as a lid open and close. The drive's own guardrails (timing against recorded oracle behaviour) are its document's.

**Acceptance criteria:**
- [ ] The split's documents exist, and the drive is built.
- [ ] `insertDisc`, `ejectDisc` and the lid work over in-memory discs as tested above.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6, split first. Unblocks 5i, and with 6f, 6g.
