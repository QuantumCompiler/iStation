# The disc readers in a product, and a disc's identity

**What / why.** Gap G2 of the design. The library can say which console a disc is for and its serial (contract rows C14–C17, C35) only if the app can read the disc's SYSTEM.CNF. The readers exist and are tested:
- `ISO9660(url:)` reads 2,048- and 2,352-byte sectors and finds files, and throws `DiscError.unreadable`, `.notISO9660` or `.truncated`.
- `SystemCNF(text:)` reads the boot key: `BOOT2` means PS2, `BOOT` means PS1, and the serial is normalized (`SLUS-00594`).
- `Playlists.cueTracks(_:)` and `m3uEntries(_:)` resolve the files a .cue or .m3u names.

But they are in no product the apps link: the products are `PS1Core`, `EmuKit` and `TraceKit` (`lib/src/darwin/Package.swift:50–53`), and CLAUDE.md's codebase map says the readers "join a product with v0.2.0's discs". This item puts them in a product and adds the one composition the library needs: from a .cue, .iso or .m3u to a console and serial. Measured, not guessed, 2026-11-21: `swift test --filter 'SystemCNF|Playlists|ISO9660'` passed.

**Core constraint(s).**
- The layer law: Data modules depend only on Data and Infrastructure; each format reader stays one format, so the composition is its own module.
- Readers tolerate the unknown: a truncated or foreign file is `nil` or a thrown error, never a trap.
- No disc image in the repository: fixtures are built in memory in `SupportDiscFixtures`.

**Seam + files.**
- `Package.swift`: a product, `DiscKit`, with `DataISO9660`, `DataSystemCNF`, `DataPlaylists` and the new module.
- Data, new module `discidentity` (`Module(.data, "DiscIdentity", uses: ["DataISO9660", "DataSystemCNF", "DataPlaylists"])`): `DiscIdentity.read(url:) throws -> DiscIdentity?` returns the console, serial, format, track or disc count, and the files it reads. `nil` means no SYSTEM.CNF, which is "not a PS1 or PS2 game".
- Tests in `tests/data/discidentity/` over in-memory images: PS1 and PS2 boot lines, a non-standard executable with no serial, a .cue with two tracks, an .m3u of three discs, and each `DiscError`.

**Reference.** The design: contract rows C14–C17 and C35 and gap G2 on the `Contract` board; the scan results on `Mac-ScanDone` quote `SystemCNF → nil`, `DiscError.truncated` and `DiscError.unreadable` beside their plain words. In-house: `SystemCNF`'s own tests; `SupportDiscFixtures`.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: a `DiscKit` product rather than adding the readers to `EmuKit`] `EmuKit` is Presentation; the readers are Data.
- [default: identification reads the first data track of a .cue and the first entry of an .m3u]

**Guardrail(s).** The tests above, with `ArchitectureTests` checking the new module's row and edges.

**Acceptance criteria:**
- [ ] The apps can link `DiscKit`; `DiscIdentity.read(url:)` identifies PS1 and PS2 discs from .cue, .iso and .m3u fixtures and reports each failure as its `DiscError` or `nil`.
- [ ] The new module has its row, card line, ADR 0002 row, tests and scheme; CLAUDE.md's codebase map and the products line say so.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6. Unblocks 5h.
