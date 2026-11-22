# The narrow interface: memory cards

**What / why.** Gap G8 of the design: memory cards live in the app, so a game's saves outlast the console (contract rows C33, C34). ProjectPSX has a memory card on the controller port (`Devices/Input/MemoryCard.cs`: 128 KB, `new byte[128 * 1024]` at `:12`), so the port device 6e ports is where cards plug in. ROADMAP v0.2.0's "Pads and memory cards" line owns this half. The app needs:
- **Insert:** a card's bytes, read from the card file, at power-on.
- **Read back:** the card's bytes when the console has changed them, written to its file.
- **What's on it:** the card's directory, how many of its 15 blocks are used, which the Memory Cards pane shows (5k).

**Core constraint(s).**
- **The clean room**: the card device comes only from ProjectPSX, iStation's own code and psx-spx ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework: the core holds and hands back bytes; files are the app's.
- A persisted format the apps write reads compatibly: the card file is the console's raw 131,072 bytes, so an older one always loads ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- No game data in the repository: card fixtures are built in code.

**Seam + files.**
- Business, `ps1`: the memory card on the port device (6e), `PS1Console.insertMemoryCard(slot:bytes:)`, `memoryCard(slot:) -> [UInt8]?`, `memoryCardChanged(slot:)`.
- Data, new module `memorycard`: reads a card's directory from its bytes (blocks used of 15, each save's block count).
- Business `session` (5b): writes a changed card back between frames.
- Tests: `tests/business/ps1/` (a program built in code writes a sector; the bytes come back changed); `tests/data/memorycard/` (directories built in code).

**Reference.** The design: contract rows C33 and C34 and gap G8 on the `Contract` board; `Mac-Cards` shows "3 of 15 blocks". ProjectPSX: `Devices/Input/MemoryCard.cs`. Public documentation: psx-spx's memory card data format.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the card file is the raw 131,072-byte image with a `.mcr` extension] It needs no version of its own: it is the console's own format.
- [default: the session writes a changed card back at most once a second and when play stops]

**Guardrail(s).** The hermetic tests above; a card written, read back and inserted again gives the guest the same bytes.

**Acceptance criteria:**
- [ ] Cards insert, change and read back through `PS1Console`, tested as above.
- [ ] The directory reader reports blocks used for code-built cards.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6, gated on 6e. Unblocks 5k and, with 6d, 6g.
