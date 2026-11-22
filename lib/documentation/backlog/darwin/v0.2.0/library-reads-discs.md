# The library reads discs

**What / why.** With the readers linked (6c), the library becomes the design's full one:
- **Console and Serial columns:** filled from each disc's SYSTEM.CNF, in place of "Unknown".
- **Format column:** ".cue · 2 tracks", ".m3u · 3 discs".
- **Sidebar:** PS1 (⌘2) and PS2 (⌘3) filters.
- **The scan job:** a "Read each disc" step, with a result per file. Added files say console and serial. Skipped ones say "Already in your library". Failed ones say why in plain words, with the backend's case beside them (`SystemCNF → nil`, `DiscError.truncated`, `DiscError.unreadable`).
- **PS2 discs:** listed with a "Plays later" chip and refused at Play with the reason, quoting `SystemCNF(text:) → console: .ps2`.

**Core constraint(s).**
- No disc image or game in the repository: fixtures in memory.
- `library.json` gains console and serial as defaulted fields; a library written by v0.1.0 keeps loading, from its recorded fixture ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- View-models import no UI toolkit.

**Seam + files.**
- Data `library`: console, serial, format detail, read when a game is added and again on Scan Again.
- Presentation `library`: the columns and filters, the scan's read step and results, the PS2 refusal through `DetailsAlert`.
- Tests: `tests/presentation/library/` over a fake identity service (each outcome); `tests/data/library/` (the v0.1.0 fixture still decodes).

**Reference.** The design: boards `Mac-Library`, `Mac-LibraryInspector`, `Mac-LibraryPs2`, `Mac-Ps2Refused`, `Mac-ScanRunning`, `Mac-ScanStopped` and `Mac-ScanDone`; contract rows C14–C17, C35, C36 and C53; the scripted flows "add a folder" and "refusals" in `tools/check.mjs`.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [user] PS2 discs before v2.x: list them and refuse them with the reason (designed), or hide them until PS2 plays?
- [default: a disc that fails to read is not added, and its result says why] Adding it would put an unplayable row in the library.

**Guardrail(s).** View-model tests for each scan outcome and the PS2 refusal; the store's fixture test across the version step.

**Acceptance criteria:**
- [ ] The library, inspector, filters, scan results and PS2 refusal match their boards.
- [ ] A library saved by v0.1.0 loads, and Scan Again fills in its discs' consoles and serials.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 5, gated on 6c and 5d. Playing a disc is 5i's.
